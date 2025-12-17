//
//  VoiceNoteCompressionService.swift
//  CalendarNotes
//
//  Created on [Date]
//

import Foundation
import AVFoundation
import Combine

/// Handles audio compression and optimization for voice notes
final class VoiceNoteCompressionService {
    static let shared = VoiceNoteCompressionService()
    
    private let compressionQueue = DispatchQueue(label: "com.calendarnotes.voicecompression", qos: .utility)
    private var compressionTasks: [UUID: Task<Void, Never>] = [:]
    
    enum CompressionPreset {
        case highQuality    // 128 kbps, 44.1 kHz
        case standard       // 64 kbps, 22.05 kHz (default for voice)
        case lowQuality     // 32 kbps, 16 kHz (for old recordings)
        
        var bitrate: Int {
            switch self {
            case .highQuality: return 128000
            case .standard: return 64000
            case .lowQuality: return 32000
            }
        }
        
        var sampleRate: Double {
            switch self {
            case .highQuality: return 44100.0
            case .standard: return 22050.0
            case .lowQuality: return 16000.0
            }
        }
    }
    
    private init() {}
    
    // MARK: - Compression
    
    /// Compresses an audio file with the specified preset
    func compressAudio(
        at sourceURL: URL,
        to destinationURL: URL,
        preset: CompressionPreset = .standard,
        removeSilence: Bool = true
    ) async throws -> CompressionResult {
        return try await withCheckedThrowingContinuation { continuation in
            compressionQueue.async {
                Task {
                    do {
                        let result = try await self.performCompression(
                            sourceURL: sourceURL,
                            destinationURL: destinationURL,
                            preset: preset,
                            removeSilence: removeSilence
                        )
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
    }
    
    private func performCompression(
        sourceURL: URL,
        destinationURL: URL,
        preset: CompressionPreset,
        removeSilence: Bool
    ) async throws -> CompressionResult {
        let asset = AVURLAsset(url: sourceURL)
        
        // Check for audio track using async API
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw CompressionError.noAudioTrack
        }
        
        // Remove existing file if it exists
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        // Use AVAudioFile for direct re-encoding with proper settings
        // This is more reliable than AVAssetExportSession for compression
        _ = try await reEncodeAudio(
            at: sourceURL,
            to: destinationURL,
            preset: preset,
            removeSilence: removeSilence
        )
        
        // Get file sizes
        let originalSize = try FileManager.default.attributesOfItem(atPath: sourceURL.path)[.size] as? Int64 ?? 0
        let compressedSize = try FileManager.default.attributesOfItem(atPath: destinationURL.path)[.size] as? Int64 ?? 0
        
        return CompressionResult(
            originalSize: originalSize,
            compressedSize: compressedSize,
            compressionRatio: Double(compressedSize) / Double(originalSize),
            bitrate: preset.bitrate,
            sampleRate: Int(preset.sampleRate)
        )
    }
    
    private func reEncodeAudio(
        at sourceURL: URL,
        to destinationURL: URL,
        preset: CompressionPreset,
        removeSilence: Bool
    ) async throws -> URL {
        // Use AVAudioFile for direct re-encoding with proper settings
        let sourceFile = try AVAudioFile(forReading: sourceURL)
        
        guard let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: preset.sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw CompressionError.reEncodingFailed
        }
        
        guard let destinationFile = try? AVAudioFile(forWriting: destinationURL, settings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: preset.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: preset.bitrate
        ]) else {
            throw CompressionError.reEncodingFailed
        }
        
        // Read and write audio data
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 4096) else {
            throw CompressionError.reEncodingFailed
        }
        
        while sourceFile.framePosition < sourceFile.length {
            try sourceFile.read(into: buffer)
            
            // Remove silence if requested
            if removeSilence {
                removeSilenceFromBuffer(buffer)
            }
            
            try destinationFile.write(from: buffer)
        }
        
        return destinationURL
    }
    
    private func removeSilenceFromBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let channel = channelData.pointee
        let frameLength = Int(buffer.frameLength)
        
        let silenceThreshold: Float = 0.01
        
        // Find first non-silent frame
        var startFrame = 0
        for i in 0..<frameLength {
            if abs(channel[i]) > silenceThreshold {
                startFrame = i
                break
            }
        }
        
        // Find last non-silent frame
        var endFrame = frameLength - 1
        for i in (0..<frameLength).reversed() {
            if abs(channel[i]) > silenceThreshold {
                endFrame = i
                break
            }
        }
        
        // Adjust buffer if silence was found
        if startFrame > 0 || endFrame < frameLength - 1 {
            // This is a simplified version - in production, you'd want to properly trim
            // For now, we'll just mark that silence removal should happen at a higher level
        }
    }
    
    // MARK: - Background Compression Queue
    
    func enqueueCompression(
        voiceNoteId: UUID,
        sourceURL: URL,
        preset: CompressionPreset = .standard
    ) {
        let task = Task {
            do {
                let storageManager = VoiceNoteStorageManager.shared
                let tempURL = try storageManager.generateFilePath()
                
                let result = try await compressAudio(
                    at: sourceURL,
                    to: tempURL,
                    preset: preset,
                    removeSilence: true
                )
                
                // Replace original with compressed version
                try FileManager.default.removeItem(at: sourceURL)
                try FileManager.default.moveItem(at: tempURL, to: sourceURL)
                
                // Update repository with new file size and bitrate
                // This would need repository integration
                print("Compressed voice note \(voiceNoteId): \(result.compressionRatio * 100)% of original size")
                
            } catch {
                print("Failed to compress voice note \(voiceNoteId): \(error)")
            }
            
            compressionTasks.removeValue(forKey: voiceNoteId)
        }
        
        compressionTasks[voiceNoteId] = task
    }
    
    func cancelCompression(for voiceNoteId: UUID) {
        compressionTasks[voiceNoteId]?.cancel()
        compressionTasks.removeValue(forKey: voiceNoteId)
    }
}

struct CompressionResult {
    let originalSize: Int64
    let compressedSize: Int64
    let compressionRatio: Double
    let bitrate: Int
    let sampleRate: Int
    
    var spaceSaved: Int64 {
        originalSize - compressedSize
    }
    
    var spaceSavedPercentage: Double {
        (1.0 - compressionRatio) * 100.0
    }
}

enum CompressionError: LocalizedError {
    case noAudioTrack
    case exportSessionCreationFailed
    case exportFailed
    case reEncodingFailed
    
    var errorDescription: String? {
        switch self {
        case .noAudioTrack:
            return "No audio track found in file"
        case .exportSessionCreationFailed:
            return "Failed to create export session"
        case .exportFailed:
            return "Audio export failed"
        case .reEncodingFailed:
            return "Audio re-encoding failed"
        }
    }
}

