# Database Migration System Usage Guide

## Overview

The CalendarNotes app includes a comprehensive database migration system that manages schema changes, tracks applied migrations, and provides rollback capabilities.

## Components

### 1. MigrationManager
- Tracks applied migrations in `calendarnotes.migrations` table
- Discovers migration files from the `Migrations` folder
- Applies migrations in order
- Supports rollback operations
- Validates migrations before applying
- Creates database backups before migration

### 2. MigrationRunner
- Runs migrations on app launch
- Checks for migrations on app updates
- Provides manual migration trigger
- Shows migration progress
- Handles migration failures gracefully

### 3. MigrationTester
- Tests migrations on database copies
- Verifies data integrity after migration
- Performance testing for large datasets

## Migration Files

Migration files follow the naming convention:
- Forward migrations: `V{version}__{name}.sql`
- Rollback migrations: `V{version}__{name}.down.sql`

Example:
- `V1__initial_schema.sql` - Creates initial database schema
- `V1__initial_schema.down.sql` - Rolls back initial schema
- `V2__add_voice_notes.sql` - Adds voice notes table
- `V2__add_voice_notes.down.sql` - Removes voice notes table

## Usage

### Automatic Migration on App Launch

Add to your app's initialization code (e.g., in `App.swift` or `SceneDelegate`):

```swift
import SwiftUI

@main
struct CalendarNotesApp: App {
    init() {
        // Run migrations on app launch
        Task {
            do {
                try await MigrationRunner.shared.runMigrationsOnLaunch()
            } catch {
                print("Migration failed: \(error.localizedDescription)")
                // Handle error appropriately
            }
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### Check for Migrations on App Update

```swift
Task {
    do {
        try await MigrationRunner.shared.checkAndRunMigrationsOnUpdate()
    } catch {
        print("Migration failed: \(error.localizedDescription)")
    }
}
```

### Manual Migration Trigger (Settings)

```swift
import SwiftUI

struct SettingsView: View {
    @State private var migrationStatus: MigrationRunner.MigrationStatus?
    @State private var isRunning = false
    @State private var migrationProgress: MigrationRunner.MigrationProgress?
    
    var body: some View {
        List {
            Section("Database Migrations") {
                if let status = migrationStatus {
                    Text("Applied: \(status.appliedMigrations)/\(status.totalMigrations)")
                    if status.pendingMigrations > 0 {
                        Text("Pending: \(status.pendingMigrations)")
                    }
                }
                
                Button("Run Migrations") {
                    runMigrations()
                }
                .disabled(isRunning)
                
                if let progress = migrationProgress {
                    ProgressView(
                        value: Double(progress.current),
                        total: Double(progress.total)
                    )
                    Text(progress.migrationName)
                }
            }
        }
        .onAppear {
            loadMigrationStatus()
        }
    }
    
    private func loadMigrationStatus() {
        Task {
            do {
                migrationStatus = try await MigrationRunner.shared.getMigrationStatus()
            } catch {
                print("Failed to load migration status: \(error)")
            }
        }
    }
    
    private func runMigrations() {
        isRunning = true
        Task {
            do {
                let result = try await MigrationRunner.shared.runMigrationsManually()
                if result.success {
                    print("Migrations applied successfully: \(result.appliedCount)")
                } else {
                    print("Migration errors: \(result.errors)")
                }
            } catch {
                print("Migration failed: \(error)")
            }
            isRunning = false
            loadMigrationStatus()
        }
    }
}
```

### Monitor Migration Progress

```swift
import Combine

class MigrationProgressObserver: ObservableObject {
    @Published var progress: MigrationRunner.MigrationProgress?
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        MigrationRunner.shared.migrationProgress
            .receive(on: DispatchQueue.main)
            .assign(to: \.progress, on: self)
            .store(in: &cancellables)
    }
}
```

### Rollback Migration

```swift
// Rollback last migration
try await MigrationRunner.shared.rollbackLastMigration()

// Rollback specific migration version
try await MigrationRunner.shared.rollbackMigration(version: 2)
```

### Test Migrations

```swift
// Test migrations on database copy
let testResult = try await MigrationTester.shared.testMigrationsOnCopy()

// Verify data integrity
let integrityResult = try await MigrationTester.shared.verifyDataIntegrityAfterMigration()

if integrityResult.allPassed {
    print("All integrity checks passed")
} else {
    print("Some checks failed: \(integrityResult.failed)")
}
```

## Creating New Migrations

1. Create a new migration file in `CalendarNotes/Services/Database/Migrations/`
2. Name it following the pattern: `V{next_version}__{descriptive_name}.sql`
3. Write your SQL migration code
4. Create a corresponding rollback file: `V{version}__{name}.down.sql`

Example:

**V4__add_notifications.sql:**
```sql
-- Migration V4: Add Notifications Table
CREATE TABLE IF NOT EXISTS calendarnotes.notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES calendarnotes.users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT,
    type VARCHAR(50),
    read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON calendarnotes.notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON calendarnotes.notifications(read) WHERE read = FALSE;
```

**V4__add_notifications.down.sql:**
```sql
-- Rollback Migration V4: Remove Notifications Table
DROP INDEX IF EXISTS calendarnotes.idx_notifications_read;
DROP INDEX IF EXISTS calendarnotes.idx_notifications_user_id;
DROP TABLE IF EXISTS calendarnotes.notifications;
```

## Best Practices

1. **Always create rollback migrations** - Every forward migration should have a corresponding rollback
2. **Test migrations locally** - Test migrations on a copy of your database before deploying
3. **Use transactions** - MigrationManager automatically wraps migrations in transactions
4. **Backup before migration** - The system attempts to create backups, but ensure you have your own backup strategy
5. **Version control** - Keep all migration files in version control
6. **Document changes** - Add comments to migration files explaining what they do
7. **Incremental changes** - Keep migrations small and focused on a single change
8. **Test data integrity** - Always verify data integrity after applying migrations

## Troubleshooting

### Migration fails to apply
- Check database connection
- Verify migration SQL syntax
- Check for conflicting migrations
- Review migration logs

### Rollback fails
- Ensure rollback file exists
- Check rollback SQL syntax
- Verify no dependent data exists

### Migration not discovered
- Check file naming convention
- Verify file is in `Migrations` folder
- Ensure file is included in app bundle

## Migration Table Schema

The migrations table is automatically created and has the following structure:

```sql
CREATE TABLE calendarnotes.migrations (
    version INTEGER PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    applied_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);
```

This table tracks which migrations have been applied and when.

