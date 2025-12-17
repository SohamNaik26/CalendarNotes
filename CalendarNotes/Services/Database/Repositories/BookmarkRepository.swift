//
//  BookmarkRepository.swift
//  CalendarNotes
//
//  Created on [Date]
//

import Foundation
import PostgresNIO

/// Repository for bookmark-related database operations
class BookmarkRepository {
    private let dbManager = DatabaseManager.shared
    
    // MARK: - Create
    func create(bookmark: BookmarkModel) async throws -> UUID {
        let sql = """
            INSERT INTO calendarnotes.bookmarks (
                id, user_id, url, title, description, favicon_url, preview_image_url,
                tags, collection_id, is_favorite, is_archived, linked_date,
                linked_event_id, linked_note_id
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
            RETURNING id
        """
        
        var parameters: [PostgresData] = [
            .fromUUID(bookmark.id),
            .fromUUID(bookmark.userId),
            .fromString(bookmark.url),
            .fromString(bookmark.title),
            .fromOptionalString(bookmark.description),
            .fromOptionalString(bookmark.faviconURL),
            .fromOptionalString(bookmark.previewImageURL),
            .fromOptionalUUID(bookmark.collectionId),
            .fromBool(bookmark.isFavorite),
            .fromBool(bookmark.isArchived),
            .fromOptionalDate(bookmark.linkedDate),
            .fromOptionalUUID(bookmark.linkedEventId),
            .fromOptionalUUID(bookmark.linkedNoteId)
        ]
        
        if bookmark.tags.isEmpty {
            parameters.insert(.null, at: 7)
        } else {
            parameters.insert(.fromStringArray(bookmark.tags), at: 7)
        }
        
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let id = try? row.decodeColumn("id", as: UUID.self) {
                return id
            }
        }
        throw DatabaseError.queryExecutionFailed("Failed to create bookmark")
    }
    
    // MARK: - Read
    func findById(id: UUID) async throws -> BookmarkModel? {
        let sql = "SELECT * FROM calendarnotes.bookmarks WHERE id = $1 AND deleted_at IS NULL"
        let parameters: [PostgresData] = [.fromUUID(id)]
        
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            return try decodeBookmark(from: row)
        }
        return nil
    }
    
    func findByUserId(_ userId: UUID, isFavorite: Bool? = nil, isArchived: Bool? = nil, limit: Int = 100, offset: Int = 0) async throws -> [BookmarkModel] {
        var sql = "SELECT * FROM calendarnotes.bookmarks WHERE user_id = $1 AND deleted_at IS NULL"
        var parameters: [PostgresData] = [.fromUUID(userId)]
        var paramIndex = 2
        
        if let isFavorite = isFavorite {
            sql += " AND is_favorite = $\(paramIndex)"
            parameters.append(.fromBool(isFavorite))
            paramIndex += 1
        }
        
        if let isArchived = isArchived {
            sql += " AND is_archived = $\(paramIndex)"
            parameters.append(.fromBool(isArchived))
            paramIndex += 1
        }
        
        sql += " ORDER BY created_at DESC LIMIT $\(paramIndex) OFFSET $\(paramIndex + 1)"
        parameters.append(.fromInt(limit))
        parameters.append(.fromInt(offset))
        
        var bookmarks: [BookmarkModel] = []
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let bookmark = try? decodeBookmark(from: row) {
                bookmarks.append(bookmark)
            }
        }
        return bookmarks
    }
    
    func findByURL(_ url: String, userId: UUID) async throws -> BookmarkModel? {
        let sql = "SELECT * FROM calendarnotes.bookmarks WHERE url = $1 AND user_id = $2 AND deleted_at IS NULL"
        let parameters: [PostgresData] = [
            .fromString(url),
            .fromUUID(userId)
        ]
        
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            return try decodeBookmark(from: row)
        }
        return nil
    }
    
    // MARK: - Update
    func update(bookmark: BookmarkModel) async throws -> Bool {
        let sql = """
            UPDATE calendarnotes.bookmarks
            SET url = $1, title = $2, description = $3, favicon_url = $4,
                preview_image_url = $5, tags = $6, collection_id = $7,
                is_favorite = $8, is_archived = $9, linked_date = $10,
                linked_event_id = $11, linked_note_id = $12, updated_at = CURRENT_TIMESTAMP
            WHERE id = $13 AND deleted_at IS NULL
        """
        
        var parameters: [PostgresData] = [
            .fromString(bookmark.url),
            .fromString(bookmark.title),
            .fromOptionalString(bookmark.description),
            .fromOptionalString(bookmark.faviconURL),
            .fromOptionalString(bookmark.previewImageURL),
            .fromOptionalUUID(bookmark.collectionId),
            .fromBool(bookmark.isFavorite),
            .fromBool(bookmark.isArchived),
            .fromOptionalDate(bookmark.linkedDate),
            .fromOptionalUUID(bookmark.linkedEventId),
            .fromOptionalUUID(bookmark.linkedNoteId),
            .fromUUID(bookmark.id)
        ]
        
        if bookmark.tags.isEmpty {
            parameters.insert(.null, at: 5)
        } else {
            parameters.insert(.fromStringArray(bookmark.tags), at: 5)
        }
        
        return try await dbManager.executeUpdate(sql: sql, parameters: parameters)
    }
    
    func incrementOpenCount(id: UUID) async throws -> Bool {
        let sql = """
            UPDATE calendarnotes.bookmarks
            SET open_count = open_count + 1, last_opened_at = CURRENT_TIMESTAMP
            WHERE id = $1 AND deleted_at IS NULL
        """
        let parameters: [PostgresData] = [.fromUUID(id)]
        return try await dbManager.executeUpdate(sql: sql, parameters: parameters)
    }
    
    // MARK: - Delete
    func delete(id: UUID) async throws -> Bool {
        let sql = "UPDATE calendarnotes.bookmarks SET deleted_at = CURRENT_TIMESTAMP WHERE id = $1"
        let parameters: [PostgresData] = [.fromUUID(id)]
        return try await dbManager.executeUpdate(sql: sql, parameters: parameters)
    }
    
    // MARK: - Batch Operations
    func createBatch(bookmarks: [BookmarkModel]) async throws -> [UUID] {
        var ids: [UUID] = []
        var queries: [(sql: String, parameters: [PostgresData])] = []
        
        for bookmark in bookmarks {
            let sql = """
                INSERT INTO calendarnotes.bookmarks (
                    id, user_id, url, title, description, favicon_url, preview_image_url,
                    tags, collection_id, is_favorite, is_archived, linked_date,
                    linked_event_id, linked_note_id
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14)
            """
            var parameters: [PostgresData] = [
                .fromUUID(bookmark.id),
                .fromUUID(bookmark.userId),
                .fromString(bookmark.url),
                .fromString(bookmark.title),
                .fromOptionalString(bookmark.description),
                .fromOptionalString(bookmark.faviconURL),
                .fromOptionalString(bookmark.previewImageURL),
                .fromOptionalUUID(bookmark.collectionId),
                .fromBool(bookmark.isFavorite),
                .fromBool(bookmark.isArchived),
                .fromOptionalDate(bookmark.linkedDate),
                .fromOptionalUUID(bookmark.linkedEventId),
                .fromOptionalUUID(bookmark.linkedNoteId)
            ]
            
            if bookmark.tags.isEmpty {
                parameters.insert(.null, at: 7)
            } else {
                parameters.insert(.fromStringArray(bookmark.tags), at: 7)
            }
            queries.append((sql: sql, parameters: parameters))
            ids.append(bookmark.id)
        }
        
        _ = try await dbManager.executeTransaction(queries: queries)
        return ids
    }
    
    // MARK: - Search
    func search(userId: UUID, query: String, isFavorite: Bool? = nil, isArchived: Bool? = nil, limit: Int = 50) async throws -> [BookmarkModel] {
        var sql = """
            SELECT * FROM calendarnotes.bookmarks
            WHERE user_id = $1 AND deleted_at IS NULL
            AND (title ILIKE $2 OR description ILIKE $2 OR url ILIKE $2)
        """
        var parameters: [PostgresData] = [
            .fromUUID(userId),
            .fromString("%\(query)%")
        ]
        var paramIndex = 3
        
        if let isFavorite = isFavorite {
            sql += " AND is_favorite = $\(paramIndex)"
            parameters.append(.fromBool(isFavorite))
            paramIndex += 1
        }
        
        if let isArchived = isArchived {
            sql += " AND is_archived = $\(paramIndex)"
            parameters.append(.fromBool(isArchived))
            paramIndex += 1
        }
        
        sql += " ORDER BY created_at DESC LIMIT $\(paramIndex)"
        parameters.append(.fromInt(limit))
        
        var bookmarks: [BookmarkModel] = []
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let bookmark = try? decodeBookmark(from: row) {
                bookmarks.append(bookmark)
            }
        }
        return bookmarks
    }
    
    // MARK: - Helper Methods
    private func decodeBookmark(from row: PostgresRow) throws -> BookmarkModel {
        var tagsArray: [String] = []
        if let tags = try? row.decodeColumn("tags", as: [String].self) {
            tagsArray = tags
        }
        
        return BookmarkModel(
            id: try row.decodeColumn("id", as: UUID.self),
            userId: try row.decodeColumn("user_id", as: UUID.self),
            url: try row.decodeColumn("url", as: String.self),
            title: try row.decodeColumn("title", as: String.self),
            description: row.decodeColumnOptional("description", as: String.self),
            faviconURL: row.decodeColumnOptional("favicon_url", as: String.self),
            previewImageURL: row.decodeColumnOptional("preview_image_url", as: String.self),
            tags: tagsArray,
            collectionId: row.decodeColumnOptional("collection_id", as: UUID.self),
            isFavorite: try row.decodeColumn("is_favorite", as: Bool.self),
            isArchived: try row.decodeColumn("is_archived", as: Bool.self),
            openCount: try row.decodeColumn("open_count", as: Int.self),
            lastOpenedAt: row.decodeColumnOptional("last_opened_at", as: Date.self),
            linkedDate: row.decodeColumnOptional("linked_date", as: Date.self),
            linkedEventId: row.decodeColumnOptional("linked_event_id", as: UUID.self),
            linkedNoteId: row.decodeColumnOptional("linked_note_id", as: UUID.self),
            createdAt: try row.decodeColumn("created_at", as: Date.self),
            updatedAt: try row.decodeColumn("updated_at", as: Date.self),
            syncedAt: row.decodeColumnOptional("synced_at", as: Date.self),
            deletedAt: row.decodeColumnOptional("deleted_at", as: Date.self)
        )
    }
}

// MARK: - Bookmark Model
struct BookmarkModel {
    let id: UUID
    let userId: UUID
    let url: String
    let title: String
    let description: String?
    let faviconURL: String?
    let previewImageURL: String?
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
    let syncedAt: Date?
    let deletedAt: Date?
}

