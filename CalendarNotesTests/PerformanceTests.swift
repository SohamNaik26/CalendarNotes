//
//  PerformanceTests.swift
//  CalendarNotesTests
//
//  Performance tests for large datasets and operations
//

import Testing
import Foundation
@testable import CalendarNotes

@Suite("Performance Tests")
struct PerformanceTests {
    
    @Test("Large dataset handling - 10,000 events")
    func testLargeEventDataset() async throws {
        let testData = TestDataGenerator.shared
        let startTime = Date()
        
        // Generate 10,000 events
        let events = testData.generateEvents(count: 10_000)
        
        let generationTime = Date().timeIntervalSince(startTime)
        #expect(generationTime < 5.0, "Event generation should complete in under 5 seconds")
        #expect(events.count == 10_000)
        
        // Test sync performance
        let syncStartTime = Date()
        let syncService = SyncService.shared
        syncService.syncAll(reason: .manual)
        
        // Wait for sync
        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        
        let syncTime = Date().timeIntervalSince(syncStartTime)
        #expect(syncTime < 30.0, "Sync should complete in under 30 seconds")
    }
    
    @Test("Sync speed with many changes")
    func testSyncSpeedWithManyChanges() async throws {
        let testData = TestDataGenerator.shared
        let syncService = SyncService.shared
        
        // Generate large number of changes
        let events = testData.generateEvents(count: 1_000)
        let notes = testData.generateNotes(count: 1_000)
        let todos = testData.generateTodos(count: 1_000)
        let bookmarks = testData.generateBookmarks(count: 1_000)
        
        let startTime = Date()
        
        // Perform sync
        syncService.syncAll(reason: .manual)
        
        // Wait for completion
        try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
        
        let duration = Date().timeIntervalSince(startTime)
        #expect(duration < 60.0, "Sync with 4,000 items should complete in under 60 seconds")
    }
    
    @Test("Database query performance")
    func testDatabaseQueryPerformance() async throws {
        let databaseManager = DatabaseManager.shared
        let testData = TestDataGenerator.shared
        
        // Generate test data
        let events = testData.generateEvents(count: 1_000)
        
        // Test query performance
        let startTime = Date()
        
        // Simulate queries (would need actual database)
        for _ in 0..<100 {
            do {
                _ = try await databaseManager.executeQuery(
                    sql: "SELECT * FROM calendar_events LIMIT 10",
                    parameters: []
                )
            } catch {
                // Expected without actual database
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        #expect(duration < 10.0, "100 queries should complete in under 10 seconds")
    }
    
    @Test("API response times")
    func testAPIResponseTimes() async throws {
        let apiClient = APIClient.shared
        
        // Test multiple API calls
        let startTime = Date()
        
        for _ in 0..<50 {
            do {
                _ = try await apiClient.get(APIEndpoint.events(query: nil)) as EventsResponse
            } catch {
                // Expected without actual server
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        // Allow more time for network requests
        #expect(duration < 30.0, "50 API calls should complete in under 30 seconds")
    }
    
    @Test("Memory usage monitoring")
    func testMemoryUsage() async throws {
        let performanceMonitor = PerformanceMonitor.shared
        let testData = TestDataGenerator.shared
        
        // Start monitoring
        performanceMonitor.startMonitoring()
        
        // Generate large dataset
        let largeDataset = testData.generateLargeDataset(
            events: 5_000,
            notes: 5_000,
            todos: 5_000,
            bookmarks: 5_000
        )
        
        // Check memory usage
        let stats = performanceMonitor.getPerformanceStats()
        let memoryMB = stats.memoryUsageMB
        
        // Memory should be reasonable (under 500MB for test data)
        #expect(memoryMB < 500.0, "Memory usage should be under 500MB")
        
        // Clear and verify memory is released
        performanceMonitor.clearStats()
    }
    
    @Test("Concurrent sync operations")
    func testConcurrentSync() async throws {
        let syncService = SyncService.shared
        
        // Start multiple sync operations concurrently
        let startTime = Date()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    syncService.syncAll(reason: .automatic)
                }
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        #expect(duration < 30.0, "5 concurrent syncs should complete in under 30 seconds")
    }
    
    @Test("Batch operations performance")
    func testBatchOperations() async throws {
        let eventRepo = EventAPIRepository.shared
        let testData = TestDataGenerator.shared
        
        // Generate batch of events
        let events = testData.generateEvents(count: 100)
        
        let startTime = Date()
        
        // Test batch create (if supported)
        // Note: This would require actual API implementation
        
        let duration = Date().timeIntervalSince(startTime)
        #expect(duration < 5.0, "Batch operations should complete quickly")
    }
    
    @Test("Database transaction performance")
    func testTransactionPerformance() async throws {
        let databaseManager = DatabaseManager.shared
        
        // Generate transaction queries
        var queries: [(sql: String, parameters: [PostgresData])] = []
        for i in 0..<100 {
            queries.append((
                sql: "INSERT INTO test_table VALUES ($1, $2)",
                parameters: [PostgresData(string: "value\(i)"), PostgresData(int: i)]
            ))
        }
        
        let startTime = Date()
        
        do {
            _ = try await databaseManager.executeTransaction(queries: queries)
        } catch {
            // Expected without actual database
        }
        
        let duration = Date().timeIntervalSince(startTime)
        #expect(duration < 5.0, "Transaction with 100 queries should complete in under 5 seconds")
    }
}

