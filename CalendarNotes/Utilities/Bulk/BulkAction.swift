//
//  BulkAction.swift
//  CalendarNotes
//
//  Created by Cursor AI on 08/11/25.
//

import Foundation

/// Describes the available toolbar buttons for bulk operations.
enum BulkActionKind: String, CaseIterable, Identifiable {
    case addToCollection
    case removeFromCollection
    case addTags
    case removeTags
    case favorite
    case unfavorite
    case archive
    case unarchive
    case delete
    case export
    case share
    case refreshMetadata
    
    var id: String { rawValue }
    
    var label: String {
        switch self {
        case .addToCollection: return "Add to Collection"
        case .removeFromCollection: return "Remove from Collection"
        case .addTags: return "Add Tags"
        case .removeTags: return "Remove Tags"
        case .favorite: return "Mark Favorite"
        case .unfavorite: return "Unfavorite"
        case .archive: return "Archive"
        case .unarchive: return "Unarchive"
        case .delete: return "Delete"
        case .export: return "Export"
        case .share: return "Share"
        case .refreshMetadata: return "Refresh Metadata"
        }
    }
    
    var systemImage: String {
        switch self {
        case .addToCollection: return "folder.badge.plus"
        case .removeFromCollection: return "folder.badge.minus"
        case .addTags: return "tag"
        case .removeTags: return "tag.slash"
        case .favorite: return "star.circle"
        case .unfavorite: return "star.slash.circle"
        case .archive: return "archivebox"
        case .unarchive: return "archivebox.fill"
        case .delete: return "trash"
        case .export: return "square.and.arrow.up.on.square"
        case .share: return "square.and.arrow.up"
        case .refreshMetadata: return "arrow.clockwise"
        }
    }
    
    var isDestructive: Bool {
        switch self {
        case .delete: return true
        default: return false
        }
    }
    
    var requiresTextInput: Bool {
        switch self {
        case .addToCollection, .addTags, .removeTags: return true
        default: return false
        }
    }
}

/// Concrete actionable request (with parameters) sent to the bulk operation service.
enum BulkAction: Equatable {
    case addToCollection(name: String)
    case removeFromCollection
    case addTags(tags: [String])
    case removeTags(tags: [String])
    case favorite
    case unfavorite
    case archive
    case unarchive
    case delete
    case export(format: BulkExportFormat)
    case share(includePreviewImages: Bool)
    case refreshMetadata
    
    var displayName: String {
        switch self {
        case .addToCollection(let name): return "Add to \(name)"
        case .removeFromCollection: return "Remove from Collection"
        case .addTags(let tags): return "Add Tags (\(tags.joined(separator: ", ")))"
        case .removeTags(let tags): return "Remove Tags (\(tags.joined(separator: ", ")))"
        case .favorite: return "Mark Favorite"
        case .unfavorite: return "Unfavorite"
        case .archive: return "Archive"
        case .unarchive: return "Unarchive"
        case .delete: return "Delete"
        case .export(let format): return "Export (\(format.description))"
        case .share: return "Share"
        case .refreshMetadata: return "Refresh Metadata"
        }
    }
    
    var isDestructive: Bool {
        switch self {
        case .delete: return true
        default: return false
        }
    }
}

/// Export formats supported when exporting bookmarks in bulk.
enum BulkExportFormat: String, CaseIterable, Identifiable {
    case json
    case markdown
    case csv
    
    var id: String { rawValue }
    
    var description: String {
        switch self {
        case .json: return "JSON"
        case .markdown: return "Markdown"
        case .csv: return "CSV"
        }
    }
}

/// Describes the lifecycle of a running bulk operation.
struct BulkOperationProgress: Equatable {
    enum Status: Equatable {
        case idle
        case running
        case completed
        case failed
        case cancelled
    }
    
    let id: UUID
    var status: Status
    var processed: Int
    var total: Int
    var message: String
    var errorMessage: String?
    
    var fractionCompleted: Double {
        guard total > 0 else { return 0 }
        return Double(processed) / Double(total)
    }
    
    static func idle() -> BulkOperationProgress {
        BulkOperationProgress(id: UUID(), status: .idle, processed: 0, total: 0, message: "")
    }
}


