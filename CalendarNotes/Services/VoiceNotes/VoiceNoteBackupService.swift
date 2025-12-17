//
//  VoiceNoteBackupService.swift
//  CalendarNotes
//
//  Created on [Date]
//

import Foundation
import UniformTypeIdentifiers
#if os(macOS)
import Foundation
#endif

/// Handles backup and restore of voice notes with metadata
final class VoiceNoteBackupService {
    static let shared = VoiceNoteBackupService()
    
    private let storageManager = VoiceNoteStorageManager.shared
    private let fileManager = FileManager.default
    
    private init() {}
    
    // MARK: - Export
    
    /// Exports voice notes with metadata to a backup file
    func exportVoiceNotes(
        voiceNoteIds: [UUID]? = nil, // nil = export all
        includeAudioFiles: Bool = true
    ) async throws -> URL {
        // Create temporary directory for backup
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("VoiceNotesBackup_\(UUID().uuidString)")
        
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        // Export metadata
        _ = tempDir.appendingPathComponent("metadata.json")
        // This would need repository support
        // let metadata = try await repository.exportMetadata(voiceNoteIds: voiceNoteIds)
        // try JSONEncoder().encode(metadata).write(to: metadataURL)
        
        // Export audio files if requested
        if includeAudioFiles {
            let audioDir = tempDir.appendingPathComponent("audio")
            try fileManager.createDirectory(at: audioDir, withIntermediateDirectories: true)
            
            // Copy audio files
            // This would need repository support
            /*
            for voiceNote in voiceNotes {
                if let sourceURL = URL(string: voiceNote.audioFilePath) {
                    let destinationURL = audioDir.appendingPathComponent("\(voiceNote.id.uuidString).m4a")
                    try fileManager.copyItem(at: sourceURL, to: destinationURL)
                }
            }
            */
        }
        
        // Create ZIP archive
        let zipURL = tempDir.appendingPathExtension("zip")
        try await createZipArchive(from: tempDir, to: zipURL)
        
        // Clean up temp directory
        try? fileManager.removeItem(at: tempDir)
        
        return zipURL
    }
    
    /// Exports voice notes to Files app (share sheet)
    func exportToFilesApp(voiceNoteIds: [UUID]? = nil) async throws -> [URL] {
        let backupURL = try await exportVoiceNotes(voiceNoteIds: voiceNoteIds, includeAudioFiles: true)
        return [backupURL]
    }
    
    /// Shares multiple voice notes
    func shareVoiceNotes(_ voiceNoteIds: [UUID]) async throws -> [URL] {
        let urls: [URL] = []
        
        for _ in voiceNoteIds {
            // Fetch voice note and get file URL
            // let voiceNote = try await repository.findById(id)
            // if let fileURL = URL(string: voiceNote.audioFilePath) {
            //     urls.append(fileURL)
            // }
        }
        
        return urls
    }
    
    // MARK: - Import
    
    /// Imports voice notes from a backup file
    func importVoiceNotes(from backupURL: URL) async throws -> ImportResult {
        // Extract ZIP archive
        let tempDir = fileManager.temporaryDirectory
            .appendingPathComponent("VoiceNotesImport_\(UUID().uuidString)")
        
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: tempDir) }
        
        try await extractZipArchive(from: backupURL, to: tempDir)
        
        // Read metadata
        let metadataURL = tempDir.appendingPathComponent("metadata.json")
        guard fileManager.fileExists(atPath: metadataURL.path) else {
            throw BackupError.metadataNotFound
        }
        
        _ = try Data(contentsOf: metadataURL)
        // let metadata = try JSONDecoder().decode([VoiceNoteMetadata].self, from: metadataData)
        
        // Import audio files
        let audioDir = tempDir.appendingPathComponent("audio")
        var importedCount = 0
        var failedCount = 0
        
        if fileManager.fileExists(atPath: audioDir.path) {
            let audioFiles = try fileManager.contentsOfDirectory(at: audioDir, includingPropertiesForKeys: nil)
            
            for _ in audioFiles {
                // Import each voice note
                // This would need repository support
                /*
                do {
                    let voiceNote = try await importVoiceNote(
                        audioFileURL: audioFile,
                        metadata: metadata.first { $0.id.uuidString == audioFile.deletingPathExtension().lastPathComponent }
                    )
                    importedCount += 1
                } catch {
                    print("Failed to import voice note from \(audioFile.lastPathComponent): \(error)")
                    failedCount += 1
                }
                */
                // Placeholder: increment counters when implementation is added
                importedCount += 0
                failedCount += 0
            }
        }
        
        return ImportResult(
            importedCount: importedCount,
            failedCount: failedCount
        )
    }
    
    // MARK: - Batch Export
    
    /// Exports multiple voice notes to Files app
    func batchExportToFiles(voiceNoteIds: [UUID]) async throws -> [URL] {
        return try await exportToFilesApp(voiceNoteIds: voiceNoteIds)
    }
    
    // MARK: - Helpers
    
    private func createZipArchive(from sourceURL: URL, to destinationURL: URL) async throws {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.arguments = [
            "-r",
            destinationURL.path,
            sourceURL.path
        ]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw BackupError.zipCreationFailed
        }
        #else
        // iOS: Use ZipFoundation or similar library, or return error
        throw BackupError.zipCreationFailed
        #endif
    }
    
    private func extractZipArchive(from sourceURL: URL, to destinationURL: URL) async throws {
        #if os(macOS)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = [
            "-o",
            sourceURL.path,
            "-d",
            destinationURL.path
        ]
        
        try process.run()
        process.waitUntilExit()
        
        guard process.terminationStatus == 0 else {
            throw BackupError.zipExtractionFailed
        }
        #else
        // iOS: Use ZipFoundation or similar library, or return error
        throw BackupError.zipExtractionFailed
        #endif
    }
}

struct ImportResult {
    let importedCount: Int
    let failedCount: Int
}

enum BackupError: LocalizedError {
    case metadataNotFound
    case zipCreationFailed
    case zipExtractionFailed
    case importFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .metadataNotFound:
            return "Metadata file not found in backup"
        case .zipCreationFailed:
            return "Failed to create ZIP archive"
        case .zipExtractionFailed:
            return "Failed to extract ZIP archive"
        case .importFailed(let message):
            return "Import failed: \(message)"
        }
    }
}

