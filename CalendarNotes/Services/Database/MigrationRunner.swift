//
//  MigrationRunner.swift
//  CalendarNotes
//
//  Migration Runner - Handles migration execution at app launch and updates
//

import Foundation
import Combine
import Logging

/// Handles running migrations at appropriate times (app launch, updates, manual)
class MigrationRunner {
    static let shared = MigrationRunner()
    
    private let migrationManager = MigrationManager.shared
    private let logger = Logger(label: "com.calendarnotes.migrationrunner")
    
    private let userDefaults = UserDefaults.standard
    private let lastMigrationVersionKey = "lastAppliedMigrationVersion"
    private let lastAppVersionKey = "lastAppVersion"
    
    /// Migration progress publisher
    let migrationProgress = PassthroughSubject<MigrationProgress, Never>()
    
    /// Migration progress information
    struct MigrationProgress {
        let current: Int
        let total: Int
        let migrationName: String
        let status: Status
        
        enum Status {
            case starting
            case applying
            case completed
            case failed(String)
        }
    }
    
    private init() {}
    
    // MARK: - App Launch Migration
    
    /// Runs migrations on app launch if needed
    func runMigrationsOnLaunch() async throws {
        logger.info("Checking for migrations on app launch")
        
        // Check if database connection is available
        guard await checkDatabaseConnection() else {
            logger.warning("Database not available, skipping migrations")
            return
        }
        
        do {
            _ = try await executeMigrations()
        } catch {
            logger.error("Migration failed on app launch: \(error.localizedDescription)")
            throw error
        }
    }
    
    /// Checks if database connection is available
    private func checkDatabaseConnection() async -> Bool {
        do {
            // Try to connect to database
            try await DatabaseManager.shared.connect()
            let status = DatabaseManager.shared.connectionStatus
            switch status {
            case .connected:
                return true
            default:
                return false
            }
        } catch {
            logger.warning("Database connection check failed: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - App Update Migration
    
    /// Checks if app was updated and runs migrations if needed
    func checkAndRunMigrationsOnUpdate() async throws {
        let currentVersion = getCurrentAppVersion()
        let lastVersion = userDefaults.string(forKey: lastAppVersionKey)
        
        logger.info("App version check - Current: \(currentVersion ?? "unknown"), Last: \(lastVersion ?? "unknown")")
        
        // If versions differ, app was updated
        if currentVersion != lastVersion {
            logger.info("App updated detected, running migrations")
            _ = try await executeMigrations()
            
            // Update stored version
            if let currentVersion = currentVersion {
                userDefaults.set(currentVersion, forKey: lastAppVersionKey)
            }
        } else {
            logger.info("No app update detected")
        }
    }
    
    /// Gets current app version
    private func getCurrentAppVersion() -> String? {
        return Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }
    
    // MARK: - Manual Migration
    
    /// Manually triggers migration execution (for Settings)
    func runMigrationsManually() async throws -> MigrationResult {
        logger.info("Manual migration triggered")
        
        migrationProgress.send(MigrationProgress(
            current: 0,
            total: 0,
            migrationName: "Starting...",
            status: .starting
        ))
        
        do {
            let result = try await executeMigrations()
            return result
        } catch {
            let errorMsg = error.localizedDescription
            migrationProgress.send(MigrationProgress(
                current: 0,
                total: 0,
                migrationName: "Failed",
                status: .failed(errorMsg)
            ))
            throw error
        }
    }
    
    // MARK: - Migration Execution
    
    /// Executes all pending migrations
    private func executeMigrations() async throws -> MigrationResult {
        // Get pending migrations
        let pending = try await migrationManager.getPendingMigrations()
        
        guard !pending.isEmpty else {
            logger.info("No pending migrations")
            migrationProgress.send(MigrationProgress(
                current: 0,
                total: 0,
                migrationName: "No migrations needed",
                status: .completed
            ))
            return MigrationResult(success: true, appliedCount: 0, errors: [])
        }
        
        logger.info("Found \(pending.count) pending migrations")
        
        migrationProgress.send(MigrationProgress(
            current: 0,
            total: pending.count,
            migrationName: "Preparing...",
            status: .starting
        ))
        
        var appliedCount = 0
        var errors: [String] = []
        
        // Apply each migration with progress updates
        for (index, migration) in pending.enumerated() {
            migrationProgress.send(MigrationProgress(
                current: index + 1,
                total: pending.count,
                migrationName: migration.name,
                status: .applying
            ))
            
            do {
                try await migrationManager.applyMigration(migration)
                appliedCount += 1
                logger.info("✓ Applied migration V\(migration.version): \(migration.name)")
            } catch {
                let errorMsg = "Migration V\(migration.version) failed: \(error.localizedDescription)"
                errors.append(errorMsg)
                logger.error("✗ \(errorMsg)")
                
                // Stop on first failure
                migrationProgress.send(MigrationProgress(
                    current: index + 1,
                    total: pending.count,
                    migrationName: migration.name,
                    status: .failed(errorMsg)
                ))
                
                throw MigrationError.migrationFailed(errorMsg)
            }
        }
        
        // Verify data integrity
        do {
            let isValid = try await migrationManager.verifyDataIntegrity()
            if !isValid {
                let errorMsg = "Data integrity verification failed"
                errors.append(errorMsg)
                logger.error("\(errorMsg)")
            }
        } catch {
            logger.warning("Data integrity check failed: \(error.localizedDescription)")
        }
        
        migrationProgress.send(MigrationProgress(
            current: pending.count,
            total: pending.count,
            migrationName: "Completed",
            status: .completed
        ))
        
        // Update last migration version
        if let lastVersion = pending.last?.version {
            userDefaults.set(lastVersion, forKey: lastMigrationVersionKey)
        }
        
        return MigrationResult(success: errors.isEmpty, appliedCount: appliedCount, errors: errors)
    }
    
    /// Migration execution result
    struct MigrationResult {
        let success: Bool
        let appliedCount: Int
        let errors: [String]
    }
    
    // MARK: - Migration Status
    
    /// Gets current migration status
    func getMigrationStatus() async throws -> MigrationStatus {
        let statuses = try await migrationManager.getMigrationStatus()
        let applied = statuses.filter { $0.applied }
        let pending = statuses.filter { !$0.applied }
        
        return MigrationStatus(
            totalMigrations: statuses.count,
            appliedMigrations: applied.count,
            pendingMigrations: pending.count,
            lastAppliedVersion: applied.max(by: { $0.version < $1.version })?.version,
            pendingVersions: pending.map { $0.version }
        )
    }
    
    /// Migration status information
    struct MigrationStatus {
        let totalMigrations: Int
        let appliedMigrations: Int
        let pendingMigrations: Int
        let lastAppliedVersion: Int?
        let pendingVersions: [Int]
    }
    
    // MARK: - Rollback
    
    /// Rolls back the last migration
    func rollbackLastMigration() async throws {
        logger.info("Rolling back last migration")
        
        try await migrationManager.rollbackLastMigration()
        
        // Update stored version
        if let status = try? await getMigrationStatus(),
           let lastVersion = status.lastAppliedVersion {
            userDefaults.set(lastVersion, forKey: lastMigrationVersionKey)
        } else {
            userDefaults.removeObject(forKey: lastMigrationVersionKey)
        }
    }
    
    /// Rolls back a specific migration version
    func rollbackMigration(version: Int) async throws {
        logger.info("Rolling back migration V\(version)")
        
        try await migrationManager.rollbackMigration(version: version)
        
        // Update stored version
        if let status = try? await getMigrationStatus(),
           let lastVersion = status.lastAppliedVersion {
            userDefaults.set(lastVersion, forKey: lastMigrationVersionKey)
        } else {
            userDefaults.removeObject(forKey: lastMigrationVersionKey)
        }
    }
}

// MARK: - Migration Errors

enum MigrationError: LocalizedError {
    case migrationFailed(String)
    case databaseUnavailable
    case validationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .migrationFailed(let message):
            return "Migration failed: \(message)"
        case .databaseUnavailable:
            return "Database is not available"
        case .validationFailed(let message):
            return "Migration validation failed: \(message)"
        }
    }
}

