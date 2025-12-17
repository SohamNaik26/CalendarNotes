//
//  VoiceTranscriptionService.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import AVFoundation
import Combine

#if os(iOS)
import Speech

@MainActor
final class VoiceTranscriptionService: NSObject, ObservableObject {
	static let shared = VoiceTranscriptionService()
	private override init() {}
	
	private let languageKey = "transcription.language.identifier"
	private let onDeviceOnlyKey = "transcription.onDeviceOnly"
	private let autoTranscribeKey = "transcription.auto"
	
	private var speechRecognizer: SFSpeechRecognizer? {
		let locale = preferredLocale()
		return SFSpeechRecognizer(locale: locale)
	}
	
	private var recognitionTask: SFSpeechRecognitionTask?
	private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
	private let audioEngine = AVAudioEngine()
	
	@Published private(set) var isTranscribing: Bool = false
	@Published private(set) var currentText: String = ""
	@Published private(set) var progress: Double = 0
	
	// MARK: - Permissions
	
	func requestPermission() async throws {
		let auth = SFSpeechRecognizer.authorizationStatus()
		switch auth {
		case .authorized:
			return
		case .notDetermined:
			let granted = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Bool, Error>) in
				SFSpeechRecognizer.requestAuthorization { status in
					switch status {
					case .authorized: cont.resume(returning: true)
					case .denied, .restricted, .notDetermined:
						cont.resume(throwing: NSError(domain: "Speech", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"]))
					@unknown default:
						cont.resume(throwing: NSError(domain: "Speech", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unknown speech auth status"]))
					}
				}
			}
			guard granted else { throw NSError(domain: "Speech", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"]) }
		default:
			throw NSError(domain: "Speech", code: 1, userInfo: [NSLocalizedDescriptionKey: "Speech recognition not authorized"])
		}
	}
	
	// MARK: - File Transcription
	
	func transcribeAudioFile(url: URL) async throws -> String {
		try await requestPermission()
		guard let recognizer = speechRecognizer, recognizer.isAvailable else {
			throw NSError(domain: "Speech", code: 2, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"])
		}
		
		let request = SFSpeechURLRecognitionRequest(url: url)
		request.requiresOnDeviceRecognition = UserDefaults.standard.bool(forKey: onDeviceOnlyKey)
		request.shouldReportPartialResults = false
		
		return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
			self.isTranscribing = true
			self.currentText = ""
			self.progress = 0
			self.recognitionTask?.cancel()
			self.recognitionTask = recognizer.recognitionTask(with: request) { result, error in
				if let error {
					self.isTranscribing = false
					return cont.resume(throwing: error)
				}
				if let result {
					self.currentText = result.bestTranscription.formattedString
					if result.isFinal {
						self.isTranscribing = false
						return cont.resume(returning: self.currentText)
					}
				}
			}
		}
	}
	
	// MARK: - Live Transcription
	
	func startLiveTranscription() async throws {
		try await requestPermission()
		guard let recognizer = speechRecognizer, recognizer.isAvailable else {
			throw NSError(domain: "Speech", code: 2, userInfo: [NSLocalizedDescriptionKey: "Speech recognizer not available"])
		}
		cancelTranscription()
		
		let audioSession = AVAudioSession.sharedInstance()
		try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
		try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
		
		let request = SFSpeechAudioBufferRecognitionRequest()
		request.requiresOnDeviceRecognition = UserDefaults.standard.bool(forKey: onDeviceOnlyKey)
		request.shouldReportPartialResults = true
		self.recognitionRequest = request
		
		let inputNode = audioEngine.inputNode
		let format = inputNode.outputFormat(forBus: 0)
		inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
			self.recognitionRequest?.append(buffer)
		}
		
		audioEngine.prepare()
		try audioEngine.start()
		
		self.isTranscribing = true
		self.currentText = ""
		self.progress = 0
		
		self.recognitionTask = recognizer.recognitionTask(with: request) { result, error in
			if error != nil {
				self.stopLiveTranscription()
				return
			}
			if let result {
				self.currentText = result.bestTranscription.formattedString
				if result.isFinal {
					self.stopLiveTranscription()
				}
			}
		}
	}
	
	func transcribeLiveAudio(audioBuffer: AVAudioPCMBuffer) async throws -> String {
		// If live transcription is active, append and return current best string
		guard let request = recognitionRequest else {
			throw NSError(domain: "Speech", code: 3, userInfo: [NSLocalizedDescriptionKey: "Live transcription not started"])
		}
		request.append(audioBuffer)
		return currentText
	}
	
	func stopLiveTranscription() {
		audioEngine.inputNode.removeTap(onBus: 0)
		audioEngine.stop()
		recognitionRequest?.endAudio()
		recognitionTask?.cancel()
		recognitionTask = nil
		recognitionRequest = nil
		isTranscribing = false
	}
	
	func cancelTranscription() {
		audioEngine.inputNode.removeTap(onBus: 0)
		audioEngine.stop()
		recognitionRequest?.endAudio()
		recognitionTask?.cancel()
		recognitionTask = nil
		recognitionRequest = nil
		isTranscribing = false
	}
	
	// MARK: - Languages
	
	func getAvailableLanguages() -> [Locale] {
		Array(SFSpeechRecognizer.supportedLocales()).sorted { $0.identifier < $1.identifier }
	}
	
	func setPreferredLocale(_ locale: Locale) {
		UserDefaults.standard.set(locale.identifier, forKey: languageKey)
	}
	
	func preferredLocale() -> Locale {
		if let id = UserDefaults.standard.string(forKey: languageKey) {
			return Locale(identifier: id)
		}
		return Locale.current
	}
	
	func setOnDeviceOnly(_ enabled: Bool) {
		UserDefaults.standard.set(enabled, forKey: onDeviceOnlyKey)
	}
	
	func isOnDeviceOnly() -> Bool {
		UserDefaults.standard.bool(forKey: onDeviceOnlyKey)
	}
	
	func setAutoTranscribe(_ enabled: Bool) {
		UserDefaults.standard.set(enabled, forKey: autoTranscribeKey)
	}
	
	func isAutoTranscribeEnabled() -> Bool {
		UserDefaults.standard.bool(forKey: autoTranscribeKey)
	}
}
#else
// Non-iOS stub for macOS builds
final class VoiceTranscriptionService: ObservableObject {
	static let shared = VoiceTranscriptionService()
	private init() {}
	
	func requestPermission() async throws {}
	func transcribeAudioFile(url: URL) async throws -> String { throw NSError(domain: "Speech", code: 0, userInfo: [NSLocalizedDescriptionKey: "Transcription only on iOS"]) }
	func transcribeLiveAudio(audioBuffer: AVAudioPCMBuffer) async throws -> String { throw NSError(domain: "Speech", code: 0, userInfo: [NSLocalizedDescriptionKey: "Transcription only on iOS"]) }
	func cancelTranscription() {}
	func getAvailableLanguages() -> [Locale] { [] }
	func setPreferredLocale(_ locale: Locale) {}
	func preferredLocale() -> Locale { Locale.current }
	func setOnDeviceOnly(_ enabled: Bool) {}
	func isOnDeviceOnly() -> Bool { false }
	func setAutoTranscribe(_ enabled: Bool) {}
	func isAutoTranscribeEnabled() -> Bool { false }
}
#endif


