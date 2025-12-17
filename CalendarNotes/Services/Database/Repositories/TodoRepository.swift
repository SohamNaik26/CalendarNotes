//
//  TodoRepository.swift
//  CalendarNotes
//
//  Created on [Date]
//

import Foundation
import PostgresNIO

/// Repository for todo item-related database operations
class TodoRepository {
    private let dbManager = DatabaseManager.shared
    
    // MARK: - Create
    func create(todo: TodoItemModel) async throws -> UUID {
        let sql = """
            INSERT INTO calendarnotes.todo_items (
                id, user_id, title, description, due_date, priority, category,
                is_completed, is_recurring, recurrence_rule, linked_event_id
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            RETURNING id
        """
        
        var parameters: [PostgresData] = [
            .fromUUID(todo.id),
            .fromUUID(todo.userId),
            .fromString(todo.title),
            .fromOptionalString(todo.description),
            .fromOptionalDate(todo.dueDate),
            .fromOptionalString(todo.priority),
            .fromOptionalString(todo.category),
            .fromBool(todo.isCompleted),
            .fromBool(todo.isRecurring),
            .fromOptionalUUID(todo.linkedEventId)
        ]
        
        if let recurrenceRule = todo.recurrenceRule,
           let jsonbData = PostgresData.fromJSONB(recurrenceRule) {
            parameters.insert(jsonbData, at: 9)
        } else {
            parameters.insert(.null, at: 9)
        }
        
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let id = try? row.decodeColumn("id", as: UUID.self) {
                return id
            }
        }
        throw DatabaseError.queryExecutionFailed("Failed to create todo item")
    }
    
    // MARK: - Read
    func findById(id: UUID) async throws -> TodoItemModel? {
        let sql = "SELECT * FROM calendarnotes.todo_items WHERE id = $1 AND deleted_at IS NULL"
        let parameters: [PostgresData] = [.fromUUID(id)]
        
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            return try decodeTodo(from: row)
        }
        return nil
    }
    
    func findByUserId(_ userId: UUID, isCompleted: Bool? = nil, dueDate: Date? = nil, limit: Int = 100, offset: Int = 0) async throws -> [TodoItemModel] {
        var sql = "SELECT * FROM calendarnotes.todo_items WHERE user_id = $1 AND deleted_at IS NULL"
        var parameters: [PostgresData] = [.fromUUID(userId)]
        var paramIndex = 2
        
        if let isCompleted = isCompleted {
            sql += " AND is_completed = $\(paramIndex)"
            parameters.append(.fromBool(isCompleted))
            paramIndex += 1
        }
        
        if let dueDate = dueDate {
            sql += " AND due_date <= $\(paramIndex)"
            parameters.append(.fromDate(dueDate))
            paramIndex += 1
        }
        
        sql += " ORDER BY due_date ASC NULLS LAST, created_at DESC LIMIT $\(paramIndex) OFFSET $\(paramIndex + 1)"
        parameters.append(.fromInt(limit))
        parameters.append(.fromInt(offset))
        
        var todos: [TodoItemModel] = []
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let todo = try? decodeTodo(from: row) {
                todos.append(todo)
            }
        }
        return todos
    }
    
    // MARK: - Update
    func update(todo: TodoItemModel) async throws -> Bool {
        let sql = """
            UPDATE calendarnotes.todo_items
            SET title = $1, description = $2, due_date = $3, priority = $4,
                category = $5, is_completed = $6, completed_at = $7,
                is_recurring = $8, recurrence_rule = $9, linked_event_id = $10,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = $11 AND deleted_at IS NULL
        """
        
        var parameters: [PostgresData] = [
            .fromString(todo.title),
            .fromOptionalString(todo.description),
            .fromOptionalDate(todo.dueDate),
            .fromOptionalString(todo.priority),
            .fromOptionalString(todo.category),
            .fromBool(todo.isCompleted),
            .fromOptionalDate(todo.completedAt),
            .fromBool(todo.isRecurring),
            .fromOptionalUUID(todo.linkedEventId),
            .fromUUID(todo.id)
        ]
        
        if let recurrenceRule = todo.recurrenceRule,
           let jsonbData = PostgresData.fromJSONB(recurrenceRule) {
            parameters.insert(jsonbData, at: 8)
        } else {
            parameters.insert(.null, at: 8)
        }
        
        return try await dbManager.executeUpdate(sql: sql, parameters: parameters)
    }
    
    func markCompleted(id: UUID) async throws -> Bool {
        let sql = """
            UPDATE calendarnotes.todo_items
            SET is_completed = true, completed_at = CURRENT_TIMESTAMP, updated_at = CURRENT_TIMESTAMP
            WHERE id = $1 AND deleted_at IS NULL
        """
        let parameters: [PostgresData] = [.fromUUID(id)]
        return try await dbManager.executeUpdate(sql: sql, parameters: parameters)
    }
    
    // MARK: - Delete
    func delete(id: UUID) async throws -> Bool {
        let sql = "UPDATE calendarnotes.todo_items SET deleted_at = CURRENT_TIMESTAMP WHERE id = $1"
        let parameters: [PostgresData] = [.fromUUID(id)]
        return try await dbManager.executeUpdate(sql: sql, parameters: parameters)
    }
    
    // MARK: - Batch Operations
    func createBatch(todos: [TodoItemModel]) async throws -> [UUID] {
        var ids: [UUID] = []
        var queries: [(sql: String, parameters: [PostgresData])] = []
        
        for todo in todos {
            let sql = """
                INSERT INTO calendarnotes.todo_items (
                    id, user_id, title, description, due_date, priority, category,
                    is_completed, is_recurring, recurrence_rule, linked_event_id
                )
                VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
            """
            var parameters: [PostgresData] = [
                .fromUUID(todo.id),
                .fromUUID(todo.userId),
                .fromString(todo.title),
                .fromOptionalString(todo.description),
                .fromOptionalDate(todo.dueDate),
                .fromOptionalString(todo.priority),
                .fromOptionalString(todo.category),
                .fromBool(todo.isCompleted),
                .fromBool(todo.isRecurring),
                .fromOptionalUUID(todo.linkedEventId)
            ]
            
            if let recurrenceRule = todo.recurrenceRule,
               let jsonbData = PostgresData.fromJSONB(recurrenceRule) {
                parameters.insert(jsonbData, at: 9)
            } else {
                parameters.insert(.null, at: 9)
            }
            queries.append((sql: sql, parameters: parameters))
            ids.append(todo.id)
        }
        
        _ = try await dbManager.executeTransaction(queries: queries)
        return ids
    }
    
    // MARK: - Search
    func search(userId: UUID, query: String, isCompleted: Bool? = nil, limit: Int = 50) async throws -> [TodoItemModel] {
        var sql = """
            SELECT * FROM calendarnotes.todo_items
            WHERE user_id = $1 AND deleted_at IS NULL
            AND (title ILIKE $2 OR description ILIKE $2)
        """
        var parameters: [PostgresData] = [
            .fromUUID(userId),
            .fromString("%\(query)%")
        ]
        var paramIndex = 3
        
        if let isCompleted = isCompleted {
            sql += " AND is_completed = $\(paramIndex)"
            parameters.append(.fromBool(isCompleted))
            paramIndex += 1
        }
        
        sql += " ORDER BY due_date ASC NULLS LAST, created_at DESC LIMIT $\(paramIndex)"
        parameters.append(.fromInt(limit))
        
        var todos: [TodoItemModel] = []
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let todo = try? decodeTodo(from: row) {
                todos.append(todo)
            }
        }
        return todos
    }
    
    // MARK: - Helper Methods
    private func decodeTodo(from row: PostgresRow) throws -> TodoItemModel {
        var recurrenceRule: [String: Any]? = nil
        if let jsonbData = try? row.decodeColumn("recurrence_rule", as: Data.self),
           let json = try? JSONSerialization.jsonObject(with: jsonbData) as? [String: Any] {
            recurrenceRule = json
        }
        
        return TodoItemModel(
            id: try row.decodeColumn("id", as: UUID.self),
            userId: try row.decodeColumn("user_id", as: UUID.self),
            title: try row.decodeColumn("title", as: String.self),
            description: row.decodeColumnOptional("description", as: String.self),
            dueDate: row.decodeColumnOptional("due_date", as: Date.self),
            priority: row.decodeColumnOptional("priority", as: String.self),
            category: row.decodeColumnOptional("category", as: String.self),
            isCompleted: try row.decodeColumn("is_completed", as: Bool.self),
            completedAt: row.decodeColumnOptional("completed_at", as: Date.self),
            isRecurring: try row.decodeColumn("is_recurring", as: Bool.self),
            recurrenceRule: recurrenceRule,
            linkedEventId: row.decodeColumnOptional("linked_event_id", as: UUID.self),
            createdAt: try row.decodeColumn("created_at", as: Date.self),
            updatedAt: try row.decodeColumn("updated_at", as: Date.self),
            syncedAt: row.decodeColumnOptional("synced_at", as: Date.self),
            deletedAt: row.decodeColumnOptional("deleted_at", as: Date.self)
        )
    }
}

// MARK: - Todo Item Model
struct TodoItemModel {
    let id: UUID
    let userId: UUID
    let title: String
    let description: String?
    let dueDate: Date?
    let priority: String? // 'high', 'medium', 'low'
    let category: String?
    let isCompleted: Bool
    let completedAt: Date?
    let isRecurring: Bool
    let recurrenceRule: [String: Any]?
    let linkedEventId: UUID?
    let createdAt: Date
    let updatedAt: Date
    let syncedAt: Date?
    let deletedAt: Date?
}

