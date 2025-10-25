//
//  CloudKitManager.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 22/10/25.
//

import Foundation
import CloudKit
import CoreData
import Network
import Combine

// MARK: - CloudKit Sync Status

enum CloudKitSyncStatus {
    case notConfigured
    case notSignedIn
    case networkUnavailable
    case syncing
    case synced
    case error(String)
    
    var displayName: String {
        switch self {
        case .notConfigured:
            return "Not Configured"
        case .notSignedIn:
            return "Not Signed In"
        case .networkUnavailable:
            return "Network Unavailable"
        case .syncing:
            return "Syncing..."
        case .synced:
            return "Synced"
        case .error(let message):
            return "Error: \(message)"
        }
    }
    
    var isError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
}

// MARK: - CloudKit Sync Statistics

struct CloudKitSyncStats {
    var recordsUploaded: Int = 0
    var recordsDownloaded: Int = 0
    var recordsDeleted: Int = 0
    var conflictsResolved: Int = 0
    var lastSyncDate: Date?
    var errors: [String] = []
    
    var totalChanges: Int {
        recordsUploaded + recordsDownloaded + recordsDeleted
    }
}

// MARK: - CloudKit Manager

@MainActor
class CloudKitManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = CloudKitManager()
    
    // MARK: - Properties
    
    private let container: CKContainer?
    private let coreDataManager = CoreDataManager.shared
    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "NetworkMonitor")
    
    @Published var syncStatus: CloudKitSyncStatus = .notConfigured
    @Published var isSignedIn: Bool = false
    @Published var isNetworkAvailable: Bool = true
    @Published var syncStats = CloudKitSyncStats()
    @Published var isWiFiOnlySync: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    private init() {
        // Disable CloudKit initialization for personal development teams
        // CloudKit requires a paid Apple Developer account
        // Set container to nil - all CloudKit operations will be no-ops
        self.container = nil
        
        print("⚠️ CloudKit is disabled (requires paid Apple Developer account)")
        isSignedIn = false
        syncStatus = .notConfigured
        
        // Still setup network monitoring for future use
        setupNetworkMonitoring()
        
        // Don't check account status or setup remote notifications
        // since CloudKit is not available
    }
    
    // MARK: - Setup
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isNetworkAvailable = path.status == .satisfied
                self?.isWiFiOnlySync = path.usesInterfaceType(.wifi)
                
                if path.status == .satisfied {
                    self?.checkAccountStatus()
                } else {
                    self?.syncStatus = .networkUnavailable
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }
    
    // MARK: - Account Status
    
    func checkAccountStatus() {
        // CloudKit is disabled - return early
        guard let container = container else {
            DispatchQueue.main.async { [weak self] in
                self?.isSignedIn = false
                self?.syncStatus = .notConfigured
            }
            return
        }
        
        container.accountStatus { [weak self] status, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch status {
                case .available:
                    self.isSignedIn = true
                    self.syncStatus = .synced
                case .noAccount:
                    self.isSignedIn = false
                    self.syncStatus = .notSignedIn
                case .restricted:
                    self.isSignedIn = false
                    self.syncStatus = .error("iCloud account is restricted")
                case .couldNotDetermine:
                    self.isSignedIn = false
                    self.syncStatus = .error("Could not determine iCloud status")
                case .temporarilyUnavailable:
                    self.isSignedIn = false
                    self.syncStatus = .error("iCloud temporarily unavailable")
                @unknown default:
                    self.isSignedIn = false
                    self.syncStatus = .error("Unknown iCloud status")
                }
                
                if let error = error {
                    self.syncStatus = .error(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Sync Operations
    
    func performSync() async throws {
        // CloudKit is disabled - return early
        guard container != nil else {
            throw CloudKitError.syncFailed("CloudKit is not available (requires paid Apple Developer account)")
        }
        
        guard isSignedIn else {
            throw CloudKitError.notSignedIn
        }
        
        guard isNetworkAvailable else {
            throw CloudKitError.networkUnavailable
        }
        
        // Check WiFi-only preference
        if UserDefaults.standard.bool(forKey: "iCloudWiFiOnlySync") && !isWiFiOnlySync {
            throw CloudKitError.wiFiRequired
        }
        
        syncStatus = .syncing
        
        do {
            // Perform CloudKit sync through Core Data
            try await syncWithCloudKit()
            
            syncStatus = .synced
            syncStats.lastSyncDate = Date()
            
            // Post sync notification
            NotificationCenter.default.post(name: .cloudKitSyncCompleted, object: nil)
            
        } catch {
            syncStatus = .error(error.localizedDescription)
            syncStats.errors.append(error.localizedDescription)
            throw error
        }
    }
    
    private func syncWithCloudKit() async throws {
        // CloudKit sync is handled automatically by Core Data + CloudKit
        // We just need to trigger a save to push changes
        try coreDataManager.save()
        
        // Wait a moment for sync to process
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
    }
    
    // MARK: - Manual Sync
    
    func triggerManualSync() async {
        do {
            try await performSync()
        } catch {
            print("Manual sync failed: \(error)")
        }
    }
    
    // MARK: - Conflict Resolution
    
    func resolveConflicts() async {
        // Last-write-wins strategy is handled automatically by Core Data + CloudKit
        // This method can be extended for custom conflict resolution if needed
        print("Conflict resolution handled by Core Data + CloudKit")
    }
    
    // MARK: - Settings Management
    
    func enableCloudKitSync() {
        UserDefaults.standard.set(true, forKey: "iCloudSyncEnabled")
        // Note: Core Data container needs to be recreated to apply CloudKit settings
        NotificationCenter.default.post(name: .cloudKitSettingsChanged, object: nil)
    }
    
    func disableCloudKitSync() {
        UserDefaults.standard.set(false, forKey: "iCloudSyncEnabled")
        NotificationCenter.default.post(name: .cloudKitSettingsChanged, object: nil)
    }
    
    func setWiFiOnlySync(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "iCloudWiFiOnlySync")
    }
    
    // MARK: - Sync Status Monitoring
    
    func startSyncMonitoring() {
        // Monitor Core Data remote change notifications
        NotificationCenter.default.addObserver(
            forName: .NSPersistentStoreRemoteChange,
            object: coreDataManager.persistentContainer.persistentStoreCoordinator,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.handleRemoteChange()
            }
        }
    }
    
    @MainActor
    private func handleRemoteChange() {
        // Update sync status when remote changes are detected
        if case .synced = syncStatus {
            syncStatus = .syncing
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                Task { @MainActor in
                    self.syncStatus = .synced
                }
            }
        }
    }
    
    // MARK: - Error Handling
    
    func handleSyncError(_ error: Error) {
        let errorMessage = error.localizedDescription
        syncStatus = .error(errorMessage)
        syncStats.errors.append(errorMessage)
        
        // Post error notification
        NotificationCenter.default.post(
            name: .cloudKitSyncError,
            object: nil,
            userInfo: ["error": errorMessage]
        )
    }
    
    // MARK: - Statistics
    
    func getSyncStatistics() -> CloudKitSyncStats {
        return syncStats
    }
    
    func resetSyncStatistics() {
        syncStats = CloudKitSyncStats()
    }
    
    // MARK: - Network Status
    
    func isWiFiAvailable() -> Bool {
        return isWiFiOnlySync
    }
    
    func canSync() -> Bool {
        // CloudKit is disabled
        guard container != nil else {
            return false
        }
        return isSignedIn && isNetworkAvailable && 
               (!UserDefaults.standard.bool(forKey: "iCloudWiFiOnlySync") || isWiFiOnlySync)
    }
}

// MARK: - CloudKit Errors

enum CloudKitError: Error, LocalizedError {
    case notSignedIn
    case networkUnavailable
    case wiFiRequired
    case syncFailed(String)
    case containerNotFound
    case recordNotFound
    case conflictDetected
    case quotaExceeded
    case serviceUnavailable
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Please sign in to iCloud to enable sync"
        case .networkUnavailable:
            return "Network connection is required for sync"
        case .wiFiRequired:
            return "WiFi connection is required for sync"
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .containerNotFound:
            return "CloudKit container not found"
        case .recordNotFound:
            return "Record not found in CloudKit"
        case .conflictDetected:
            return "Sync conflict detected"
        case .quotaExceeded:
            return "iCloud storage quota exceeded"
        case .serviceUnavailable:
            return "iCloud service unavailable"
        case .unknown:
            return "Unknown iCloud error"
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let cloudKitSyncCompleted = Notification.Name("cloudKitSyncCompleted")
    static let cloudKitSyncError = Notification.Name("cloudKitSyncError")
    static let cloudKitSettingsChanged = Notification.Name("cloudKitSettingsChanged")
}

// MARK: - CloudKit Record Extensions

extension CKRecord {
    /// Get the last modified date for conflict resolution
    var lastModifiedDate: Date {
        return modificationDate ?? creationDate ?? Date()
    }
}

// MARK: - Sync Status Helpers

extension CloudKitManager {
    
    /// Get a user-friendly sync status message
    var statusMessage: String {
        switch syncStatus {
        case .notConfigured:
            return "iCloud sync is not configured"
        case .notSignedIn:
            return "Please sign in to iCloud in System Settings"
        case .networkUnavailable:
            return "Network connection required"
        case .syncing:
            return "Syncing with iCloud..."
        case .synced:
            if let lastSync = syncStats.lastSyncDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .short
                formatter.timeStyle = .short
                return "Last synced: \(formatter.string(from: lastSync))"
            }
            return "Synced with iCloud"
        case .error(let message):
            return "Sync error: \(message)"
        }
    }
    
    /// Check if sync is currently in progress
    var isSyncing: Bool {
        if case .syncing = syncStatus {
            return true
        }
        return false
    }
    
    /// Get sync progress percentage (estimated)
    var syncProgress: Double {
        guard isSyncing else { return 1.0 }
        // This is a simplified progress indicator
        // In a real implementation, you'd track actual progress
        return 0.5
    }
}
