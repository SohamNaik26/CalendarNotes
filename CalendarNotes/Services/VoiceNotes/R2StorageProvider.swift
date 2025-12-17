//
//  R2StorageProvider.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation

/// Cloudflare R2 storage provider (S3-compatible API)
final class R2StorageProvider: S3StorageProvider {
    // R2 is S3-compatible, so we can reuse S3StorageProvider
    // Just override the endpoint construction if needed
    
    override init(config: CloudStorageConfig) {
        // R2 uses a different endpoint format: <account-id>.r2.cloudflarestorage.com
        var r2Config = config
        if let endpoint = config.endpoint, !endpoint.contains("r2.cloudflarestorage.com") {
            // Transform endpoint if needed
            r2Config = CloudStorageConfig(
                type: .r2,
                endpoint: endpoint.contains("cloudflarestorage.com") ? endpoint : "\(endpoint).r2.cloudflarestorage.com",
                accessKeyId: config.accessKeyId,
                secretAccessKey: config.secretAccessKey,
                bucketName: config.bucketName,
                region: nil, // R2 doesn't use regions
                customHeaders: config.customHeaders,
                apiKey: config.apiKey,
                baseURL: config.baseURL
            )
        }
        super.init(config: r2Config)
    }
}

