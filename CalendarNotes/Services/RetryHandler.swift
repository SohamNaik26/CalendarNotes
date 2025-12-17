//
//  RetryHandler.swift
//  CalendarNotes
//
//  Retry handler with exponential backoff
//

import Foundation

/// Retry handler with exponential backoff for async operations
class RetryHandler {
    /// Retry an async operation with exponential backoff
    /// - Parameters:
    ///   - maxAttempts: Maximum number of retry attempts (default: 3)
    ///   - delay: Initial delay in seconds (default: 1.0)
    ///   - operation: The async operation to retry
    /// - Returns: The result of the operation
    /// - Throws: The last error encountered if all retries fail
    static func retry<T>(
        maxAttempts: Int = 3,
        delay: TimeInterval = 1.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        var currentDelay = delay
        var lastError: Error?
        
        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                // Don't retry on certain unrecoverable errors
                if shouldNotRetry(error) {
                    throw error
                }
                
                if attempt < maxAttempts {
                    try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
                    currentDelay *= 2 // Exponential backoff
                }
            }
        }
        
        throw lastError ?? AppError.unknownError(NSError(domain: "RetryFailed", code: -1, userInfo: [NSLocalizedDescriptionKey: "Retry failed after \(maxAttempts) attempts"]))
    }
    
    /// Check if an error should not be retried
    private static func shouldNotRetry(_ error: Error) -> Bool {
        // Don't retry validation errors, authentication errors (unless specifically retryable)
        if error is ValidationError {
            return true
        }
        
        // Don't retry certain network errors
        if let networkError = error as? NetworkError {
            switch networkError {
            case .invalidResponse:
                return true // Invalid response won't improve with retry
            default:
                return false
            }
        }
        
        // Don't retry certain auth errors
        if let authError = error as? AuthServiceError {
            switch authError {
            case .notAuthenticated, .unauthorized:
                return false // These might be retryable after re-auth
            default:
                return false
            }
        }
        
        return false
    }
}

