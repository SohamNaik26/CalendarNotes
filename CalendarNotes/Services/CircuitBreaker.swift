//
//  CircuitBreaker.swift
//  CalendarNotes
//
//  Circuit breaker pattern implementation for fault tolerance
//

import Foundation
import Combine

/// Circuit breaker state
enum CircuitState {
    case closed    // Normal operation
    case open      // Circuit is open, requests are blocked
    case halfOpen  // Testing if service is back online
}

/// Circuit breaker for managing service availability
@MainActor
class CircuitBreaker: ObservableObject {
    static let shared = CircuitBreaker()
    
    @Published private(set) var state: CircuitState = .closed
    @Published private(set) var failureCount: Int = 0
    @Published private(set) var lastFailureTime: Date?
    @Published private(set) var lastSuccessTime: Date?
    
    private let failureThreshold: Int
    private let resetTimeout: TimeInterval
    private let cooldownPeriod: TimeInterval = 300 // 5 minutes
    
    private var resetTimer: Timer?
    private let serviceName: String
    
    init(
        serviceName: String = "Default",
        failureThreshold: Int = 3,
        resetTimeout: TimeInterval = 60
    ) {
        self.serviceName = serviceName
        self.failureThreshold = failureThreshold
        self.resetTimeout = resetTimeout
    }
    
    /// Record a successful operation
    func recordSuccess() {
        lastSuccessTime = Date()
        failureCount = 0
        
        if state == .halfOpen {
            state = .closed
            resetTimer?.invalidate()
            resetTimer = nil
        }
    }
    
    /// Record a failed operation
    func recordFailure() {
        failureCount += 1
        lastFailureTime = Date()
        
        if failureCount >= failureThreshold && state == .closed {
            openCircuit()
        } else if state == .halfOpen {
            openCircuit()
        }
    }
    
    /// Check if the circuit allows the operation
    func canAttempt() -> Bool {
        switch state {
        case .closed:
            return true
        case .open:
            // Check if cooldown period has passed
            if let lastFailure = lastFailureTime,
               Date().timeIntervalSince(lastFailure) >= cooldownPeriod {
                state = .halfOpen
                return true
            }
            return false
        case .halfOpen:
            return true
        }
    }
    
    /// Get the status message for UI
    func getStatusMessage() -> String {
        switch state {
        case .closed:
            return "Service is available"
        case .open:
            if let lastFailure = lastFailureTime {
                let timeRemaining = cooldownPeriod - Date().timeIntervalSince(lastFailure)
                if timeRemaining > 0 {
                    let minutes = Int(timeRemaining) / 60
                    let seconds = Int(timeRemaining) % 60
                    return "Service temporarily unavailable. Retry in \(minutes)m \(seconds)s"
                }
            }
            return "Service temporarily unavailable"
        case .halfOpen:
            return "Testing service availability..."
        }
    }
    
    /// Get time until next retry attempt is allowed
    func getTimeUntilRetry() -> TimeInterval? {
        guard state == .open, let lastFailure = lastFailureTime else {
            return nil
        }
        
        let elapsed = Date().timeIntervalSince(lastFailure)
        let remaining = cooldownPeriod - elapsed
        return remaining > 0 ? remaining : nil
    }
    
    /// Manually reset the circuit breaker
    func reset() {
        state = .closed
        failureCount = 0
        lastFailureTime = nil
        resetTimer?.invalidate()
        resetTimer = nil
    }
    
    /// Open the circuit
    private func openCircuit() {
        state = .open
        resetTimer?.invalidate()
        
        // Schedule automatic retry after cooldown period
        resetTimer = Timer.scheduledTimer(withTimeInterval: cooldownPeriod, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.state = .halfOpen
            }
        }
        
        // Log circuit opening
        ErrorLogger.log(
            NSError(
                domain: "CircuitBreaker",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Circuit opened for \(serviceName) after \(failureCount) failures"]
            ),
            context: "CircuitBreaker.\(serviceName)",
            severity: .warning
        )
    }
    
    deinit {
        resetTimer?.invalidate()
    }
}

/// Circuit breaker wrapper for async operations
extension CircuitBreaker {
    /// Execute an operation with circuit breaker protection
    func execute<T>(_ operation: @escaping () async throws -> T) async throws -> T {
        guard canAttempt() else {
            throw CircuitBreakerError.serviceUnavailable(message: getStatusMessage())
        }
        
        do {
            let result = try await operation()
            recordSuccess()
            return result
        } catch {
            recordFailure()
            throw error
        }
    }
}

/// Circuit breaker specific errors
enum CircuitBreakerError: LocalizedError {
    case serviceUnavailable(message: String)
    
    var errorDescription: String? {
        switch self {
        case .serviceUnavailable(let message):
            return message
        }
    }
}

