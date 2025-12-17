//
//  ErrorTracker.swift
//  CalendarNotes
//
//  Comprehensive error tracking and logging
//

import Foundation
import SwiftUI
import Combine

/// Centralized error tracking service
@MainActor
final class ErrorTracker: ObservableObject {
    static let shared = ErrorTracker()
    
    @Published var errors: [TrackedError] = []
    @Published var isEnabled = true
    
    private var cancellables = Set<AnyCancellable>()
    private let maxErrors = 1000
    
    private init() {
        setupErrorObservers()
    }
    
    // MARK: - Error Tracking
    
    func trackError(
        _ error: Error,
        context: ErrorContext,
        severity: ErrorSeverity = .error
    ) {
        guard isEnabled else { return }
        
        let trackedError = TrackedError(
            id: UUID(),
            timestamp: Date(),
            error: error,
            context: context,
            severity: severity,
            userInfo: extractUserInfo(from: error)
        )
        
        errors.append(trackedError)
        
        // Limit error count
        if errors.count > maxErrors {
            errors.removeFirst(errors.count - maxErrors)
        }
        
        // Log to console
        logError(trackedError)
        
        // Optional: Send to crash reporting service
        #if !DEBUG
        sendToCrashReporting(trackedError)
        #endif
    }
    
    func trackSyncError(_ error: Error, entityType: String, operation: String) {
        trackError(
            error,
            context: .sync(entityType: entityType, operation: operation),
            severity: .error
        )
    }
    
    func trackAPIError(_ error: Error, endpoint: String, method: String) {
        trackError(
            error,
            context: .api(endpoint: endpoint, method: method),
            severity: .error
        )
    }
    
    func trackDatabaseError(_ error: Error, query: String) {
        trackError(
            error,
            context: .database(query: query),
            severity: .error
        )
    }
    
    func trackAuthError(_ error: Error, operation: String) {
        trackError(
            error,
            context: .authentication(operation: operation),
            severity: .warning
        )
    }
    
    // MARK: - Error Reporting
    
    func getUserFriendlyMessage(for error: Error) -> String {
        if let authError = error as? AuthServiceError {
            switch authError {
            case .invalidURL:
                return "Invalid server address. Please check your settings."
            case .serverError(let msg):
                return "Server error: \(msg)"
            case .decodingFailed:
                return "Failed to process server response. Please try again."
            case .unauthorized:
                return "Your session has expired. Please log in again."
            case .notAuthenticated:
                return "Please log in to continue."
            case .notImplemented:
                return "This feature is not yet available."
            }
        }
        
        if let databaseError = error as? DatabaseError {
            switch databaseError {
            case .connectionFailed(let msg):
                return "Unable to connect to database: \(msg)"
            case .networkUnavailable:
                return "No internet connection. Please check your network."
            case .queryExecutionFailed(let msg):
                return "Database error: \(msg)"
            case .transactionFailed(let msg):
                return "Transaction failed: \(msg)"
            case .connectionTimeout:
                return "Connection timed out. Please try again."
            case .invalidParameters(let msg):
                return "Invalid database parameters: \(msg)"
            case .authenticationFailed:
                return "Database authentication failed. Please check your credentials."
            case .databaseNotFound:
                return "Database not found. Please check your configuration."
            case .tableNotFound(let table):
                return "Database table '\(table)' not found."
            case .constraintViolation(let msg):
                return "Database constraint violation: \(msg)"
            case .migrationFailed(let msg):
                return "Database migration failed: \(msg)"
            case .unknown(let underlyingError):
                return "Database error: \(underlyingError.localizedDescription)"
            }
        }
        
        // Generic error message
        return "An error occurred. Please try again."
    }
    
    // MARK: - Error Analysis
    
    func getErrorSummary() -> ErrorSummary {
        let last24Hours = errors.filter { Date().timeIntervalSince($0.timestamp) < 86400 }
        let last7Days = errors.filter { Date().timeIntervalSince($0.timestamp) < 604800 }
        
        let bySeverity = Dictionary(grouping: last24Hours) { $0.severity }
        let byContext = Dictionary(grouping: last24Hours) { $0.context.category }
        
        return ErrorSummary(
            totalErrors: errors.count,
            errorsLast24Hours: last24Hours.count,
            errorsLast7Days: last7Days.count,
            errorsBySeverity: bySeverity.mapValues { $0.count },
            errorsByContext: byContext.mapValues { $0.count },
            mostCommonError: getMostCommonError(in: last24Hours)
        )
    }
    
    private func getMostCommonError(in errors: [TrackedError]) -> String? {
        let errorTypes = Dictionary(grouping: errors) { String(describing: type(of: $0.error)) }
        return errorTypes.max(by: { $0.value.count < $1.value.count })?.key
    }
    
    // MARK: - Private Helpers
    
    private func setupErrorObservers() {
        // Observe sync errors
        NotificationCenter.default.publisher(for: .syncFailed)
            .sink { [weak self] notification in
                if let error = notification.userInfo?["error"] as? Error {
                    self?.trackSyncError(error, entityType: "unknown", operation: "sync")
                }
            }
            .store(in: &cancellables)
    }
    
    private func extractUserInfo(from error: Error) -> [String: Any] {
        var userInfo: [String: Any] = [:]
        
        if let nsError = error as NSError? {
            userInfo = nsError.userInfo
        }
        
        return userInfo
    }
    
    private func logError(_ error: TrackedError) {
        let severityEmoji: String
        switch error.severity {
        case .debug: severityEmoji = "🔍"
        case .info: severityEmoji = "ℹ️"
        case .warning: severityEmoji = "⚠️"
        case .error: severityEmoji = "❌"
        case .critical: severityEmoji = "🚨"
        }
        
        print("\(severityEmoji) [ERROR] [\(error.context.category)] \(error.error.localizedDescription)")
        print("   Context: \(error.context.description)")
        print("   Timestamp: \(error.timestamp)")
    }
    
    private func sendToCrashReporting(_ error: TrackedError) {
        // Integrate with Crashlytics or similar service
        // Example:
        // Crashlytics.crashlytics().record(error: error.error)
    }
    
    func clearErrors() {
        errors.removeAll()
    }
    
    func exportErrors() -> String {
        errors.map { error in
            """
            [\(error.timestamp)] [\(error.severity.rawValue)] \(error.error.localizedDescription)
            Context: \(error.context.description)
            Type: \(type(of: error.error))
            """
        }.joined(separator: "\n\n")
    }
}

// MARK: - Error Models

struct TrackedError: Identifiable {
    let id: UUID
    let timestamp: Date
    let error: Error
    let context: ErrorContext
    let severity: ErrorSeverity
    let userInfo: [String: Any]
}

enum ErrorSeverity: String, CaseIterable {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
    case critical = "CRITICAL"
}

enum ErrorContext {
    case sync(entityType: String, operation: String)
    case api(endpoint: String, method: String)
    case database(query: String)
    case authentication(operation: String)
    case ui(view: String, action: String)
    case general(description: String)
    
    var category: String {
        switch self {
        case .sync: return "Sync"
        case .api: return "API"
        case .database: return "Database"
        case .authentication: return "Authentication"
        case .ui: return "UI"
        case .general: return "General"
        }
    }
    
    var description: String {
        switch self {
        case .sync(let entityType, let operation):
            return "Sync - \(entityType) - \(operation)"
        case .api(let endpoint, let method):
            return "API - \(method) \(endpoint)"
        case .database(let query):
            return "Database - \(query.prefix(50))"
        case .authentication(let operation):
            return "Auth - \(operation)"
        case .ui(let view, let action):
            return "UI - \(view) - \(action)"
        case .general(let description):
            return description
        }
    }
}

struct ErrorSummary {
    let totalErrors: Int
    let errorsLast24Hours: Int
    let errorsLast7Days: Int
    let errorsBySeverity: [ErrorSeverity: Int]
    let errorsByContext: [String: Int]
    let mostCommonError: String?
}

