//
//  DatabaseError.swift
//  CalendarNotes
//
//  Created on [Date]
//

import Foundation

/// Custom error types for database operations
enum DatabaseError: LocalizedError {
    case connectionFailed(String)
    case queryExecutionFailed(String)
    case transactionFailed(String)
    case invalidParameters(String)
    case connectionTimeout
    case networkUnavailable
    case authenticationFailed
    case databaseNotFound
    case tableNotFound(String)
    case constraintViolation(String)
    case migrationFailed(String)
    case unknown(Error)
    
    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return "Database connection failed: \(message)"
        case .queryExecutionFailed(let message):
            return "Query execution failed: \(message)"
        case .transactionFailed(let message):
            return "Transaction failed: \(message)"
        case .invalidParameters(let message):
            return "Invalid parameters: \(message)"
        case .connectionTimeout:
            return "Database connection timeout"
        case .networkUnavailable:
            return "Network is unavailable"
        case .authenticationFailed:
            return "Database authentication failed"
        case .databaseNotFound:
            return "Database not found"
        case .tableNotFound(let table):
            return "Table not found: \(table)"
        case .constraintViolation(let message):
            return "Constraint violation: \(message)"
        case .migrationFailed(let message):
            return "Migration failed: \(message)"
        case .unknown(let error):
            return "Unknown database error: \(error.localizedDescription)"
        }
    }
    
    var failureReason: String? {
        switch self {
        case .connectionFailed:
            return "Unable to establish connection to the database server"
        case .queryExecutionFailed:
            return "The SQL query could not be executed"
        case .transactionFailed:
            return "The database transaction was rolled back"
        case .invalidParameters:
            return "The provided parameters are invalid"
        case .connectionTimeout:
            return "Connection attempt timed out"
        case .networkUnavailable:
            return "No network connection available"
        case .authenticationFailed:
            return "Invalid credentials provided"
        case .databaseNotFound:
            return "The specified database does not exist"
        case .tableNotFound:
            return "The specified table does not exist"
        case .constraintViolation:
            return "A database constraint was violated"
        case .migrationFailed:
            return "Database migration failed"
        case .unknown:
            return "An unexpected error occurred"
        }
    }
}

