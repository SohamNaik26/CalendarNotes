//
//  VoiceNoteAPIRepository.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation

// MARK: - API Models

struct APIVoiceNote: Codable, Identifiable {
	let id: UUID
	let userId: UUID
	let transcription: String?
	let durationSeconds: Int?
	let fileSizeBytes: Int?
	let bitrateKbps: Int?
	let sampleRateHz: Int?
	let linkedNoteId: UUID?
	let linkedEventId: UUID?
	let linkedTaskId: UUID?
	let isFavorite: Bool
	let isArchived: Bool
	let createdAt: Date
	let updatedAt: Date
	
	private enum CodingKeys: String, CodingKey {
		case id
		case userId = "user_id"
		case transcription
		case durationSeconds = "duration_seconds"
		case fileSizeBytes = "file_size_bytes"
		case bitrateKbps = "bitrate_kbps"
		case sampleRateHz = "sample_rate_hz"
		case linkedNoteId = "linked_note_id"
		case linkedEventId = "linked_event_id"
		case linkedTaskId = "linked_task_id"
		case isFavorite = "is_favorite"
		case isArchived = "is_archived"
		case createdAt = "created_at"
		case updatedAt = "updated_at"
	}
}

struct VoiceNotesResponse: Codable {
	let voicenotes: [APIVoiceNote]
	let pagination: Pagination?
}

struct VoiceNoteResponse: Codable {
	let voicenote: APIVoiceNote
}

struct CreateVoiceNoteRequest: Codable {
	let linkedNoteId: UUID?
	let linkedEventId: UUID?
	let linkedTaskId: UUID?
	
	private enum CodingKeys: String, CodingKey {
		case linkedNoteId = "linked_note_id"
		case linkedEventId = "linked_event_id"
		case linkedTaskId = "linked_task_id"
	}
}

struct TranscribeResponse: Codable {
	let voicenote: APIVoiceNote
	let message: String?
}

// MARK: - Repository

@MainActor
final class VoiceNoteAPIRepository {
	private let client = APIClient.shared
	
	func fetchVoiceNotes(page: Int? = nil, limit: Int? = nil) async throws -> [APIVoiceNote] {
		let endpoint = APIEndpoint.voiceNotes
		let response: VoiceNotesResponse = try await client.get(endpoint)
		return response.voicenotes
	}
	
	func fetchVoiceNote(id: UUID) async throws -> APIVoiceNote {
		let endpoint = APIEndpoint.voiceNote(id: id)
		let response: VoiceNoteResponse = try await client.get(endpoint)
		return response.voicenote
	}
	
	func uploadVoiceNote(audioURL: URL, metadata: CreateVoiceNoteRequest) async throws -> APIVoiceNote {
		let endpoint = APIEndpoint.createVoiceNote
		let metadataDict: [String: String] = [:]
		let response: VoiceNoteResponse = try await client.upload(endpoint, fileURL: audioURL, metadata: metadataDict)
		return response.voicenote
	}
	
	func updateVoiceNote(id: UUID, metadata: CreateVoiceNoteRequest) async throws -> APIVoiceNote {
		let endpoint = APIEndpoint.updateVoiceNote(id: id)
		let response: VoiceNoteResponse = try await client.put(endpoint, body: metadata)
		return response.voicenote
	}
	
	func deleteVoiceNote(id: UUID) async throws {
		let endpoint = APIEndpoint.deleteVoiceNote(id: id)
		try await client.delete(endpoint)
	}
	
	func transcribeVoiceNote(id: UUID) async throws -> String {
		let endpoint = APIEndpoint.transcribeVoiceNote(id: id)
		let response: TranscribeResponse = try await client.post(endpoint, body: nil as EmptyRequest?)
		return response.voicenote.transcription ?? ""
	}
	
	func downloadAudio(id: UUID) async throws -> URL {
		_ = APIEndpoint.voiceNoteAudio(id: id)
		// This would need a special download method in APIClient
		// For now, return a placeholder
		throw APINetworkError.unknown(NSError(domain: "VoiceNoteAPIRepository", code: -1, userInfo: [NSLocalizedDescriptionKey: "Audio download not yet implemented"]))
	}
}

