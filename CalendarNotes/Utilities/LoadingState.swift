//
//  LoadingState.swift
//  CalendarNotes
//
//  Created for loading state implementation
//

import Foundation

// MARK: - Loading State Enum

enum LoadingState<T> {
    case idle
    case loading
    case loaded(T)
    case error(Error)
    
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    var value: T? {
        if case .loaded(let value) = self {
            return value
        }
        return nil
    }
    
    var error: Error? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }
}

// MARK: - Cached Loading State

struct CachedLoadingState<T> {
    var state: LoadingState<T>
    var cachedValue: T?
    var lastUpdated: Date?
    var isOutdated: Bool {
        guard let lastUpdated = lastUpdated else { return false }
        return Date().timeIntervalSince(lastUpdated) > 300 // 5 minutes
    }
    
    init(state: LoadingState<T> = .idle, cachedValue: T? = nil, lastUpdated: Date? = nil) {
        self.state = state
        self.cachedValue = cachedValue
        self.lastUpdated = lastUpdated
    }
    
    mutating func updateState(_ newState: LoadingState<T>) {
        state = newState
        if case .loaded(let value) = newState {
            cachedValue = value
            lastUpdated = Date()
        }
    }
}

// MARK: - Timeout Error

struct TimeoutError: LocalizedError {
    let timeout: TimeInterval
    let message: String
    
    var errorDescription: String? {
        "Request timed out after \(Int(timeout)) seconds. \(message)"
    }
}

// MARK: - Network Timeout Handler

actor NetworkTimeoutHandler {
    static let shared = NetworkTimeoutHandler()
    private let defaultTimeout: TimeInterval = 10.0
    
    private init() {}
    
    func withTimeout<T>(
        timeout: TimeInterval? = nil,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        let timeoutDuration = timeout ?? defaultTimeout
        
        return try await withThrowingTaskGroup(of: T.self) { group in
            // Add the actual operation
            group.addTask {
                try await operation()
            }
            
            // Add timeout task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutDuration * 1_000_000_000))
                throw TimeoutError(timeout: timeoutDuration, message: "Network request timed out")
            }
            
            // Return the first completed task and cancel the other
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

