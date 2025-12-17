//
//  APIEndpoint.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation

enum HTTPMethod: String {
	case get = "GET"
	case post = "POST"
	case put = "PUT"
	case patch = "PATCH"
	case delete = "DELETE"
}

enum APIEndpoint {
	// MARK: - Auth
	case login
	case register
	case logout
	case refreshToken
	case me
	
	// MARK: - Events
	case events(query: EventQuery?)
	case event(id: UUID)
	case createEvent
	case updateEvent(id: UUID)
	case deleteEvent(id: UUID)
	case batchCreateEvents
	case batchUpdateEvents
	
	// MARK: - Notes
	case notes(query: NoteQuery?)
	case note(id: UUID)
	case createNote
	case updateNote(id: UUID)
	case deleteNote(id: UUID)
	case linkNoteToEvent(noteId: UUID)
	case linkNoteToBookmark(noteId: UUID)
	
	// MARK: - Todos
	case todos(query: TodoQuery?)
	case todo(id: UUID)
	case createTodo
	case updateTodo(id: UUID)
	case deleteTodo(id: UUID)
	case completeTodo(id: UUID)
	case uncompleteTodo(id: UUID)
	
	// MARK: - Bookmarks
	case bookmarks(query: BookmarkQuery?)
	case bookmark(id: UUID)
	case createBookmark
	case updateBookmark(id: UUID)
	case deleteBookmark(id: UUID)
	case favoriteBookmark(id: UUID)
	case unfavoriteBookmark(id: UUID)
	case bookmarkMetadata(id: UUID)
	
	// MARK: - Collections
	case collections
	case collection(id: UUID)
	case createCollection
	case updateCollection(id: UUID)
	case deleteCollection(id: UUID)
	case collectionBookmarks(id: UUID)
	
	// MARK: - Voice Notes
	case voiceNotes
	case voiceNote(id: UUID)
	case createVoiceNote
	case updateVoiceNote(id: UUID)
	case deleteVoiceNote(id: UUID)
	case transcribeVoiceNote(id: UUID)
	case voiceNoteAudio(id: UUID)
	
	// MARK: - Sync
	case syncPull(query: SyncQuery?)
	case syncPush
	case syncStatus
	case syncResolveConflict
	
	// MARK: - Users
	case userProfile
	case updateUserProfile
	case changePassword
	case deleteAccount
	case userStats
	
	var method: HTTPMethod {
		switch self {
		case .login, .register, .logout, .refreshToken, .createEvent, .batchCreateEvents,
			 .createNote, .createTodo, .createBookmark, .createCollection, .createVoiceNote,
			 .linkNoteToEvent, .linkNoteToBookmark,
			 .favoriteBookmark, .bookmarkMetadata, .transcribeVoiceNote,
			 .syncPull, .syncPush, .syncResolveConflict:
			return .post
		case .updateEvent, .batchUpdateEvents, .updateNote, .updateTodo, .updateBookmark, .updateCollection,
			 .updateVoiceNote, .updateUserProfile, .changePassword:
			return .put
		case .completeTodo, .uncompleteTodo:
			return .patch
		case .deleteEvent, .deleteNote, .deleteTodo, .deleteBookmark, .deleteCollection,
			 .deleteVoiceNote, .deleteAccount, .unfavoriteBookmark:
			return .delete
		case .events, .event, .notes, .note, .todos, .todo, .bookmarks, .bookmark,
			 .collections, .collection, .collectionBookmarks, .voiceNotes, .voiceNote,
			 .voiceNoteAudio, .syncStatus, .userProfile, .userStats, .me:
			return .get
		}
	}
	
	var path: String {
		switch self {
		case .login:
			return "/api/auth/login"
		case .register:
			return "/api/auth/register"
		case .logout:
			return "/api/auth/logout"
		case .refreshToken:
			return "/api/auth/refresh-token"
		case .me:
			return "/api/auth/me"
			
		case .events:
			return "/api/events"
		case .event(let id):
			return "/api/events/\(id.uuidString)"
		case .createEvent:
			return "/api/events"
		case .updateEvent(let id):
			return "/api/events/\(id.uuidString)"
		case .deleteEvent(let id):
			return "/api/events/\(id.uuidString)"
		case .batchCreateEvents:
			return "/api/events/batch"
		case .batchUpdateEvents:
			return "/api/events/batch"
			
		case .notes:
			return "/api/notes"
		case .note(let id):
			return "/api/notes/\(id.uuidString)"
		case .createNote:
			return "/api/notes"
		case .updateNote(let id):
			return "/api/notes/\(id.uuidString)"
		case .deleteNote(let id):
			return "/api/notes/\(id.uuidString)"
		case .linkNoteToEvent(let noteId):
			return "/api/notes/\(noteId.uuidString)/link-event"
		case .linkNoteToBookmark(let noteId):
			return "/api/notes/\(noteId.uuidString)/link-bookmark"
			
		case .todos:
			return "/api/todos"
		case .todo(let id):
			return "/api/todos/\(id.uuidString)"
		case .createTodo:
			return "/api/todos"
		case .updateTodo(let id):
			return "/api/todos/\(id.uuidString)"
		case .deleteTodo(let id):
			return "/api/todos/\(id.uuidString)"
		case .completeTodo(let id):
			return "/api/todos/\(id.uuidString)/complete"
		case .uncompleteTodo(let id):
			return "/api/todos/\(id.uuidString)/uncomplete"
			
		case .bookmarks:
			return "/api/bookmarks"
		case .bookmark(let id):
			return "/api/bookmarks/\(id.uuidString)"
		case .createBookmark:
			return "/api/bookmarks"
		case .updateBookmark(let id):
			return "/api/bookmarks/\(id.uuidString)"
		case .deleteBookmark(let id):
			return "/api/bookmarks/\(id.uuidString)"
		case .favoriteBookmark(let id):
			return "/api/bookmarks/\(id.uuidString)/favorite"
		case .unfavoriteBookmark(let id):
			return "/api/bookmarks/\(id.uuidString)/favorite"
		case .bookmarkMetadata(let id):
			return "/api/bookmarks/\(id.uuidString)/metadata"
			
		case .collections:
			return "/api/collections"
		case .collection(let id):
			return "/api/collections/\(id.uuidString)"
		case .createCollection:
			return "/api/collections"
		case .updateCollection(let id):
			return "/api/collections/\(id.uuidString)"
		case .deleteCollection(let id):
			return "/api/collections/\(id.uuidString)"
		case .collectionBookmarks(let id):
			return "/api/collections/\(id.uuidString)/bookmarks"
			
		case .voiceNotes:
			return "/api/voicenotes"
		case .voiceNote(let id):
			return "/api/voicenotes/\(id.uuidString)"
		case .createVoiceNote:
			return "/api/voicenotes"
		case .updateVoiceNote(let id):
			return "/api/voicenotes/\(id.uuidString)"
		case .deleteVoiceNote(let id):
			return "/api/voicenotes/\(id.uuidString)"
		case .transcribeVoiceNote(let id):
			return "/api/voicenotes/\(id.uuidString)/transcribe"
		case .voiceNoteAudio(let id):
			return "/api/voicenotes/\(id.uuidString)/audio"
			
		case .syncPull:
			return "/api/sync/pull"
		case .syncPush:
			return "/api/sync/push"
		case .syncStatus:
			return "/api/sync/status"
		case .syncResolveConflict:
			return "/api/sync/resolve-conflict"
			
		case .userProfile:
			return "/api/users/profile"
		case .updateUserProfile:
			return "/api/users/profile"
		case .changePassword:
			return "/api/users/password"
		case .deleteAccount:
			return "/api/users/account"
		case .userStats:
			return "/api/users/stats"
		}
	}
	
	var queryItems: [URLQueryItem]? {
		switch self {
		case .events(let query):
			return query?.toQueryItems()
		case .notes(let query):
			return query?.toQueryItems()
		case .todos(let query):
			return query?.toQueryItems()
		case .bookmarks(let query):
			return query?.toQueryItems()
		case .syncPull(let query):
			return query?.toQueryItems()
		default:
			return nil
		}
	}
}

// MARK: - Query Parameters

struct EventQuery {
	let startDate: Date?
	let endDate: Date?
	let category: String?
	let page: Int?
	let limit: Int?
	
	func toQueryItems() -> [URLQueryItem] {
		var items: [URLQueryItem] = []
		if let startDate = startDate {
			items.append(URLQueryItem(name: "startDate", value: ISO8601DateFormatter().string(from: startDate)))
		}
		if let endDate = endDate {
			items.append(URLQueryItem(name: "endDate", value: ISO8601DateFormatter().string(from: endDate)))
		}
		if let category = category {
			items.append(URLQueryItem(name: "category", value: category))
		}
		if let page = page {
			items.append(URLQueryItem(name: "page", value: String(page)))
		}
		if let limit = limit {
			items.append(URLQueryItem(name: "limit", value: String(limit)))
		}
		return items
	}
}

struct NoteQuery {
	let linkedDate: Date?
	let tag: String?
	let search: String?
	let page: Int?
	let limit: Int?
	
	func toQueryItems() -> [URLQueryItem] {
		var items: [URLQueryItem] = []
		if let linkedDate = linkedDate {
			items.append(URLQueryItem(name: "linkedDate", value: ISO8601DateFormatter().string(from: linkedDate)))
		}
		if let tag = tag {
			items.append(URLQueryItem(name: "tag", value: tag))
		}
		if let search = search {
			items.append(URLQueryItem(name: "search", value: search))
		}
		if let page = page {
			items.append(URLQueryItem(name: "page", value: String(page)))
		}
		if let limit = limit {
			items.append(URLQueryItem(name: "limit", value: String(limit)))
		}
		return items
	}
}

struct TodoQuery {
	let completed: Bool?
	let priority: String?
	let dueDate: Date?
	let page: Int?
	let limit: Int?
	
	func toQueryItems() -> [URLQueryItem] {
		var items: [URLQueryItem] = []
		if let completed = completed {
			items.append(URLQueryItem(name: "completed", value: String(completed)))
		}
		if let priority = priority {
			items.append(URLQueryItem(name: "priority", value: priority))
		}
		if let dueDate = dueDate {
			items.append(URLQueryItem(name: "dueDate", value: ISO8601DateFormatter().string(from: dueDate)))
		}
		if let page = page {
			items.append(URLQueryItem(name: "page", value: String(page)))
		}
		if let limit = limit {
			items.append(URLQueryItem(name: "limit", value: String(limit)))
		}
		return items
	}
}

struct BookmarkQuery {
	let collection: UUID?
	let tag: String?
	let favorite: Bool?
	let archived: Bool?
	let page: Int?
	let limit: Int?
	
	func toQueryItems() -> [URLQueryItem] {
		var items: [URLQueryItem] = []
		if let collection = collection {
			items.append(URLQueryItem(name: "collection", value: collection.uuidString))
		}
		if let tag = tag {
			items.append(URLQueryItem(name: "tag", value: tag))
		}
		if let favorite = favorite {
			items.append(URLQueryItem(name: "favorite", value: String(favorite)))
		}
		if let archived = archived {
			items.append(URLQueryItem(name: "archived", value: String(archived)))
		}
		if let page = page {
			items.append(URLQueryItem(name: "page", value: String(page)))
		}
		if let limit = limit {
			items.append(URLQueryItem(name: "limit", value: String(limit)))
		}
		return items
	}
}

struct SyncQuery {
	let lastSyncTimestamp: Date?
	let deviceId: String?
	
	func toQueryItems() -> [URLQueryItem] {
		var items: [URLQueryItem] = []
		if let lastSyncTimestamp = lastSyncTimestamp {
			items.append(URLQueryItem(name: "lastSyncTimestamp", value: ISO8601DateFormatter().string(from: lastSyncTimestamp)))
		}
		if let deviceId = deviceId {
			items.append(URLQueryItem(name: "device_id", value: deviceId))
		}
		return items
	}
}

