//
//  VoiceNotesListForEvent.swift
//  CalendarNotes
//
//  Created by Cursor AI on 17/11/25.
//

import SwiftUI

struct VoiceNotesListForEvent: View {
	let event: CalendarEvent
	@State private var voiceNotes: [VoiceNote] = []
	@State private var playingId: UUID?
	
	var body: some View {
		Group {
			if voiceNotes.isEmpty {
				Text("No voice notes attached")
					.font(.caption)
					.foregroundColor(.secondary)
			} else {
				ForEach(voiceNotes) { note in
					VoiceNoteRowCompact(
						note: note,
						isPlaying: playingId == note.id,
						onPlay: {
							if playingId == note.id {
								playingId = nil
							} else {
								playingId = note.id
							}
						}
					)
				}
			}
		}
		.onAppear {
			loadVoiceNotes()
		}
	}
	
	init(event: CalendarEvent) {
		self.event = event
	}
	
	func loadVoiceNotes() {
		do {
			voiceNotes = try VoiceNoteRepository.shared.fetchVoiceNotes(for: .event(event))
		} catch {
			print("Failed to load voice notes: \(error)")
		}
	}
}

