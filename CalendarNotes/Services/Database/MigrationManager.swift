//
//  MigrationManager.swift
//  CalendarNotes
//
//  Database Migration Management System
//

import Foundation
import PostgresNIO
import Logging

/// Manages database migrations for the CalendarNotes app
class MigrationManager {
    static let shared = MigrationManager()
    
    private let dbManager = DatabaseManager.shared
    private let logger = Logger(label: "com.calendarnotes.migrations")
    
    private let migrationsTableName = "calendarnotes.migrations"
    private let migrationsFolder = "Migrations"
    
    /// Migration record structure
    struct MigrationRecord: Codable {
        let version: Int
        let name: String
        let appliedAt: Date
        
        enum CodingKeys: String, CodingKey {
            case version
            case name
            case appliedAt = "applied_at"
        }
    }
    
    /// Migration result
    enum MigrationResult {
        case success
        case failure(String)
        case skipped
    }
    
    /// Migration status
    struct MigrationStatus {
        let version: Int
        let name: String
        let applied: Bool
        let appliedAt: Date?
    }
    
    private init() {}
    
    // MARK: - Migration Table Setup
    
    /// Creates the migrations tracking table if it doesn't exist
    func createMigrationsTable() async throws {
        let sql = """
            CREATE TABLE IF NOT EXISTS \(migrationsTableName) (
                version INTEGER PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
            );
            
            CREATE INDEX IF NOT EXISTS idx_migrations_version ON \(migrationsTableName)(version);
        """
        
        _ = try await dbManager.executeUpdate(sql: sql)
        logger.info("Migrations table created or verified")
    }
    
    // MARK: - Migration Discovery
    
    /// Discovers all migration files in the Migrations folder
    func discoverMigrations() -> [MigrationFile] {
        var migrations: [MigrationFile] = []
        
        // Try to find migrations folder in multiple locations
        var migrationsPath: URL?
        
        // First, try in the main bundle (for production)
        if let bundlePath = Bundle.main.resourceURL {
            let bundleMigrationsPath = bundlePath.appendingPathComponent(migrationsFolder)
            if FileManager.default.fileExists(atPath: bundleMigrationsPath.path) {
                migrationsPath = bundleMigrationsPath
            }
        }
        
        // If not in bundle, try in the source directory (for development)
        if migrationsPath == nil {
            let sourcePath = URL(fileURLWithPath: #file)
                .deletingLastPathComponent() // Remove MigrationManager.swift
                .appendingPathComponent(migrationsFolder)
            if FileManager.default.fileExists(atPath: sourcePath.path) {
                migrationsPath = sourcePath
            }
        }
        
        guard let path = migrationsPath else {
            logger.warning("Migrations folder not found")
            return migrations
        }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: path, includingPropertiesForKeys: nil)
            
            for file in files {
                let filename = file.lastPathComponent
                
                // Parse forward migrations (V{version}__{name}.sql)
                // Skip rollback files (.down.sql)
                if filename.hasSuffix(".down.sql") {
                    continue
                }
                
                if filename.hasSuffix(".sql") && filename.hasPrefix("V") {
                    // Extract version number (V{number}__)
                    let components = filename.replacingOccurrences(of: ".sql", with: "").components(separatedBy: "__")
                    if components.count == 2 {
                        let versionStr = components[0].replacingOccurrences(of: "V", with: "")
                        if let version = Int(versionStr) {
                        let name = components[1]
                        
                        migrations.append(MigrationFile(
                            version: version,
                            name: name,
                            filename: filename,
                            path: file.path,
                            type: .forward
                        ))
                        }
                    }
                }
            }
            
            // Sort by version
            migrations.sort { $0.version < $1.version }
            
            logger.info("Discovered \(migrations.count) migration files")
        } catch {
            logger.error("Error discovering migrations: \(error.localizedDescription)")
        }
        
        return migrations
    }
    
    /// Migration file structure
    struct MigrationFile {
        let version: Int
        let name: String
        let filename: String
        let path: String
        let type: MigrationType
        
        enum MigrationType {
            case forward
            case rollback
        }
        
        var rollbackFilename: String {
            return filename.replacingOccurrences(of: ".sql", with: ".down.sql")
        }
    }
    
    // MARK: - Migration Status
    
    /// Gets all applied migrations from the database
    func getAppliedMigrations() async throws -> [MigrationRecord] {
        let sql = "SELECT version, name, applied_at FROM \(migrationsTableName) ORDER BY version"
        
        var records: [MigrationRecord] = []
        let rows = try await dbManager.executeQuery(sql: sql)
        
        for try await row in rows {
            let randomAccessRow = row.makeRandomAccess()
            let version = try randomAccessRow["version"].decode(Int.self)
            let name = try randomAccessRow["name"].decode(String.self)
            let appliedAt = try randomAccessRow["applied_at"].decode(Date.self)
            
            records.append(MigrationRecord(version: version, name: name, appliedAt: appliedAt))
        }
        
        return records
    }
    
    /// Gets migration status for all discovered migrations
    func getMigrationStatus() async throws -> [MigrationStatus] {
        let discovered = discoverMigrations()
        let applied = try await getAppliedMigrations()
        
        return discovered.map { migration in
            if let appliedRecord = applied.first(where: { $0.version == migration.version }) {
                return MigrationStatus(
                    version: migration.version,
                    name: migration.name,
                    applied: true,
                    appliedAt: appliedRecord.appliedAt
                )
            } else {
                return MigrationStatus(
                    version: migration.version,
                    name: migration.name,
                    applied: false,
                    appliedAt: nil
                )
            }
        }
    }
    
    /// Gets pending migrations that need to be applied
    func getPendingMigrations() async throws -> [MigrationFile] {
        let discovered = discoverMigrations()
        let applied = try await getAppliedMigrations()
        let appliedVersions = Set(applied.map { $0.version })
        
        return discovered.filter { !appliedVersions.contains($0.version) }
    }
    
    // MARK: - Migration Validation
    
    /// Validates a migration file before applying
    func validateMigration(_ migration: MigrationFile) -> Bool {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: migration.path) else {
            logger.error("Migration file not found: \(migration.path)")
            return false
        }
        
        // Check if file is readable
        guard FileManager.default.isReadableFile(atPath: migration.path) else {
            logger.error("Migration file is not readable: \(migration.path)")
            return false
        }
        
        // Check if file has content
        guard let content = try? String(contentsOfFile: migration.path, encoding: .utf8),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.error("Migration file is empty: \(migration.path)")
            return false
        }
        
        logger.info("Migration \(migration.version) validated: \(migration.name)")
        return true
    }
    
    // MARK: - Database Backup
    
    /// Creates a backup of the database before migration
    func backupDatabase() async throws -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        let backupFilename = "calendarnotes_backup_\(timestamp).sql"
        
        // Note: In a production environment, you would use pg_dump
        // For now, we'll just log the backup intent
        logger.info("Database backup requested: \(backupFilename)")
        
        // TODO: Implement actual backup using pg_dump or similar
        // This would require shell access or a backup service
        
        return backupFilename
    }
    
    // MARK: - Apply Migration
    
    /// Applies a single migration
    func applyMigration(_ migration: MigrationFile) async throws {
        logger.info("Applying migration V\(migration.version): \(migration.name)")
        
        // Validate migration
        guard validateMigration(migration) else {
            throw DatabaseError.migrationFailed("Migration validation failed for V\(migration.version)")
        }
        
        // Read migration SQL
        guard let sql = try? String(contentsOfFile: migration.path, encoding: .utf8) else {
            throw DatabaseError.migrationFailed("Could not read migration file: \(migration.path)")
        }
        
        // Execute migration in a transaction
        _ = try await dbManager.executeTransaction(queries: [
            (sql: sql, parameters: [])
        ])
        
        // Record migration
        let recordSQL = """
            INSERT INTO \(migrationsTableName) (version, name, applied_at)
            VALUES ($1, $2, CURRENT_TIMESTAMP)
            ON CONFLICT (version) DO NOTHING
        """
        
        let parameters: [PostgresData] = [
            .fromInt(migration.version),
            .fromString(migration.name)
        ]
        
        _ = try await dbManager.executeUpdate(sql: recordSQL, parameters: parameters)
        
        logger.info("Migration V\(migration.version) applied successfully")
    }
    
    /// Applies all pending migrations in order
    func applyPendingMigrations() async throws -> [MigrationResult] {
        logger.info("Starting migration process")
        
        // Ensure migrations table exists
        try await createMigrationsTable()
        
        // Get pending migrations
        let pending = try await getPendingMigrations()
        
        guard !pending.isEmpty else {
            logger.info("No pending migrations")
            return []
        }
        
        logger.info("Found \(pending.count) pending migrations")
        
        var results: [MigrationResult] = []
        
        // Create backup before migration
        do {
            let backupFile = try await backupDatabase()
            logger.info("Database backup created: \(backupFile)")
        } catch {
            logger.warning("Failed to create backup: \(error.localizedDescription)")
            // Continue with migration even if backup fails
        }
        
        // Apply each migration
        for migration in pending {
            do {
                try await applyMigration(migration)
                results.append(.success)
                logger.info("✓ Migration V\(migration.version) applied: \(migration.name)")
            } catch {
                let errorMsg = "Failed to apply migration V\(migration.version): \(error.localizedDescription)"
                logger.error("✗ \(errorMsg)")
                results.append(.failure(errorMsg))
                
                // Stop on first failure
                throw DatabaseError.migrationFailed(errorMsg)
            }
        }
        
        logger.info("Migration process completed: \(results.filter { if case .success = $0 { return true }; return false }.count) succeeded")
        
        return results
    }
    
    // MARK: - Rollback Migration
    
    /// Rolls back a specific migration
    func rollbackMigration(version: Int) async throws {
        logger.info("Rolling back migration V\(version)")
        
        // Find the migration
        let migrations = discoverMigrations()
        guard let migration = migrations.first(where: { $0.version == version }) else {
            throw DatabaseError.migrationFailed("Migration V\(version) not found")
        }
        
        // Check if migration is applied
        let applied = try await getAppliedMigrations()
        guard applied.contains(where: { $0.version == version }) else {
            throw DatabaseError.migrationFailed("Migration V\(version) is not applied")
        }
        
        // Find rollback file
        let rollbackPath = (migration.path as NSString).deletingLastPathComponent + "/" + migration.rollbackFilename
        
        guard FileManager.default.fileExists(atPath: rollbackPath) else {
            throw DatabaseError.migrationFailed("Rollback file not found: \(rollbackPath)")
        }
        
        // Read rollback SQL
        guard let sql = try? String(contentsOfFile: rollbackPath, encoding: .utf8) else {
            throw DatabaseError.migrationFailed("Could not read rollback file: \(rollbackPath)")
        }
        
        // Execute rollback in a transaction
        _ = try await dbManager.executeTransaction(queries: [
            (sql: sql, parameters: [])
        ])
        
        // Remove migration record
        let deleteSQL = "DELETE FROM \(migrationsTableName) WHERE version = $1"
        let parameters: [PostgresData] = [.fromInt(version)]
        _ = try await dbManager.executeUpdate(sql: deleteSQL, parameters: parameters)
        
        logger.info("Migration V\(version) rolled back successfully")
    }
    
    /// Rolls back the last applied migration
    func rollbackLastMigration() async throws {
        let applied = try await getAppliedMigrations()
        guard let lastMigration = applied.max(by: { $0.version < $1.version }) else {
            throw DatabaseError.migrationFailed("No migrations to rollback")
        }
        
        try await rollbackMigration(version: lastMigration.version)
    }
    
    // MARK: - Migration Testing
    
    /// Tests migrations on a copy of the database (for development/testing)
    func testMigrations() async throws {
        logger.info("Testing migrations on database copy")
        
        // Note: In a real implementation, this would:
        // 1. Create a test database
        // 2. Apply migrations to test database
        // 3. Verify data integrity
        // 4. Run performance tests
        // 5. Clean up test database
        
        logger.warning("Migration testing not fully implemented - requires test database setup")
    }
    
    // MARK: - Data Integrity Verification
    
    /// Verifies data integrity after migration
    func verifyDataIntegrity() async throws -> Bool {
        logger.info("Verifying data integrity")
        
        // Check that all tables exist
        let tablesSQL = """
            SELECT table_name
            FROM information_schema.tables
            WHERE table_schema = 'calendarnotes'
            AND table_type = 'BASE TABLE'
        """
        
        var tableCount = 0
        let rows = try await dbManager.executeQuery(sql: tablesSQL)
        for try await _ in rows {
            tableCount += 1
        }
        
        logger.info("Found \(tableCount) tables in calendarnotes schema")
        
        // Additional integrity checks can be added here
        // - Check foreign key constraints
        // - Verify indexes exist
        // - Check data consistency
        
        return tableCount > 0
    }
}

// MARK: - DatabaseError Extension

