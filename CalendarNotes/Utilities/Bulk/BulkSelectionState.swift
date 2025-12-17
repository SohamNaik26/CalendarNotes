//
//  BulkSelectionState.swift
//  CalendarNotes
//
//  Created by Cursor AI on 08/11/25.
//

import Foundation
import CoreData

/// Describes the logical scope from which a bulk selection was created.
enum BulkSelectionContext: Equatable {
    case library
    case collection(String)
    case tag(String)
    case favorites
    case archived
    case search(query: String)
    case contentType(BookmarkContentType)
    
    var title: String {
        switch self {
        case .library: return "All Bookmarks"
        case .collection(let name): return "Collection: \(name)"
        case .tag(let name): return "Tag: \(name)"
        case .favorites: return "Favorites"
        case .archived: return "Archived"
        case .search(let query): return "Search “\(query)”"
        case .contentType(let type):
            switch type {
            case .article: return "Articles"
            case .video: return "Videos"
            case .pdf: return "PDFs"
            case .image: return "Images"
            case .social: return "Social Posts"
            case .product: return "Products"
            case .repository: return "GitHub Repos"
            case .recipe: return "Recipes"
            case .unknown: return "Other Bookmarks"
            }
        }
    }
}

/// Criteria used when selecting bookmarks in bulk.
struct BulkSelectionCriteria: Equatable {
    var collectionName: String?
    var tagNames: [String] = []
    var dateRange: ClosedRange<Date>?
    
    var isEmpty: Bool {
        collectionName == nil && tagNames.isEmpty && dateRange == nil
    }
    
    func matches(_ bookmark: Bookmark) -> Bool {
        if let collectionName {
            let direct = bookmark.collectionName?.caseInsensitiveCompare(collectionName) == .orderedSame
            let relation = bookmark.collection?.name?.caseInsensitiveCompare(collectionName) == .orderedSame
            guard direct || relation else { return false }
        }
        if !tagNames.isEmpty {
            let bookmarkTags = Set(bookmark.decodedTags.map { $0.lowercased() })
            let required = Set(tagNames.map { $0.lowercased() })
            guard !bookmarkTags.isDisjoint(with: required) else { return false }
        }
        if let range = dateRange {
            guard let created = bookmark.createdDate else { return false }
            guard range.contains(created) else { return false }
        }
        return true
    }
}

/// Summary information about a bulk selection.
struct BulkSelectionSummary: Equatable {
    var count: Int
    var contextTitle: String
    
    var description: String {
        "\(count) selected · \(contextTitle)"
    }
}

/// Describes the selection state for bulk actions.
struct BulkSelectionState: Equatable {
    var isActive: Bool = false
    var context: BulkSelectionContext = .library
    private(set) var selectedObjectIDs: Set<NSManagedObjectID> = []
    var lastInteraction: Date = Date()
    
    init(isActive: Bool = false,
         context: BulkSelectionContext = .library,
         selectedObjectIDs: Set<NSManagedObjectID> = []) {
        self.isActive = isActive
        self.context = context
        self.selectedObjectIDs = selectedObjectIDs
    }
    
    var isEmpty: Bool { selectedObjectIDs.isEmpty }
    var count: Int { selectedObjectIDs.count }
    
    mutating func updateContext(_ newContext: BulkSelectionContext) {
        context = newContext
    }
    
    mutating func activate(initialSelection objectID: NSManagedObjectID? = nil) {
        isActive = true
        if let id = objectID {
            selectedObjectIDs.insert(id)
        }
        lastInteraction = Date()
    }
    
    mutating func deactivate() {
        isActive = false
        selectedObjectIDs.removeAll()
        lastInteraction = Date()
    }
    
    mutating func toggle(_ objectID: NSManagedObjectID) {
        if selectedObjectIDs.contains(objectID) {
            selectedObjectIDs.remove(objectID)
        } else {
            selectedObjectIDs.insert(objectID)
        }
        lastInteraction = Date()
    }
    
    mutating func select(_ objectID: NSManagedObjectID) {
        selectedObjectIDs.insert(objectID)
        lastInteraction = Date()
    }
    
    mutating func selectMany(_ objectIDs: [NSManagedObjectID]) {
        selectedObjectIDs.formUnion(objectIDs)
        lastInteraction = Date()
    }
    
    mutating func deselect(_ objectID: NSManagedObjectID) {
        selectedObjectIDs.remove(objectID)
        lastInteraction = Date()
    }
    
    mutating func clear() {
        selectedObjectIDs.removeAll()
        lastInteraction = Date()
    }
    
    mutating func keepOnly(_ objectIDs: Set<NSManagedObjectID>) {
        selectedObjectIDs = selectedObjectIDs.intersection(objectIDs)
        if selectedObjectIDs.isEmpty {
            isActive = false
        }
        lastInteraction = Date()
    }
    
    func contains(_ objectID: NSManagedObjectID) -> Bool {
        selectedObjectIDs.contains(objectID)
    }
    
    func summary() -> BulkSelectionSummary {
        BulkSelectionSummary(count: count, contextTitle: context.title)
    }
}


