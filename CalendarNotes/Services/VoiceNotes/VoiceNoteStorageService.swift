//
//  VoiceNoteStorageService.swift
//  CalendarNotes
//
//  Created on [Date]
//

import Foundation
import Combine

/// Manages storage quotas, usage tracking, and warnings for voice notes
@MainActor
final class VoiceNoteStorageService: ObservableObject {
    static let shared = VoiceNoteStorageService()
    
    @Published private(set) var totalStorageUsed: Int64 = 0
    @Published private(set) var storageQuota: Int64 = 100 * 1024 * 1024 // 100 MB default
    @Published private(set) var storageUsagePercentage: Double = 0.0
    @Published private(set) var isNearQuota: Bool = false
    @Published private(set) var isOverQuota: Bool = false
    
    private let storageManager = VoiceNoteStorageManager.shared
    private let repository: VoiceNoteRepositoryProtocol?
    private let userDefaults = UserDefaults.standard
    
    private let quotaWarningThreshold: Double = 0.85 // Warn at 85% of quota
    private let quotaKey = "voiceNoteStorageQuota"
    
    enum StorageQuota: Int64, CaseIterable {
        case small = 104857600   // 100 MB
        case medium = 524288000  // 500 MB
        case large = 1073741824  // 1 GB
        
        var displayName: String {
            switch self {
            case .small: return "100 MB"
            case .medium: return "500 MB"
            case .large: return "1 GB"
            }
        }
    }
    
    init(repository: VoiceNoteRepositoryProtocol? = nil) {
        self.repository = repository ?? PostgresVoiceNoteRepository.shared
        loadQuota()
        Task {
            await refreshStorageUsage()
        }
    }
    
    // MARK: - Quota Management
    
    func setQuota(_ quota: StorageQuota) {
        storageQuota = quota.rawValue
        userDefaults.set(quota.rawValue, forKey: quotaKey)
        updateQuotaStatus()
    }
    
    func setCustomQuota(_ bytes: Int64) {
        storageQuota = bytes
        userDefaults.set(bytes, forKey: quotaKey)
        updateQuotaStatus()
    }
    
    private func loadQuota() {
        if let savedQuota = userDefaults.object(forKey: quotaKey) as? Int64 {
            storageQuota = savedQuota
        } else {
            storageQuota = StorageQuota.small.rawValue
        }
        updateQuotaStatus()
    }
    
    // MARK: - Storage Usage
    
    func refreshStorageUsage() async {
        do {
            totalStorageUsed = try await calculateTotalStorageUsed()
            updateQuotaStatus()
        } catch {
            print("Failed to calculate storage usage: \(error)")
        }
    }
    
    private func calculateTotalStorageUsed() async throws -> Int64 {
        // Get all voice note files
        let files = try storageManager.getAllVoiceNoteFiles()
        var totalSize: Int64 = 0
        
        for file in files {
            do {
                let size = try storageManager.fileSize(at: file)
                totalSize += size
            } catch {
                // Skip files that can't be read
                continue
            }
        }
        
        return totalSize
    }
    
    private func updateQuotaStatus() {
        storageUsagePercentage = storageQuota > 0 ? Double(totalStorageUsed) / Double(storageQuota) : 0.0
        isNearQuota = storageUsagePercentage >= quotaWarningThreshold && !isOverQuota
        isOverQuota = totalStorageUsed >= storageQuota
    }
    
    // MARK: - Storage Info
    
    func formattedStorageUsed() -> String {
        return ByteCountFormatter.string(fromByteCount: totalStorageUsed, countStyle: .file)
    }
    
    func formattedStorageQuota() -> String {
        return ByteCountFormatter.string(fromByteCount: storageQuota, countStyle: .file)
    }
    
    func formattedStorageAvailable() -> String {
        let available = max(0, storageQuota - totalStorageUsed)
        return ByteCountFormatter.string(fromByteCount: available, countStyle: .file)
    }
    
    // MARK: - Quota Checks
    
    func canStoreFile(of size: Int64) -> Bool {
        return (totalStorageUsed + size) <= storageQuota
    }
    
    func spaceNeededForFile(of size: Int64) -> Int64 {
        let needed = (totalStorageUsed + size) - storageQuota
        return max(0, needed)
    }
    
    // MARK: - Cleanup Recommendations
    
    func getCleanupRecommendations() async throws -> [CleanupRecommendation] {
        var recommendations: [CleanupRecommendation] = []
        
        // Check for old voice notes
        _ = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        // This would need repository support - placeholder for now
        // let thirtyDaysAgo = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        // let oldNotes = try await repository.fetchVoiceNotes(olderThan: thirtyDaysAgo)
        
        // Check for large files
        let files = try storageManager.getAllVoiceNoteFiles()
        var largeFiles: [(URL, Int64)] = []
        
        for file in files {
            if let size = try? storageManager.fileSize(at: file), size > 10 * 1024 * 1024 { // > 10 MB
                largeFiles.append((file, size))
            }
        }
        
        if !largeFiles.isEmpty {
            let totalSize = largeFiles.reduce(0) { $0 + $1.1 }
            recommendations.append(.largeFiles(count: largeFiles.count, totalSize: totalSize))
        }
        
        return recommendations
    }
}

enum CleanupRecommendation {
    case oldNotes(count: Int, totalSize: Int64)
    case largeFiles(count: Int, totalSize: Int64)
    case transcribedNotes(count: Int, totalSize: Int64)
    
    var description: String {
        switch self {
        case .oldNotes(let count, let size):
            return "\(count) old voice notes (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)))"
        case .largeFiles(let count, let size):
            return "\(count) large files (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)))"
        case .transcribedNotes(let count, let size):
            return "\(count) transcribed notes (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)))"
        }
    }
}

protocol VoiceNoteRepositoryProtocol {
    func findById(id: UUID) async throws -> VoiceNoteModel?
    func findByUserId(_ userId: UUID, limit: Int, offset: Int) async throws -> [VoiceNoteModel]
}

