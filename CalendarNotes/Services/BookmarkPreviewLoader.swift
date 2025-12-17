import Foundation
import CoreData
import Network

struct BookmarkPreviewRequest: @unchecked Sendable {
    let objectID: NSManagedObjectID
    let url: String?
    let existingPreview: Data?
    let existingFavicon: Data?
}

actor BookmarkPreviewLoader {
    struct PreviewResult {
        let thumbnailData: Data?
        let faviconData: Data?
        let metadata: BookmarkPageMetadata?
        let previewFileName: String?
    }
    
    nonisolated static let shared = BookmarkPreviewLoader()
    
    private let previewIndex = BookmarkPreviewIndex.shared
    private var inFlightTasks: [NSManagedObjectID: Task<PreviewResult, Never>] = [:]
    
    func assets(for request: BookmarkPreviewRequest) async -> PreviewResult {
        let objectID = request.objectID
        if let task = inFlightTasks[objectID] {
            return await task.value
        }
        let task = Task<PreviewResult, Never> {
            await self.loadAssets(for: request)
        }
        inFlightTasks[objectID] = task
        let value = await task.value
        inFlightTasks[objectID] = nil
        return value
    }
    
    private func loadAssets(for request: BookmarkPreviewRequest) async -> PreviewResult {
        let objectID = request.objectID
        var thumbnailData: Data? = request.existingPreview
        var faviconData: Data? = request.existingFavicon
        var metadata: BookmarkPageMetadata?
        var previewFileName: String? = await previewIndex.fileName(for: objectID)
        let host = URL(string: request.url ?? "")?.host
        let service = await bookmarkService()
        let autoFetchMetadata = await MainActor.run { BookmarkPreferenceStore.autoFetchMetadata }
        let downloadMode = await MainActor.run { BookmarkPreferenceStore.previewDownloadMode }
        let allowImageDownloads = await shouldDownloadImages(for: downloadMode)
        
        if thumbnailData == nil, let fileName = previewFileName, let cached = await cachedPreview(named: fileName, service: service) {
            thumbnailData = cached
        }
        if faviconData == nil, let host = host, let cachedFavicon = await cachedFavicon(for: host, service: service) {
            faviconData = cachedFavicon
        }
        
        let needsMetadata = autoFetchMetadata && (thumbnailData == nil || faviconData == nil)
        if needsMetadata, let urlString = request.url, let url = URL(string: urlString) {
            do {
                let fetchedMetadata = try await service.fetchMetadata(for: url)
                metadata = fetchedMetadata
                if allowImageDownloads, thumbnailData == nil, let imageURL = fetchedMetadata.imageURL {
                    if let (fileURL, fileName) = await service.cachePreviewImage(from: imageURL, maxSize: 960) {
                        previewFileName = fileName
                        await previewIndex.setFileName(fileName, for: objectID)
                        thumbnailData = await cachedPreview(named: fileName, service: service) ?? (try? Data(contentsOf: fileURL))
                    }
                }
                if allowImageDownloads, faviconData == nil {
                    let targetHost = host ?? fetchedMetadata.faviconURL?.host
                    if let faviconURL = fetchedMetadata.faviconURL, let host = targetHost {
                        if let savedURL = await service.cacheFavicon(from: faviconURL, for: host) {
                            faviconData = try? Data(contentsOf: savedURL)
                        } else if let cached = await cachedFavicon(for: host, service: service) {
                            faviconData = cached
                        }
                    }
                }
            } catch {
                // Metadata fetch failures are non-fatal for UI purposes.
            }
        }
        
        let thumbnailForPersistence = request.existingPreview ?? thumbnailData
        let thumbnailForDisplay = thumbnailData ?? thumbnailForPersistence
        let coreData = await coreDataManager()
        await coreData.updateBookmarkAssets(
            objectID: objectID,
            previewData: thumbnailForPersistence,
            faviconData: faviconData,
            title: metadata?.title,
            description: metadata?.description,
            contentType: metadata?.contentType,
            contentSubtype: metadata?.contentSubtype,
            contentMetadata: metadata?.contentMetadata
        )
        return PreviewResult(
            thumbnailData: thumbnailForDisplay,
            faviconData: faviconData,
            metadata: metadata,
            previewFileName: previewFileName
        )
    }

    private func bookmarkService() async -> BookmarkService {
        await MainActor.run { BookmarkService.shared }
    }
    
    private func cachedPreview(named fileName: String, service: BookmarkService) async -> Data? {
        await MainActor.run { service.cachedPreview(named: fileName) }
    }
    
    private func cachedFavicon(for host: String, service: BookmarkService) async -> Data? {
        await MainActor.run { service.cachedFavicon(for: host) }
    }

    private func shouldDownloadImages(for mode: BookmarkPreviewDownloadMode) async -> Bool {
        switch mode {
        case .always:
            return true
        case .never:
            return false
        case .wifiOnly:
            let path = await MainActor.run { ConnectivityMonitor.shared.currentPath }
            guard let path else { return false }
            if #available(macOS 10.15, iOS 13.0, *) {
                if path.isExpensive { return false }
                if path.usesInterfaceType(.wifi) { return true }
                return !path.isExpensive
            } else {
                return true
            }
        }
    }

    private func coreDataManager() async -> CoreDataManager {
        await MainActor.run { CoreDataManager.shared }
    }

}
