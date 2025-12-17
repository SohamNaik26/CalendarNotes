//
//  NetworkRequestLogger.swift
//  CalendarNotes
//
//  Debug tool for logging network requests
//

import Foundation
import SwiftUI
import Combine

#if DEBUG

/// Logger for network requests and responses
@MainActor
final class NetworkRequestLogger: ObservableObject {
    static let shared = NetworkRequestLogger()
    
    @Published var requests: [NetworkRequestLog] = []
    @Published var isEnabled = true
    
    private let maxLogs = 500
    
    private init() {
        // Intercept URLSession requests if needed
    }
    
    func logRequest(
        method: String,
        url: String,
        headers: [String: String]? = nil,
        body: Data? = nil
    ) {
        guard isEnabled else { return }
        
        let log = NetworkRequestLog(
            id: UUID(),
            timestamp: Date(),
            method: method,
            url: url,
            headers: headers,
            requestBody: body,
            responseBody: nil,
            statusCode: nil,
            duration: nil,
            error: nil
        )
        
        requests.append(log)
        
        if requests.count > maxLogs {
            requests.removeFirst(requests.count - maxLogs)
        }
        
        print("🌐 [REQUEST] \(method) \(url)")
    }
    
    func logResponse(
        for url: String,
        statusCode: Int?,
        headers: [String: String]? = nil,
        body: Data? = nil,
        duration: TimeInterval? = nil,
        error: Error? = nil
    ) {
        guard isEnabled else { return }
        
        // Find matching request
        if let index = requests.lastIndex(where: { $0.url == url && $0.statusCode == nil }) {
            requests[index].statusCode = statusCode
            requests[index].responseBody = body
            requests[index].duration = duration
            requests[index].error = error
            
            let statusEmoji = statusCode.map { (200...299).contains($0) ? "✅" : "❌" } ?? "⚠️"
            print("📥 [RESPONSE] \(statusEmoji) \(statusCode ?? 0) \(url) (\(String(format: "%.2f", duration ?? 0))s)")
        }
    }
    
    func clearLogs() {
        requests.removeAll()
    }
    
    func exportLogs() -> String {
        requests.map { log in
            var lines = [
                "[\(log.timestamp)] \(log.method) \(log.url)",
                "Status: \(log.statusCode?.description ?? "N/A")",
                "Duration: \(log.duration.map { String(format: "%.2f", $0) } ?? "N/A")s"
            ]
            
            if let error = log.error {
                lines.append("Error: \(error.localizedDescription)")
            }
            
            return lines.joined(separator: "\n")
        }.joined(separator: "\n\n")
    }
}

struct NetworkRequestLog: Identifiable {
    let id: UUID
    let timestamp: Date
    let method: String
    let url: String
    let headers: [String: String]?
    var requestBody: Data?
    var responseBody: Data?
    var statusCode: Int?
    var duration: TimeInterval?
    var error: Error?
}

#endif

