# Testing Guide

## Overview

This document describes the comprehensive testing suite for CalendarNotes, including unit tests, integration tests, UI tests, and performance tests.

## Test Structure

### Unit Tests

Located in `CalendarNotesTests/`:

- **DatabaseManagerTests.swift**: Tests for database connection, queries, transactions, and offline queue
- **SyncServiceTests.swift**: Tests for sync operations, conflict resolution, and state management
- **AuthServiceTests.swift**: Tests for authentication, registration, login, and token management
- **RepositoryTests.swift**: Tests for API repository CRUD operations
- **APIClientTests.swift**: Tests for API client request/response handling, caching, and retry logic

### Integration Tests

Located in `CalendarNotesTests/IntegrationTests.swift`:

- End-to-end sync flow
- Authentication flow
- CRUD operations flow
- Conflict resolution flow
- Offline to online transition
- Multi-device sync scenario
- Token expiry handling
- Network interruption handling

### UI Tests

Located in `CalendarNotesUITests/`:

- **LoginRegistrationFlowTests.swift**: Login and registration UI flows
- **EntityCRUDTests.swift**: Create, edit, delete operations for events, notes, todos
- **VoiceNoteTests.swift**: Voice note recording, playback, and transcription
- **SyncStatusTests.swift**: Sync status display and manual sync trigger
- **ErrorHandlingTests.swift**: Error message display and recovery

### Performance Tests

Located in `CalendarNotesTests/PerformanceTests.swift`:

- Large dataset handling (10,000+ items)
- Sync speed with many changes
- Database query performance
- API response times
- Memory usage monitoring
- Concurrent sync operations
- Batch operations performance
- Database transaction performance

## Test Data Generation

The `TestDataGenerator` class provides realistic test data:

```swift
let generator = TestDataGenerator.shared

// Generate individual items
let event = generator.generateEvent()
let note = generator.generateNote()
let todo = generator.generateTodo()

// Generate bulk data
let events = generator.generateEvents(count: 1000)
let largeDataset = generator.generateLargeDataset(
    events: 5000,
    notes: 5000,
    todos: 5000,
    bookmarks: 5000
)

// Generate sync scenarios
let scenario = generator.generateSyncScenario(
    localChanges: 10,
    remoteChanges: 10,
    conflicts: 2
)
```

## Debugging Tools

### Sync Log Viewer

View sync operations and their status:

```swift
#if DEBUG
let viewer = SyncLogViewer.shared
viewer.addLog(level: .info, message: "Sync started")
let logs = viewer.logs
let exported = viewer.exportLogs()
#endif
```

### Network Request Logger

Track all network requests and responses:

```swift
#if DEBUG
let logger = NetworkRequestLogger.shared
logger.logRequest(method: "GET", url: "https://api.example.com/events")
logger.logResponse(for: "https://api.example.com/events", statusCode: 200)
let requests = logger.requests
#endif
```

### Database Query Logger

Monitor database query performance:

```swift
#if DEBUG
let logger = DatabaseQueryLogger.shared
logger.logQuery(sql: "SELECT * FROM events", duration: 0.05)
let queries = logger.queries
#endif
```

### Conflict Viewer

View and resolve sync conflicts:

```swift
#if DEBUG
let viewer = ConflictViewer.shared
viewer.addConflict(
    entityType: "Event",
    entityId: UUID(),
    localVersion: [:],
    remoteVersion: [:],
    conflictType: .bothModified
)
#endif
```

### Debug Tools

Centralized debug utilities:

```swift
#if DEBUG
let tools = DebugTools.shared

// Clear all data
tools.clearAllData()

// Reset sync state
tools.resetSyncState()

// Export all logs
let allLogs = tools.exportAllLogs()

// Get performance report
let report = tools.getPerformanceReport()

// Populate test data
tools.populateTestData()
#endif
```

## Performance Monitoring

### Enhanced Metrics

The `PerformanceMonitor` now tracks:

- API latency (average, min, max, median, p95, p99)
- Sync duration statistics
- Database query times
- CPU usage
- Network usage (bytes sent/received)

```swift
let monitor = PerformanceMonitor.shared

// Record API latency
monitor.recordAPILatency(endpoint: "/api/events", latency: 0.5)

// Record sync duration
monitor.recordSyncDuration(2.5)

// Record query time
monitor.recordQueryTime(query: "SELECT * FROM events", duration: 0.1)

// Get detailed report
let report = monitor.getDetailedPerformanceReport()
```

## Error Tracking

### Error Tracker

Comprehensive error tracking with user-friendly messages:

```swift
let tracker = ErrorTracker.shared

// Track errors
tracker.trackError(error, context: .sync(entityType: "Event", operation: "create"))
tracker.trackAPIError(error, endpoint: "/api/events", method: "POST")
tracker.trackDatabaseError(error, query: "SELECT * FROM events")

// Get user-friendly message
let message = tracker.getUserFriendlyMessage(for: error)

// Get error summary
let summary = tracker.getErrorSummary()
```

## Running Tests

### Unit Tests

```bash
# Run all unit tests
xcodebuild test -scheme CalendarNotes -destination 'platform=iOS Simulator,name=iPhone 15'

# Run specific test suite
xcodebuild test -scheme CalendarNotes -only-testing:CalendarNotesTests/DatabaseManagerTests
```

### UI Tests

```bash
# Run all UI tests
xcodebuild test -scheme CalendarNotes -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:CalendarNotesUITests
```

### Performance Tests

```bash
# Run performance tests
xcodebuild test -scheme CalendarNotes -destination 'platform=iOS Simulator,name=iPhone 15' -only-testing:CalendarNotesTests/PerformanceTests
```

## Test Scenarios

### First-time User Setup

1. Launch app
2. Register new account
3. Verify initial sync
4. Create first entities

### Multi-device Sync

1. Create data on device 1
2. Sync device 1
3. Create different data on device 2
4. Sync device 2
5. Verify both devices have all data

### Offline Usage

1. Disable network
2. Create/modify entities
3. Verify offline queue
4. Re-enable network
5. Verify sync completes

### Conflict Resolution

1. Modify same entity on two devices
2. Sync both devices
3. Verify conflict detection
4. Resolve conflict
5. Verify resolution applied

### Network Interruptions

1. Start sync operation
2. Interrupt network mid-sync
3. Verify operation is queued
4. Restore network
5. Verify queue is processed

## Best Practices

1. **Isolation**: Each test should be independent and not rely on other tests
2. **Cleanup**: Always clean up test data after tests complete
3. **Mocking**: Use mocks for external dependencies (network, database)
4. **Performance**: Keep performance tests realistic but fast
5. **Coverage**: Aim for high code coverage, especially for critical paths
6. **Documentation**: Document complex test scenarios

## Continuous Integration

Tests should be run automatically on:

- Every pull request
- Before merging to main
- Nightly builds
- Before releases

## Troubleshooting

### Tests Failing Intermittently

- Check for race conditions
- Verify proper async/await usage
- Ensure test isolation

### Performance Tests Too Slow

- Reduce dataset sizes for CI
- Use faster test devices
- Optimize test data generation

### UI Tests Unreliable

- Add proper waits for async operations
- Use accessibility identifiers
- Verify element existence before interaction

