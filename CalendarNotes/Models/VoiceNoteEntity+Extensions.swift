//
//  VoiceNoteEntity+Extensions.swift
//  CalendarNotes
//
//  Created by GPT-5.1 Codex on 17/11/25.
//

import Foundation
import CoreData

extension VoiceNoteEntity {
	var tagsList: [String] {
		get {
			guard let tags, !tags.isEmpty else { return [] }
			return tags
				.components(separatedBy: ",")
				.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
				.filter { !$0.isEmpty }
		}
		set {
			let normalized = newValue
				.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
				.filter { !$0.isEmpty }
			tags = normalized.isEmpty ? nil : normalized.joined(separator: ", ")
		}
	}
	
	var smartKeywordList: [String] {
		get {
			guard let smartKeywords, !smartKeywords.isEmpty else { return [] }
			return smartKeywords
				.components(separatedBy: ",")
				.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
				.filter { !$0.isEmpty }
		}
		set {
			let normalized = newValue
				.map { $0.lowercased() }
				.filter { !$0.isEmpty }
			smartKeywords = normalized.isEmpty ? nil : normalized.joined(separator: ",")
		}
	}
	
	var waveformSamples: [Double] {
		get {
			guard let waveformSamplesJSON,
				  let data = waveformSamplesJSON.data(using: .utf8),
				  let samples = try? JSONDecoder().decode([Double].self, from: data) else {
				return []
			}
			return samples
		}
		set {
			if newValue.isEmpty {
				waveformSamplesJSON = nil
			} else if let data = try? JSONEncoder().encode(newValue) {
				waveformSamplesJSON = String(data: data, encoding: .utf8)
			}
		}
	}
	
	func updateMetadata(from model: VoiceNote) {
		title = model.title
		transcription = model.transcription
		transcriptionSummary = model.transcriptionSummary
		durationSeconds = model.duration
		createdAt = model.createdAt
		updatedAt = model.updatedAt
		tagsList = model.tags
		collectionName = model.collectionName
		isFavorite = model.isFavorite
		isArchived = model.isArchived
		if let days = model.autoDeleteAfterDays {
			autoDeleteAfterDays = Int16(days)
		} else {
			autoDeleteAfterDays = 0
		}
		autoDeleteOn = model.autoDeleteOn
		lastPlayedAt = model.lastPlayedAt
		smartKeywordList = model.smartKeywords
		waveformSamples = model.waveformSamples
	}
	
	var playbackDisplayTitle: String {
		if let title, !title.isEmpty { return title }
		if let path = audioFilePath {
			return URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
		}
		return "Voice Note"
	}
}

