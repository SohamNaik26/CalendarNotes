//
//  VoiceRecorderService.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import AVFoundation
#if os(iOS)
import AVFAudio
import UIKit
#endif
import Combine

#if os(iOS)
enum RecordingError: LocalizedError {
	case permissionDenied
	case configurationFailed
	case fileCreationFailed
	case recordingFailed
	
	var errorDescription: String? {
		switch self {
		case .permissionDenied:
			return "Microphone permission denied"
		case .configurationFailed:
			return "Failed to configure audio session"
		case .fileCreationFailed:
			return "Failed to create recording file"
		case .recordingFailed:
			return "Recording failed"
		}
	}
}

final class VoiceRecorderService: NSObject, ObservableObject {
	static let shared = VoiceRecorderService()
	private override init() {}
	
	private var recorder: AVAudioRecorder?
	private var meterTimer: Timer?
	private var recordingStartDate: Date?
	private var backgroundTaskId: UIBackgroundTaskIdentifier?
	
	@Published private(set) var isRecording: Bool = false
	@Published private(set) var isPaused: Bool = false
	@Published private(set) var currentLevel: Float = 0.0 // 0.0 - 1.0
	@Published private(set) var currentTime: TimeInterval = 0
	
	// MARK: - Permissions & Session
	
	private func configureSession() throws {
		let session = AVAudioSession.sharedInstance()
		try session.setCategory(.record, mode: .default, options: [.allowBluetoothHFP, .allowBluetoothA2DP])
		try session.setActive(true)
	}
	
	private func requestPermissionIfNeeded() async throws {
		#if os(iOS)
		if #available(iOS 17.0, *) {
			let status = AVAudioApplication.shared.recordPermission
			switch status {
			case .undetermined:
				let granted = await AVAudioApplication.requestRecordPermission()
				if !granted { throw RecordingError.permissionDenied }
			case .denied:
				throw RecordingError.permissionDenied
			case .granted:
				break
			@unknown default:
				throw RecordingError.permissionDenied
			}
		} else {
			let status = AVAudioSession.sharedInstance().recordPermission
			switch status {
			case .undetermined:
				let granted = await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
					AVAudioSession.sharedInstance().requestRecordPermission { cont.resume(returning: $0) }
				}
				if !granted { throw RecordingError.permissionDenied }
			case .denied:
				throw RecordingError.permissionDenied
			case .granted:
				break
			@unknown default:
				throw RecordingError.permissionDenied
			}
		}
		#endif
	}
	
	// MARK: - Recording
	
	func startRecording() async throws {
		try await requestPermissionIfNeeded()
		try configureSession()
		
		let url = try makeFileURL()
		let settings: [String: Any] = [
			AVFormatIDKey: kAudioFormatMPEG4AAC,
			AVSampleRateKey: 44100,
			AVNumberOfChannelsKey: 1,
			AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
		]
		
		recorder = try AVAudioRecorder(url: url, settings: settings)
		recorder?.isMeteringEnabled = true
		recorder?.delegate = self
		
		guard recorder?.record() == true else {
			throw NSError(domain: "VoiceRecorder", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to start recording"])
		}
		
		isRecording = true
		isPaused = false
		recordingStartDate = Date()
		startMetering()
		beginBackgroundTask()
	}
	
	func stopRecording() -> URL? {
		guard let recorder else { return nil }
		recorder.stop()
		let url = recorder.url
		cleanupAfterStop()
		return url
	}
	
	func pauseRecording() {
		guard isRecording, !isPaused else { return }
		recorder?.pause()
		isPaused = true
		stopMetering()
	}
	
	func resumeRecording() {
		guard isRecording, isPaused else { return }
		recorder?.record()
		isPaused = false
		startMetering()
	}
	
	func cancelRecording() {
		if let url = recorder?.url {
			recorder?.stop()
			try? FileManager.default.removeItem(at: url)
		}
		cleanupAfterStop()
	}
	
	func deleteRecording(at url: URL) {
		try? FileManager.default.removeItem(at: url)
	}
	
	func getDuration() -> TimeInterval {
		if let start = recordingStartDate {
			return Date().timeIntervalSince(start)
		}
		return recorder?.currentTime ?? 0
	}
	
	func getCurrentTime() -> TimeInterval {
		return recorder?.currentTime ?? currentTime
	}
	
	// MARK: - Metering
	
	private func startMetering() {
		stopMetering()
		meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
			guard let self, let recorder = self.recorder else { return }
			recorder.updateMeters()
			let avg = recorder.averagePower(forChannel: 0) // in dB, ~ -160 .. 0
			let level = self.normalize(power: avg)
			DispatchQueue.main.async {
				self.currentLevel = level
				self.currentTime = recorder.currentTime
			}
		}
	}
	
	private func stopMetering() {
		meterTimer?.invalidate()
		meterTimer = nil
	}
	
	private func normalize(power: Float) -> Float {
		// Map from [-60, 0] dB to [0, 1]
		let minDb: Float = -60.0
		if power < minDb {
			return 0
		} else if power >= 0 {
			return 1
		} else {
			return (power - minDb) / -minDb
		}
	}
	
	// MARK: - Utilities
	
	private func makeFileURL() throws -> URL {
		let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
		let formatter = DateFormatter()
		formatter.dateFormat = "yyyyMMdd-HHmmss"
		let name = "Recording-\(formatter.string(from: Date())).m4a"
		let url = docs.appendingPathComponent(name)
		return url
	}
	
	private func cleanupAfterStop() {
		stopMetering()
		isRecording = false
		isPaused = false
		recordingStartDate = nil
		recorder = nil
		endBackgroundTask()
		try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
	}
	
	// MARK: - Background
	
	private func beginBackgroundTask() {
		#if os(iOS)
		backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "VoiceRecording") { [weak self] in
			// Expiration handler
			self?.endBackgroundTask()
		}
		#endif
	}
	
	private func endBackgroundTask() {
		#if os(iOS)
		if let id = backgroundTaskId {
			UIApplication.shared.endBackgroundTask(id)
			backgroundTaskId = UIBackgroundTaskIdentifier.invalid
		}
		#endif
	}
	
	// MARK: - Disk space
	
	func hasSufficientDiskSpace(minimumBytes: Int64 = 50 * 1024 * 1024) -> Bool {
		guard let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
			  let free = attrs[.systemFreeSize] as? NSNumber else { return true }
		return free.int64Value > minimumBytes
	}
}

extension VoiceRecorderService: AVAudioRecorderDelegate {
	func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
		print("Audio encode error: \(error?.localizedDescription ?? "unknown")")
	}
	
	func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
		if !flag {
			print("Recording finished unsuccessfully")
		}
	}
}
#else
// Non-iOS stub to allow macOS builds
final class VoiceRecorderService: ObservableObject {
	static let shared = VoiceRecorderService()
	private init() {}
	
	@Published private(set) var isRecording: Bool = false
	@Published private(set) var isPaused: Bool = false
	@Published private(set) var currentLevel: Float = 0.0
	@Published private(set) var currentTime: TimeInterval = 0
	
	func startRecording() async throws {
		throw NSError(domain: "VoiceRecorder", code: 0, userInfo: [NSLocalizedDescriptionKey: "Recording is only available on iOS"])
	}
	func stopRecording() -> URL? { nil }
	func pauseRecording() {}
	func resumeRecording() {}
	func cancelRecording() {}
	func deleteRecording(at url: URL) { try? FileManager.default.removeItem(at: url) }
	func getDuration() -> TimeInterval { 0 }
	func getCurrentTime() -> TimeInterval { 0 }
	func hasSufficientDiskSpace(minimumBytes: Int64 = 50 * 1024 * 1024) -> Bool { true }
}
#endif


