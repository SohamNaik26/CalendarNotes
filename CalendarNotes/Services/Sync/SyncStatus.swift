//
//  SyncStatus.swift
//  CalendarNotes
//
//  Created by Cursor AI on 08/11/25.
//

import Foundation
import SwiftUI

enum SyncState: Equatable {
    case idle
    case offline
    case syncing(progress: Double)
    case succeeded
    case failed(error: String)
}

enum ConnectionQuality: String, Equatable {
    case offline
    case poor
    case fair
    case good
    case excellent
    
    var symbolName: String {
        switch self {
        case .offline: return "wifi.slash"
        case .poor: return "wifi.exclamationmark"
        case .fair: return "wifi"
        case .good: return "wifi"
        case .excellent: return "wifi.circle"
        }
    }
}

struct SyncSummary: Equatable {
    var lastSuccessfulSync: Date?
    var lastAttempt: Date?
    var totalObjectsSynced: Int = 0
    var totalConflicts: Int = 0
}

/// High-level activity status of sync to drive UI indicators.
struct SyncStatus: Equatable {
	var isPending: Bool = false
	var isInProgress: Bool = false
	var lastSyncDate: Date?
	var lastSyncErrorMessage: String?
	var pendingChangesCount: Int = 0
}

struct OfflineOperation: Codable, Identifiable, Equatable {
    enum OperationType: String, Codable {
        case create
        case update
        case delete
    }
    
    let id: UUID
    let entityName: String
    let objectIdentifier: String
    let payload: Data?
    let type: OperationType
    let createdAt: Date
    var retries: Int
    
    init(entityName: String,
         objectIdentifier: String,
         payload: Data?,
         type: OperationType,
         createdAt: Date = Date(),
         retries: Int = 0) {
        self.id = UUID()
        self.entityName = entityName
        self.objectIdentifier = objectIdentifier
        self.payload = payload
        self.type = type
        self.createdAt = createdAt
        self.retries = retries
    }
}

extension ConnectionQuality {
    var tintColor: Color {
        switch self {
        case .offline: return .cnStatusError
        case .poor: return .cnStatusWarning
        case .fair: return .cnAccent
        case .good: return .cnAccent
        case .excellent: return .cnPrimary
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
}



