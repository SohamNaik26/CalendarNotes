//
//  S3StorageProvider.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import CryptoKit

/// S3-compatible storage provider (AWS S3, MinIO, etc.)
class S3StorageProvider: CloudStorageProvider {
    private let config: CloudStorageConfig
    private let session: URLSession
    
    init(config: CloudStorageConfig) {
        self.config = config
        self.session = URLSession.shared
    }
    
    func upload(
        fileURL: URL,
        key: String,
        contentType: String,
        progressHandler: ((Double) -> Void)?
    ) async throws -> String {
        guard let endpoint = config.endpoint,
              let bucketName = config.bucketName,
              let _ = config.accessKeyId,
              let _ = config.secretAccessKey else {
            throw CloudStorageError.configurationMissing
        }
        
        let url = URL(string: "https://\(bucketName).\(endpoint)/\(key)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        // Sign the request using AWS Signature Version 4
        let signedRequest = try signRequest(request, method: "PUT", body: nil)
        
        // Upload with progress
        let delegate = UploadProgressDelegate(progressHandler: progressHandler)
        let sessionWithDelegate = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let (_, response) = try await sessionWithDelegate.upload(for: signedRequest, fromFile: fileURL)
        delegate.invalidate()
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CloudStorageError.uploadFailed
        }
        
        return url.absoluteString
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
        
        // Sign the request
        let signedRequest = try signRequest(request, method: "GET", body: nil)
        
        // Download with progress
        let delegate = DownloadProgressDelegate(progressHandler: progressHandler)
        let sessionWithDelegate = URLSession(configuration: .default, delegate: delegate, delegateQueue: nil)
        let (tempURL, response) = try await sessionWithDelegate.download(for: signedRequest)
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
        guard let endpoint = config.endpoint,
              let bucketName = config.bucketName,
              let accessKeyId = config.accessKeyId,
              let secretAccessKey = config.secretAccessKey else {
            throw CloudStorageError.configurationMissing
        }
        
        let url = URL(string: "https://\(bucketName).\(endpoint)/\(key)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Add expiration query parameter
        let expirationDate = Date().addingTimeInterval(expiresIn)
        let expirationSeconds = Int64(expirationDate.timeIntervalSince1970)
        
        // Sign with query string authentication
        let signedURL = try signRequestForPresignedURL(
            request: request,
            key: key,
            expiresIn: expirationSeconds,
            accessKeyId: accessKeyId,
            secretAccessKey: secretAccessKey
        )
        
        return signedURL.absoluteString
    }
    
    func delete(key: String) async throws {
        guard let endpoint = config.endpoint,
              let bucketName = config.bucketName,
              let _ = config.accessKeyId,
              let _ = config.secretAccessKey else {
            throw CloudStorageError.configurationMissing
        }
        
        let url = URL(string: "https://\(bucketName).\(endpoint)/\(key)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let signedRequest = try signRequest(request, method: "DELETE", body: nil)
        
        let (_, response) = try await session.data(for: signedRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CloudStorageError.deleteFailed
        }
    }
    
    func exists(key: String) async throws -> Bool {
        guard let endpoint = config.endpoint,
              let bucketName = config.bucketName,
              let _ = config.accessKeyId,
              let _ = config.secretAccessKey else {
            throw CloudStorageError.configurationMissing
        }
        
        let url = URL(string: "https://\(bucketName).\(endpoint)/\(key)")!
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        let signedRequest = try signRequest(request, method: "HEAD", body: nil)
        
        let (_, response) = try await session.data(for: signedRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            return false
        }
        
        return httpResponse.statusCode == 200
    }
    
    func getMetadata(key: String) async throws -> FileMetadata {
        guard let endpoint = config.endpoint,
              let bucketName = config.bucketName,
              let _ = config.accessKeyId,
              let _ = config.secretAccessKey else {
            throw CloudStorageError.configurationMissing
        }
        
        let url = URL(string: "https://\(bucketName).\(endpoint)/\(key)")!
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        
        let signedRequest = try signRequest(request, method: "HEAD", body: nil)
        
        let (_, response) = try await session.data(for: signedRequest)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw CloudStorageError.metadataFetchFailed
        }
        
        let size = Int64(httpResponse.expectedContentLength)
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")
        let lastModified = httpResponse.value(forHTTPHeaderField: "Last-Modified").flatMap { parseDate($0) }
        let etag = httpResponse.value(forHTTPHeaderField: "ETag")
        
        return FileMetadata(
            size: size,
            contentType: contentType,
            lastModified: lastModified,
            etag: etag
        )
    }
    
    // MARK: - AWS Signature V4
    
    private func signRequest(_ request: URLRequest, method: String, body: Data?) throws -> URLRequest {
        // Simplified AWS Signature V4 - in production, use a proper AWS SDK
        // This is a placeholder implementation
        var signedRequest = request
        signedRequest.setValue("AWS4-HMAC-SHA256", forHTTPHeaderField: "Authorization")
        return signedRequest
    }
    
    private func signRequestForPresignedURL(
        request: URLRequest,
        key: String,
        expiresIn: Int64,
        accessKeyId: String,
        secretAccessKey: String
    ) throws -> URL {
        // Simplified presigned URL generation
        // In production, use proper AWS SDK or implement full Signature V4
        var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "X-Amz-Algorithm", value: "AWS4-HMAC-SHA256"),
            URLQueryItem(name: "X-Amz-Credential", value: accessKeyId),
            URLQueryItem(name: "X-Amz-Date", value: iso8601Date()),
            URLQueryItem(name: "X-Amz-Expires", value: "\(expiresIn)"),
            URLQueryItem(name: "X-Amz-SignedHeaders", value: "host")
        ]
        return components.url!
    }
    
    private func iso8601Date() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: Date())
    }
    
    private func parseDate(_ dateString: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter.date(from: dateString)
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

enum CloudStorageError: LocalizedError {
    case configurationMissing
    case uploadFailed
    case downloadFailed
    case deleteFailed
    case invalidURL
    case metadataFetchFailed
    
    var errorDescription: String? {
        switch self {
        case .configurationMissing:
            return "Cloud storage configuration is missing"
        case .uploadFailed:
            return "Failed to upload file to cloud storage"
        case .downloadFailed:
            return "Failed to download file from cloud storage"
        case .deleteFailed:
            return "Failed to delete file from cloud storage"
        case .invalidURL:
            return "Invalid cloud storage URL"
        case .metadataFetchFailed:
            return "Failed to fetch file metadata"
        }
    }
}

