//
//  SyncManager.swift
//  CalendarNotes
//
//  Created by Cursor AI on 08/11/25.
//

import Foundation
import Combine
import CoreData
import Network

@MainActor
final class SyncManager: ObservableObject {
    static let shared = SyncManager()
    
    @Published private(set) var state: SyncState = .idle
    @Published private(set) var connectionQuality: ConnectionQuality = .excellent
    @Published private(set) var statistics = SyncSummary()
    @Published private(set) var pendingChanges: Int = 0
    @Published private(set) var isOffline: Bool = false
    
    private let offlineQueue = OfflineQueue.shared
    private let connectivityMonitor = ConnectivityMonitor.shared
    private let policyStore = SyncPolicyStore.shared
    private var cancellables = Set<AnyCancellable>()
    
    private let backgroundQueue = DispatchQueue(label: "SyncManagerQueue", qos: .utility)
    
    private init() {
        pendingChanges = offlineQueue.load().count
        setupBindings()
    }
    
    private func setupBindings() {
        connectivityMonitor
            .publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] path in
                guard let self else { return }
                self.connectionQuality = path.connectionQuality
                let isConnected = path.status == .satisfied
                self.isOffline = !isConnected
                if isConnected, self.state == .offline {
                    self.state = .idle
                }
                if isConnected && self.pendingChanges > 0 {
                    self.autoSyncIfPermitted()
                }
            }
            .store(in: &cancellables)
    }
    
    func enqueueBookmarkOperation(_ operation: OfflineOperation) {
        offlineQueue.append(operation)
        pendingChanges += 1
        if !isOffline {
            autoSyncIfPermitted()
        }
    }
    
    func triggerManualSync() {
        guard !isOffline else {
            state = .offline
            return
        }
        if policyStore.policy.wifiOnly && connectionQuality != .excellent {
            state = .failed(error: "Wi-Fi connection required for sync.")
            return
        }
        runSync(reason: "Manual")
    }
    
    func autoSyncIfPermitted() {
        guard !isOffline else { return }
        let policy = policyStore.policy
        if policy.wifiOnly && connectionQuality != .excellent {
            state = .failed(error: "Waiting for Wi-Fi to sync changes.")
            return
        }
        runSync(reason: "Auto")
    }
    
    func markBulkProgress(_ progress: Double) {
        state = .syncing(progress: progress)
    }
    
    func recordConflict() {
        statistics.totalConflicts += 1
        state = .failed(error: "Sync conflict detected. Review changes.")
    }
    
    func resetStatistics() {
        statistics = SyncSummary()
    }
    
    private func runSync(reason: String) {
        state = .syncing(progress: 0)
        statistics.lastAttempt = Date()
        let operations = offlineQueue.load()
        pendingChanges = operations.count
        
        backgroundQueue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            var processed = 0
            for _ in operations {
                processed += 1
                let fraction = Double(processed) / Double(max(1, operations.count))
                Task { @MainActor in
                    self.state = .syncing(progress: fraction)
                }
                usleep(100_000) // Simulated network delay
            }
            Task { @MainActor in
                self.offlineQueue.removeAll()
                self.pendingChanges = 0
                self.statistics.totalObjectsSynced += operations.count
                self.statistics.lastSuccessfulSync = Date()
                self.state = .succeeded
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    if self.state == .succeeded {
                        self.state = .idle
                    }
                }
            }
        }
    }
}


