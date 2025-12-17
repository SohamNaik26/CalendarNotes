//
//  DatabaseQueryLogger.swift
//  CalendarNotes
//
//  Debug tool for logging database queries
//

import Foundation
import SwiftUI
import Combine

#if DEBUG

/// Logger for database queries
@MainActor
final class DatabaseQueryLogger: ObservableObject {
    static let shared = DatabaseQueryLogger()
    
    @Published var queries: [DatabaseQueryLog] = []
    @Published var isEnabled = true
    
    private let maxLogs = 500
    
    private init() {}
    
    func logQuery(
        sql: String,
        parameters: [String: Any]? = nil,
        duration: TimeInterval? = nil,
        error: Error? = nil,
        rowsAffected: Int? = nil
    ) {
        guard isEnabled else { return }
        
        let log = DatabaseQueryLog(
            id: UUID(),
            timestamp: Date(),
            sql: sql,
            parameters: parameters,
            duration: duration,
            error: error,
            rowsAffected: rowsAffected
        )
        
        queries.append(log)
        
        if queries.count > maxLogs {
            queries.removeFirst(queries.count - maxLogs)
        }
        
        let durationStr = duration.map { String(format: "%.3f", $0) } ?? "N/A"
        let status = error == nil ? "✅" : "❌"
        print("🗄️ [DB QUERY] \(status) (\(durationStr)s) \(sql)")
    }
    
    func clearLogs() {
        queries.removeAll()
    }
    
    func exportLogs() -> String {
        queries.map { log in
            var lines = [
                "[\(log.timestamp)] \(log.sql)",
                "Duration: \(log.duration.map { String(format: "%.3f", $0) } ?? "N/A")s"
            ]
            
            if let parameters = log.parameters {
                lines.append("Parameters: \(parameters)")
            }
            
            if let error = log.error {
                lines.append("Error: \(error.localizedDescription)")
            }
            
            if let rows = log.rowsAffected {
                lines.append("Rows affected: \(rows)")
            }
            
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }
}

struct DatabaseQueryLog: Identifiable {
    let id: UUID
    let timestamp: Date
    let sql: String
    let parameters: [String: Any]?
    let duration: TimeInterval?
    let error: Error?
    let rowsAffected: Int?
}

#endif

