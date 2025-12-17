//
//  CloudStorageProvider.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import Combine

/// Protocol for cloud storage providers (S3, R2, iCloud, custom server)
protocol CloudStorageProvider {
    /// Uploads a file and returns the cloud URL
    func upload(
        fileURL: URL,
        key: String,
        contentType: String,
        progressHandler: ((Double) -> Void)?
    ) async throws -> String
    
    /// Downloads a file from cloud storage
    func download(
        from cloudURL: String,
        to destinationURL: URL,
        progressHandler: ((Double) -> Void)?
    ) async throws
    
    /// Generates a presigned URL for temporary access
    func generatePresignedURL(for key: String, expiresIn: TimeInterval) async throws -> String
    
    /// Deletes a file from cloud storage
    func delete(key: String) async throws
    
    /// Checks if a file exists in cloud storage
    func exists(key: String) async throws -> Bool
    
    /// Gets file metadata (size, content type, etc.)
    func getMetadata(key: String) async throws -> FileMetadata
}

struct FileMetadata {
    let size: Int64
    let contentType: String?
    let lastModified: Date?
    let etag: String?
}

/// Configuration for cloud storage providers
struct CloudStorageConfig {
    enum ProviderType {
        case s3
        case r2
        case iCloud
        case customServer
    }
    
    let type: ProviderType
    let endpoint: String?
    let accessKeyId: String?
    let secretAccessKey: String?
    let bucketName: String?
    let region: String?
    let customHeaders: [String: String]?
    
    // For custom server
    let apiKey: String?
    let baseURL: String?
}

