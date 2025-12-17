//
//  BookmarkAPIRepository.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation

// MARK: - API Models

struct APIBookmark: Codable, Identifiable {
	let id: UUID
	let userId: UUID
	let url: String
	let title: String
	let description: String?
	let faviconUrl: String?
	let previewImageUrl: String?
	let tags: [String]
	let collectionId: UUID?
	let isFavorite: Bool
	let isArchived: Bool
	let openCount: Int
	let lastOpenedAt: Date?
	let linkedDate: Date?
	let linkedEventId: UUID?
	let linkedNoteId: UUID?
	let createdAt: Date
	let updatedAt: Date
	
	private enum CodingKeys: String, CodingKey {
		case id
		case userId = "user_id"
		case url
		case title
		case description
		case faviconUrl = "favicon_url"
		case previewImageUrl = "preview_image_url"
		case tags
		case collectionId = "collection_id"
		case isFavorite = "is_favorite"
		case isArchived = "is_archived"
		case openCount = "open_count"
		case lastOpenedAt = "last_opened_at"
		case linkedDate = "linked_date"
		case linkedEventId = "linked_event_id"
		case linkedNoteId = "linked_note_id"
		case createdAt = "created_at"
		case updatedAt = "updated_at"
	}
}

struct BookmarksResponse: Codable {
	let bookmarks: [APIBookmark]
	let pagination: Pagination?
}

struct BookmarkResponse: Codable {
	let bookmark: APIBookmark
}

struct CreateBookmarkRequest: Codable {
	let url: String
	let title: String
	let description: String?
	let faviconUrl: String?
	let previewImageUrl: String?
	let tags: [String]?
	let collectionId: UUID?
	let linkedDate: Date?
	let linkedEventId: UUID?
	let linkedNoteId: UUID?
	
	private enum CodingKeys: String, CodingKey {
		case url, title, description, tags
		case faviconUrl = "favicon_url"
		case previewImageUrl = "preview_image_url"
		case collectionId = "collection_id"
		case linkedDate = "linked_date"
		case linkedEventId = "linked_event_id"
		case linkedNoteId = "linked_note_id"
	}
}

// MARK: - Repository

@MainActor
final class BookmarkAPIRepository {
	private let client = APIClient.shared
	
	func fetchBookmarks(collectionId: UUID? = nil, tag: String? = nil, favorite: Bool? = nil, archived: Bool? = nil, page: Int? = nil, limit: Int? = nil) async throws -> [APIBookmark] {
		let query = BookmarkQuery(collection: collectionId, tag: tag, favorite: favorite, archived: archived, page: page, limit: limit)
		let endpoint = APIEndpoint.bookmarks(query: query)
		let response: BookmarksResponse = try await client.get(endpoint)
		return response.bookmarks
	}
	
	func fetchBookmark(id: UUID) async throws -> APIBookmark {
		let endpoint = APIEndpoint.bookmark(id: id)
		let response: BookmarkResponse = try await client.get(endpoint)
		return response.bookmark
	}
	
	func createBookmark(_ bookmark: CreateBookmarkRequest) async throws -> APIBookmark {
		let endpoint = APIEndpoint.createBookmark
		let response: BookmarkResponse = try await client.post(endpoint, body: bookmark)
		return response.bookmark
	}
	
	func updateBookmark(id: UUID, bookmark: CreateBookmarkRequest) async throws -> APIBookmark {
		let endpoint = APIEndpoint.updateBookmark(id: id)
		let response: BookmarkResponse = try await client.put(endpoint, body: bookmark)
		return response.bookmark
	}
	
	func deleteBookmark(id: UUID) async throws {
		let endpoint = APIEndpoint.deleteBookmark(id: id)
		try await client.delete(endpoint)
	}
	
	func toggleFavorite(id: UUID, isFavorite: Bool) async throws -> APIBookmark {
		let endpoint: APIEndpoint
		if isFavorite {
			endpoint = APIEndpoint.favoriteBookmark(id: id)
		} else {
			endpoint = APIEndpoint.unfavoriteBookmark(id: id)
		}
		let response: BookmarkResponse = try await client.post(endpoint, body: nil as EmptyRequest?)
		return response.bookmark
	}
	
	func fetchMetadata(id: UUID) async throws -> APIBookmark {
		let endpoint = APIEndpoint.bookmarkMetadata(id: id)
		let response: BookmarkResponse = try await client.post(endpoint, body: nil as EmptyRequest?)
		return response.bookmark
	}
}

