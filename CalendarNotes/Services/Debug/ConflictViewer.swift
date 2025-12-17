//
//  ConflictViewer.swift
//  CalendarNotes
//
//  Debug tool for viewing sync conflicts
//

import Foundation
import SwiftUI
import Combine
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

#if DEBUG

/// Viewer for sync conflicts
@MainActor
final class ConflictViewer: ObservableObject {
    static let shared = ConflictViewer()
    
    @Published var conflicts: [SyncConflict] = []
    
    private init() {}
    
    func addConflict(
        entityType: ConflictEntityType,
        entityId: String,
        localFields: [String: String],
        serverFields: [String: String],
        conflictType: ConflictType
    ) {
        let conflict = SyncConflict(
            id: UUID().uuidString,
            entityType: entityType,
            entityId: entityId,
            conflictType: conflictType,
            local: ConflictSide(
                deviceName: {
                    #if os(iOS)
                    return UIDevice.current.name
                    #elseif os(macOS)
                    return ProcessInfo.processInfo.hostName
                    #else
                    return "Device"
                    #endif
                }(),
                timestamp: Date(),
                fields: localFields
            ),
            server: ConflictSide(
                deviceName: "Server",
                timestamp: Date(),
                fields: serverFields
            )
        )
        
        conflicts.append(conflict)
        
        print("⚠️ [CONFLICT] \(entityType.rawValue) \(entityId)")
    }
    
    func resolveConflict(_ conflictId: String, resolution: ConflictResolutionChoice) {
        // Note: SyncConflict is immutable, so we'd need to replace it
        if let index = conflicts.firstIndex(where: { $0.id == conflictId }) {
            // In a real implementation, you'd update the conflict resolution
            // For now, we just remove it from the list
            conflicts.remove(at: index)
            print("✅ [CONFLICT RESOLVED] \(conflictId) - \(resolution.rawValue)")
        }
    }
    
    func clearConflicts() {
        conflicts.removeAll()
    }
}

#endif

