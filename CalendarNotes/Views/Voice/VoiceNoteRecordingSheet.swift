//
//  VoiceNoteRecordingSheet.swift
//  CalendarNotes
//
//  Created by Cursor AI on 17/11/25.
//

import SwiftUI

struct VoiceNoteRecordingSheet: View {
	let event: CalendarEvent?
	let note: Note?
	let task: TodoItem?
	let onSave: () -> Void
	
	@Environment(\.dismiss) var dismiss
	@StateObject private var recorder = VoiceRecorderService.shared
	@State private var savedURL: URL?
	@State private var transcription: String?
	@State private var showingSuggestions = false
	@State private var suggestions: [VoiceNoteSuggestion] = []
	
	init(event: CalendarEvent? = nil, note: Note? = nil, task: TodoItem? = nil, onSave: @escaping () -> Void) {
		self.event = event
		self.note = note
		self.task = task
		self.onSave = onSave
	}
	
	var body: some View {
		NavigationView {
			VStack(spacing: 20) {
				VoiceRecorderView()
				
				if savedURL != nil {
					VStack(spacing: 12) {
						Text("Recording saved")
							.font(.headline)
						
						Button("Transcribe") {
							Task {
								await transcribeRecording()
							}
						}
						.buttonStyle(.borderedProminent)
						
						if let transcription = transcription {
							TextEditor(text: .constant(transcription))
								.frame(height: 100)
								.padding(8)
								.background(Color.cnSecondaryBackground)
								.cornerRadius(8)
							
							if !suggestions.isEmpty {
								VStack(alignment: .leading, spacing: 8) {
									Text("Suggestions:")
										.font(.subheadline)
										.fontWeight(.semibold)
									
									ForEach(Array(suggestions.enumerated()), id: \.offset) { _, suggestion in
										suggestionButton(for: suggestion)
									}
								}
							}
							
							Button("Save Voice Note") {
								saveVoiceNote()
							}
							.buttonStyle(.borderedProminent)
						}
					}
					.padding()
				}
				
				Spacer()
			}
			.padding()
			.navigationTitle("Record Voice Note")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") {
						dismiss()
					}
				}
			}
		}
		.onChange(of: recorder.isRecording) { _, isRecording in
			if !isRecording, let url = recorder.stopRecording() {
				savedURL = url
			}
		}
	}
	
	private func transcribeRecording() async {
		guard let url = savedURL else { return }
		
		do {
			transcription = try await VoiceTranscriptionService.shared.transcribeAudioFile(url: url)
			
			// Get suggestions
			suggestions = VoiceNoteSuggestionEngine.shared.suggestActions(from: transcription)
			showingSuggestions = !suggestions.isEmpty
		} catch {
			print("Transcription error: \(error)")
		}
	}
	
	private func saveVoiceNote() {
		guard let url = savedURL else { return }
		
		do {
			let duration = recorder.getDuration()
			var payload = VoiceNoteRecordingPayload(
				audioFileURL: url,
				duration: duration,
				transcription: transcription
			)
			
			// Auto-link based on context
			if let event = event {
				payload.linkedContext = .event(event)
			} else if let note = note {
				payload.linkedContext = .note(note)
			} else if let task = task {
				payload.linkedContext = .task(task)
			} else {
				// Smart suggestion: link to current event if recording during event time
				if let currentEvent = VoiceNoteSuggestionEngine.shared.suggestEventForCurrentTime() {
					payload.linkedContext = .event(currentEvent)
				}
			}
			
			_ = try VoiceNoteRepository.shared.createVoiceNote(from: payload)
			
			// If linked to note, append transcription
			if let note = note, let transcription = transcription {
				try? VoiceNoteActionHandler.shared.appendTranscriptionToNote(note, transcription: transcription)
			}
			
			onSave()
			dismiss()
		} catch {
			print("Failed to save voice note: \(error)")
		}
	}
	
	@ViewBuilder
	private func suggestionButton(for suggestion: VoiceNoteSuggestion) -> some View {
		switch suggestion {
		case .createEvent:
			Button("Create Event from Recording") {
				// Handle event creation
			}
			.buttonStyle(.bordered)
		case .createTask:
			Button("Create Task from Recording") {
				// Handle task creation
			}
			.buttonStyle(.bordered)
		case .createNote:
			Button("Create Note from Recording") {
				// Handle note creation
			}
			.buttonStyle(.bordered)
		default:
			EmptyView()
		}
	}
}

