//
//  CustomServerStorageProvider.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation

/// Custom server storage provider (for self-hosted solutions)
final class CustomServerStorageProvider: CloudStorageProvider {
    private let config: CloudStorageConfig
    private let session: URLSession
    private let sessionConfiguration: URLSessionConfiguration
    
    init(config: CloudStorageConfig) {
        self.config = config
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 300 // 5 minutes for large uploads
        self.sessionConfiguration = configuration
        self.session = URLSession(configuration: configuration)
    }
    
    func upload(
        fileURL: URL,
        key: String,
        contentType: String,
        progressHandler: ((Double) -> Void)?
    ) async throws -> String {
        guard let baseURL = config.baseURL,
              let apiKey = config.apiKey else {
            throw CloudStorageError.configurationMissing
        }
        
        let url = URL(string: "\(baseURL)/api/voice-notes/upload")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data", forHTTPHeaderField: "Content-Type")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build multipart body
        var body = Data()
        
        // Add key parameter
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"key\"\r\n\r\n".data(using: .utf8)!)
        body.append(key.data(using: .utf8)!)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add file header
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(key)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(contentType)\r\n\r\n".data(using: .utf8)!)
        
        // Create temp file with multipart data + file content
        let tempFileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("tmp")
        
        // Write multipart header
        try body.write(to: tempFileURL)
        
        // Append file content
        let fileHandle = try FileHandle(forWritingTo: tempFileURL)
        fileHandle.seekToEndOfFile()
        let fileData = try Data(contentsOf: fileURL)
        fileHandle.write(fileData)
        
        // Append closing boundary
        let closingBoundary = "\r\n--\(boundary)--\r\n".data(using: .utf8)!
        fileHandle.write(closingBoundary)
        try fileHandle.close()
        
        // Upload with progress
        let delegate = UploadProgressDelegate(progressHandler: progressHandler)
        let sessionWithDelegate = URLSession(configuration: sessionConfiguration, delegate: delegate, delegateQueue: nil)
        
        // Upload the temp file
        let (data, response) = try await sessionWithDelegate.upload(for: request, fromFile: tempFileURL)
        
        // Cleanup temp file
        try? FileManager.default.removeItem(at: tempFileURL)
        
        delegate.invalidate()
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CloudStorageError.uploadFailed
        }
        
        struct UploadResponse: Codable {
            let url: String
        }
        
        let uploadResponse = try JSONDecoder().decode(UploadResponse.self, from: data)
        return uploadResponse.url
    }
    
    func download(
        from cloudURL: String,
        to destinationURL: URL,
        progressHandler: ((Double) -> Void)?
    ) async throws {
        guard let url = URL(string: cloudURL) else {
            throw CloudStorageError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let apiKey = config.apiKey {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        
        // Download with progress
        let delegate = DownloadProgressDelegate(progressHandler: progressHandler)
        let sessionWithDelegate = URLSession(configuration: sessionConfiguration, delegate: delegate, delegateQueue: nil)
        let (tempURL, response) = try await sessionWithDelegate.download(for: request)
        delegate.invalidate()
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CloudStorageError.downloadFailed
        }
        
        // Move to destination
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
    }
    
    func generatePresignedURL(for key: String, expiresIn: TimeInterval) async throws -> String {
        guard let baseURL = config.baseURL,
              let apiKey = config.apiKey else {
            throw CloudStorageError.configurationMissing
        }
        
        let url = URL(string: "\(baseURL)/api/voice-notes/presigned-url")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        struct PresignedURLRequest: Codable {
            let key: String
            let expiresIn: TimeInterval
        }
        
        let requestBody = PresignedURLRequest(key: key, expiresIn: expiresIn)
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CloudStorageError.metadataFetchFailed
        }
        
        struct PresignedURLResponse: Codable {
            let url: String
        }
        
        let presignedResponse = try JSONDecoder().decode(PresignedURLResponse.self, from: data)
        return presignedResponse.url
    }
    
    func delete(key: String) async throws {
        guard let baseURL = config.baseURL,
              let apiKey = config.apiKey else {
            throw CloudStorageError.configurationMissing
        }
        
        let url = URL(string: "\(baseURL)/api/voice-notes/\(key)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CloudStorageError.deleteFailed
        }
    }
    
    func exists(key: String) async throws -> Bool {
        guard let baseURL = config.baseURL,
              let apiKey = config.apiKey else {
            throw CloudStorageError.configurationMissing
        }
        
        let url = URL(string: "\(baseURL)/api/voice-notes/\(key)/exists")!
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        return httpResponse.statusCode == 200
    }
    
    func getMetadata(key: String) async throws -> FileMetadata {
        guard let baseURL = config.baseURL,
              let apiKey = config.apiKey else {
            throw CloudStorageError.configurationMissing
        }
        
        let url = URL(string: "\(baseURL)/api/voice-notes/\(key)/metadata")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudStorageError.metadataFetchFailed
        }
        
        struct MetadataResponse: Codable {
            let size: Int64
            let contentType: String?
            let lastModified: Date?
            let etag: String?
        }
        
        let metadataResponse = try JSONDecoder().decode(MetadataResponse.self, from: data)
        return FileMetadata(
            size: metadataResponse.size,
            contentType: metadataResponse.contentType,
            lastModified: metadataResponse.lastModified,
            etag: metadataResponse.etag
        )
    }
}

// MARK: - Progress Delegates

private class UploadProgressDelegate: NSObject, URLSessionTaskDelegate {
    let progressHandler: ((Double) -> Void)?
    
    init(progressHandler: ((Double) -> Void)?) {
        self.progressHandler = progressHandler
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didSendBodyData bytesSent: Int64, totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
        progressHandler?(min(progress, 1.0))
    }
    
    func invalidate() {
        // Cleanup if needed
    }
}

private class DownloadProgressDelegate: NSObject, URLSessionDownloadDelegate {
    let progressHandler: ((Double) -> Void)?
    
    init(progressHandler: ((Double) -> Void)?) {
        self.progressHandler = progressHandler
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        progressHandler?(min(progress, 1.0))
    }
    
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Download completed
    }
    
    func invalidate() {
        // Cleanup if needed
    }
}

