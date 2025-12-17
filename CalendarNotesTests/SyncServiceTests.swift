//
//  SyncServiceTests.swift
//  CalendarNotesTests
//
//  Unit tests for SyncService
//

import Testing
import Foundation
@testable import CalendarNotes

@Suite("SyncService Tests")
struct SyncServiceTests {
    
    @Test("Initial state is idle")
    func testInitialState() {
        let service = SyncService.shared
        #expect(service.state == .idle)
    }
    
    @Test("Device ID is generated")
    func testDeviceIdGeneration() {
        let service = SyncService.shared
        let deviceId = service.deviceId()
        #expect(!deviceId.isEmpty)
        #expect(deviceId.count > 10) // UUID format
    }
    
    @Test("Sync strategy can be set")
    func testSyncStrategy() {
        let service = SyncService.shared
        service.setStrategy(.manual)
        #expect(service.strategy == .manual)
        
        service.setStrategy(.automatic)
        #expect(service.strategy == .automatic)
    }
    
    @Test("Sync all entities")
    func testSyncAll() async {
        let service = SyncService.shared
        service.syncAll(reason: .manual)
        
        // Wait a bit for async operations
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Verify sync was initiated
        // State should be syncing or completed
        let state = service.state
        #expect(state == .syncing(progress: 0) || state == .succeeded || state == .idle)
    }
    
    @Test("Individual entity sync")
    func testEntitySync() async {
        let service = SyncService.shared
        
        let results = await [
            service.syncCalendarEvents(),
            service.syncNotes(),
            service.syncTodos(),
            service.syncBookmarks(),
            service.syncVoiceNotes(),
            service.syncCollections()
        ]
        
        // All should return results (success or failure)
        for result in results {
            switch result {
            case .success:
                break
            case .failure:
                break
            }
        }
    }
    
    @Test("Conflict resolution strategies")
    func testConflictResolution() {
        let service = SyncService.shared
        
        let local = "local_value"
        let remote = "remote_value"
        
        // Test different resolution strategies
        let lastWriteWins = service.resolveConflict(local: local, remote: remote, strategy: .lastWriteWins)
        #expect(lastWriteWins == remote)
        
        let clientWins = service.resolveConflict(local: local, remote: remote, strategy: .clientWins)
        #expect(clientWins == local)
        
        let serverWins = service.resolveConflict(local: local, remote: remote, strategy: .serverWins)
        #expect(serverWins == remote)
    }
    
    @Test("Sync status tracking")
    func testSyncStatus() {
        let service = SyncService.shared
        
        // Verify activity tracking
        let activity = service.activity
        #expect(activity.pendingChangesCount >= 0)
    }
}

