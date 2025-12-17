//
//  TodoAPIRepository.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation

// MARK: - API Models

struct APITodoItem: Codable, Identifiable {
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
	let recurrenceRule: [String: APIAnyCodable]?
	let linkedEventId: UUID?
	let createdAt: Date
	let updatedAt: Date
	
	private enum CodingKeys: String, CodingKey {
		case id
		case userId = "user_id"
		case title
		case description
		case dueDate = "due_date"
		case priority
		case category
		case isCompleted = "is_completed"
		case completedAt = "completed_at"
		case isRecurring = "is_recurring"
		case recurrenceRule = "recurrence_rule"
		case linkedEventId = "linked_event_id"
		case createdAt = "created_at"
		case updatedAt = "updated_at"
	}
}

struct TodosResponse: Codable {
	let todos: [APITodoItem]
	let pagination: Pagination?
}

struct TodoResponse: Codable {
	let todo: APITodoItem
}

struct CreateTodoRequest: Codable {
	let title: String
	let description: String?
	let dueDate: Date?
	let priority: String?
	let category: String?
	let isRecurring: Bool?
	let recurrenceRule: [String: APIAnyCodable]?
	let linkedEventId: UUID?
	
	private enum CodingKeys: String, CodingKey {
		case title, description, priority, category
		case dueDate = "due_date"
		case isRecurring = "is_recurring"
		case recurrenceRule = "recurrence_rule"
		case linkedEventId = "linked_event_id"
	}
}

// MARK: - Repository

@MainActor
final class TodoAPIRepository {
	private let client = APIClient.shared
	
	func fetchTodos(completed: Bool? = nil, priority: String? = nil, dueDate: Date? = nil, page: Int? = nil, limit: Int? = nil) async throws -> [APITodoItem] {
		let query = TodoQuery(completed: completed, priority: priority, dueDate: dueDate, page: page, limit: limit)
		let endpoint = APIEndpoint.todos(query: query)
		let response: TodosResponse = try await client.get(endpoint)
		return response.todos
	}
	
	func fetchTodo(id: UUID) async throws -> APITodoItem {
		let endpoint = APIEndpoint.todo(id: id)
		let response: TodoResponse = try await client.get(endpoint)
		return response.todo
	}
	
	func createTodo(_ todo: CreateTodoRequest) async throws -> APITodoItem {
		let endpoint = APIEndpoint.createTodo
		let response: TodoResponse = try await client.post(endpoint, body: todo)
		return response.todo
	}
	
	func updateTodo(id: UUID, todo: CreateTodoRequest) async throws -> APITodoItem {
		let endpoint = APIEndpoint.updateTodo(id: id)
		let response: TodoResponse = try await client.put(endpoint, body: todo)
		return response.todo
	}
	
	func completeTodo(id: UUID) async throws -> APITodoItem {
		let endpoint = APIEndpoint.completeTodo(id: id)
		let response: TodoResponse = try await client.patch(endpoint, body: nil as EmptyRequest?)
		return response.todo
	}
	
	func uncompleteTodo(id: UUID) async throws -> APITodoItem {
		let endpoint = APIEndpoint.uncompleteTodo(id: id)
		let response: TodoResponse = try await client.patch(endpoint, body: nil as EmptyRequest?)
		return response.todo
	}
	
	func deleteTodo(id: UUID) async throws {
		let endpoint = APIEndpoint.deleteTodo(id: id)
		try await client.delete(endpoint)
	}
}

struct EmptyRequest: Codable {}

