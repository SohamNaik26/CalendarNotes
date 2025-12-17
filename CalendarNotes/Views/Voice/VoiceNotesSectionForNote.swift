//
//  VoiceNotesSectionForNote.swift
//  CalendarNotes
//
//  Created by Cursor AI on 17/11/25.
//

import SwiftUI

struct VoiceNotesSectionForNote: View {
	let note: Note
	@State private var voiceNotes: [VoiceNote] = []
	@State private var showingRecorder = false
	@State private var playingId: UUID?
	
	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				Image(systemName: "waveform")
					.foregroundColor(.cnAccent)
				Text("Voice Notes")
					.font(.headline)
				Spacer()
				Button(action: {
					showingRecorder = true
			 }) {
					Image(systemName: "plus.circle.fill")
						.foregroundColor(.cnAccent)
				}
			}
			
			if voiceNotes.isEmpty {
				Text("No voice notes attached")
					.font(.caption)
					.foregroundColor(.secondary)
			} else {
				ForEach(voiceNotes) { voiceNote in
					VoiceNoteRowCompact(
						note: voiceNote,
						isPlaying: playingId == voiceNote.id,
						onPlay: {
							if playingId == voiceNote.id {
								playingId = nil
							} else {
								playingId = voiceNote.id
							}
						}
					)
				}
			}
		}
		.padding()
		.background(Color.cnSecondaryBackground)
		.cornerRadius(12)
		.onAppear {
			loadVoiceNotes()
		}
		.sheet(isPresented: $showingRecorder) {
			VoiceNoteRecordingSheet(
				note: note,
				onSave: {
					loadVoiceNotes()
				}
			)
		}
	}
	
	private func loadVoiceNotes() {
		do {
			voiceNotes = try VoiceNoteRepository.shared.fetchVoiceNotes(for: .note(note))
		} catch {
			print("Failed to load voice notes: \(error)")
		}
	}
}

