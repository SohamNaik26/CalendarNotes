//
//  GracefulDegradation.swift
//  CalendarNotes
//
//  Graceful degradation and offline mode support
//

import Foundation
import Combine

/// Service for managing graceful degradation and offline mode
@MainActor
class GracefulDegradationService: ObservableObject {
    static let shared = GracefulDegradationService()
    
    @Published var isOfflineMode: Bool = false
    @Published var queuedOperations: [QueuedOperation] = []
    @Published var cachedDataAvailable: Bool = false
    
    private let networkMonitor = NetworkMonitor.shared
    private var cancellables = Set<AnyCancellable>()
    private let operationQueue = DispatchQueue(label: "GracefulDegradation.Operations", qos: .utility)
    
    private init() {
        setupNetworkMonitoring()
        loadQueuedOperations()
    }
    
    /// Setup network monitoring to enable/disable offline mode
    private func setupNetworkMonitoring() {
        networkMonitor.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isConnected in
                self?.isOfflineMode = !isConnected
                
                if isConnected {
                    // Process queued operations when back online
                    self?.processQueuedOperations()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Queue an operation for later execution when online
    func queueOperation(_ operation: QueuedOperation) {
        queuedOperations.append(operation)
        saveQueuedOperations()
        
        // Try to process immediately if online
        if networkMonitor.isConnected {
            processQueuedOperations()
        }
    }
    
    /// Process all queued operations
    private func processQueuedOperations() {
        guard networkMonitor.isConnected, !queuedOperations.isEmpty else {
            return
        }
        
        let operations = queuedOperations
        queuedOperations.removeAll()
        
        Task {
            for operation in operations {
                do {
                    try await operation.execute()
                } catch {
                    // Re-queue if still failing (with limit)
                    if operation.attemptCount < 3 {
                        var failedOperation = operation
                        failedOperation.attemptCount += 1
                        await MainActor.run {
                            self.queuedOperations.append(failedOperation)
                        }
                    } else {
                        ErrorLogger.log(error, context: "GracefulDegradation.queueOperation")
                    }
                }
            }
            
            await MainActor.run {
                saveQueuedOperations()
            }
        }
    }
    
    /// Check if cached data is available
    func checkCachedDataAvailable() -> Bool {
        // Implementation depends on your cache system
        // For now, return based on stored flag
        return cachedDataAvailable
    }
    
    /// Show cached data when offline
    func getCachedData<T: Codable>(for key: String, type: T.Type) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else {
            return nil
        }
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            ErrorLogger.log(error, context: "GracefulDegradation.getCachedData")
            return nil
        }
    }
    
    /// Save data to cache
    func saveCachedData<T: Codable>(_ data: T, for key: String) {
        do {
            let encoded = try JSONEncoder().encode(data)
            UserDefaults.standard.set(encoded, forKey: key)
            cachedDataAvailable = true
        } catch {
            ErrorLogger.log(error, context: "GracefulDegradation.saveCachedData")
        }
    }
    
    /// Clear cached data
    func clearCache() {
        // Clear all cached data keys
        let keys = UserDefaults.standard.dictionaryRepresentation().keys.filter { key in
            key.hasPrefix("cached_")
        }
        
        for key in keys {
            UserDefaults.standard.removeObject(forKey: key)
        }
        
        cachedDataAvailable = false
    }
    
    /// Disable features that require network
    func isFeatureEnabled(_ feature: OfflineFeature) -> Bool {
        switch feature {
        case .sync:
            return networkMonitor.isConnected
        case .upload:
            return networkMonitor.isConnected
        case .download:
            return networkMonitor.isConnected
        case .realTimeCollaboration:
            return networkMonitor.isConnected
        case .onlineSearch:
            return networkMonitor.isConnected
        case .readOnly:
            // Read-only features are always enabled
            return true
        }
    }
    
    /// Save queued operations to disk
    private func saveQueuedOperations() {
        // Save to UserDefaults or CoreData for persistence
        if let encoded = try? JSONEncoder().encode(queuedOperations) {
            UserDefaults.standard.set(encoded, forKey: "queued_operations")
        }
    }
    
    /// Load queued operations from disk
    private func loadQueuedOperations() {
        guard let data = UserDefaults.standard.data(forKey: "queued_operations"),
              let decoded = try? JSONDecoder().decode([QueuedOperation].self, from: data) else {
            return
        }
        
        queuedOperations = decoded
    }
    
    /// Clear all queued operations
    func clearQueuedOperations() {
        queuedOperations.removeAll()
        UserDefaults.standard.removeObject(forKey: "queued_operations")
    }
}

/// Queued operation for offline mode
struct QueuedOperation: Codable, Identifiable {
    let id: UUID
    let type: OperationType
    let data: Data
    let timestamp: Date
    var attemptCount: Int
    
    enum OperationType: String, Codable {
        case create
        case update
        case delete
        case sync
    }
    
    /// Execute the queued operation
    func execute() async throws {
        // Decode the operation data and execute
        // This is a simplified version - actual implementation would
        // depend on your specific operation types
        switch type {
        case .create, .update, .delete, .sync:
            // Execute the operation
            // Implementation depends on your service layer
            break
        }
    }
}

/// Offline features
enum OfflineFeature {
    case sync
    case upload
    case download
    case realTimeCollaboration
    case onlineSearch
    case readOnly
}

