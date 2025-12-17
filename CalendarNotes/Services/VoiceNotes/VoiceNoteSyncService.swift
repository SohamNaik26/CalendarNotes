//
//  VoiceNoteSyncService.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import Combine
import CryptoKit
import Network

/// Main service for voice notes synchronization with cloud storage
@MainActor
final class VoiceNoteSyncService: ObservableObject {
    static let shared = VoiceNoteSyncService()
    
    @Published private(set) var isSyncing = false
    @Published private(set) var uploadProgress: [UUID: Double] = [:]
    @Published private(set) var downloadProgress: [UUID: Double] = [:]
    @Published private(set) var syncStatus: [UUID: SyncStatus] = [:]
    
    private let repository = PostgresVoiceNoteRepository.shared
    private let storageManager = VoiceNoteStorageManager.shared
    private let compressionService = VoiceNoteCompressionService.shared
    private let userDefaults = UserDefaults.standard
    
    private var storageProvider: CloudStorageProvider?
    private var uploadQueue: [UploadQueueItem] = []
    private var cancellables = Set<AnyCancellable>()
    private let connectivityMonitor = ConnectivityMonitor.shared
    
    enum SyncStatus: String, Codable {
        case pending = "pending"
        case uploading = "uploading"
        case downloading = "downloading"
        case synced = "synced"
        case failed = "failed"
        case conflict = "conflict"
    }
    
    private init() {
        loadUploadQueue()
        bindConnectivity()
        startQueueProcessor()
    }
    
    // MARK: - Configuration
    
    func configure(provider: CloudStorageProvider) {
        self.storageProvider = provider
    }
    
    // MARK: - Upload Flow
    
    /// Records a voice note and adds it to the upload queue
    func recordAndQueueUpload(
        voiceNoteId: UUID,
        audioFileURL: URL,
        metadata: VoiceNoteMetadata
    ) async throws {
        // 1. Save to local storage immediately
        let savedURL = try storageManager.saveAudioFile(from: audioFileURL)
        
        // 2. Add to upload queue
        let queueItem = UploadQueueItem(
            voiceNoteId: voiceNoteId,
            localFileURL: savedURL,
            metadata: metadata,
            createdAt: Date(),
            retryCount: 0
        )
        
        uploadQueue.append(queueItem)
        saveUploadQueue()
        syncStatus[voiceNoteId] = .pending
        
        // 3. Upload if network available
        if await isNetworkAvailable() && shouldAutoUpload() {
            try await uploadVoiceNote(voiceNoteId: voiceNoteId)
        }
    }
    
    /// Uploads a voice note to cloud storage
    func uploadVoiceNote(voiceNoteId: UUID) async throws {
        guard let provider = storageProvider else {
            throw SyncError.providerNotConfigured
        }
        
        guard let queueItem = uploadQueue.first(where: { $0.voiceNoteId == voiceNoteId }) else {
            throw SyncError.voiceNoteNotFound
        }
        
        // Check WiFi-only setting
        if shouldUseWiFiOnly() {
            let isWiFi = await isWiFiConnected()
            if !isWiFi {
                throw SyncError.wifiRequired
            }
        }
        
        syncStatus[voiceNoteId] = .uploading
        uploadProgress[voiceNoteId] = 0.0
        
        do {
            // Compress if enabled
            let fileURL = queueItem.localFileURL
            let uploadURL: URL
            
            if shouldCompressBeforeUpload() {
                let tempURL = try storageManager.generateFilePath()
                let result = try await compressionService.compressAudio(
                    at: fileURL,
                    to: tempURL,
                    preset: .standard
                )
                uploadURL = tempURL
                print("Compressed voice note: \(result.compressionRatio * 100)% of original size")
            } else {
                uploadURL = fileURL
            }
            
            // Generate cloud key
            let key = generateCloudKey(voiceNoteId: voiceNoteId)
            
            // Upload to cloud
            let cloudURL = try await provider.upload(
                fileURL: uploadURL,
                key: key,
                contentType: "audio/m4a",
                progressHandler: { [weak self] progress in
                    Task { @MainActor in
                        self?.uploadProgress[voiceNoteId] = progress
                    }
                }
            )
            
            // Update database with cloud URL
            _ = try await repository.updateCloudSyncStatus(
                id: voiceNoteId,
                status: SyncStatus.synced.rawValue,
                cloudStorageURL: cloudURL
            )
            
            // Optionally delete local file to save space
            if shouldDeleteLocalAfterUpload() {
                try? storageManager.deleteAudioFile(at: fileURL)
            }
            
            // Remove from queue
            uploadQueue.removeAll { $0.voiceNoteId == voiceNoteId }
            saveUploadQueue()
            
            syncStatus[voiceNoteId] = .synced
            uploadProgress[voiceNoteId] = 1.0
            
        } catch {
            // Retry logic
            var updatedItem = queueItem
            updatedItem.retryCount += 1
            
            if updatedItem.retryCount < maxRetryAttempts() {
                // Update queue item with new retry count
                if let index = uploadQueue.firstIndex(where: { $0.voiceNoteId == voiceNoteId }) {
                    uploadQueue[index] = updatedItem
                    saveUploadQueue()
                }
                
                // Schedule retry
                syncStatus[voiceNoteId] = .pending
                scheduleRetry(voiceNoteId: voiceNoteId, delay: retryDelay(for: updatedItem.retryCount))
            } else {
                syncStatus[voiceNoteId] = .failed
                throw error
            }
        }
    }
    
    // MARK: - Download Flow
    
    /// Downloads a voice note from cloud storage
    func downloadVoiceNote(voiceNoteId: UUID) async throws {
        guard let provider = storageProvider else {
            throw SyncError.providerNotConfigured
        }
        
        guard let voiceNote = try await repository.findById(id: voiceNoteId) else {
            throw SyncError.voiceNoteNotFound
        }
        
        guard let cloudURL = voiceNote.cloudStorageURL else {
            throw SyncError.cloudURLNotFound
        }
        
        // Check if file exists locally
        let localURL = URL(fileURLWithPath: voiceNote.audioFilePath)
        if storageManager.fileExists(at: localURL) {
            // File already exists locally
            return
        }
        
        syncStatus[voiceNoteId] = .downloading
        downloadProgress[voiceNoteId] = 0.0
        
        do {
            // Generate local path
            let destinationURL = try storageManager.generateFilePath(for: voiceNote.createdAt)
            
            // Download from cloud
            try await provider.download(
                from: cloudURL,
                to: destinationURL,
                progressHandler: { [weak self] progress in
                    Task { @MainActor in
                        self?.downloadProgress[voiceNoteId] = progress
                    }
                }
            )
            
            // Update database with local path
            // Note: This would require a repository method to update audio_file_path
            // For now, we'll just mark as downloaded
            
            syncStatus[voiceNoteId] = .synced
            downloadProgress[voiceNoteId] = 1.0
            
        } catch {
            syncStatus[voiceNoteId] = .failed
            throw error
        }
    }
    
    /// Streams a voice note (downloads on-demand when playing)
    func streamVoiceNote(voiceNoteId: UUID) async throws -> URL {
        guard let provider = storageProvider else {
            throw SyncError.providerNotConfigured
        }
        
        guard let voiceNote = try await repository.findById(id: voiceNoteId) else {
            throw SyncError.voiceNoteNotFound
        }
        
        // Check local cache first
        let localURL = URL(fileURLWithPath: voiceNote.audioFilePath)
        if storageManager.fileExists(at: localURL) {
            return localURL
        }
        
        // Check if cloud URL available
        guard voiceNote.cloudStorageURL != nil else {
            throw SyncError.cloudURLNotFound
        }
        
        // Generate presigned URL for streaming
        let key = generateCloudKey(voiceNoteId: voiceNoteId)
        let presignedURL = try await provider.generatePresignedURL(for: key, expiresIn: 3600)
        
        // For streaming, we return the presigned URL
        // The player can stream directly from this URL
        return URL(string: presignedURL)!
    }
    
    // MARK: - Sync Metadata
    
    /// Syncs voice note metadata to PostgreSQL
    func syncMetadata(voiceNoteId: UUID) async throws {
        guard let voiceNote = try await repository.findById(id: voiceNoteId) else {
            throw SyncError.voiceNoteNotFound
        }
        
        // Metadata is already in PostgreSQL via the repository
        // This method can be used to sync metadata changes to other devices
        // For now, it's a placeholder for future multi-device sync
        
        _ = try await repository.updateCloudSyncStatus(
            id: voiceNoteId,
            status: SyncStatus.synced.rawValue,
            cloudStorageURL: voiceNote.cloudStorageURL
        )
    }
    
    /// Syncs transcriptions
    func syncTranscription(voiceNoteId: UUID, transcription: String) async throws {
        _ = try await repository.updateTranscription(id: voiceNoteId, transcription: transcription)
    }
    
    // MARK: - Conflict Resolution
    
    /// Resolves sync conflicts between local and cloud versions
    func resolveConflict(voiceNoteId: UUID, strategy: ConflictResolutionStrategy) async throws {
        guard let provider = storageProvider else {
            throw SyncError.providerNotConfigured
        }
        
        guard let localNote = try await repository.findById(id: voiceNoteId) else {
            throw SyncError.voiceNoteNotFound
        }
        
        let localURL = URL(fileURLWithPath: localNote.audioFilePath)
        let localHash = try await calculateFileHash(fileURL: localURL)
        
        // Get cloud metadata
        let key = generateCloudKey(voiceNoteId: voiceNoteId)
        let cloudMetadata = try await provider.getMetadata(key: key)
        
        // Compare hashes
        if let cloudEtag = cloudMetadata.etag, cloudEtag == localHash {
            // Files are identical, no conflict
            syncStatus[voiceNoteId] = .synced
            return
        }
        
        // Conflict detected - resolve based on strategy
        switch strategy {
        case .keepBoth:
            // Keep both versions with different IDs
            // This would require creating a duplicate with a new ID
            break
            
        case .keepLocal:
            // Upload local version to cloud
            try await uploadVoiceNote(voiceNoteId: voiceNoteId)
            
        case .keepCloud:
            // Download cloud version
            try await downloadVoiceNote(voiceNoteId: voiceNoteId)
            
        case .mergeMetadata:
            // Merge metadata (combine tags, links, etc.)
            // Keep local file, merge metadata from cloud
            // This would require fetching cloud metadata
            break
            
        case .lastWriteWins:
            // Compare timestamps
            if let cloudModified = cloudMetadata.lastModified,
               cloudModified > localNote.updatedAt {
                // Cloud is newer
                try await downloadVoiceNote(voiceNoteId: voiceNoteId)
            } else {
                // Local is newer
                try await uploadVoiceNote(voiceNoteId: voiceNoteId)
            }
        }
        
        syncStatus[voiceNoteId] = .synced
    }
    
    enum ConflictResolutionStrategy {
        case keepBoth
        case keepLocal
        case keepCloud
        case mergeMetadata
        case lastWriteWins
    }
    
    // MARK: - Queue Management
    
    private func startQueueProcessor() {
        Task {
            while true {
                if await isNetworkAvailable() && shouldAutoUpload() {
                    await processUploadQueue()
                }
                try? await Task.sleep(nanoseconds: 30_000_000_000) // 30 seconds
            }
        }
    }
    
    private func processUploadQueue() async {
        guard !uploadQueue.isEmpty else { return }
        
        for item in uploadQueue {
            do {
                try await uploadVoiceNote(voiceNoteId: item.voiceNoteId)
            } catch {
                print("Failed to upload queued item \(item.voiceNoteId): \(error)")
            }
        }
    }
    
    private func scheduleRetry(voiceNoteId: UUID, delay: TimeInterval) {
        Task {
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            try? await uploadVoiceNote(voiceNoteId: voiceNoteId)
        }
    }
    
    // MARK: - Settings
    
    private func shouldAutoUpload() -> Bool {
        userDefaults.bool(forKey: "voiceNotes.autoUpload")
    }
    
    private func shouldUseWiFiOnly() -> Bool {
        userDefaults.bool(forKey: "voiceNotes.wifiOnlyUpload")
    }
    
    private func shouldCompressBeforeUpload() -> Bool {
        userDefaults.bool(forKey: "voiceNotes.compressBeforeUpload")
    }
    
    private func shouldDeleteLocalAfterUpload() -> Bool {
        userDefaults.bool(forKey: "voiceNotes.deleteLocalAfterUpload")
    }
    
    private func shouldAutoDownload() -> Bool {
        userDefaults.bool(forKey: "voiceNotes.autoDownload")
    }
    
    private func maxRetryAttempts() -> Int {
        userDefaults.integer(forKey: "voiceNotes.maxRetryAttempts").clamped(to: 1...10)
    }
    
    private func retryDelay(for attempt: Int) -> TimeInterval {
        // Exponential backoff: 1s, 2s, 4s, 8s, 16s, etc.
        return min(pow(2.0, Double(attempt)), 300) // Max 5 minutes
    }
    
    // MARK: - Helpers
    
    private func generateCloudKey(voiceNoteId: UUID) -> String {
        // Generate a unique key for cloud storage
        // Format: voice-notes/{userId}/{voiceNoteId}.m4a
        let userId = getCurrentUserId() // This would need to be implemented
        return "voice-notes/\(userId.uuidString)/\(voiceNoteId.uuidString).m4a"
    }
    
    private func getCurrentUserId() -> UUID {
        // This should get the current user ID from auth
        // For now, return a placeholder
        if let userIdString = userDefaults.string(forKey: "currentUserId"),
           let userId = UUID(uuidString: userIdString) {
            return userId
        }
        return UUID() // Placeholder
    }
    
    private func calculateFileHash(fileURL: URL) async throws -> String {
        let data = try Data(contentsOf: fileURL)
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func isNetworkAvailable() async -> Bool {
        return await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "NetworkMonitor")
            
            monitor.pathUpdateHandler = { path in
                let isAvailable = path.status == .satisfied
                monitor.cancel()
                continuation.resume(returning: isAvailable)
            }
            
            monitor.start(queue: queue)
        }
    }
    
    private func isWiFiConnected() async -> Bool {
        return await withCheckedContinuation { continuation in
            let monitor = NWPathMonitor()
            let queue = DispatchQueue(label: "NetworkMonitor")
            
            monitor.pathUpdateHandler = { path in
                let isWiFi = path.usesInterfaceType(.wifi)
                monitor.cancel()
                continuation.resume(returning: isWiFi)
            }
            
            monitor.start(queue: queue)
        }
    }
    
    private func bindConnectivity() {
        connectivityMonitor.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] path in
                guard let self = self else { return }
                if path.status == .satisfied && self.shouldAutoUpload() {
                    Task {
                        await self.processUploadQueue()
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Queue Persistence
    
    private func saveUploadQueue() {
        if let encoded = try? JSONEncoder().encode(uploadQueue) {
            userDefaults.set(encoded, forKey: "voiceNotes.uploadQueue")
        }
    }
    
    private func loadUploadQueue() {
        if let data = userDefaults.data(forKey: "voiceNotes.uploadQueue"),
           let decoded = try? JSONDecoder().decode([UploadQueueItem].self, from: data) {
            uploadQueue = decoded
        }
    }
}

// MARK: - Upload Queue Item

struct UploadQueueItem: Codable {
    let voiceNoteId: UUID
    let localFileURL: URL
    let metadata: VoiceNoteMetadata
    let createdAt: Date
    var retryCount: Int
}

extension UploadQueueItem {
    enum CodingKeys: String, CodingKey {
        case voiceNoteId
        case localFileURL
        case metadata
        case createdAt
        case retryCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        voiceNoteId = try container.decode(UUID.self, forKey: .voiceNoteId)
        let path = try container.decode(String.self, forKey: .localFileURL)
        localFileURL = URL(fileURLWithPath: path)
        metadata = try container.decode(VoiceNoteMetadata.self, forKey: .metadata)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        retryCount = try container.decode(Int.self, forKey: .retryCount)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(voiceNoteId, forKey: .voiceNoteId)
        try container.encode(localFileURL.path, forKey: .localFileURL)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(retryCount, forKey: .retryCount)
    }
}

enum SyncError: LocalizedError {
    case providerNotConfigured
    case voiceNoteNotFound
    case cloudURLNotFound
    case uploadFailed
    case downloadFailed
    case wifiRequired
    
    var errorDescription: String? {
        switch self {
        case .providerNotConfigured:
            return "Cloud storage provider is not configured"
        case .voiceNoteNotFound:
            return "Voice note not found"
        case .cloudURLNotFound:
            return "Cloud storage URL not found"
        case .uploadFailed:
            return "Failed to upload voice note"
        case .downloadFailed:
            return "Failed to download voice note"
        case .wifiRequired:
            return "WiFi connection required for upload"
        }
    }
}

extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        return Swift.max(range.lowerBound, Swift.min(range.upperBound, self))
    }
}

