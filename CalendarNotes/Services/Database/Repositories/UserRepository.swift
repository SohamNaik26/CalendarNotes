//
//  UserRepository.swift
//  CalendarNotes
//
//  Created on [Date]
//

import Foundation
import PostgresNIO

/// Repository for user-related database operations
class UserRepository {
    private let dbManager = DatabaseManager.shared
    
    // MARK: - Create
    func create(user: UserModel) async throws -> UUID {
        let sql = """
            INSERT INTO calendarnotes.users (id, email, password_hash, full_name, profile_image_url, email_verified, is_active)
            VALUES ($1, $2, $3, $4, $5, $6, $7)
            RETURNING id
        """
        
        let parameters: [PostgresData] = [
            .fromUUID(user.id),
            .fromString(user.email),
            .fromString(user.passwordHash),
            .fromOptionalString(user.fullName),
            .fromOptionalString(user.profileImageURL),
            .fromBool(user.emailVerified),
            .fromBool(user.isActive)
        ]
        
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let id = try? row.decodeColumn("id", as: UUID.self) {
                return id
            }
        }
        throw DatabaseError.queryExecutionFailed("Failed to create user")
    }
    
    // MARK: - Read
    func findById(id: UUID) async throws -> UserModel? {
        let sql = "SELECT * FROM calendarnotes.users WHERE id = $1 AND deleted_at IS NULL"
        let parameters: [PostgresData] = [.fromUUID(id)]
        
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            return try decodeUser(from: row)
        }
        return nil
    }
    
    func findByEmail(_ email: String) async throws -> UserModel? {
        let sql = "SELECT * FROM calendarnotes.users WHERE email = $1"
        let parameters: [PostgresData] = [.fromString(email)]
        
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            return try decodeUser(from: row)
        }
        return nil
    }
    
    func findAll(limit: Int = 100, offset: Int = 0) async throws -> [UserModel] {
        let sql = "SELECT * FROM calendarnotes.users WHERE is_active = true ORDER BY created_at DESC LIMIT $1 OFFSET $2"
        let parameters: [PostgresData] = [
            .fromInt(limit),
            .fromInt(offset)
        ]
        
        var users: [UserModel] = []
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let user = try? decodeUser(from: row) {
                users.append(user)
            }
        }
        return users
    }
    
    // MARK: - Update
    func update(user: UserModel) async throws -> Bool {
        let sql = """
            UPDATE calendarnotes.users
            SET email = $1, password_hash = $2, full_name = $3, profile_image_url = $4,
                email_verified = $5, is_active = $6, last_login_at = $7, updated_at = CURRENT_TIMESTAMP
            WHERE id = $8
        """
        
        let parameters: [PostgresData] = [
            .fromString(user.email),
            .fromString(user.passwordHash),
            .fromOptionalString(user.fullName),
            .fromOptionalString(user.profileImageURL),
            .fromBool(user.emailVerified),
            .fromBool(user.isActive),
            .fromOptionalDate(user.lastLoginAt),
            .fromUUID(user.id)
        ]
        
        return try await dbManager.executeUpdate(sql: sql, parameters: parameters)
    }
    
    func updateLastLogin(userId: UUID) async throws -> Bool {
        let sql = "UPDATE calendarnotes.users SET last_login_at = CURRENT_TIMESTAMP WHERE id = $1"
        let parameters: [PostgresData] = [.fromUUID(userId)]
        return try await dbManager.executeUpdate(sql: sql, parameters: parameters)
    }
    
    // MARK: - Delete
    func delete(id: UUID) async throws -> Bool {
        // Soft delete - just mark as inactive
        let sql = "UPDATE calendarnotes.users SET is_active = false WHERE id = $1"
        let parameters: [PostgresData] = [.fromUUID(id)]
        return try await dbManager.executeUpdate(sql: sql, parameters: parameters)
    }
    
    // MARK: - Batch Operations
    func createBatch(users: [UserModel]) async throws -> [UUID] {
        var ids: [UUID] = []
        var queries: [(sql: String, parameters: [PostgresData])] = []
        
        for user in users {
            let sql = """
                INSERT INTO calendarnotes.users (id, email, password_hash, full_name, email_verified, is_active)
                VALUES ($1, $2, $3, $4, $5, $6)
            """
            let parameters: [PostgresData] = [
                .fromUUID(user.id),
                .fromString(user.email),
                .fromString(user.passwordHash),
                .fromOptionalString(user.fullName),
                .fromBool(user.emailVerified),
                .fromBool(user.isActive)
            ]
            queries.append((sql: sql, parameters: parameters))
            ids.append(user.id)
        }
        
        _ = try await dbManager.executeTransaction(queries: queries)
        return ids
    }
    
    // MARK: - Search
    func search(query: String, limit: Int = 50) async throws -> [UserModel] {
        let sql = """
            SELECT * FROM calendarnotes.users
            WHERE (email ILIKE $1 OR full_name ILIKE $1)
            AND is_active = true
            ORDER BY created_at DESC
            LIMIT $2
        """
        let searchPattern = "%\(query)%"
        let parameters: [PostgresData] = [
            .fromString(searchPattern),
            .fromInt(limit)
        ]
        
        var users: [UserModel] = []
        let rows = try await dbManager.executeQuery(sql: sql, parameters: parameters)
        for try await row in rows {
            if let user = try? decodeUser(from: row) {
                users.append(user)
            }
        }
        return users
    }
    
    // MARK: - Helper Methods
    private func decodeUser(from row: PostgresRow) throws -> UserModel {
        return UserModel(
            id: try row.decodeColumn("id", as: UUID.self),
            email: try row.decodeColumn("email", as: String.self),
            passwordHash: try row.decodeColumn("password_hash", as: String.self),
            fullName: row.decodeColumnOptional("full_name", as: String.self),
            profileImageURL: row.decodeColumnOptional("profile_image_url", as: String.self),
            emailVerified: try row.decodeColumn("email_verified", as: Bool.self),
            isActive: try row.decodeColumn("is_active", as: Bool.self),
            createdAt: try row.decodeColumn("created_at", as: Date.self),
            updatedAt: try row.decodeColumn("updated_at", as: Date.self),
            lastLoginAt: row.decodeColumnOptional("last_login_at", as: Date.self)
        )
    }
}

// MARK: - User Model
struct UserModel {
    let id: UUID
    let email: String
    let passwordHash: String
    let fullName: String?
    let profileImageURL: String?
    let emailVerified: Bool
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    let lastLoginAt: Date?
}

