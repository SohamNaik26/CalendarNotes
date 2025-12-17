//
//  ConflictModels.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation

public enum ConflictEntityType: String, Codable, CaseIterable, Identifiable {
    case event
    case task
    case note
    case bookmark
    case collection
    case other
    
    public var id: String { rawValue }
}

public enum ConflictType: String, Codable, CaseIterable, Identifiable {
    case editedOnMultipleDevices
    case deletedVsEdited
    case duplicateCreationSameId
    
    public var id: String { rawValue }
}

public enum ConflictResolutionChoice: String, Codable {
    case keepLocal
    case keepServer
    case keepBoth
    case manualMerge
    case skipped
}

public struct ConflictFieldDiff: Identifiable, Codable, Hashable {
    public enum ChangeType: String, Codable {
        case same
        case changed
        case added
        case removed
    }
    
    public var id: String { fieldKey }
    public let fieldKey: String
    public let localValue: String?
    public let serverValue: String?
    public let changeType: ChangeType
}

public struct ConflictSide: Codable, Hashable {
    public let deviceName: String
    public let timestamp: Date
    public let fields: [String: String] // flattened, display-ready values
}

public struct SyncConflict: Identifiable, Codable {
    public let id: String
    public let entityType: ConflictEntityType
    public let entityId: String
    public let conflictType: ConflictType
    public let local: ConflictSide
    public let server: ConflictSide
    
    public init(
        id: String = UUID().uuidString,
        entityType: ConflictEntityType,
        entityId: String,
        conflictType: ConflictType,
        local: ConflictSide,
        server: ConflictSide
    ) {
        self.id = id
        self.entityType = entityType
        self.entityId = entityId
        self.conflictType = conflictType
        self.local = local
        self.server = server
    }
    
    public func computeFieldDiffs(sortedKeys: [String]? = nil) -> [ConflictFieldDiff] {
        let keys = sortedKeys ?? Array(Set(local.fields.keys).union(server.fields.keys)).sorted()
        return keys.map { key in
            let l = local.fields[key]
            let s = server.fields[key]
            let type: ConflictFieldDiff.ChangeType
            switch (l, s) {
            case let (lv?, sv?):
                type = (lv == sv) ? .same : .changed
            case (_?, nil):
                type = .removed
            case (nil, _?):
                type = .added
            default:
                type = .same
            }
            return ConflictFieldDiff(fieldKey: key, localValue: l, serverValue: s, changeType: type)
        }
    }
}


