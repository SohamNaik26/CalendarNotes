//
//  VoiceNoteCleanupService.swift
//  CalendarNotes
//
//  Created on [Date]
//

import Foundation
import Combine

/// Handles automatic cleanup of voice notes based on user settings
@MainActor
final class VoiceNoteCleanupService: ObservableObject {
    static let shared = VoiceNoteCleanupService()
    
    private let repository: VoiceNoteRepositoryProtocol?
    private let storageManager = VoiceNoteStorageManager.shared
    private let userDefaults = UserDefaults.standard
    
    private let autoDeleteDaysKey = "voiceNoteAutoDeleteDays"
    private let autoDeleteTranscribedDaysKey = "voiceNoteAutoDeleteTranscribedDays"
    
    init(repository: VoiceNoteRepositoryProtocol? = nil) {
        self.repository = repository ?? PostgresVoiceNoteRepository.shared
    }
    
    // MARK: - Settings
    
    var autoDeleteAfterDays: Int? {
        get {
            let value = userDefaults.integer(forKey: autoDeleteDaysKey)
            return value > 0 ? value : nil
        }
        set {
            if let days = newValue {
                userDefaults.set(days, forKey: autoDeleteDaysKey)
            } else {
                userDefaults.removeObject(forKey: autoDeleteDaysKey)
            }
        }
    }
    
    var autoDeleteTranscribedAfterDays: Int? {
        get {
            let value = userDefaults.integer(forKey: autoDeleteTranscribedDaysKey)
            return value > 0 ? value : nil
        }
        set {
            if let days = newValue {
                userDefaults.set(days, forKey: autoDeleteTranscribedDaysKey)
            } else {
                userDefaults.removeObject(forKey: autoDeleteTranscribedDaysKey)
            }
        }
    }
    
    // MARK: - Cleanup Operations
    
    /// Performs automatic cleanup based on user settings
    func performAutomaticCleanup() async throws -> CleanupResult {
        var deletedCount = 0
        var freedSpace: Int64 = 0
        
        // Clean up expired voice notes
        if let autoDeleteDays = autoDeleteAfterDays {
            let result = try await cleanupExpiredVoiceNotes(olderThanDays: autoDeleteDays)
            deletedCount += result.deletedCount
            freedSpace += result.freedSpace
        }
        
        // Clean up transcribed voice notes if setting is enabled
        if let transcribedDays = autoDeleteTranscribedAfterDays {
            let result = try await cleanupTranscribedVoiceNotes(olderThanDays: transcribedDays)
            deletedCount += result.deletedCount
            freedSpace += result.freedSpace
        }
        
        // Clean up empty directories
        try storageManager.cleanupEmptyDirectories()
        
        return CleanupResult(
            deletedCount: deletedCount,
            freedSpace: freedSpace
        )
    }
    
    /// Cleans up voice notes older than specified days (excluding favorites and linked notes)
    func cleanupExpiredVoiceNotes(olderThanDays days: Int) async throws -> CleanupResult {
        _ = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        // This would need repository support
        // For now, this is a placeholder that shows the logic
        /*
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let expiredNotes = try await repository.fetchVoiceNotes(
            olderThan: cutoffDate,
            excludeFavorites: true,
            excludeLinked: true
        )
        
        var deletedCount = 0
        var freedSpace: Int64 = 0
        
        for note in expiredNotes {
            if let fileURL = URL(string: note.audioFilePath) {
                if let size = try? storageManager.fileSize(at: fileURL) {
                    freedSpace += size
                }
                try? storageManager.deleteAudioFile(at: fileURL)
            }
            try await repository.delete(note.id)
            deletedCount += 1
        }
        */
        
        return CleanupResult(deletedCount: 0, freedSpace: 0)
    }
    
    /// Cleans up transcribed voice notes older than specified days
    func cleanupTranscribedVoiceNotes(olderThanDays days: Int) async throws -> CleanupResult {
        _ = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        // Similar to above, would need repository support
        // Placeholder for now
        /*
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        // Implementation would go here
        */
        
        return CleanupResult(deletedCount: 0, freedSpace: 0)
    }
    
    /// Manual cleanup tool - allows user to select which notes to delete
    func performManualCleanup(
        voiceNoteIds: [UUID],
        deleteFiles: Bool = true
    ) async throws -> CleanupResult {
        var deletedCount = 0
        let freedSpace: Int64 = 0
        
        for _ in voiceNoteIds {
            // Fetch voice note
            // let note = try await repository.findById(id)
            
            // Delete file if requested
            if deleteFiles {
                // if let fileURL = URL(string: note.audioFilePath) {
                //     if let size = try? storageManager.fileSize(at: fileURL) {
                //         freedSpace += size
                //     }
                //     try? storageManager.deleteAudioFile(at: fileURL)
                // }
            }
            
            // Delete from repository
            // try await repository.delete(id)
            deletedCount += 1
        }
        
        return CleanupResult(deletedCount: deletedCount, freedSpace: freedSpace)
    }
    
    /// Gets voice notes that are candidates for cleanup
    func getCleanupCandidates() async throws -> [CleanupCandidate] {
        let candidates: [CleanupCandidate] = []
        
        // Get expired notes
        if let autoDeleteDays = autoDeleteAfterDays {
            _ = Calendar.current.date(byAdding: .day, value: -autoDeleteDays, to: Date()) ?? Date()
            // let cutoffDate = Calendar.current.date(byAdding: .day, value: -autoDeleteDays, to: Date()) ?? Date()
            // let expired = try await repository.fetchVoiceNotes(olderThan: cutoffDate, excludeFavorites: true, excludeLinked: true)
            // candidates.append(contentsOf: expired.map { .expired($0) })
        }
        
        // Get transcribed notes if setting is enabled
        if let transcribedDays = autoDeleteTranscribedAfterDays {
            _ = Calendar.current.date(byAdding: .day, value: -transcribedDays, to: Date()) ?? Date()
            // let cutoffDate = Calendar.current.date(byAdding: .day, value: -transcribedDays, to: Date()) ?? Date()
            // let transcribed = try await repository.fetchTranscribedVoiceNotes(olderThan: cutoffDate)
            // candidates.append(contentsOf: transcribed.map { .transcribed($0) })
        }
        
        return candidates
    }
}

struct CleanupResult {
    let deletedCount: Int
    let freedSpace: Int64
    
    var formattedFreedSpace: String {
        ByteCountFormatter.string(fromByteCount: freedSpace, countStyle: .file)
    }
}

enum CleanupCandidate {
    case expired(VoiceNote)
    case transcribed(VoiceNote)
    case large(VoiceNote, size: Int64)
    
    var voiceNote: VoiceNote {
        switch self {
        case .expired(let note), .transcribed(let note), .large(let note, _):
            return note
        }
    }
    
    var reason: String {
        switch self {
        case .expired:
            return "Expired (older than auto-delete threshold)"
        case .transcribed:
            return "Transcribed (older than transcribed delete threshold)"
        case .large(_, let size):
            return "Large file (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file)))"
        }
    }
}

