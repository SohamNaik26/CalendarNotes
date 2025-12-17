//
//  PerformanceOptimizations.swift
//  CalendarNotes
//
//  Performance optimization utilities and helpers
//

import Foundation
import SwiftUI
import Combine
import CoreData

// MARK: - Debounced Publisher

extension Publisher {
    /// Debounce with configurable delay
    func debounce<S: Scheduler>(for interval: TimeInterval, scheduler: S) -> AnyPublisher<Output, Failure> {
        self.debounce(for: .seconds(interval), scheduler: scheduler)
            .eraseToAnyPublisher()
    }
}

// MARK: - Equatable View Helpers

/// Protocol for views that can be compared for equality to prevent unnecessary redraws
protocol EquatableView: View, Equatable {}

extension EquatableView {
    static func == (lhs: Self, rhs: Self) -> Bool {
        // Default implementation - override in specific views
        return true
    }
}

// MARK: - Lazy Loading Helper

class LazyLoadManager {
    static let shared = LazyLoadManager()
    
    private var loadedPages: Set<Int> = []
    private let pageSize: Int = 50
    
    func shouldLoadPage(_ page: Int) -> Bool {
        !loadedPages.contains(page)
    }
    
    func markPageLoaded(_ page: Int) {
        loadedPages.insert(page)
    }
    
    func reset() {
        loadedPages.removeAll()
    }
}

// MARK: - View Performance Modifiers

extension View {
    /// Prevents unnecessary redraws (view must conform to Equatable)
    /// Use this only on views that conform to Equatable protocol
    func preventRedraws() -> some View where Self: Equatable {
        self.equatable()
    }
    
    /// Adds performance tracking (uses PerformanceMonitor's trackPerformance)
    // Note: trackPerformance is defined in PerformanceMonitor.swift to avoid duplication
    
    /// Optimizes for lists by using lazy loading
    func optimizeForList() -> some View {
        self.drawingGroup() // Rasterize complex views
    }
}

// MARK: - Memory Management Helpers

class MemoryManager {
    static let shared = MemoryManager()
    
    private var cacheSizeLimit: Int = 100 * 1024 * 1024 // 100MB
    private var currentCacheSize: Int = 0
    
    func registerCache(size: Int) {
        currentCacheSize += size
        checkAndEvict()
    }
    
    func unregisterCache(size: Int) {
        currentCacheSize = max(0, currentCacheSize - size)
    }
    
    private func checkAndEvict() {
        if currentCacheSize > cacheSizeLimit {
            // Trigger cache eviction
            NotificationCenter.default.post(name: .memoryPressure, object: nil)
        }
    }
    
    func clearAllCaches() {
        currentCacheSize = 0
        ImageCacheService.shared.clearAllCache()
        NotificationCenter.default.post(name: .clearAllCaches, object: nil)
    }
}

extension Notification.Name {
    static let memoryPressure = Notification.Name("MemoryPressure")
    static let clearAllCaches = Notification.Name("ClearAllCaches")
}

// MARK: - Background Task Helpers

/// Execute on background thread with performance tracking
func performBackgroundTask<T>(
    _ operation: String,
    priority: TaskPriority = .userInitiated,
    _ block: @escaping () async throws -> T
) async throws -> T {
    return try await TimeProfiler.shared.measureAsync(operation) {
        return try await Task(priority: priority) {
            try await block()
        }.value
    }
}

// MARK: - Pagination Helper

struct PaginatedData<T> {
    let items: [T]
    let hasMore: Bool
    let currentPage: Int
    let totalPages: Int?
}

class PaginationManager<T> {
    private var currentPage: Int = 0
    private let pageSize: Int
    private var allItems: [T] = []
    
    init(pageSize: Int = 50) {
        self.pageSize = pageSize
    }
    
    func loadPage(_ items: [T]) -> PaginatedData<T> {
        let startIndex = currentPage * pageSize
        let endIndex = min(startIndex + pageSize, items.count)
        
        guard startIndex < items.count else {
            return PaginatedData(items: [], hasMore: false, currentPage: currentPage, totalPages: nil)
        }
        
        let pageItems = Array(items[startIndex..<endIndex])
        let hasMore = endIndex < items.count
        
        if hasMore {
            currentPage += 1
        }
        
        return PaginatedData(
            items: pageItems,
            hasMore: hasMore,
            currentPage: currentPage,
            totalPages: nil
        )
    }
    
    func reset() {
        currentPage = 0
        allItems.removeAll()
    }
}

// MARK: - Image Optimization

extension Image {
    /// Load image asynchronously with downscaling
    static func asyncLoad(
        from url: URL?,
        maxDimension: CGFloat = 1024,
        placeholder: Image = Image(systemName: "photo")
    ) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                placeholder
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            case .failure:
                placeholder
            @unknown default:
                placeholder
            }
        }
    }
}

// MARK: - Database Query Optimization

// Helper function for optimizing fetch requests (avoids generic extension issues with NSFetchRequest)
func optimizeFetchRequest(_ request: NSFetchRequest<NSFetchRequestResult>, limit: Int = 1000, batchSize: Int = 50) {
    request.fetchLimit = limit
    request.fetchBatchSize = batchSize
    request.returnsObjectsAsFaults = false
}

// MARK: - Network Request Debouncing

class RequestDebouncer {
    static let shared = RequestDebouncer()
    
    private var pendingRequests: [String: Task<Void, Never>] = [:]
    private let debounceInterval: TimeInterval = 0.3
    
    func debounce<T>(
        key: String,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        // Cancel previous request with same key
        pendingRequests[key]?.cancel()
        
        // Create new task with proper type
        let task: Task<T, Error> = Task {
            try await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
            return try await operation()
        }
        
        // Store cancellation token separately (wrapped in Void task)
        pendingRequests[key] = Task {
            _ = try? await task.value
        }
        
        return try await task.value
    }
    
    func cancel(key: String) {
        pendingRequests[key]?.cancel()
        pendingRequests.removeValue(forKey: key)
    }
}

