//
//  VoiceRecordingPanel.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import SwiftUI

/// Complete voice recording panel with controls and visualization
struct VoiceRecordingPanel: View {
    @ObservedObject var speechService: SpeechRecognitionService
    let onTranscriptionUpdate: (String) -> Void
    
    @State private var showLanguagePicker = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text(speechService.isRecording ? "Recording..." : "Voice to Text")
                    .font(.headline)
                
                Spacer()
                
                // Language selector
                Button(action: { showLanguagePicker.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "globe")
                        Text(languageDisplayName)
                            .font(.caption)
                    }
                    .foregroundColor(.cnPrimary)
                }
            }
            
            // Waveform visualization
            if speechService.isRecording {
                WaveformView(audioLevel: $speechService.audioLevel)
                    .frame(height: 50)
                    .transition(.scale.combined(with: .opacity))
            }
            
            // Transcription preview
            if !speechService.transcribedText.isEmpty {
                ScrollView {
                    Text(speechService.transcribedText)
                        .font(.body)
                        .foregroundColor(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.cnSecondaryBackground)
                        .cornerRadius(8)
                }
                .frame(maxHeight: 100)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Error message
            if let error = speechService.errorMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.cnStatusError)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.cnStatusError)
                }
                .padding(8)
                .background(Color.cnStatusError.opacity(0.1))
                .cornerRadius(6)
                .transition(.scale.combined(with: .opacity))
            }
            
            // Control buttons
            HStack(spacing: 20) {
                // Record/Stop button
                RecordingButton(isRecording: $speechService.isRecording) {
                    handleRecordingToggle()
                }
                
                // Action buttons (only when not recording)
                if !speechService.isRecording && !speechService.transcribedText.isEmpty {
                    VStack(spacing: 8) {
                        // Append button
                        Button(action: appendTranscription) {
                            VStack(spacing: 4) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                Text("Append")
                                    .font(.caption)
                            }
                            .foregroundColor(.cnStatusSuccess)
                        }
                        
                        // Clear button
                        Button(action: clearTranscription) {
                            VStack(spacing: 4) {
                                Image(systemName: "trash.circle.fill")
                                    .font(.title2)
                                Text("Clear")
                                    .font(.caption)
                            }
                            .foregroundColor(.cnStatusError)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.vertical, 8)
            
            // Recording hint
            if speechService.isRecording {
                Text("Speak clearly into your device microphone")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .transition(.opacity)
            }
        }
        .padding()
        .background(Color.cnBackground)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
        .animation(.spring(), value: speechService.isRecording)
        .animation(.spring(), value: speechService.transcribedText)
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView(
                selectedLanguage: $speechService.currentLanguage,
                languages: speechService.supportedLanguages,
                onSelect: { language in
                    speechService.changeLanguage(to: language)
                    showLanguagePicker = false
                }
            )
        }
    }
    
    private var languageDisplayName: String {
        speechService.supportedLanguages[speechService.currentLanguage] ?? "English (US)"
    }
    
    private func handleRecordingToggle() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            Task {
                await speechService.startRecording()
            }
        }
    }
    
    private func appendTranscription() {
        onTranscriptionUpdate(speechService.transcribedText)
        speechService.resetRecording()
    }
    
    private func clearTranscription() {
        speechService.resetRecording()
    }
}

/// Language picker view
struct LanguagePickerView: View {
    @Binding var selectedLanguage: String
    let languages: [String: String]
    let onSelect: (String) -> Void
    
    @Environment(\.dismiss) var dismiss
    
    var sortedLanguages: [(key: String, value: String)] {
        languages.sorted { $0.value < $1.value }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(sortedLanguages, id: \.key) { language in
                    Button(action: {
                        onSelect(language.key)
                    }) {
                        HStack {
                            Text(language.value)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if language.key == selectedLanguage {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.cnPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Language")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Compact inline recording control
struct InlineRecordingControl: View {
    @ObservedObject var speechService: SpeechRecognitionService
    
    var body: some View {
        HStack(spacing: 12) {
            // Compact button
            CompactRecordingButton(isRecording: $speechService.isRecording) {
                handleRecordingToggle()
            }
            
            // Waveform or status
            if speechService.isRecording {
                CompactWaveformView(audioLevel: $speechService.audioLevel)
                    .transition(.scale)
            } else if !speechService.transcribedText.isEmpty {
                Text("\(speechService.transcribedText.prefix(30))...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
        }
        .animation(.spring(), value: speechService.isRecording)
    }
    
    private func handleRecordingToggle() {
        if speechService.isRecording {
            speechService.stopRecording()
        } else {
            Task {
                await speechService.startRecording()
            }
        }
    }
}

#Preview("Voice Recording Panel") {
    VoiceRecordingPanel(
        speechService: SpeechRecognitionService(),
        onTranscriptionUpdate: { text in
            print("Transcription: \(text)")
        }
    )
    .padding()
}

#Preview("Inline Recording") {
    InlineRecordingControl(speechService: SpeechRecognitionService())
        .padding()
}

