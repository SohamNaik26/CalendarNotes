//
//  EventAPIRepository.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation

// MARK: - API Models

struct APICalendarEvent: Codable, Identifiable {
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
	let recurrenceRule: [String: APIAnyCodable]?
	let createdAt: Date
	let updatedAt: Date
	
	private enum CodingKeys: String, CodingKey {
		case id
		case userId = "user_id"
		case title
		case description
		case startDate = "start_date"
		case endDate = "end_date"
		case location
		case category
		case color
		case isAllDay = "is_all_day"
		case isRecurring = "is_recurring"
		case recurrenceRule = "recurrence_rule"
		case createdAt = "created_at"
		case updatedAt = "updated_at"
	}
}

struct EventsResponse: Codable {
	let events: [APICalendarEvent]
	let pagination: Pagination?
}

struct BatchCreateEventsRequest: Codable {
	let events: [CreateEventRequest]
}

struct BatchCreateEventsResponse: Codable {
	let created: Int
	let ids: [UUID]
	let errors: [BatchError]?
}

struct BatchError: Codable {
	let index: Int
	let error: String
}

struct CreateEventRequest: Codable {
	let title: String
	let description: String?
	let startDate: Date
	let endDate: Date
	let location: String?
	let category: String?
	let color: String?
	let isAllDay: Bool
	let isRecurring: Bool
	let recurrenceRule: [String: APIAnyCodable]?
	
	private enum CodingKeys: String, CodingKey {
		case title, description, location, category, color
		case startDate = "start_date"
		case endDate = "end_date"
		case isAllDay = "is_all_day"
		case isRecurring = "is_recurring"
		case recurrenceRule = "recurrence_rule"
	}
}

struct EventResponse: Codable {
	let event: APICalendarEvent
}

struct Pagination: Codable {
	let page: Int
	let limit: Int
	let total: Int
	let totalPages: Int
}

// MARK: - Repository

@MainActor
final class EventAPIRepository {
	private let client = APIClient.shared
	
	func fetchEvents(startDate: Date? = nil, endDate: Date? = nil, category: String? = nil, page: Int? = nil, limit: Int? = nil) async throws -> [APICalendarEvent] {
		let query = EventQuery(startDate: startDate, endDate: endDate, category: category, page: page, limit: limit)
		let endpoint = APIEndpoint.events(query: query)
		let response: EventsResponse = try await client.get(endpoint)
		return response.events
	}
	
	func fetchEvent(id: UUID) async throws -> APICalendarEvent {
		let endpoint = APIEndpoint.event(id: id)
		let response: EventResponse = try await client.get(endpoint)
		return response.event
	}
	
	func createEvent(_ event: CreateEventRequest) async throws -> APICalendarEvent {
		let endpoint = APIEndpoint.createEvent
		let response: EventResponse = try await client.post(endpoint, body: event)
		return response.event
	}
	
	func updateEvent(id: UUID, event: CreateEventRequest) async throws -> APICalendarEvent {
		let endpoint = APIEndpoint.updateEvent(id: id)
		let response: EventResponse = try await client.put(endpoint, body: event)
		return response.event
	}
	
	func deleteEvent(id: UUID) async throws {
		let endpoint = APIEndpoint.deleteEvent(id: id)
		try await client.delete(endpoint)
	}
	
	func batchCreateEvents(_ events: [CreateEventRequest]) async throws -> BatchCreateEventsResponse {
		let endpoint = APIEndpoint.batchCreateEvents
		let request = BatchCreateEventsRequest(events: events)
		return try await client.post(endpoint, body: request)
	}
}

// MARK: - APIAnyCodable Helper

struct APIAnyCodable: Codable {
	let value: Any
	
	init(_ value: Any) {
		self.value = value
	}
	
	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		
		if let bool = try? container.decode(Bool.self) {
			value = bool
		} else if let int = try? container.decode(Int.self) {
			value = int
		} else if let double = try? container.decode(Double.self) {
			value = double
		} else if let string = try? container.decode(String.self) {
			value = string
		} else if let array = try? container.decode([APIAnyCodable].self) {
			value = array.map { $0.value }
		} else if let dict = try? container.decode([String: APIAnyCodable].self) {
			value = dict.mapValues { $0.value }
		} else {
			throw DecodingError.dataCorruptedError(in: container, debugDescription: "AnyCodable value cannot be decoded")
		}
	}
	
	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		
		switch value {
		case let bool as Bool:
			try container.encode(bool)
		case let int as Int:
			try container.encode(int)
		case let double as Double:
			try container.encode(double)
		case let string as String:
			try container.encode(string)
		case let array as [Any]:
			try container.encode(array.map { APIAnyCodable($0) })
		case let dict as [String: Any]:
			try container.encode(dict.mapValues { APIAnyCodable($0) })
		default:
			throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "AnyCodable value cannot be encoded"))
		}
	}
}

