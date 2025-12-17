//
//  EventRepository.swift
//  CalendarNotes
//
//  Created on [Date]
//

import Foundation
import PostgresNIO

/// Repository for calendar event-related database operations
class EventRepository {
    private let dbManager = DatabaseManager.shared
    
    // MARK: - Create
    func create(event: CalendarEventModel) async throws -> UUID {
        let sql = """
            INSERT INTO calendarnotes.calendar_events (
                id, user_id, title, description, start_date, end_date, location,
                category, color, is_all_day, is_recurring, recurrence_rule
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
            RETURNING id
        """
        
        var parameters: [PostgresData] = [
            .fromUUID(event.id),
            .fromUUID(event.userId),
            .fromString(event.title),
            .fromOptionalString(event.description),
            .fromDate(event.startDate),
            .fromDate(event.endDate),
            .fromOptionalString(event.location),
            .fromOptionalString(event.category),
            .fromOptionalString(event.color),
            .fromBool(event.isAllDay),
            .fromBool(event.isRecurring)
        ]
        
        if let recurrenceRule = event.recurrenceRule,
           let jsonbData = PostgresData.fromJSONB(recurrenceRule) {
            parameters.append(jsonbData)
        } else {
            parameters.append(.null)
        }
        
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let id = try? row.decodeColumn("id", as: UUID.self) {
                return id
            }
        }
        throw DatabaseError.queryExecutionFailed("Failed to create event")
    }
    
    // MARK: - Read
    func findById(id: UUID) async throws -> CalendarEventModel? {
        let sql = "SELECT * FROM calendarnotes.calendar_events WHERE id = $1 AND deleted_at IS NULL"
        let parameters: [PostgresData] = [.fromUUID(id)]
        
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            return try decodeEvent(from: row)
        }
        return nil
    }
    
    func findByUserId(_ userId: UUID, startDate: Date? = nil, endDate: Date? = nil, limit: Int = 100, offset: Int = 0) async throws -> [CalendarEventModel] {
        var sql = "SELECT * FROM calendarnotes.calendar_events WHERE user_id = $1 AND deleted_at IS NULL"
        var parameters: [PostgresData] = [.fromUUID(userId)]
        var paramIndex = 2
        
        if let startDate = startDate {
            sql += " AND start_date >= $\(paramIndex)"
            parameters.append(.fromDate(startDate))
            paramIndex += 1
        }
        
        if let endDate = endDate {
            sql += " AND end_date <= $\(paramIndex)"
            parameters.append(.fromDate(endDate))
            paramIndex += 1
        }
        
        sql += " ORDER BY start_date ASC LIMIT $\(paramIndex) OFFSET $\(paramIndex + 1)"
        parameters.append(.fromInt(limit))
        parameters.append(.fromInt(offset))
        
        var events: [CalendarEventModel] = []
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let event = try? decodeEvent(from: row) {
                events.append(event)
            }
        }
        return events
    }
    
    // MARK: - Update
    func update(event: CalendarEventModel) async throws -> Bool {
        let sql = """
            UPDATE calendarnotes.calendar_events
            SET title = $1, description = $2, start_date = $3, end_date = $4,
                location = $5, category = $6, color = $7, is_all_day = $8,
                is_recurring = $9, recurrence_rule = $10, updated_at = CURRENT_TIMESTAMP
            WHERE id = $11 AND deleted_at IS NULL
        """
        
        var parameters: [PostgresData] = [
            .fromString(event.title),
            .fromOptionalString(event.description),
            .fromDate(event.startDate),
            .fromDate(event.endDate),
            .fromOptionalString(event.location),
            .fromOptionalString(event.category),
            .fromOptionalString(event.color),
            .fromBool(event.isAllDay),
            .fromBool(event.isRecurring)
        ]
        
        if let recurrenceRule = event.recurrenceRule,
           let jsonbData = PostgresData.fromJSONB(recurrenceRule) {
            parameters.append(jsonbData)
        } else {
            parameters.append(.null)
        }
        
        parameters.append(.fromUUID(event.id))
        
        return try await dbManager.executeUpdate(sql: sql, parameters: parameters)
    }
    
    // MARK: - Delete
    func delete(id: UUID) async throws -> Bool {
        let sql = "UPDATE calendarnotes.calendar_events SET deleted_at = CURRENT_TIMESTAMP WHERE id = $1"
        let parameters: [PostgresData] = [.fromUUID(id)]
        return try await dbManager.executeUpdate(sql: sql, parameters: parameters)
    }
    
    // MARK: - Batch Operations
    func createBatch(events: [CalendarEventModel]) async throws -> [UUID] {
        var ids: [UUID] = []
        var queries: [(sql: String, parameters: [PostgresData])] = []
        
        for event in events {
            let sql = """
                INSERT INTO calendarnotes.calendar_events (
                    id, user_id, title, description, start_date, end_date, location,
                    category, color, is_all_day, is_recurring, recurrence_rule
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
            """
            var parameters: [PostgresData] = [
                .fromUUID(event.id),
                .fromUUID(event.userId),
                .fromString(event.title),
                .fromOptionalString(event.description),
                .fromDate(event.startDate),
                .fromDate(event.endDate),
                .fromOptionalString(event.location),
                .fromOptionalString(event.category),
                .fromOptionalString(event.color),
                .fromBool(event.isAllDay),
                .fromBool(event.isRecurring)
            ]
            
            if let recurrenceRule = event.recurrenceRule,
               let jsonbData = PostgresData.fromJSONB(recurrenceRule) {
                parameters.append(jsonbData)
            } else {
                parameters.append(.null)
            }
            queries.append((sql: sql, parameters: parameters))
            ids.append(event.id)
        }
        
        _ = try await dbManager.executeTransaction(queries: queries)
        return ids
    }
    
    // MARK: - Search
    func search(userId: UUID, query: String, startDate: Date? = nil, endDate: Date? = nil, limit: Int = 50) async throws -> [CalendarEventModel] {
        var sql = """
            SELECT * FROM calendarnotes.calendar_events
            WHERE user_id = $1 AND deleted_at IS NULL
            AND (title ILIKE $2 OR description ILIKE $2)
        """
        var parameters: [PostgresData] = [
            .fromUUID(userId),
            .fromString("%\(query)%")
        ]
        var paramIndex = 3
        
        if let startDate = startDate {
            sql += " AND start_date >= $\(paramIndex)"
            parameters.append(.fromDate(startDate))
            paramIndex += 1
        }
        
        if let endDate = endDate {
            sql += " AND end_date <= $\(paramIndex)"
            parameters.append(.fromDate(endDate))
            paramIndex += 1
        }
        
        sql += " ORDER BY start_date ASC LIMIT $\(paramIndex)"
        parameters.append(.fromInt(limit))
        
        var events: [CalendarEventModel] = []
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let event = try? decodeEvent(from: row) {
                events.append(event)
            }
        }
        return events
    }
    
    // MARK: - Helper Methods
    private func decodeEvent(from row: PostgresRow) throws -> CalendarEventModel {
        var recurrenceRule: [String: Any]? = nil
        if let jsonbData = try? row.decodeColumn("recurrence_rule", as: Data.self),
           let json = try? JSONSerialization.jsonObject(with: jsonbData) as? [String: Any] {
            recurrenceRule = json
        }
        
        return CalendarEventModel(
            id: try row.decodeColumn("id", as: UUID.self),
            userId: try row.decodeColumn("user_id", as: UUID.self),
            title: try row.decodeColumn("title", as: String.self),
            description: row.decodeColumnOptional("description", as: String.self),
            startDate: try row.decodeColumn("start_date", as: Date.self),
            endDate: try row.decodeColumn("end_date", as: Date.self),
            location: row.decodeColumnOptional("location", as: String.self),
            category: row.decodeColumnOptional("category", as: String.self),
            color: row.decodeColumnOptional("color", as: String.self),
            isAllDay: try row.decodeColumn("is_all_day", as: Bool.self),
            isRecurring: try row.decodeColumn("is_recurring", as: Bool.self),
            recurrenceRule: recurrenceRule,
            createdAt: try row.decodeColumn("created_at", as: Date.self),
            updatedAt: try row.decodeColumn("updated_at", as: Date.self),
            syncedAt: row.decodeColumnOptional("synced_at", as: Date.self),
            deletedAt: row.decodeColumnOptional("deleted_at", as: Date.self)
        )
    }
}

// MARK: - Calendar Event Model
struct CalendarEventModel {
    let id: UUID
    let userId: UUID
    let title: String
    let description: String?
    let startDate: Date
    let endDate: Date
    let location: String?
    let category: String?
    let color: String?
    let isAllDay: Bool
    let isRecurring: Bool
    let recurrenceRule: [String: Any]?
    let createdAt: Date
    let updatedAt: Date
    let syncedAt: Date?
    let deletedAt: Date?
}

