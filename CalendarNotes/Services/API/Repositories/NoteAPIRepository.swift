//
//  NoteAPIRepository.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation

// MARK: - API Models

struct APINote: Codable, Identifiable {
	let id: UUID
	let userId: UUID
	let title: String?
	let content: String?
	let richContent: [String: APIAnyCodable]?
	let linkedDate: Date?
	let linkedEventId: UUID?
	let tags: [String]
	let createdAt: Date
	let updatedAt: Date
	
	private enum CodingKeys: String, CodingKey {
		case id
		case userId = "user_id"
		case title
		case content
		case richContent = "rich_content"
		case linkedDate = "linked_date"
		case linkedEventId = "linked_event_id"
		case tags
		case createdAt = "created_at"
		case updatedAt = "updated_at"
	}
}

struct NotesResponse: Codable {
	let notes: [APINote]
	let pagination: Pagination?
}

struct NoteResponse: Codable {
	let note: APINote
}

struct CreateNoteRequest: Codable {
	let title: String?
	let content: String?
	let richContent: [String: APIAnyCodable]?
	let linkedDate: Date?
	let linkedEventId: UUID?
	let tags: [String]?
	
	private enum CodingKeys: String, CodingKey {
		case title, content, tags
		case richContent = "rich_content"
		case linkedDate = "linked_date"
		case linkedEventId = "linked_event_id"
	}
}

struct LinkNoteToEventRequest: Codable {
	let eventId: UUID
	
	private enum CodingKeys: String, CodingKey {
		case eventId = "event_id"
	}
}

struct LinkNoteToBookmarkRequest: Codable {
	let bookmarkId: UUID
	
	private enum CodingKeys: String, CodingKey {
		case bookmarkId = "bookmark_id"
	}
}

// MARK: - Repository

@MainActor
final class NoteAPIRepository {
	private let client = APIClient.shared
	
	func fetchNotes(linkedDate: Date? = nil, tag: String? = nil, search: String? = nil, page: Int? = nil, limit: Int? = nil) async throws -> [APINote] {
		let query = NoteQuery(linkedDate: linkedDate, tag: tag, search: search, page: page, limit: limit)
		let endpoint = APIEndpoint.notes(query: query)
		let response: NotesResponse = try await client.get(endpoint)
		return response.notes
	}
	
	func searchNotes(query: String) async throws -> [APINote] {
		return try await fetchNotes(search: query)
	}
	
	func fetchNote(id: UUID) async throws -> APINote {
		let endpoint = APIEndpoint.note(id: id)
		let response: NoteResponse = try await client.get(endpoint)
		return response.note
	}
	
	func createNote(_ note: CreateNoteRequest) async throws -> APINote {
		let endpoint = APIEndpoint.createNote
		let response: NoteResponse = try await client.post(endpoint, body: note)
		return response.note
	}
	
	func updateNote(id: UUID, note: CreateNoteRequest) async throws -> APINote {
		let endpoint = APIEndpoint.updateNote(id: id)
		let response: NoteResponse = try await client.put(endpoint, body: note)
		return response.note
	}
	
	func deleteNote(id: UUID) async throws {
		let endpoint = APIEndpoint.deleteNote(id: id)
		try await client.delete(endpoint)
	}
	
	func linkToEvent(noteId: UUID, eventId: UUID) async throws -> APINote {
		let endpoint = APIEndpoint.linkNoteToEvent(noteId: noteId)
		let request = LinkNoteToEventRequest(eventId: eventId)
		let response: NoteResponse = try await client.post(endpoint, body: request)
		return response.note
	}
	
	func linkToBookmark(noteId: UUID, bookmarkId: UUID) async throws {
		let endpoint = APIEndpoint.linkNoteToBookmark(noteId: noteId)
		let request = LinkNoteToBookmarkRequest(bookmarkId: bookmarkId)
		let _: EmptyResponse = try await client.post(endpoint, body: request)
	}
}

