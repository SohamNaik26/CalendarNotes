//
//  VoiceNoteRepository.swift
//  CalendarNotes
//
//  Created on [Date]
//

import Foundation
import PostgresNIO

/// PostgreSQL repository for voice note operations with integrated storage management
class PostgresVoiceNoteRepository: VoiceNoteRepositoryProtocol {
    static let shared = PostgresVoiceNoteRepository()
    
    private let dbManager = DatabaseManager.shared
    private let storageManager = VoiceNoteStorageManager.shared
    private let compressionService = VoiceNoteCompressionService.shared
    private let cloudService = VoiceNoteCloudService.shared
    
    private init() {}
    
    // MARK: - Create
    
    /// Creates a new voice note with file storage and database entry
    func create(
        userId: UUID,
        audioFileURL: URL,
        transcription: String? = nil,
        duration: TimeInterval,
        linkedNoteId: UUID? = nil,
        linkedEventId: UUID? = nil,
        linkedTaskId: UUID? = nil,
        isFavorite: Bool = false,
        autoDeleteAfterDays: Int? = nil,
        createdAt: Date = Date()
    ) async throws -> VoiceNoteModel {
        let id = UUID()
        
        // Save audio file with date-based organization
        let savedFileURL = try storageManager.saveAudioFile(from: audioFileURL, to: createdAt)
        let fileSize = try storageManager.fileSize(at: savedFileURL)
        
        // Calculate auto-delete date if specified
        let autoDeleteOn = autoDeleteAfterDays.map { days in
            Calendar.current.date(byAdding: .day, value: days, to: createdAt) ?? createdAt
        }
        
        // Insert into database
        let sql = """
            INSERT INTO calendarnotes.voice_notes (
                id, user_id, audio_file_path, transcription, duration_seconds,
                file_size_bytes, linked_note_id, linked_event_id, linked_task_id,
                is_favorite, auto_delete_after_days, auto_delete_on, created_at
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13)
            RETURNING id
        """
        
        let parameters: [PostgresData] = [
            .fromUUID(id),
            .fromUUID(userId),
            .fromString(savedFileURL.path),
            .fromOptionalString(transcription),
            .fromInt(Int(duration)),
            .fromInt(Int(fileSize)),
            .fromOptionalUUID(linkedNoteId),
            .fromOptionalUUID(linkedEventId),
            .fromOptionalUUID(linkedTaskId),
            .fromBool(isFavorite),
            autoDeleteAfterDays.map { .fromInt($0) } ?? .null,
            autoDeleteOn.map { .fromDate($0) } ?? .null,
            .fromDate(createdAt)
        ]
        
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let returnedId = try? row.decodeColumn("id", as: UUID.self) {
                // Enqueue compression in background
                compressionService.enqueueCompression(
                    voiceNoteId: returnedId,
                    sourceURL: savedFileURL,
                    preset: .standard
                )
                
                // Return the created model
                return try await findById(id: returnedId)!
            }
        }
        throw DatabaseError.queryExecutionFailed("Failed to create voice note")
    }
    
    // MARK: - Read
    
    func findById(id: UUID) async throws -> VoiceNoteModel? {
        let sql = "SELECT * FROM calendarnotes.voice_notes WHERE id = $1 AND deleted_at IS NULL"
        let parameters: [PostgresData] = [.fromUUID(id)]
        
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            return try decodeVoiceNote(from: row)
        }
        return nil
    }
    
    func findByUserId(
        _ userId: UUID,
        limit: Int = 100,
        offset: Int = 0
    ) async throws -> [VoiceNoteModel] {
        let sql = """
            SELECT * FROM calendarnotes.voice_notes
            WHERE user_id = $1 AND deleted_at IS NULL
            ORDER BY created_at DESC
            LIMIT $2 OFFSET $3
        """
        let parameters: [PostgresData] = [
            .fromUUID(userId),
            .fromInt(limit),
            .fromInt(offset)
        ]
        
        var voiceNotes: [VoiceNoteModel] = []
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let note = try? decodeVoiceNote(from: row) {
                voiceNotes.append(note)
            }
        }
        return voiceNotes
    }
    
    func findByDate(
        userId: UUID,
        date: Date,
        limit: Int = 100
    ) async throws -> [VoiceNoteModel] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let sql = """
            SELECT * FROM calendarnotes.voice_notes
            WHERE user_id = $1 AND created_at >= $2 AND created_at < $3 AND deleted_at IS NULL
            ORDER BY created_at DESC
            LIMIT $4
        """
        let parameters: [PostgresData] = [
            .fromUUID(userId),
            .fromDate(startOfDay),
            .fromDate(endOfDay),
            .fromInt(limit)
        ]
        
        var voiceNotes: [VoiceNoteModel] = []
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let note = try? decodeVoiceNote(from: row) {
                voiceNotes.append(note)
            }
        }
        return voiceNotes
    }
    
    func findByLinkedEntity(
        userId: UUID,
        linkedNoteId: UUID? = nil,
        linkedEventId: UUID? = nil,
        linkedTaskId: UUID? = nil
    ) async throws -> [VoiceNoteModel] {
        var sql = "SELECT * FROM calendarnotes.voice_notes WHERE user_id = $1 AND deleted_at IS NULL"
        var parameters: [PostgresData] = [.fromUUID(userId)]
        var paramIndex = 2
        
        if let linkedNoteId = linkedNoteId {
            sql += " AND linked_note_id = $\(paramIndex)"
            parameters.append(.fromUUID(linkedNoteId))
            paramIndex += 1
        }
        
        if let linkedEventId = linkedEventId {
            sql += " AND linked_event_id = $\(paramIndex)"
            parameters.append(.fromUUID(linkedEventId))
            paramIndex += 1
        }
        
        if let linkedTaskId = linkedTaskId {
            sql += " AND linked_task_id = $\(paramIndex)"
            parameters.append(.fromUUID(linkedTaskId))
            paramIndex += 1
        }
        
        sql += " ORDER BY created_at DESC"
        
        var voiceNotes: [VoiceNoteModel] = []
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let note = try? decodeVoiceNote(from: row) {
                voiceNotes.append(note)
            }
        }
        return voiceNotes
    }
    
    func searchTranscriptions(
        userId: UUID,
        query: String,
        limit: Int = 50
    ) async throws -> [VoiceNoteModel] {
        let sql = """
            SELECT * FROM calendarnotes.voice_notes
            WHERE user_id = $1 AND deleted_at IS NULL
            AND transcription ILIKE $2
            ORDER BY created_at DESC
            LIMIT $3
        """
        let parameters: [PostgresData] = [
            .fromUUID(userId),
            .fromString("%\(query)%"),
            .fromInt(limit)
        ]
        
        var voiceNotes: [VoiceNoteModel] = []
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let note = try? decodeVoiceNote(from: row) {
                voiceNotes.append(note)
            }
        }
        return voiceNotes
    }
    
    // MARK: - Update
    
    func updateTranscription(
        id: UUID,
        transcription: String
    ) async throws -> Bool {
        let sql = """
            UPDATE calendarnotes.voice_notes
            SET transcription = $1, updated_at = CURRENT_TIMESTAMP
            WHERE id = $2 AND deleted_at IS NULL
        """
        let parameters: [PostgresData] = [
            .fromString(transcription),
            .fromUUID(id)
        ]
        return try await dbManager.executeUpdate(sql: sql, parameters: parameters)
    }
    
    func updateLinkedEntities(
        id: UUID,
        linkedNoteId: UUID? = nil,
        linkedEventId: UUID? = nil,
        linkedTaskId: UUID? = nil
    ) async throws -> Bool {
        var sql = "UPDATE calendarnotes.voice_notes SET updated_at = CURRENT_TIMESTAMP"
        var parameters: [PostgresData] = []
        var paramIndex = 1
        
        if linkedNoteId != nil {
            sql += ", linked_note_id = $\(paramIndex)"
            parameters.append(.fromOptionalUUID(linkedNoteId))
            paramIndex += 1
        }
        
        if linkedEventId != nil {
            sql += ", linked_event_id = $\(paramIndex)"
            parameters.append(.fromOptionalUUID(linkedEventId))
            paramIndex += 1
        }
        
        if linkedTaskId != nil {
            sql += ", linked_task_id = $\(paramIndex)"
            parameters.append(.fromOptionalUUID(linkedTaskId))
            paramIndex += 1
        }
        
        sql += " WHERE id = $\(paramIndex) AND deleted_at IS NULL"
        parameters.append(.fromUUID(id))
        
        return try await dbManager.executeUpdate(sql: sql, parameters: parameters)
    }
    
    func toggleFavorite(id: UUID) async throws -> Bool {
        let sql = """
            UPDATE calendarnotes.voice_notes
            SET is_favorite = NOT is_favorite, updated_at = CURRENT_TIMESTAMP
            WHERE id = $1 AND deleted_at IS NULL
        """
        let parameters: [PostgresData] = [.fromUUID(id)]
        return try await dbManager.executeUpdate(sql: sql, parameters: parameters)
    }
    
    func updateCompressionStatus(
        id: UUID,
        status: String,
        bitrate: Int? = nil,
        sampleRate: Int? = nil,
        fileSize: Int64? = nil
    ) async throws -> Bool {
        var sql = """
            UPDATE calendarnotes.voice_notes
            SET compression_status = $1, updated_at = CURRENT_TIMESTAMP
        """
        var parameters: [PostgresData] = [.fromString(status)]
        var paramIndex = 2
        
        if let bitrate = bitrate {
            sql += ", bitrate_kbps = $\(paramIndex)"
            parameters.append(.fromInt(bitrate))
            paramIndex += 1
        }
        
        if let sampleRate = sampleRate {
            sql += ", sample_rate_hz = $\(paramIndex)"
            parameters.append(.fromInt(sampleRate))
            paramIndex += 1
        }
        
        if let fileSize = fileSize {
            sql += ", file_size_bytes = $\(paramIndex)"
            parameters.append(.fromInt(Int(fileSize)))
            paramIndex += 1
        }
        
        sql += " WHERE id = $\(paramIndex) AND deleted_at IS NULL"
        parameters.append(.fromUUID(id))
        
        return try await dbManager.executeUpdate(sql: sql, parameters: parameters)
    }
    
    func updateCloudSyncStatus(
        id: UUID,
        status: String,
        cloudStorageURL: String? = nil
    ) async throws -> Bool {
        var sql = """
            UPDATE calendarnotes.voice_notes
            SET cloud_sync_status = $1, updated_at = CURRENT_TIMESTAMP
        """
        var parameters: [PostgresData] = [.fromString(status)]
        var paramIndex = 2
        
        if let cloudURL = cloudStorageURL {
            sql += ", cloud_storage_url = $\(paramIndex)"
            parameters.append(.fromString(cloudURL))
            paramIndex += 1
        }
        
        sql += " WHERE id = $\(paramIndex) AND deleted_at IS NULL"
        parameters.append(.fromUUID(id))
        
        return try await dbManager.executeUpdate(sql: sql, parameters: parameters)
    }
    
    // MARK: - Delete
    
    func delete(id: UUID) async throws -> Bool {
        // Get voice note to delete file
        if let voiceNote = try await findById(id: id) {
            let fileURL = URL(fileURLWithPath: voiceNote.audioFilePath)
            try? storageManager.deleteAudioFile(at: fileURL)
        }
        
        // Soft delete in database
        let sql = "UPDATE calendarnotes.voice_notes SET deleted_at = CURRENT_TIMESTAMP WHERE id = $1"
        let parameters: [PostgresData] = [.fromUUID(id)]
        return try await dbManager.executeUpdate(sql: sql, parameters: parameters)
    }
    
    // MARK: - Cleanup
    
    func findExpiredVoiceNotes(
        userId: UUID,
        excludeFavorites: Bool = true,
        excludeLinked: Bool = true
    ) async throws -> [VoiceNoteModel] {
        var sql = """
            SELECT * FROM calendarnotes.voice_notes
            WHERE user_id = $1 AND deleted_at IS NULL
            AND auto_delete_on IS NOT NULL AND auto_delete_on <= CURRENT_TIMESTAMP
        """
        let parameters: [PostgresData] = [.fromUUID(userId)]
        
        if excludeFavorites {
            sql += " AND is_favorite = FALSE"
        }
        
        if excludeLinked {
            sql += " AND linked_note_id IS NULL AND linked_event_id IS NULL AND linked_task_id IS NULL"
        }
        
        sql += " ORDER BY created_at ASC"
        
        var voiceNotes: [VoiceNoteModel] = []
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let note = try? decodeVoiceNote(from: row) {
                voiceNotes.append(note)
            }
        }
        return voiceNotes
    }
    
    // MARK: - Helper Methods
    
    private func decodeVoiceNote(from row: PostgresRow) throws -> VoiceNoteModel {
        return VoiceNoteModel(
            id: try row.decodeColumn("id", as: UUID.self),
            userId: try row.decodeColumn("user_id", as: UUID.self),
            audioFilePath: try row.decodeColumn("audio_file_path", as: String.self),
            transcription: row.decodeColumnOptional("transcription", as: String.self),
            durationSeconds: row.decodeColumnOptional("duration_seconds", as: Int.self) ?? 0,
            fileSizeBytes: row.decodeColumnOptional("file_size_bytes", as: Int64.self) ?? 0,
            bitrateKbps: row.decodeColumnOptional("bitrate_kbps", as: Int.self),
            sampleRateHz: row.decodeColumnOptional("sample_rate_hz", as: Int.self),
            linkedNoteId: row.decodeColumnOptional("linked_note_id", as: UUID.self),
            linkedEventId: row.decodeColumnOptional("linked_event_id", as: UUID.self),
            linkedTaskId: row.decodeColumnOptional("linked_task_id", as: UUID.self),
            isFavorite: row.decodeColumnOptional("is_favorite", as: Bool.self) ?? false,
            isArchived: row.decodeColumnOptional("is_archived", as: Bool.self) ?? false,
            autoDeleteAfterDays: row.decodeColumnOptional("auto_delete_after_days", as: Int.self),
            autoDeleteOn: row.decodeColumnOptional("auto_delete_on", as: Date.self),
            cloudStorageURL: row.decodeColumnOptional("cloud_storage_url", as: String.self),
            cloudSyncStatus: row.decodeColumnOptional("cloud_sync_status", as: String.self),
            isOfflineAvailable: row.decodeColumnOptional("is_offline_available", as: Bool.self) ?? true,
            compressionStatus: row.decodeColumnOptional("compression_status", as: String.self),
            createdAt: try row.decodeColumn("created_at", as: Date.self),
            updatedAt: try row.decodeColumn("updated_at", as: Date.self),
            syncedAt: row.decodeColumnOptional("synced_at", as: Date.self),
            deletedAt: row.decodeColumnOptional("deleted_at", as: Date.self)
        )
    }
}

// MARK: - Voice Note Model
struct VoiceNoteModel {
    let id: UUID
    let userId: UUID
    let audioFilePath: String
    let transcription: String?
    let durationSeconds: Int
    let fileSizeBytes: Int64
    let bitrateKbps: Int?
    let sampleRateHz: Int?
    let linkedNoteId: UUID?
    let linkedEventId: UUID?
    let linkedTaskId: UUID?
    let isFavorite: Bool
    let isArchived: Bool
    let autoDeleteAfterDays: Int?
    let autoDeleteOn: Date?
    let cloudStorageURL: String?
    let cloudSyncStatus: String?
    let isOfflineAvailable: Bool
    let compressionStatus: String?
    let createdAt: Date
    let updatedAt: Date
    let syncedAt: Date?
    let deletedAt: Date?
}

