//
//  UploadProgressService.swift
//  CalendarNotes
//
//  Created for loading state implementation
//

import Foundation
import Combine

// MARK: - Upload Progress Model

struct UploadProgress {
    let progress: Double // 0.0 to 1.0
    let currentFile: String
    let totalFiles: Int
    let currentFileIndex: Int
    let bytesUploaded: Int64
    let totalBytes: Int64
    let estimatedTimeRemaining: TimeInterval?
    
    var percentage: Int {
        Int(progress * 100)
    }
    
    var formattedTimeRemaining: String? {
        guard let time = estimatedTimeRemaining else { return nil }
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s remaining"
        }
        return "\(seconds)s remaining"
    }
}

// MARK: - Upload Progress Service

@MainActor
class UploadProgressService: ObservableObject {
    static let shared = UploadProgressService()
    
    @Published var currentUpload: UploadProgress?
    @Published var isUploading: Bool = false
    
    private var uploadTask: Task<Void, Never>?
    private var startTime: Date?
    private var lastProgressUpdate: Date?
    
    private init() {}
    
    func startUpload(
        files: [String],
        uploadFunction: @escaping (String, @escaping (Double) -> Void) async throws -> Void
    ) {
        guard !isUploading else { return }
        
        isUploading = true
        startTime = Date()
        lastProgressUpdate = Date()
        
        uploadTask = Task {
            var totalProgress: Double = 0
            let totalFiles = files.count
            
            for (index, file) in files.enumerated() {
                guard !Task.isCancelled else { break }
                
                do {
                    try await uploadFunction(file) { progress in
                        let currentTime = Date()
                        self.lastProgressUpdate = currentTime
                        
                        // Calculate overall progress
                        totalProgress = (Double(index) + progress) / Double(totalFiles)
                        
                        // Estimate time remaining
                        let elapsed = currentTime.timeIntervalSince(self.startTime ?? currentTime)
                        let estimatedTotal = elapsed / totalProgress
                        let remaining = estimatedTotal - elapsed
                        
                        // Calculate bytes (simplified - would need actual byte tracking)
                        let bytesUploaded = Int64(totalProgress * 1_000_000) // Placeholder
                        let totalBytes = Int64(1_000_000) // Placeholder
                        
                        self.currentUpload = UploadProgress(
                            progress: totalProgress,
                            currentFile: file,
                            totalFiles: totalFiles,
                            currentFileIndex: index + 1,
                            bytesUploaded: bytesUploaded,
                            totalBytes: totalBytes,
                            estimatedTimeRemaining: remaining > 0 ? remaining : nil
                        )
                    }
                } catch {
                    // Handle error
                    print("Upload error for \(file): \(error)")
                }
            }
            
            isUploading = false
            currentUpload = nil
        }
    }
    
    func cancelUpload() {
        uploadTask?.cancel()
        isUploading = false
        currentUpload = nil
        startTime = nil
        lastProgressUpdate = nil
    }
}

