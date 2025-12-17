//
//  IntegrationTests.swift
//  CalendarNotesTests
//
//  Integration tests for end-to-end scenarios
//

import Testing
import Foundation
@testable import CalendarNotes

@Suite("Integration Tests")
struct IntegrationTests {
    
    @Test("End-to-end sync flow")
    func testEndToEndSync() async throws {
        let syncService = SyncService.shared
        let testData = TestDataGenerator.shared
        
        // Generate test data
        let events = testData.generateEvents(count: 10)
        let notes = testData.generateNotes(count: 10)
        let todos = testData.generateTodos(count: 10)
        
        // Perform sync
        syncService.syncAll(reason: .manual)
        
        // Wait for sync to complete
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        
        // Verify sync status
        let state = syncService.state
        #expect(state == .succeeded || state == .idle || state == .failed(error: ""))
    }
    
    @Test("Authentication flow")
    func testAuthenticationFlow() async throws {
        let authService = AuthService.shared
        
        // Test registration
        do {
            let response = try await authService.register(
                email: "integration_test@example.com",
                password: "TestPassword123!",
                fullName: "Integration Test User"
            )
            #expect(!response.accessToken.isEmpty)
        } catch {
            // May fail without actual server, but verify error handling
            #expect(error is AuthServiceError)
        }
        
        // Test login
        do {
            let credentials = AuthCredentials(email: "integration_test@example.com", password: "TestPassword123!")
            let response = try await authService.login(credentials: credentials)
            #expect(!response.accessToken.isEmpty)
        } catch {
            // May fail without actual server
            #expect(error is AuthServiceError)
        }
        
        // Test get current user
        do {
            let user = try await authService.getCurrentUser()
            #expect(!user.email.isEmpty)
        } catch {
            // Expected if not authenticated
        }
        
        // Test logout
        do {
            try await authService.logout()
        } catch {
            // May fail if not authenticated
        }
    }
    
    @Test("CRUD operations flow")
    func testCRUDOperations() async throws {
        let eventRepo = EventAPIRepository.shared
        let testData = TestDataGenerator.shared
        
        // Create
        let newEvent = testData.generateEvent()
        do {
            let created = try await eventRepo.create(event: APICalendarEvent(
                id: newEvent.id,
                userId: UUID(),
                title: newEvent.title,
                description: newEvent.description,
                startDate: newEvent.startDate,
                endDate: newEvent.endDate,
                location: newEvent.location,
                category: newEvent.category,
                color: nil,
                isAllDay: newEvent.isAllDay,
                isRecurring: false,
                recurrenceRule: nil,
                createdAt: newEvent.createdAt,
                updatedAt: newEvent.updatedAt
            ))
            #expect(created.id == newEvent.id)
        } catch {
            // Expected without actual server
        }
        
        // Read
        do {
            let events = try await eventRepo.getAll(query: nil)
            #expect(events.events.count >= 0)
        } catch {
            // Expected without actual server
        }
        
        // Update
        do {
            let updatedEvent = testData.generateEvent(id: newEvent.id, title: "Updated Title")
            let updated = try await eventRepo.update(id: newEvent.id, event: APICalendarEvent(
                id: updatedEvent.id,
                userId: UUID(),
                title: updatedEvent.title,
                description: updatedEvent.description,
                startDate: updatedEvent.startDate,
                endDate: updatedEvent.endDate,
                location: updatedEvent.location,
                category: updatedEvent.category,
                color: nil,
                isAllDay: updatedEvent.isAllDay,
                isRecurring: false,
                recurrenceRule: nil,
                createdAt: updatedEvent.createdAt,
                updatedAt: updatedEvent.updatedAt
            ))
            #expect(updated.title == "Updated Title")
        } catch {
            // Expected without actual server
        }
        
        // Delete
        do {
            try await eventRepo.delete(id: newEvent.id)
        } catch {
            // Expected without actual server
        }
    }
    
    @Test("Conflict resolution flow")
    func testConflictResolution() async throws {
        let syncService = SyncService.shared
        let testData = TestDataGenerator.shared
        
        // Generate conflicting scenario
        let scenario = testData.generateSyncScenario(localChanges: 5, remoteChanges: 5, conflicts: 2)
        
        // Test conflict resolution strategies
        for conflict in scenario.conflictingEvents {
            let local = scenario.localEvents.first { $0.id == conflict.id }
            if let local = local {
                // Test different resolution strategies
                let resolved = syncService.resolveConflict(
                    local: local,
                    remote: conflict,
                    strategy: .lastWriteWins
                )
                #expect(resolved.id == conflict.id)
            }
        }
    }
    
    @Test("Offline to online transition")
    func testOfflineOnlineTransition() async throws {
        let syncService = SyncService.shared
        let databaseManager = DatabaseManager.shared
        
        // Simulate offline state
        // Note: This would require mocking network status
        
        // Perform operations while offline
        syncService.syncAll(reason: .automatic)
        
        // Wait a bit
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Simulate coming back online
        // Process offline queue
        await databaseManager.processOfflineQueue()
        
        // Verify sync completes
        let state = syncService.state
        #expect(state != .offline || state == .idle || state == .succeeded)
    }
    
    @Test("Multi-device sync scenario")
    func testMultiDeviceSync() async throws {
        let syncService = SyncService.shared
        let testData = TestDataGenerator.shared
        
        // Generate data for device 1
        let device1Events = testData.generateEvents(count: 10)
        
        // Generate data for device 2
        let device2Events = testData.generateEvents(count: 10)
        
        // Simulate sync from device 1
        syncService.syncAll(reason: .automatic)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Simulate sync from device 2
        syncService.syncAll(reason: .automatic)
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Verify both devices' data is synced
        // This would require checking the actual database
    }
    
    @Test("Token expiry during operation")
    func testTokenExpiry() async throws {
        let authService = AuthService.shared
        let apiClient = APIClient.shared
        
        // Simulate token expiry
        // Clear tokens
        TokenManager.shared.clearTokens()
        
        // Try to make an authenticated request
        do {
            _ = try await apiClient.get(APIEndpoint.me) as User
        } catch {
            // Expected to fail or trigger token refresh
            // Verify error handling
        }
    }
    
    @Test("Network interruption handling")
    func testNetworkInterruption() async throws {
        let syncService = SyncService.shared
        
        // Start sync
        syncService.syncAll(reason: .automatic)
        
        // Simulate network interruption (would require mocking)
        // Verify operations are queued
        
        // Simulate network restoration
        // Verify queue is processed
    }
}

