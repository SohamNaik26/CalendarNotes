//
//  OfflineDownloadManager.swift
//  CalendarNotes
//
//  Created by Cursor AI on 08/11/25.
//

import Foundation
import CoreData

final class OfflineDownloadManager {
    static let shared = OfflineDownloadManager()
    
    private let userDefaults = UserDefaults.standard
    private let storageKey = "offlineBookmarkIDs"
    private let metadataKey = "offlineBookmarkMetadata"
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
    }
    
    var offlineBookmarkIDs: Set<String> {
        if let values = userDefaults.array(forKey: storageKey) as? [String] {
            return Set(values)
        }
        return []
    }
    
    func isOfflineAvailable(bookmarkID: String) -> Bool {
        offlineBookmarkIDs.contains(bookmarkID)
    }
    
    func toggleOffline(for bookmark: Bookmark, enable: Bool) {
        let bookmarkID = bookmark.objectID.uriRepresentation().absoluteString
        var ids = offlineBookmarkIDs
        if enable {
            ids.insert(bookmarkID)
            cacheMetadataIfNeeded(for: bookmark)
        } else {
            ids.remove(bookmarkID)
            removeCachedAssets(for: bookmarkID)
        }
        userDefaults.set(Array(ids), forKey: storageKey)
        updateMetadata(for: bookmarkID, enable: enable)
    }
    
    func cacheMetadataIfNeeded(for bookmark: Bookmark) {
        guard let urlString = bookmark.url else { return }
        let metadata = [
            "title": bookmark.title ?? "",
            "url": urlString,
            "cachedAt": Date().timeIntervalSince1970
        ] as [String: Any]
        let bookmarkID = bookmark.objectID.uriRepresentation().absoluteString
        storeMetadata(metadata, for: bookmarkID)
    }
    
    func totalOfflineSize() -> Int64 {
        guard let metadataData = userDefaults.data(forKey: metadataKey),
              let metadata = try? decoder.decode([String: OfflineBookmarkMetadata].self, from: metadataData) else {
            return 0
        }
        return metadata.values.reduce(0) { $0 + $1.estimatedSize }
    }
    
    func manageStorage(maximumSize: Int64) {
        guard totalOfflineSize() > maximumSize else { return }
        removeOldDownloads(keeping: maximumSize)
    }
    
    func removeOldDownloads(keeping maximumSize: Int64) {
        guard var metadata = loadMetadataDictionary() else { return }
        let sorted = metadata.values.sorted { $0.lastAccessed < $1.lastAccessed }
        var currentSize = sorted.reduce(0) { $0 + $1.estimatedSize }
        var idsToRemove: [String] = []
        for item in sorted where currentSize > maximumSize {
            idsToRemove.append(item.bookmarkID)
            currentSize -= item.estimatedSize
        }
        idsToRemove.forEach { id in
            removeCachedAssets(for: id)
            metadata[id] = nil
        }
        saveMetadataDictionary(metadata)
        var ids = offlineBookmarkIDs
        ids.subtract(idsToRemove)
        userDefaults.set(Array(ids), forKey: storageKey)
    }
    
    func markAccess(for bookmarkID: String) {
        guard var metadata = loadMetadataDictionary(),
              var entry = metadata[bookmarkID] else { return }
        entry.lastAccessed = Date()
        metadata[bookmarkID] = entry
        saveMetadataDictionary(metadata)
    }
    
    private func updateMetadata(for bookmarkID: String, enable: Bool) {
        var metadata = loadMetadataDictionary() ?? [:]
        if enable {
            let entry = metadata[bookmarkID] ?? OfflineBookmarkMetadata(bookmarkID: bookmarkID)
            metadata[bookmarkID] = entry
        } else {
            metadata[bookmarkID] = nil
        }
        saveMetadataDictionary(metadata)
    }
    
    private func storeMetadata(_ payload: [String: Any], for bookmarkID: String) {
        var metadata = loadMetadataDictionary() ?? [:]
        var entry = metadata[bookmarkID] ?? OfflineBookmarkMetadata(bookmarkID: bookmarkID)
        entry.title = payload["title"] as? String ?? ""
        entry.url = payload["url"] as? String ?? ""
        entry.cachedAt = Date()
        metadata[bookmarkID] = entry
        saveMetadataDictionary(metadata)
    }
    
    private func removeCachedAssets(for bookmarkID: String) {
        let directory = cacheDirectory.appendingPathComponent("bookmark-\(bookmarkID.safeFileName)")
        try? fileManager.removeItem(at: directory)
    }
    
    private func loadMetadataDictionary() -> [String: OfflineBookmarkMetadata]? {
        guard let data = userDefaults.data(forKey: metadataKey) else { return nil }
        return try? decoder.decode([String: OfflineBookmarkMetadata].self, from: data)
    }
    
    private func saveMetadataDictionary(_ metadata: [String: OfflineBookmarkMetadata]) {
        if let data = try? encoder.encode(metadata) {
            userDefaults.set(data, forKey: metadataKey)
        }
    }
}

private struct OfflineBookmarkMetadata: Codable {
    let bookmarkID: String
    var title: String = ""
    var url: String = ""
    var cachedAt: Date = Date()
    var lastAccessed: Date = Date()
    var estimatedSize: Int64 = 512_000 // default 500 KB
}

private extension String {
    var safeFileName: String {
        components(separatedBy: CharacterSet.alphanumerics.inverted).joined()
    }
}


