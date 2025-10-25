//
//  SpeechRecognitionService.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import Foundation
import Speech
import AVFoundation
import Combine

/// Speech recognition service for converting voice to text
@MainActor
class SpeechRecognitionService: ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var transcribedText = ""
    @Published var authorizationStatus: SFSpeechRecognizerAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    @Published var currentLanguage: String = "en-US"
    @Published var audioLevel: Float = 0.0 // For waveform animation
    
    // MARK: - Private Properties
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private var silenceTimer: Timer?
    private let silenceThreshold: TimeInterval = 2.0 // Stop after 2 seconds of silence
    private var lastSpeechTime: Date?
    
    // MARK: - Supported Languages
    let supportedLanguages: [String: String] = [
        "en-US": "English (US)",
        "en-GB": "English (UK)",
        "es-ES": "Spanish",
        "fr-FR": "French",
        "de-DE": "German",
        "it-IT": "Italian",
        "ja-JP": "Japanese",
        "ko-KR": "Korean",
        "zh-CN": "Chinese (Simplified)",
        "pt-BR": "Portuguese (Brazil)",
        "ru-RU": "Russian",
        "ar-SA": "Arabic"
    ]
    
    // MARK: - Initialization
    init() {
        setupSpeechRecognizer()
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: currentLanguage))
        speechRecognizer?.delegate = nil
    }
    
    // MARK: - Authorization
    func requestAuthorization() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Task { @MainActor in
                    self.authorizationStatus = status
                    continuation.resume(returning: status == .authorized)
                }
            }
        }
    }
    
    func requestMicrophonePermission() async -> Bool {
        #if os(iOS)
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        #else
        // macOS doesn't use AVAudioSession
        return true
        #endif
    }
    
    // MARK: - Language Management
    func changeLanguage(to languageCode: String) {
        guard supportedLanguages.keys.contains(languageCode) else {
            errorMessage = "Unsupported language"
            return
        }
        
        // Stop current recording if active
        if isRecording {
            stopRecording()
        }
        
        currentLanguage = languageCode
        setupSpeechRecognizer()
    }
    
    // MARK: - Recording Control
    func startRecording() async {
        // Check speech recognition authorization
        if authorizationStatus != .authorized {
            let authorized = await requestAuthorization()
            guard authorized else {
                errorMessage = "Speech recognition not authorized"
                return
            }
        }
        
        // Check microphone permission
        let micAuthorized = await requestMicrophonePermission()
        guard micAuthorized else {
            errorMessage = "Microphone access not authorized"
            return
        }
        
        // Cancel any ongoing recognition
        if recognitionTask != nil {
            recognitionTask?.cancel()
            recognitionTask = nil
        }
        
        // Configure audio session
        #if os(iOS)
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Failed to setup audio session: \(error.localizedDescription)"
            return
        }
        #endif
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Unable to create recognition request"
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // For better performance on device
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
        
        // Get audio input node
        let inputNode = audioEngine.inputNode
        
        // Start recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }
            
            Task { @MainActor in
                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                    self.lastSpeechTime = Date()
                    
                    // Reset silence timer
                    self.resetSilenceTimer()
                }
                
                if let error = error {
                    self.handleRecognitionError(error)
                }
                
                if result?.isFinal == true {
                    self.stopRecording()
                }
            }
        }
        
        // Configure microphone input
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            self.recognitionRequest?.append(buffer)
            
            // Calculate audio level for waveform animation
            self.calculateAudioLevel(from: buffer)
        }
        
        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            errorMessage = nil
            lastSpeechTime = Date()
            startSilenceTimer()
        } catch {
            errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
        }
    }
    
    func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        isRecording = false
        audioLevel = 0.0
        
        silenceTimer?.invalidate()
        silenceTimer = nil
    }
    
    func resetRecording() {
        transcribedText = ""
        errorMessage = nil
    }
    
    // MARK: - Silence Detection
    private func startSilenceTimer() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            Task { @MainActor [weak self] in
                self?.checkForSilence()
            }
        }
    }
    
    private func resetSilenceTimer() {
        startSilenceTimer()
    }
    
    private func checkForSilence() {
        guard let lastSpeech = lastSpeechTime else { return }
        
        let timeSinceLastSpeech = Date().timeIntervalSince(lastSpeech)
        if timeSinceLastSpeech > silenceThreshold && isRecording {
            stopRecording()
        }
    }
    
    // MARK: - Audio Level Calculation
    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        
        let channelDataValue = channelData.pointee
        let channelDataValueArray = stride(from: 0,
                                           to: Int(buffer.frameLength),
                                           by: buffer.stride).map { channelDataValue[$0] }
        
        let rms = sqrt(channelDataValueArray.map { $0 * $0 }.reduce(0, +) / Float(buffer.frameLength))
        let avgPower = 20 * log10(rms)
        let normalizedLevel = max(0, min(1, (avgPower + 50) / 50))
        
        Task { @MainActor in
            self.audioLevel = normalizedLevel
        }
    }
    
    // MARK: - Error Handling
    private func handleRecognitionError(_ error: Error) {
        let nsError = error as NSError
        
        switch nsError.code {
        case 203: // Network error
            errorMessage = "Network connection required for speech recognition"
        case 209: // Recognition service busy
            errorMessage = "Speech recognition service is busy. Please try again."
        case 216: // Audio session error
            errorMessage = "Audio session error. Please check microphone permissions."
        default:
            errorMessage = "Recognition error: \(error.localizedDescription)"
        }
        
        stopRecording()
    }
    
    // MARK: - Cleanup
    func cleanup() {
        if isRecording {
            stopRecording()
        }
        silenceTimer?.invalidate()
        silenceTimer = nil
        
        // Clean up speech recognition resources
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
    }
    
    deinit {
        // Synchronously clean up to avoid retain cycles
        silenceTimer?.invalidate()
        silenceTimer = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
    }
}

// MARK: - Error Types
enum SpeechRecognitionError: LocalizedError {
    case notAuthorized
    case microphoneNotAuthorized
    case recognizerUnavailable
    case audioEngineFailure
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Speech recognition is not authorized. Please enable it in Settings."
        case .microphoneNotAuthorized:
            return "Microphone access is not authorized. Please enable it in Settings."
        case .recognizerUnavailable:
            return "Speech recognizer is not available for the selected language."
        case .audioEngineFailure:
            return "Failed to start audio engine. Please try again."
        }
    }
}

