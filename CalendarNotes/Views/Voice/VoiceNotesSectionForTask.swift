//
//  VoiceNotesSectionForTask.swift
//  CalendarNotes
//
//  Created by Cursor AI on 17/11/25.
//

import SwiftUI

struct VoiceNotesSectionForTask: View {
	let task: TodoItem
	@State private var voiceNotes: [VoiceNote] = []
	@State private var showingRecorder = false
	@State private var playingId: UUID?
	
	var body: some View {
		Group {
			if voiceNotes.isEmpty {
				Text("No voice instructions attached")
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
		.onAppear {
			loadVoiceNotes()
		}
	}
	
	init(task: TodoItem) {
		self.task = task
	}
	
	func loadVoiceNotes() {
		do {
			voiceNotes = try VoiceNoteRepository.shared.fetchVoiceNotes(for: .task(task))
		} catch {
			print("Failed to load voice notes: \(error)")
		}
	}
}

