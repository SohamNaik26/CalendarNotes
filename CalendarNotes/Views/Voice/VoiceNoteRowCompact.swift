//
//  VoiceNoteRowCompact.swift
//  CalendarNotes
//
//  Created by Cursor AI on 17/11/25.
//

import SwiftUI

struct VoiceNoteRowCompact: View {
	let note: VoiceNote
	let isPlaying: Bool
	let onPlay: () -> Void
	
	var body: some View {
		HStack(spacing: 12) {
			Button(action: onPlay) {
				Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
					.font(.title3)
					.foregroundColor(.cnAccent)
			}
			
			VStack(alignment: .leading, spacing: 4) {
				Text(note.displayTitle)
					.font(.subheadline)
					.fontWeight(.medium)
				
				if let snippet = note.transcriptionSnippet {
					Text(snippet)
						.font(.caption)
						.foregroundColor(.secondary)
						.lineLimit(2)
				} else {
					Text(formatDuration(note.duration))
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}
			
			Spacer()
			
			Text(note.createdAt.formatted(date: .omitted, time: .shortened))
				.font(.caption2)
				.foregroundColor(.secondary)
		}
		.padding(.vertical, 4)
	}
	
	private func formatDuration(_ t: TimeInterval) -> String {
		let s = Int(t)
		return String(format: "%d:%02d", s/60, s%60)
	}
}

