//
//  ErrorLogger.swift
//  CalendarNotes
//
//  Centralized error logging
//

import Foundation

/// Centralized error logging service
class ErrorLogger {
    static func log(_ error: Error, context: String) {
        print("❌ ERROR in \(context): \(error.localizedDescription)")
        
        // Extract additional error information
        if let nsError = error as NSError? {
            print("   Domain: \(nsError.domain)")
            print("   Code: \(nsError.code)")
            if !nsError.userInfo.isEmpty {
                print("   UserInfo: \(nsError.userInfo)")
            }
        }
        
        // Log to ErrorTracker
        Task { @MainActor in
            ErrorTracker.shared.trackError(
                error,
                context: .general(description: context),
                severity: .error
            )
        }
        
        // In production, send to analytics
        #if !DEBUG
        // Analytics.logError(error, context: context)
        #endif
    }
    
    /// Log a user-friendly error message
    static func logUserFriendly(_ message: String, context: String) {
        print("⚠️ USER-FACING ERROR in \(context): \(message)")
        
        let error = NSError(
            domain: "UserFacingError",
            code: -1,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        
        Task { @MainActor in
            ErrorTracker.shared.trackError(
                error,
                context: .general(description: context),
                severity: .warning
            )
        }
    }
    
    /// Log with severity level
    static func log(_ error: Error, context: String, severity: ErrorSeverity) {
        let emoji: String
        switch severity {
        case .debug: emoji = "🔍"
        case .info: emoji = "ℹ️"
        case .warning: emoji = "⚠️"
        case .error: emoji = "❌"
        case .critical: emoji = "🚨"
        }
        
        print("\(emoji) [\(severity.rawValue)] ERROR in \(context): \(error.localizedDescription)")
        
        Task { @MainActor in
            ErrorTracker.shared.trackError(
                error,
                context: .general(description: context),
                severity: severity
            )
        }
    }
}

