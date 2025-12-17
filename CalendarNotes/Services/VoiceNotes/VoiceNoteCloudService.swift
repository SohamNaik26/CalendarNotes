//
//  VoiceNoteCloudService.swift
//  CalendarNotes
//
//  Created on [Date]
//

import Foundation
import Combine

/// Handles cloud storage upload, download, and sync for voice notes
final class VoiceNoteCloudService {
    static let shared = VoiceNoteCloudService()
    
    private let storageManager = VoiceNoteStorageManager.shared
    private let baseURL = "https://api.calendarnotes.com/voice-notes" // Replace with actual API URL
    
    enum SyncStatus: String, Codable {
        case pending = "pending"
        case uploading = "uploading"
        case synced = "synced"
        case failed = "failed"
        case downloading = "downloading"
    }
    
    private init() {}
    
    // MARK: - Upload
    
    /// Uploads a voice note to the server
    func uploadVoiceNote(
        voiceNoteId: UUID,
        audioFileURL: URL,
        metadata: VoiceNoteMetadata
    ) async throws -> String {
        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: URL(string: "\(baseURL)/upload")!)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add metadata
        if let metadataData = try? JSONEncoder().encode(metadata) {
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"metadata\"\r\n\r\n".data(using: .utf8)!)
            body.append(metadataData)
            body.append("\r\n".data(using: .utf8)!)
        }
        
        // Add audio file
        let audioData = try Data(contentsOf: audioFileURL)
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(audioFileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: audio/m4a\r\n\r\n".data(using: .utf8)!)
        body.append(audioData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Perform upload
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudServiceError.uploadFailed
        }
        
        struct UploadResponse: Codable {
            let cloudStorageURL: String
        }
        
        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        return uploadResponse.cloudStorageURL
    }
    
    // MARK: - Download
    
    /// Downloads a voice note from the server
    func downloadVoiceNote(
        cloudStorageURL: String,
        to destinationURL: URL
    ) async throws {
        guard let url = URL(string: cloudStorageURL) else {
            throw CloudServiceError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudServiceError.downloadFailed
        }
        
        try data.write(to: destinationURL)
    }
    
    // MARK: - Sync Status
    
    /// Checks sync status for a voice note
    func checkSyncStatus(voiceNoteId: UUID) async throws -> SyncStatus {
        guard let url = URL(string: "\(baseURL)/\(voiceNoteId.uuidString)/status") else {
            throw CloudServiceError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return .failed
        }
        
        struct StatusResponse: Codable {
            let status: SyncStatus
        }
        
        let statusResponse = try JSONDecoder().decode(StatusResponse.self, from: data)
        return statusResponse.status
    }
    
    // MARK: - Stream
    
    /// Streams a voice note from the server instead of downloading
    func streamVoiceNote(cloudStorageURL: String) async throws -> URL {
        // For streaming, we create a temporary file that gets populated as data arrives
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")
        
        guard let url = URL(string: cloudStorageURL) else {
            throw CloudServiceError.invalidURL
        }
        
        let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudServiceError.downloadFailed
        }
        
        let fileHandle = try FileHandle(forWritingTo: tempURL)
        defer { try? fileHandle.close() }
        
        // Collect bytes into Data chunks for writing
        var dataBuffer = Data()
        for try await byte in asyncBytes {
            dataBuffer.append(byte)
            // Write in chunks to avoid memory issues
            if dataBuffer.count >= 8192 {
                try fileHandle.write(contentsOf: dataBuffer)
                dataBuffer.removeAll()
            }
        }
        // Write remaining data
        if !dataBuffer.isEmpty {
            try fileHandle.write(contentsOf: dataBuffer)
        }
        
        return tempURL
    }
    
    // MARK: - Batch Operations
    
    /// Uploads multiple voice notes
    func uploadVoiceNotes(_ voiceNotes: [(UUID, URL, VoiceNoteMetadata)]) async throws -> [UUID: String] {
        var results: [UUID: String] = [:]
        
        for (id, url, metadata) in voiceNotes {
            do {
                let cloudURL = try await uploadVoiceNote(
                    voiceNoteId: id,
                    audioFileURL: url,
                    metadata: metadata
                )
                results[id] = cloudURL
            } catch {
                print("Failed to upload voice note \(id): \(error)")
                // Continue with other uploads
            }
        }
        
        return results
    }
}

struct VoiceNoteMetadata: Codable {
    let id: UUID
    let userId: UUID
    let transcription: String?
    let duration: TimeInterval
    let createdAt: Date
    let linkedNoteId: UUID?
    let linkedEventId: UUID?
    let linkedTaskId: UUID?
}

enum CloudServiceError: LocalizedError {
    case uploadFailed
    case downloadFailed
    case invalidURL
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .uploadFailed:
            return "Failed to upload voice note to cloud"
        case .downloadFailed:
            return "Failed to download voice note from cloud"
        case .invalidURL:
            return "Invalid cloud storage URL"
        case .networkError:
            return "Network error occurred"
        }
    }
}

