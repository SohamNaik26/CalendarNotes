//
//  NoteRepository.swift
//  CalendarNotes
//
//  Created on [Date]
//

import Foundation
import PostgresNIO

/// Repository for note-related database operations
class NoteRepository {
    private let dbManager = DatabaseManager.shared
    
    // MARK: - Create
    func create(note: NoteModel) async throws -> UUID {
        let sql = """
            INSERT INTO calendarnotes.notes (
                id, user_id, title, content, rich_content, linked_date, linked_event_id, tags
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            RETURNING id
        """
        
        var parameters: [PostgresData] = [
            .fromUUID(note.id),
            .fromUUID(note.userId),
            .fromOptionalString(note.title),
            .fromOptionalString(note.content),
            .fromOptionalDate(note.linkedDate),
            .fromOptionalUUID(note.linkedEventId)
        ]
        
        if let richContent = note.richContent,
           let jsonbData = PostgresData.fromJSONB(richContent) {
            parameters.append(jsonbData)
        } else {
            parameters.append(.null)
        }
        
        if note.tags.isEmpty {
            parameters.append(.null)
        } else {
            parameters.append(.fromStringArray(note.tags))
        }
        
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let id = try? row.decodeColumn("id", as: UUID.self) {
                return id
            }
        }
        throw DatabaseError.queryExecutionFailed("Failed to create note")
    }
    
    // MARK: - Read
    func findById(id: UUID) async throws -> NoteModel? {
        let sql = "SELECT * FROM calendarnotes.notes WHERE id = $1 AND deleted_at IS NULL"
        let parameters: [PostgresData] = [.fromUUID(id)]
        
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            return try decodeNote(from: row)
        }
        return nil
    }
    
    func findByUserId(_ userId: UUID, linkedDate: Date? = nil, limit: Int = 100, offset: Int = 0) async throws -> [NoteModel] {
        var sql = "SELECT * FROM calendarnotes.notes WHERE user_id = $1 AND deleted_at IS NULL"
        var parameters: [PostgresData] = [.fromUUID(userId)]
        var paramIndex = 2
        
        if let linkedDate = linkedDate {
            sql += " AND linked_date = $\(paramIndex)"
            parameters.append(.fromDate(linkedDate))
            paramIndex += 1
        }
        
        sql += " ORDER BY created_at DESC LIMIT $\(paramIndex) OFFSET $\(paramIndex + 1)"
        parameters.append(.fromInt(limit))
        parameters.append(.fromInt(offset))
        
        var notes: [NoteModel] = []
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let note = try? decodeNote(from: row) {
                notes.append(note)
            }
        }
        return notes
    }
    
    // MARK: - Update
    func update(note: NoteModel) async throws -> Bool {
        let sql = """
            UPDATE calendarnotes.notes
            SET title = $1, content = $2, rich_content = $3, linked_date = $4,
                linked_event_id = $5, tags = $6, updated_at = CURRENT_TIMESTAMP
            WHERE id = $7 AND deleted_at IS NULL
        """
        
        var parameters: [PostgresData] = [
            .fromOptionalString(note.title),
            .fromOptionalString(note.content),
            .fromOptionalDate(note.linkedDate),
            .fromOptionalUUID(note.linkedEventId)
        ]
        
        if let richContent = note.richContent,
           let jsonbData = PostgresData.fromJSONB(richContent) {
            parameters.append(jsonbData)
        } else {
            parameters.append(.null)
        }
        
        if note.tags.isEmpty {
            parameters.append(.null)
        } else {
            parameters.append(.fromStringArray(note.tags))
        }
        
        parameters.append(.fromUUID(note.id))
        
        return try await dbManager.executeUpdate(sql: sql, parameters: parameters)
    }
    
    // MARK: - Delete
    func delete(id: UUID) async throws -> Bool {
        let sql = "UPDATE calendarnotes.notes SET deleted_at = CURRENT_TIMESTAMP WHERE id = $1"
        let parameters: [PostgresData] = [.fromUUID(id)]
        return try await dbManager.executeUpdate(sql: sql, parameters: parameters)
    }
    
    // MARK: - Batch Operations
    func createBatch(notes: [NoteModel]) async throws -> [UUID] {
        var ids: [UUID] = []
        var queries: [(sql: String, parameters: [PostgresData])] = []
        
        for note in notes {
            let sql = """
                INSERT INTO calendarnotes.notes (
                    id, user_id, title, content, rich_content, linked_date, linked_event_id, tags
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            """
            var parameters: [PostgresData] = [
                .fromUUID(note.id),
                .fromUUID(note.userId),
                .fromOptionalString(note.title),
                .fromOptionalString(note.content),
                .fromOptionalDate(note.linkedDate),
                .fromOptionalUUID(note.linkedEventId)
            ]
            
            if let richContent = note.richContent,
               let jsonbData = PostgresData.fromJSONB(richContent) {
                parameters.append(jsonbData)
            } else {
                parameters.append(.null)
            }
            
            if note.tags.isEmpty {
                parameters.append(.null)
            } else {
                parameters.append(.fromStringArray(note.tags))
            }
            queries.append((sql: sql, parameters: parameters))
            ids.append(note.id)
        }
        
        _ = try await dbManager.executeTransaction(queries: queries)
        return ids
    }
    
    // MARK: - Search
    func search(userId: UUID, query: String, limit: Int = 50) async throws -> [NoteModel] {
        let sql = """
            SELECT * FROM calendarnotes.notes
            WHERE user_id = $1 AND deleted_at IS NULL
            AND (title ILIKE $2 OR content ILIKE $2)
            ORDER BY created_at DESC
            LIMIT $3
        """
        let parameters: [PostgresData] = [
            .fromUUID(userId),
            .fromString("%\(query)%"),
            .fromInt(limit)
        ]
        
        var notes: [NoteModel] = []
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let note = try? decodeNote(from: row) {
                notes.append(note)
            }
        }
        return notes
    }
    
    // MARK: - Helper Methods
    private func decodeNote(from row: PostgresRow) throws -> NoteModel {
        var tagsArray: [String] = []
        if let tags = try? row.decodeColumn("tags", as: [String].self) {
            tagsArray = tags
        }
        
        var richContent: [String: Any]? = nil
        if let jsonbData = try? row.decodeColumn("rich_content", as: Data.self),
           let json = try? JSONSerialization.jsonObject(with: jsonbData) as? [String: Any] {
            richContent = json
        }
        
        return NoteModel(
            id: try row.decodeColumn("id", as: UUID.self),
            userId: try row.decodeColumn("user_id", as: UUID.self),
            title: row.decodeColumnOptional("title", as: String.self),
            content: row.decodeColumnOptional("content", as: String.self),
            richContent: richContent,
            linkedDate: row.decodeColumnOptional("linked_date", as: Date.self),
            linkedEventId: row.decodeColumnOptional("linked_event_id", as: UUID.self),
            tags: tagsArray,
            createdAt: try row.decodeColumn("created_at", as: Date.self),
            updatedAt: try row.decodeColumn("updated_at", as: Date.self),
            syncedAt: row.decodeColumnOptional("synced_at", as: Date.self),
            deletedAt: row.decodeColumnOptional("deleted_at", as: Date.self)
        )
    }
}

// MARK: - Note Model
struct NoteModel {
    let id: UUID
    let userId: UUID
    let title: String?
    let content: String?
    let richContent: [String: Any]?
    let linkedDate: Date?
    let linkedEventId: UUID?
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
    let syncedAt: Date?
    let deletedAt: Date?
}

