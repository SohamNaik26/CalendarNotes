//
//  VoiceNoteSuggestionEngine.swift
//  CalendarNotes
//
//  Created by Cursor AI on 17/11/25.
//

import Foundation
import CoreData

/// Engine for smart suggestions when recording or processing voice notes
@MainActor
final class VoiceNoteSuggestionEngine {
	static let shared = VoiceNoteSuggestionEngine()
	
	private let manager = CoreDataManager.shared
	private let calendar = Calendar.current
	
	private init() {}
	
	// MARK: - Keyword Extraction
	
	func extractKeywords(from transcription: String?) -> [String] {
		guard let transcription = transcription?.lowercased(), !transcription.isEmpty else { return [] }
		
		// Common action words and important terms
		let actionWords = ["meeting", "call", "task", "todo", "reminder", "deadline", "event", "appointment", "note", "important", "urgent", "schedule"]
		let timeWords = ["today", "tomorrow", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday", "morning", "afternoon", "evening", "week", "month"]
		let priorityWords = ["urgent", "high", "low", "medium", "critical", "asap"]
		
		var keywords: Set<String> = []
		
		for word in actionWords + timeWords + priorityWords {
			if transcription.contains(word) {
				keywords.insert(word)
			}
		}
		
		// Extract potential dates (simple pattern matching)
		let datePatterns = [
			"\\d{1,2}/\\d{1,2}", // MM/DD
			"\\d{1,2}-\\d{1,2}", // MM-DD
			"january|february|march|april|may|june|july|august|september|october|november|december"
		]
		
		for pattern in datePatterns {
			if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
				let range = NSRange(transcription.startIndex..., in: transcription)
				if regex.firstMatch(in: transcription, options: [], range: range) != nil {
					keywords.insert("date")
				}
			}
		}
		
		return Array(keywords)
	}
	
	// MARK: - Smart Linking Suggestions
	
	/// Suggests linking to an event if recording during event time
	func suggestEventForCurrentTime() -> CalendarEvent? {
		let now = Date()
		let context = manager.viewContext
		
		let request: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
		request.predicate = NSPredicate(
			format: "startDate <= %@ AND endDate >= %@",
			now as NSDate,
			now as NSDate
		)
		request.fetchLimit = 1
		
		return try? context.fetch(request).first
	}
	
	/// Suggests creating entities based on transcription content
	func suggestActions(from transcription: String?) -> [VoiceNoteSuggestion] {
		guard let transcription = transcription?.lowercased(), !transcription.isEmpty else { return [] }
		
		var suggestions: [VoiceNoteSuggestion] = []
		
		// Check for event keywords
		if transcription.contains("meeting") || transcription.contains("appointment") || transcription.contains("event") || transcription.contains("schedule") {
			suggestions.append(.createEvent)
		}
		
		// Check for task keywords
		if transcription.contains("task") || transcription.contains("todo") || transcription.contains("reminder") || transcription.contains("deadline") || transcription.contains("need to") || transcription.contains("should") {
			suggestions.append(.createTask)
		}
		
		// Check for note keywords
		if transcription.contains("note") || transcription.contains("remember") || transcription.contains("idea") || transcription.contains("thought") {
			suggestions.append(.createNote)
		}
		
		// Check for date/time mentions
		if transcription.contains("today") || transcription.contains("tomorrow") || transcription.contains("monday") || transcription.contains("tuesday") || transcription.contains("wednesday") || transcription.contains("thursday") || transcription.contains("friday") || transcription.contains("saturday") || transcription.contains("sunday") {
			if !suggestions.contains(.createEvent) && !suggestions.contains(.createTask) {
				suggestions.append(.createEvent)
			}
		}
		
		return suggestions
	}
	
	// MARK: - Date/Time Parsing
	
	/// Attempts to parse date/time from transcription
	func parseDate(from transcription: String?) -> Date? {
		guard let transcription = transcription?.lowercased() else { return nil }
		
		let now = Date()
		let calendar = Calendar.current
		
		// Today
		if transcription.contains("today") {
			return calendar.startOfDay(for: now)
		}
		
		// Tomorrow
		if transcription.contains("tomorrow") {
			return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))
		}
		
		// Day of week
		let weekdays = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"]
		for (index, day) in weekdays.enumerated() {
			if transcription.contains(day) {
				let todayWeekday = calendar.component(.weekday, from: now) - 1
				var daysToAdd = index - todayWeekday
				if daysToAdd <= 0 {
					daysToAdd += 7
				}
				return calendar.date(byAdding: .day, value: daysToAdd, to: calendar.startOfDay(for: now))
			}
		}
		
		// Time parsing (simple patterns)
		let timePattern = "(\\d{1,2}):?(\\d{2})?\\s*(am|pm)?"
		if let regex = try? NSRegularExpression(pattern: timePattern, options: .caseInsensitive) {
			let range = NSRange(transcription.startIndex..., in: transcription)
			if regex.firstMatch(in: transcription, options: [], range: range) != nil {
				// Basic time extraction - could be enhanced
				return now
			}
		}
		
		return nil
	}
	
	// MARK: - Action Item Extraction
	
	/// Extracts action items from transcription
	func extractActionItems(from transcription: String?) -> [String] {
		guard let transcription = transcription else { return [] }
		
		var actionItems: [String] = []
		let lines = transcription.components(separatedBy: .newlines)
		
		for line in lines {
			let lowercased = line.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
			
			// Look for action indicators
			if lowercased.hasPrefix("-") || lowercased.hasPrefix("•") || lowercased.hasPrefix("*") {
				actionItems.append(line.trimmingCharacters(in: CharacterSet(charactersIn: "-•* ")))
			} else if lowercased.contains("need to") || lowercased.contains("should") || lowercased.contains("must") || lowercased.contains("todo") {
				actionItems.append(line)
			}
		}
		
		return actionItems
	}
}

enum VoiceNoteSuggestion: Equatable {
	case createEvent
	case createTask
	case createNote
	case linkToEvent(CalendarEvent)
	case linkToNote(Note)
	case linkToTask(TodoItem)
	
	static func == (lhs: VoiceNoteSuggestion, rhs: VoiceNoteSuggestion) -> Bool {
		switch (lhs, rhs) {
		case (.createEvent, .createEvent), (.createTask, .createTask), (.createNote, .createNote):
			return true
		case (.linkToEvent(let lhsEvent), .linkToEvent(let rhsEvent)):
			return lhsEvent.id == rhsEvent.id
		case (.linkToNote(let lhsNote), .linkToNote(let rhsNote)):
			return lhsNote.id == rhsNote.id
		case (.linkToTask(let lhsTask), .linkToTask(let rhsTask)):
			return lhsTask.id == rhsTask.id
		default:
			return false
		}
	}
}

