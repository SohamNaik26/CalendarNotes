//
//  iCloudStorageProvider.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import UniformTypeIdentifiers

/// iCloud Drive storage provider
final class iCloudStorageProvider: CloudStorageProvider {
    private let fileManager = FileManager.default
    private let containerIdentifier: String
    
    init(containerIdentifier: String = "iCloud.com.calendarnotes.app") {
        self.containerIdentifier = containerIdentifier
    }
    
    func upload(
        fileURL: URL,
        key: String,
        contentType: String,
        progressHandler: ((Double) -> Void)?
    ) async throws -> String {
        guard let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: containerIdentifier) else {
            throw CloudStorageError.configurationMissing
        }
        
        let destinationURL = iCloudURL
            .appendingPathComponent("Documents")
            .appendingPathComponent("VoiceNotes")
            .appendingPathComponent(key)
        
        // Create directory if needed
        let destinationDir = destinationURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: destinationDir.path) {
            try fileManager.createDirectory(at: destinationDir, withIntermediateDirectories: true)
        }
        
        // Copy file to iCloud
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        
        try fileManager.copyItem(at: fileURL, to: destinationURL)
        
        // Mark for iCloud upload
        try (destinationURL as NSURL).setResourceValue(true, forKey: .ubiquitousItemIsUploadedKey)
        #if os(iOS)
        setDownloadedStatusiOS(url: destinationURL, downloaded: false)
        #elseif os(macOS)
        // On macOS, use NSURLUbiquitousItemDownloadingStatusKey instead
        try (destinationURL as NSURL).setResourceValue(URLUbiquitousItemDownloadingStatus.notDownloaded, forKey: .ubiquitousItemDownloadingStatusKey)
        #endif
        
        // Monitor upload progress
        if let progressHandler = progressHandler {
            await monitorUploadProgress(fileURL: destinationURL, progressHandler: progressHandler)
        }
        
        return destinationURL.path
    }
    
    func download(
        from cloudURL: String,
        to destinationURL: URL,
        progressHandler: ((Double) -> Void)?
    ) async throws {
        let sourceURL = URL(fileURLWithPath: cloudURL)
        
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            throw CloudStorageError.downloadFailed
        }
        
        // Check if file is downloaded
        var isDownloaded = false
        #if os(iOS)
        isDownloaded = checkDownloadedStatusiOS(url: sourceURL)
        #elseif os(macOS)
        // On macOS, use NSURLUbiquitousItemDownloadingStatusKey
        if let resourceValues = try? sourceURL.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]),
           let status = resourceValues.ubiquitousItemDownloadingStatus {
            isDownloaded = (status == URLUbiquitousItemDownloadingStatus.current)
        }
        #endif
        
        if !isDownloaded {
            // Trigger download
            #if os(iOS)
            setDownloadedStatusiOS(url: sourceURL, downloaded: false)
            #elseif os(macOS)
            try (sourceURL as NSURL).setResourceValue(URLUbiquitousItemDownloadingStatus.notDownloaded, forKey: .ubiquitousItemDownloadingStatusKey)
            #endif
            
            // Monitor download progress
            if let progressHandler = progressHandler {
                await monitorDownloadProgress(fileURL: sourceURL, progressHandler: progressHandler)
            }
        }
        
        // Copy to destination
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }
    
    func generatePresignedURL(for key: String, expiresIn: TimeInterval) async throws -> String {
        // iCloud doesn't support presigned URLs
        // Return the file path instead
        guard let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: containerIdentifier) else {
            throw CloudStorageError.configurationMissing
        }
        
        return iCloudURL
            .appendingPathComponent("Documents")
            .appendingPathComponent("VoiceNotes")
            .appendingPathComponent(key)
            .path
    }
    
    func delete(key: String) async throws {
        guard let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: containerIdentifier) else {
            throw CloudStorageError.configurationMissing
        }
        
        let fileURL = iCloudURL
            .appendingPathComponent("Documents")
            .appendingPathComponent("VoiceNotes")
            .appendingPathComponent(key)
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
    }
    
    func exists(key: String) async throws -> Bool {
        guard let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: containerIdentifier) else {
            return false
        }
        
        let fileURL = iCloudURL
            .appendingPathComponent("Documents")
            .appendingPathComponent("VoiceNotes")
            .appendingPathComponent(key)
        
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    func getMetadata(key: String) async throws -> FileMetadata {
        guard let iCloudURL = fileManager.url(forUbiquityContainerIdentifier: containerIdentifier) else {
            throw CloudStorageError.configurationMissing
        }
        
        let fileURL = iCloudURL
            .appendingPathComponent("Documents")
            .appendingPathComponent("VoiceNotes")
            .appendingPathComponent(key)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw CloudStorageError.metadataFetchFailed
        }
        
        let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
        let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
        let contentType = UTType(filenameExtension: fileURL.pathExtension)?.identifier
        let lastModified = attributes[.modificationDate] as? Date
        
        return FileMetadata(
            size: size,
            contentType: contentType,
            lastModified: lastModified,
            etag: nil
        )
    }
    
    // MARK: - Progress Monitoring
    
    private func monitorUploadProgress(fileURL: URL, progressHandler: @escaping (Double) -> Void) async {
        var lastProgress: Double = 0.0
        
        while true {
            do {
                let resourceValues = try fileURL.resourceValues(forKeys: [
                    .ubiquitousItemIsUploadedKey,
                    .ubiquitousItemUploadingErrorKey
                ])
                
                if resourceValues.ubiquitousItemIsUploaded == true {
                    progressHandler(1.0)
                    break
                }
                
                if resourceValues.ubiquitousItemUploadingError != nil {
                    break
                }
                
                // Estimate progress (iCloud doesn't provide exact progress)
                // Use a simple time-based estimate
                lastProgress = min(lastProgress + 0.1, 0.9)
                progressHandler(lastProgress)
                
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            } catch {
                break
            }
        }
    }
    
    private func monitorDownloadProgress(fileURL: URL, progressHandler: @escaping (Double) -> Void) async {
        var lastProgress: Double = 0.0
        
        while true {
            do {
                #if os(iOS)
                let (isDownloaded, hasError) = checkDownloadProgressiOS(url: fileURL)
                if isDownloaded {
                    progressHandler(1.0)
                    break
                }
                if hasError {
                    break
                }
                #elseif os(macOS)
                // On macOS, use NSURLUbiquitousItemDownloadingStatusKey
                let resourceValues = try fileURL.resourceValues(forKeys: [
                    .ubiquitousItemDownloadingStatusKey,
                    .ubiquitousItemDownloadingErrorKey
                ])
                
                if let status = resourceValues.ubiquitousItemDownloadingStatus,
                   status == URLUbiquitousItemDownloadingStatus.current {
                    progressHandler(1.0)
                    break
                }
                
                if resourceValues.ubiquitousItemDownloadingError != nil {
                    break
                }
                #endif
                
                // Estimate progress
                lastProgress = min(lastProgress + 0.1, 0.9)
                progressHandler(lastProgress)
                
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            } catch {
                break
            }
        }
    }
    
    // MARK: - iOS-specific helpers
    
    #if os(iOS)
    private func setDownloadedStatusiOS(url: URL, downloaded: Bool) {
        // Note: Can't directly set download status, but can request download
        if downloaded {
            try? FileManager.default.startDownloadingUbiquitousItem(at: url)
        }
    }
    
    private func checkDownloadedStatusiOS(url: URL) -> Bool {
        if let resourceValues = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]) {
            // Check if item is downloaded or current (available locally)
            if let status = resourceValues.ubiquitousItemDownloadingStatus {
                return status == .downloaded || status == .current
            }
        }
        return false
    }
    
    private func checkDownloadProgressiOS(url: URL) -> (isDownloaded: Bool, hasError: Bool) {
        if let resourceValues = try? url.resourceValues(forKeys: [
            .ubiquitousItemDownloadingStatusKey,
            .ubiquitousItemDownloadingErrorKey
        ]) {
            let isDownloaded: Bool
            if let status = resourceValues.ubiquitousItemDownloadingStatus {
                isDownloaded = status == .downloaded || status == .current
            } else {
                isDownloaded = false
            }
            let hasError = resourceValues.ubiquitousItemDownloadingError != nil
            return (isDownloaded, hasError)
        }
        return (false, false)
    }
    #endif
}

