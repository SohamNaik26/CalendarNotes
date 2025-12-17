//
//  ConflictStore.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import Combine

final class ConflictStore: ObservableObject {
    static let shared = ConflictStore()
    private init() {}
    
    @Published var conflicts: [SyncConflict] = []
    @Published var unresolvedCount: Int = 0
    
    func setConflicts(_ conflicts: [SyncConflict]) {
        self.conflicts = conflicts
        self.unresolvedCount = conflicts.count
    }
    
    func resolve(_ conflict: SyncConflict, with choice: ConflictResolutionChoice) {
        // Placeholder for integration with actual sync manager resolution
        conflicts.removeAll { $0.id == conflict.id }
        unresolvedCount = max(0, unresolvedCount - 1)
        
        let record = ResolvedConflictRecord(
            id: UUID().uuidString,
            conflict: conflict,
            resolvedAt: Date(),
            resolution: choice
        )
        ConflictHistoryStore.shared.append(record)
    }
}


