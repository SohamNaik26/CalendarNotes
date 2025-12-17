//
//  VoiceNoteLinkContext.swift
//  CalendarNotes
//
//  Created by GPT-5.1 Codex on 17/11/25.
//

import Foundation

enum VoiceNoteLinkContext: Equatable {
	case event(CalendarEvent)
	case note(Note)
	case task(TodoItem)
	
	var event: CalendarEvent? {
		if case let .event(event) = self { return event }
		return nil
	}
	
	var note: Note? {
		if case let .note(note) = self { return note }
		return nil
	}
	
	var task: TodoItem? {
		if case let .task(task) = self { return task }
		return nil
	}
	
	var entityIdentifier: UUID? {
		switch self {
		case .event(let event):
			return event.id
		case .note(let note):
			return note.id
		case .task(let task):
			return task.id
		}
	}
	
	var entityName: String {
		switch self {
		case .event: return "event"
		case .note: return "note"
		case .task: return "task"
		}
	}
}

