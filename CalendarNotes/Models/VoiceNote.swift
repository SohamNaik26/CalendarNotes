//
//  VoiceNote.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import CoreData

/// Lightweight domain model used by SwiftUI views to render and interact with persisted voice notes.
struct VoiceNote: Identifiable, Codable, Equatable {
	enum LinkedEntity: Equatable {
		case event(UUID)
		case note(UUID)
		case task(UUID)
	}
	
	let id: UUID
	var title: String
	let audioFileURL: URL
	var transcription: String?
	var transcriptionSummary: String?
	let duration: TimeInterval
	let createdAt: Date
	var updatedAt: Date
	var linkedNoteId: UUID?
	var linkedEventId: UUID?
	var linkedTaskId: UUID?
	var tags: [String]
	var collectionName: String?
	var isFavorite: Bool
	var isArchived: Bool
	var autoDeleteAfterDays: Int?
	var autoDeleteOn: Date?
	var lastPlayedAt: Date?
	var smartKeywords: [String]
	var waveformSamples: [Double]
	
	var hasTranscription: Bool {
		guard let transcription else { return false }
		return !transcription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
	}
	
	var displayTitle: String {
		if !title.trimmingCharacters(in: .whitespaces).isEmpty {
			return title
		}
		return audioFileURL.deletingPathExtension().lastPathComponent
	}
	
	var transcriptionSnippet: String? {
		guard let transcription else { return nil }
		return transcription.count > 160 ? String(transcription.prefix(160)) + "…" : transcription
	}
	
	var linkedEntities: [LinkedEntity] {
		var entities: [LinkedEntity] = []
		if let linkedEventId { entities.append(.event(linkedEventId)) }
		if let linkedNoteId { entities.append(.note(linkedNoteId)) }
		if let linkedTaskId { entities.append(.task(linkedTaskId)) }
		return entities
	}
	
	init(
		id: UUID = UUID(),
		title: String = "",
		audioFileURL: URL,
		transcription: String? = nil,
		transcriptionSummary: String? = nil,
		duration: TimeInterval,
		createdAt: Date = Date(),
		updatedAt: Date = Date(),
		linkedNoteId: UUID? = nil,
		linkedEventId: UUID? = nil,
		linkedTaskId: UUID? = nil,
		tags: [String] = [],
		collectionName: String? = nil,
		isFavorite: Bool = false,
		isArchived: Bool = false,
		autoDeleteAfterDays: Int? = nil,
		autoDeleteOn: Date? = nil,
		lastPlayedAt: Date? = nil,
		smartKeywords: [String] = [],
		waveformSamples: [Double] = []
	) {
		self.id = id
		self.title = title
		self.audioFileURL = audioFileURL
		self.transcription = transcription
		self.transcriptionSummary = transcriptionSummary
		self.duration = duration
		self.createdAt = createdAt
		self.updatedAt = updatedAt
		self.linkedNoteId = linkedNoteId
		self.linkedEventId = linkedEventId
		self.linkedTaskId = linkedTaskId
		self.tags = tags
		self.collectionName = collectionName
		self.isFavorite = isFavorite
		self.isArchived = isArchived
		self.autoDeleteAfterDays = autoDeleteAfterDays
		self.autoDeleteOn = autoDeleteOn
		self.lastPlayedAt = lastPlayedAt
		self.smartKeywords = smartKeywords
		self.waveformSamples = waveformSamples
	}
	
	init?(entity: VoiceNoteEntity) {
		guard let id = entity.id,
			  let path = entity.audioFilePath else {
			return nil
		}
		
		self.id = id
		self.title = entity.title ?? ""
		self.audioFileURL = URL(fileURLWithPath: path)
		self.transcription = entity.transcription
		self.transcriptionSummary = entity.transcriptionSummary
		self.duration = entity.durationSeconds
		self.createdAt = entity.createdAt ?? Date()
		self.updatedAt = entity.updatedAt ?? entity.createdAt ?? Date()
		self.linkedNoteId = entity.note?.id
		self.linkedEventId = entity.event?.id
		self.linkedTaskId = entity.task?.id
		self.tags = entity.tagsList
		self.collectionName = entity.collectionName
		self.isFavorite = entity.isFavorite
		self.isArchived = entity.isArchived
		if entity.autoDeleteAfterDays != 0 {
			self.autoDeleteAfterDays = Int(entity.autoDeleteAfterDays)
		} else {
			self.autoDeleteAfterDays = nil
		}
		self.autoDeleteOn = entity.autoDeleteOn
		self.lastPlayedAt = entity.lastPlayedAt
		self.smartKeywords = entity.smartKeywordList
		self.waveformSamples = entity.waveformSamples
	}
}


