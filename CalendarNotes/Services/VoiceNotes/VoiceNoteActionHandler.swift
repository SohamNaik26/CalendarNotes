//
//  VoiceNoteActionHandler.swift
//  CalendarNotes
//
//  Created by Cursor AI on 17/11/25.
//

import Foundation
import CoreData

/// Handles transcription-driven actions (create note/event/task, append transcription, etc.)
@MainActor
final class VoiceNoteActionHandler {
	static let shared = VoiceNoteActionHandler()
	
	private let manager = CoreDataManager.shared
	private let suggestionEngine = VoiceNoteSuggestionEngine.shared
	private let repository = VoiceNoteRepository.shared
	
	private init() {}
	
	// MARK: - Create from Transcription
	
	/// Creates a new note from voice note transcription
	func createNote(from voiceNote: VoiceNote) throws -> Note {
		guard let transcription = voiceNote.transcription, !transcription.isEmpty else {
			throw VoiceNoteActionError.missingTranscription
		}
		
		let context = manager.viewContext
		let note = Note(context: context)
		note.id = UUID()
		note.content = transcription
		note.createdDate = Date()
		
		// Link voice note to the new note
		if let entity = try? fetchVoiceNoteEntity(id: voiceNote.id) {
			repository.link(entity, to: .note(note))
		}
		
		try manager.save()
		return note
	}
	
	/// Creates a new event from voice note transcription
	func createEvent(from voiceNote: VoiceNote, viewModel: CalendarViewModel) async throws -> CalendarEvent {
		guard let transcription = voiceNote.transcription, !transcription.isEmpty else {
			throw VoiceNoteActionError.missingTranscription
		}
		
		// Parse title (first sentence or first 50 chars)
		let title = transcription.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? String(transcription.prefix(50))
		
		// Parse date/time
		let suggestedDate = suggestionEngine.parseDate(from: transcription) ?? Date()
		let startDate = suggestedDate
		let endDate = Calendar.current.date(byAdding: .hour, value: 1, to: startDate) ?? startDate.addingTimeInterval(3600)
		
		// Create event
		let event = try manager.createEvent(
			title: title,
			startDate: startDate,
			endDate: endDate,
			category: EventCategory.personal.rawValue,
			notes: transcription
		)
		
		// Link voice note to the new event
		if let entity = try? fetchVoiceNoteEntity(id: voiceNote.id) {
			repository.link(entity, to: .event(event))
		}
		
		viewModel.loadEvents()
		return event
	}
	
	/// Creates a new task from voice note transcription
	func createTask(from voiceNote: VoiceNote, viewModel: TasksViewModel) throws -> TodoItem {
		guard let transcription = voiceNote.transcription, !transcription.isEmpty else {
			throw VoiceNoteActionError.missingTranscription
		}
		
		// Extract title (first line or first 100 chars)
		let title = transcription.components(separatedBy: .newlines).first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? String(transcription.prefix(100))
		
		// Detect priority from transcription
		let lowercased = transcription.lowercased()
		let priority: String
		if lowercased.contains("urgent") || lowercased.contains("asap") || lowercased.contains("critical") {
			priority = TodoItem.Priority.urgent.rawValue
		} else if lowercased.contains("high") || lowercased.contains("important") {
			priority = TodoItem.Priority.high.rawValue
		} else if lowercased.contains("low") {
			priority = TodoItem.Priority.low.rawValue
		} else {
			priority = TodoItem.Priority.medium.rawValue
		}
		
		// Parse due date
		let dueDate = suggestionEngine.parseDate(from: transcription)
		
		// Create task
		let context = manager.viewContext
		let task = TodoItem(context: context)
		task.id = UUID()
		task.title = title
		task.priority = priority
		task.category = EventCategory.personal.rawValue
		task.dueDate = dueDate
		task.isCompleted = false
		
		// Link voice note to the new task
		if let entity = try? fetchVoiceNoteEntity(id: voiceNote.id) {
			repository.link(entity, to: .task(task))
		}
		
		try manager.save()
		viewModel.loadTasks()
		return task
	}
	
	// MARK: - Append Transcription
	
	/// Appends transcription to existing note
	func appendTranscriptionToNote(_ note: Note, transcription: String) throws {
		let existingContent = note.content ?? ""
		let separator = existingContent.isEmpty ? "" : "\n\n"
		note.content = existingContent + separator + transcription
		
		try manager.save()
		NoteAnalysisService.shared.analyze(note: note, autoSave: false)
	}
	
	/// Appends transcription to existing task description
	func appendTranscriptionToTask(_ task: TodoItem, transcription: String) throws {
		// Note: TodoItem doesn't have a description field in the current model
		// This could be added to the model or stored in a notes field
		// For now, we'll skip this or add a notes field
		try manager.save()
	}
	
	// MARK: - Extract Action Items
	
	/// Extracts and returns action items from transcription
	func extractActionItems(from voiceNote: VoiceNote) -> [String] {
		return suggestionEngine.extractActionItems(from: voiceNote.transcription)
	}
	
	// MARK: - Helpers
	
	private func fetchVoiceNoteEntity(id: UUID) throws -> VoiceNoteEntity? {
		let request: NSFetchRequest<VoiceNoteEntity> = VoiceNoteEntity.fetchRequest()
		request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
		request.fetchLimit = 1
		return try manager.viewContext.fetch(request).first
	}
}

enum VoiceNoteActionError: LocalizedError {
	case missingTranscription
	case invalidEntity
	
	var errorDescription: String? {
		switch self {
		case .missingTranscription:
			return "Voice note does not have transcription"
		case .invalidEntity:
			return "Invalid voice note entity"
		}
	}
}

