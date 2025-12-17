//
//  VoiceNoteRepository.swift
//  CalendarNotes
//
//  Created by GPT-5.1 Codex on 17/11/25.
//

import Foundation
import CoreData

struct VoiceNoteSearchFilter {
	enum LinkedEntity: Hashable {
		case event(UUID)
		case note(UUID)
		case task(UUID)
	}
	
	var query: String = ""
	var dateRange: ClosedRange<Date>?
	var linkedEntity: LinkedEntity?
	var favoritesOnly: Bool = false
	var includeArchived: Bool = true
	var collectionName: String?
	var tags: [String] = []
	var limit: Int?
	
	static func forEvent(_ event: CalendarEvent) -> VoiceNoteSearchFilter {
		var filter = VoiceNoteSearchFilter()
		if let id = event.id {
			filter.linkedEntity = .event(id)
		}
		return filter
	}
}

struct VoiceNoteRecordingPayload {
	let audioFileURL: URL
	let duration: TimeInterval
	var waveformSamples: [Double] = []
	var transcription: String?
	var transcriptionSummary: String?
	var title: String?
	var tags: [String] = []
	var collectionName: String?
	var autoDeleteAfterDays: Int?
	var linkedContext: VoiceNoteLinkContext?
	var createdAt: Date = Date()
}

@MainActor
final class VoiceNoteRepository {
	static let shared = VoiceNoteRepository()
	
	private let manager = CoreDataManager.shared
	private let fileManager = FileManager.default
	
	private init() {}
	
	// MARK: - Fetching
	
    func fetchVoiceNotes(filter: VoiceNoteSearchFilter? = nil) throws -> [VoiceNote] {
        let filter = filter ?? VoiceNoteSearchFilter()
        let request: NSFetchRequest<VoiceNoteEntity> = NSFetchRequest(entityName: "VoiceNoteEntity")
		var predicates: [NSPredicate] = []
		
		if let range = filter.dateRange {
			predicates.append(NSPredicate(format: "createdAt >= %@ AND createdAt <= %@", range.lowerBound as NSDate, range.upperBound as NSDate))
		}
		
		if let linked = filter.linkedEntity {
			switch linked {
			case .event(let id):
				predicates.append(NSPredicate(format: "event.id == %@", id as CVarArg))
			case .note(let id):
				predicates.append(NSPredicate(format: "note.id == %@", id as CVarArg))
			case .task(let id):
				predicates.append(NSPredicate(format: "task.id == %@", id as CVarArg))
			}
		}
		
		if !filter.includeArchived {
			predicates.append(NSPredicate(format: "isArchived == NO"))
		}
		
		if filter.favoritesOnly {
			predicates.append(NSPredicate(format: "isFavorite == YES"))
		}
		
		if let collection = filter.collectionName {
			predicates.append(NSPredicate(format: "collectionName ==[c] %@", collection))
		}
		
		if !filter.tags.isEmpty {
			let tagPredicates = filter.tags.map { NSPredicate(format: "tags CONTAINS[cd] %@", $0) }
			predicates.append(NSCompoundPredicate(andPredicateWithSubpredicates: tagPredicates))
		}
		
		if !filter.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			let query = filter.query
			let queryPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
				NSPredicate(format: "title CONTAINS[cd] %@", query),
				NSPredicate(format: "transcription CONTAINS[cd] %@", query),
				NSPredicate(format: "smartKeywords CONTAINS[cd] %@", query)
			])
			predicates.append(queryPredicate)
		}
		
		if !predicates.isEmpty {
			request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
		}
		
		request.sortDescriptors = [NSSortDescriptor(keyPath: \VoiceNoteEntity.createdAt, ascending: false)]
		if let limit = filter.limit {
			request.fetchLimit = limit
		}
		
		let entities = try manager.fetch(request)
		return entities.compactMap(VoiceNote.init)
	}
	
	func fetchVoiceNotes(for context: VoiceNoteLinkContext) throws -> [VoiceNote] {
		var filter = VoiceNoteSearchFilter()
		switch context {
		case .event(let event):
			if let id = event.id {
				filter.linkedEntity = .event(id)
			}
		case .note(let note):
			if let id = note.id {
				filter.linkedEntity = .note(id)
			}
		case .task(let task):
			if let id = task.id {
				filter.linkedEntity = .task(id)
			}
		}
		return try fetchVoiceNotes(filter: filter)
	}
	
	// MARK: - Creation
	
	@discardableResult
	func createVoiceNote(from payload: VoiceNoteRecordingPayload) throws -> VoiceNote {
		let persistedURL = try persistAudio(at: payload.audioFileURL)
		let context = manager.viewContext
		
		let entity = VoiceNoteEntity(context: context)
		entity.id = UUID()
		entity.audioFilePath = persistedURL.path
		entity.createdAt = payload.createdAt
		entity.updatedAt = payload.createdAt
		
		// Ensure required fields are set (in case model validation requires them)
		if entity.audioFilePath == nil || entity.audioFilePath!.isEmpty {
			entity.audioFilePath = persistedURL.path
		}
		entity.title = payload.title ?? ""
		entity.transcription = payload.transcription
		if let summary = payload.transcriptionSummary {
			entity.transcriptionSummary = summary
		} else if let transcription = payload.transcription {
			entity.transcriptionSummary = String(transcription.prefix(200))
		}
		entity.durationSeconds = payload.duration
		entity.tagsList = payload.tags
		entity.collectionName = payload.collectionName
		entity.isFavorite = false
		entity.isArchived = false
		entity.waveformSamples = payload.waveformSamples
		entity.smartKeywordList = VoiceNoteSuggestionEngine.shared.extractKeywords(from: payload.transcription)
		
		if let autoDeleteAfterDays = payload.autoDeleteAfterDays {
			entity.autoDeleteAfterDays = Int16(autoDeleteAfterDays)
			entity.autoDeleteOn = Calendar.current.date(byAdding: .day, value: autoDeleteAfterDays, to: payload.createdAt)
		}
		
		if let linkedContext = payload.linkedContext {
			link(entity, to: linkedContext)
		}
		
		try manager.save()
		VoiceNoteUsageMetrics.shared.trackCreation()
		return VoiceNote(entity: entity)!
	}
	
	// MARK: - Mutations
	
	func update(_ voiceNote: VoiceNoteEntity, block: (VoiceNoteEntity) -> Void) throws {
		block(voiceNote)
		voiceNote.updatedAt = Date()
		try manager.save()
	}
	
	func delete(_ voiceNote: VoiceNoteEntity) throws {
		if let path = voiceNote.audioFilePath {
			try? fileManager.removeItem(at: URL(fileURLWithPath: path))
		}
		try manager.delete(voiceNote)
		try manager.save()
	}
	
	func toggleFavorite(_ voiceNote: VoiceNoteEntity) throws {
		try update(voiceNote) { entity in
			entity.isFavorite.toggle()
		}
	}
	
	func toggleArchive(_ voiceNote: VoiceNoteEntity) throws {
		try update(voiceNote) { entity in
			entity.isArchived.toggle()
		}
	}
	
	func link(_ voiceNote: VoiceNoteEntity, to context: VoiceNoteLinkContext) {
		switch context {
		case .event(let event):
			voiceNote.event = event
		case .note(let note):
			voiceNote.note = note
		case .task(let task):
			voiceNote.task = task
		}
	}
	
	func unlink(_ voiceNote: VoiceNoteEntity, from context: VoiceNoteLinkContext) {
		switch context {
		case .event:
			voiceNote.event = nil
		case .note:
			voiceNote.note = nil
		case .task:
			voiceNote.task = nil
		}
	}
	
	func purgeExpiredVoiceNotes() throws {
        let request: NSFetchRequest<VoiceNoteEntity> = NSFetchRequest(entityName: "VoiceNoteEntity")
		request.predicate = NSPredicate(format: "autoDeleteOn <= %@", Date() as NSDate)
		
		let expired = try manager.fetch(request)
		for note in expired {
			if let path = note.audioFilePath {
				try? fileManager.removeItem(at: URL(fileURLWithPath: path))
			}
			manager.viewContext.delete(note)
		}
		if !expired.isEmpty {
			try manager.save()
		}
	}
	
	// MARK: - Helpers
	
	private func persistAudio(at url: URL) throws -> URL {
		let directory = try voiceNotesDirectory()
		let destination = directory.appendingPathComponent(url.lastPathComponent)
		
		if fileManager.fileExists(atPath: destination.path) {
			try fileManager.removeItem(at: destination)
		}
		
		if url != destination {
			try fileManager.copyItem(at: url, to: destination)
		}
		
		return destination
	}
	
	private func voiceNotesDirectory() throws -> URL {
		let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
		let directory = docs.appendingPathComponent("VoiceNotesData", isDirectory: true)
		if !fileManager.fileExists(atPath: directory.path) {
			try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
		}
		return directory
	}
}

