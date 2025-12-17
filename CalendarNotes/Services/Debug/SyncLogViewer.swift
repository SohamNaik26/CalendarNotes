//
//  SyncLogViewer.swift
//  CalendarNotes
//
//  Debug tool for viewing sync logs
//

import Foundation
import SwiftUI
import Combine

#if DEBUG

/// Debug viewer for sync logs
@MainActor
final class SyncLogViewer: ObservableObject {
    static let shared = SyncLogViewer()
    
    @Published var logs: [SyncLogEntry] = []
    @Published var isEnabled = true
    
    private var cancellables = Set<AnyCancellable>()
    private let maxLogs = 1000
    
    private init() {
        // Subscribe to sync events
        NotificationCenter.default.publisher(for: .syncStarted)
            .sink { [weak self] _ in
                self?.addLog(level: .info, message: "Sync started")
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .syncCompleted)
            .sink { [weak self] _ in
                self?.addLog(level: .info, message: "Sync completed")
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .syncFailed)
            .sink { [weak self] notification in
                if let error = notification.userInfo?["error"] as? Error {
                    self?.addLog(level: .error, message: "Sync failed: \(error.localizedDescription)")
                }
            }
            .store(in: &cancellables)
    }
    
    func addLog(level: LogLevel, message: String, metadata: [String: Any]? = nil) {
        guard isEnabled else { return }
        
        let entry = SyncLogEntry(
            timestamp: Date(),
            level: level,
            message: message,
            metadata: metadata
        )
        
        logs.append(entry)
        
        // Limit log size
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
        
        // Print to console
        print("[SYNC LOG] [\(level.rawValue)] \(message)")
    }
    
    func clearLogs() {
        logs.removeAll()
    }
    
    func exportLogs() -> String {
        logs.map { entry in
            let metadataStr: String
            if let metadata = entry.metadata {
                metadataStr = metadata.map { key, value in
                    "\(key): \(value)"
                }.joined(separator: ", ")
            } else {
                metadataStr = ""
            }
            return "[\(entry.timestamp)] [\(entry.level.rawValue)] \(entry.message)\(metadataStr.isEmpty ? "" : " | \(metadataStr)")"
        }.joined(separator: "\n")
    }
}

struct SyncLogEntry: Identifiable {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let message: String
    let metadata: [String: Any]?
}

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARNING"
    case error = "ERROR"
}

extension Notification.Name {
    static let syncStarted = Notification.Name("syncStarted")
    static let syncCompleted = Notification.Name("syncCompleted")
    static let syncFailed = Notification.Name("syncFailed")
}

#endif

