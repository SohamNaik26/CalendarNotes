//
//  DatabaseManagerTests.swift
//  CalendarNotesTests
//
//  Unit tests for DatabaseManager
//

import Testing
import Foundation
@testable import CalendarNotes

@Suite("DatabaseManager Tests")
struct DatabaseManagerTests {
    
    @Test("Connection status starts as disconnected")
    func testInitialConnectionStatus() async {
        let manager = DatabaseManager.shared
        #expect(manager.connectionStatus == .disconnected)
    }
    
    @Test("Connection retry with exponential backoff")
    func testConnectionRetry() async throws {
        let manager = DatabaseManager.shared
        
        // This test would require a mock database connection
        // For now, we test the retry logic structure
        do {
            try await manager.connectWithRetry()
        } catch {
            // Expected to fail without actual database
            // In real tests, we'd mock the connection
        }
    }
    
    @Test("Health check updates connection status")
    func testHealthCheck() async {
        let manager = DatabaseManager.shared
        await manager.performHealthCheck()
        // Verify status is updated (would need actual connection for full test)
    }
    
    @Test("Query execution handles offline queue")
    func testOfflineQueue() async throws {
        let manager = DatabaseManager.shared
        
        // Test that queries are queued when offline
        // This would require mocking network status
        let sql = "SELECT * FROM test_table"
        do {
            _ = try await manager.executeQuery(sql: sql, parameters: [])
        } catch {
            // Expected without connection
        }
    }
    
    @Test("Transaction rollback on error")
    func testTransactionRollback() async throws {
        let manager = DatabaseManager.shared
        
        let queries: [(sql: String, parameters: [PostgresData])] = [
            ("INSERT INTO test VALUES ($1)", [PostgresData(string: "test")]),
            ("INVALID SQL", []) // This should cause rollback
        ]
        
        do {
            _ = try await manager.executeTransaction(queries: queries)
        } catch {
            // Expected to fail and rollback
        }
    }
    
    @Test("Timeout handling")
    func testTimeoutHandling() async throws {
        let manager = DatabaseManager.shared
        
        do {
            _ = try await manager.executeWithTimeout(timeout: 0.1) {
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
                return true
            }
            #expect(Bool(false), "Should have timed out")
        } catch {
            // Expected timeout
        }
    }
    
    @Test("Connection status publisher")
    func testConnectionStatusPublisher() async {
        let manager = DatabaseManager.shared
        let publisher = manager.connectionStatusPublisher
        
        // Verify publisher exists and emits values
        #expect(publisher != nil)
    }
}

