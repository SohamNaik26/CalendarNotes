//
//  DebugTools.swift
//  CalendarNotes
//
//  Centralized debug tools and utilities
//

import Foundation
import SwiftUI
import Combine

#if DEBUG

/// Centralized debug tools
@MainActor
final class DebugTools: ObservableObject {
    static let shared = DebugTools()
    
    @Published var isDebugModeEnabled = true
    
    private init() {}
    
    // MARK: - Data Management
    
    func clearAllData() {
        // Clear Core Data
        do {
            try CoreDataManager.shared.resetDatabase()
        } catch {
            print("⚠️ [DEBUG] Failed to reset database: \(error.localizedDescription)")
        }
        
        // Clear UserDefaults
        if let bundleID = Bundle.main.bundleIdentifier {
            UserDefaults.standard.removePersistentDomain(forName: bundleID)
        }
        
        // Clear caches
        APIClient.shared.clearCache()
        
        // Clear offline queues
        OfflineQueue.shared.removeAll()
        DatabaseOfflineQueue.shared.clear()
        
        print("🗑️ [DEBUG] All data cleared")
    }
    
    func resetSyncState() {
        // Clear sync timestamps
        let keys = UserDefaults.standard.dictionaryRepresentation().keys.filter { $0.hasPrefix("sync.last.") }
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        // Clear device ID
        UserDefaults.standard.removeObject(forKey: "sync.deviceId")
        
        // Clear offline queue
        OfflineQueue.shared.removeAll()
        
        print("🔄 [DEBUG] Sync state reset")
    }
    
    // MARK: - Logging
    
    func exportAllLogs() -> String {
        var logs: [String] = []
        
        logs.append("=== SYNC LOGS ===")
        logs.append(SyncLogViewer.shared.exportLogs())
        logs.append("")
        
        logs.append("=== NETWORK LOGS ===")
        logs.append(NetworkRequestLogger.shared.exportLogs())
        logs.append("")
        
        logs.append("=== DATABASE LOGS ===")
        logs.append(DatabaseQueryLogger.shared.exportLogs())
        logs.append("")
        
        return logs.joined(separator: "\n")
    }
    
    // MARK: - Performance
    
    func getPerformanceReport() -> String {
        let stats = PerformanceMonitor.shared.getPerformanceStats()
        
        return """
        === PERFORMANCE REPORT ===
        Memory Usage: \(String(format: "%.2f", stats.memoryUsageMB)) MB
        Cache Hit Rate: \(String(format: "%.2f", stats.cacheHitRatePercentage))%
        Average Load Time: \(String(format: "%.2f", stats.averageLoadTimeMS)) ms
        Active Operations: \(stats.activeOperations)
        Total Cache Hits: \(stats.totalCacheHits)
        Total Cache Misses: \(stats.totalCacheMisses)
        """
    }
    
    // MARK: - Testing Helpers
    
    func populateTestData() {
        let generator = TestDataGenerator.shared
        
        // Generate test data (for now just log - actual Core Data persistence would need implementation)
        _ = generator.generateEvents(count: 100)
        _ = generator.generateNotes(count: 100)
        _ = generator.generateTodos(count: 100)
        _ = generator.generateBookmarks(count: 100)
        
        // TODO: Save to Core Data (would need actual implementation)
        print("📝 [DEBUG] Test data generated: 100 events, 100 notes, 100 todos, 100 bookmarks")
        print("⚠️ [DEBUG] Note: Test data is not yet persisted to Core Data")
    }
}

#endif

