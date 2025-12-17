//
//  VoiceNoteStorageManager.swift
//  CalendarNotes
//
//  Created on [Date]
//

import Foundation

/// Manages file storage for voice notes with date-based organization
final class VoiceNoteStorageManager {
    static let shared = VoiceNoteStorageManager()
    
    private let fileManager = FileManager.default
    private let baseDirectoryName = "VoiceNotes"
    
    private init() {}
    
    // MARK: - Directory Management
    
    /// Returns the base directory for voice notes: Documents/VoiceNotes/
    func baseDirectory() throws -> URL {
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw VoiceNoteStorageError.documentsDirectoryNotFound
        }
        
        let baseURL = documentsURL.appendingPathComponent(baseDirectoryName, isDirectory: true)
        
        if !fileManager.fileExists(atPath: baseURL.path) {
            try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        return baseURL
    }
    
    /// Returns directory for a specific date: Documents/VoiceNotes/YYYY/MM/DD/
    func directory(for date: Date) throws -> URL {
        let baseURL = try baseDirectory()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        
        guard let year = components.year,
              let month = components.month,
              let day = components.day else {
            throw VoiceNoteStorageError.invalidDate
        }
        
        let yearDir = baseURL.appendingPathComponent(String(format: "%04d", year), isDirectory: true)
        let monthDir = yearDir.appendingPathComponent(String(format: "%02d", month), isDirectory: true)
        let dayDir = monthDir.appendingPathComponent(String(format: "%02d", day), isDirectory: true)
        
        if !fileManager.fileExists(atPath: dayDir.path) {
            try fileManager.createDirectory(at: dayDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        return dayDir
    }
    
    // MARK: - File Operations
    
    /// Generates a file path for a new voice note: voicenote_UUID_timestamp.m4a
    func generateFilePath(for date: Date = Date()) throws -> URL {
        let directory = try self.directory(for: date)
        let uuid = UUID()
        let timestamp = Int64(date.timeIntervalSince1970)
        let filename = "voicenote_\(uuid.uuidString)_\(timestamp).m4a"
        return directory.appendingPathComponent(filename)
    }
    
    /// Saves an audio file to the appropriate date-based directory
    func saveAudioFile(from sourceURL: URL, to date: Date = Date()) throws -> URL {
        let destinationURL = try generateFilePath(for: date)
        
        // Remove existing file if it exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        // Copy or move the file
        if sourceURL.path == destinationURL.path {
            // File is already in the correct location
            return destinationURL
        } else {
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
        }
        
        return destinationURL
    }
    
    /// Moves a file to a new date-based directory (e.g., when updating created_at)
    func moveFile(from sourceURL: URL, to newDate: Date) throws -> URL {
        let destinationURL = try generateFilePath(for: newDate)
        
        // Create destination directory if needed
        let destinationDir = destinationURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: destinationDir.path) {
            try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Remove existing file if it exists
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        // Move the file
        try fileManager.moveItem(at: sourceURL, to: destinationURL)
        
        return destinationURL
    }
    
    /// Deletes an audio file
    func deleteAudioFile(at url: URL) throws {
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
    
    /// Checks if a file exists
    func fileExists(at url: URL) -> Bool {
        return fileManager.fileExists(atPath: url.path)
    }
    
    /// Gets file size in bytes
    func fileSize(at url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        if let size = attributes[.size] as? NSNumber {
            return size.int64Value
        }
        throw VoiceNoteStorageError.fileSizeNotFound
    }
    
    // MARK: - Directory Cleanup
    
    /// Removes empty date directories (YYYY/MM/DD)
    func cleanupEmptyDirectories() throws {
        let baseURL = try baseDirectory()
        
        // Walk through year/month/day directories
        guard let yearEnumerator = fileManager.enumerator(at: baseURL, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            return
        }
        
        var directoriesToRemove: [URL] = []
        
        for case let url as URL in yearEnumerator {
            guard let resourceValues = try? url.resourceValues(forKeys: [.isDirectoryKey]),
                  resourceValues.isDirectory == true else {
                continue
            }
            
            // Check if directory is empty
            if let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles]),
               contents.isEmpty {
                directoriesToRemove.append(url)
            }
        }
        
        // Remove empty directories (in reverse order: day -> month -> year)
        for directory in directoriesToRemove.sorted(by: { $0.pathComponents.count > $1.pathComponents.count }) {
            try? fileManager.removeItem(at: directory)
        }
    }
    
    /// Gets all voice note files
    func getAllVoiceNoteFiles() throws -> [URL] {
        let baseURL = try baseDirectory()
        var files: [URL] = []
        
        guard let enumerator = fileManager.enumerator(at: baseURL, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return files
        }
        
        for case let url as URL in enumerator {
            guard let resourceValues = try? url.resourceValues(forKeys: [.isRegularFileKey]),
                  resourceValues.isRegularFile == true,
                  url.pathExtension.lowercased() == "m4a" else {
                continue
            }
            files.append(url)
        }
        
        return files
    }
}

enum VoiceNoteStorageError: LocalizedError {
    case documentsDirectoryNotFound
    case invalidDate
    case fileSizeNotFound
    case fileOperationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .documentsDirectoryNotFound:
            return "Documents directory not found"
        case .invalidDate:
            return "Invalid date provided"
        case .fileSizeNotFound:
            return "Could not determine file size"
        case .fileOperationFailed(let message):
            return "File operation failed: \(message)"
        }
    }
}

