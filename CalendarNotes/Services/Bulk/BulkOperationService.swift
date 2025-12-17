//
//  BulkOperationService.swift
//  CalendarNotes
//
//  Created by Cursor AI on 08/11/25.
//

import Foundation
import Combine
import CoreData
import UniformTypeIdentifiers

@MainActor
final class BulkOperationService: ObservableObject {
    static let shared = BulkOperationService()
    
    @Published private(set) var progress: BulkOperationProgress = .idle()
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false
    
    private let coreData = CoreDataManager.shared
    private var undoStack: [BulkOperationSnapshot] = []
    private var redoStack: [BulkOperationSnapshot] = []
    private var cancellables: Set<AnyCancellable> = []
    private var runningTask: Task<Void, Never>?
    
    private init() {}
    
    func perform(action: BulkAction, on objectIDs: [NSManagedObjectID], context: BulkSelectionContext) async throws {
        guard runningTask == nil else {
            throw BulkOperationError.operationInProgress
        }
        guard !objectIDs.isEmpty else { return }
        
        let snapshotID = UUID()
        progress = BulkOperationProgress(id: snapshotID, status: .running, processed: 0, total: objectIDs.count, message: action.displayName)
        progress.errorMessage = nil
        
        let viewContext = coreData.viewContext
        let beforeStates = try objectIDs.compactMap { id -> BookmarkState? in
            guard let bookmark = try viewContext.existingObject(with: id) as? Bookmark else { return nil }
            return BookmarkState(from: bookmark)
        }
        guard !beforeStates.isEmpty else {
            progress.status = .completed
            return
        }
        
        runningTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            do {
                try await viewContext.perform {
                    let bookmarks = try beforeStates.compactMap { state -> Bookmark? in
                        try viewContext.existingObject(with: state.objectID) as? Bookmark
                    }
                    try applyBulkAction(action, to: bookmarks) { processed, total in
                        Task { @MainActor [weak self] in
                            guard let self else { return }
                            self.progress.processed = processed
                            self.progress.total = total
                        }
                    }
                    try self.coreData.save()
                }
                let afterStates = try await viewContext.perform { () -> [BookmarkState] in
                    try objectIDs.compactMap { id -> BookmarkState? in
                        guard let bookmark = try viewContext.existingObject(with: id) as? Bookmark else { return nil }
                        return BookmarkState(from: bookmark)
                    }
                }
                await MainActor.run {
                    let snapshot = BulkOperationSnapshot(id: snapshotID,
                                                         action: action,
                                                         context: context,
                                                         before: beforeStates,
                                                         after: afterStates)
                    self.undoStack.append(snapshot)
                    self.redoStack.removeAll()
                    self.updateUndoRedoFlags()
                    self.progress.status = .completed
                    self.progress.processed = objectIDs.count
                    self.runningTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.progress.status = .cancelled
                    self.progress.errorMessage = "Operation cancelled"
                    self.runningTask = nil
                }
            } catch {
                await MainActor.run {
                    self.progress.status = .failed
                    self.progress.errorMessage = error.localizedDescription
                    self.runningTask = nil
                }
            }
        }
    }
    
    func cancel() {
        runningTask?.cancel()
        runningTask = nil
    }
    
    func undo() async throws {
        guard let snapshot = undoStack.popLast() else { return }
        try await restore(snapshot.before)
        redoStack.append(snapshot)
        updateUndoRedoFlags()
    }
    
    func redo() async throws {
        guard let snapshot = redoStack.popLast() else { return }
        try await restore(snapshot.after)
        undoStack.append(snapshot)
        updateUndoRedoFlags()
    }
    
    private func updateUndoRedoFlags() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
    }
    
    private func restore(_ states: [BookmarkState]) async throws {
        let viewContext = coreData.viewContext
        try await viewContext.perform {
            for state in states {
                guard let bookmark = try? viewContext.existingObject(with: state.objectID) as? Bookmark else { continue }
                bookmark.title = state.title
                if let newURL = state.url, !newURL.isEmpty {
                    let sanitized = URLPrivacySanitizer.sanitized(newURL)
                    bookmark.url = sanitized
                }
                bookmark.collectionName = state.collectionName
                bookmark.isFavorite = state.isFavorite
                bookmark.isArchived = state.isArchived
                bookmark.decodedTags = state.tags
            }
            try self.coreData.save()
        }
        progress = BulkOperationProgress(id: UUID(), status: .completed, processed: states.count, total: states.count, message: "Undo")
    }
    
}

// MARK: - Snapshot & Error

private struct BookmarkState: Equatable {
    let objectID: NSManagedObjectID
    let title: String?
    let url: String?
    let collectionName: String?
    let isFavorite: Bool
    let isArchived: Bool
    let tags: [String]
    
    init(from bookmark: Bookmark) {
        objectID = bookmark.objectID
        title = bookmark.title
        url = bookmark.url
        collectionName = bookmark.collectionName
        isFavorite = bookmark.isFavorite
        isArchived = bookmark.isArchived
        tags = bookmark.decodedTags
    }
}

private struct BulkOperationSnapshot {
    let id: UUID
    let action: BulkAction
    let context: BulkSelectionContext
    let before: [BookmarkState]
    let after: [BookmarkState]
}

enum BulkOperationError: LocalizedError {
    case operationInProgress
    
    var errorDescription: String? {
        switch self {
        case .operationInProgress:
            return "Another bulk operation is currently running."
        }
    }
}

// MARK: - Helpers

private func applyBulkAction(_ action: BulkAction,
                             to bookmarks: [Bookmark],
                             progress: @escaping @Sendable (Int, Int) -> Void) throws {
    guard !bookmarks.isEmpty else { return }
    for (index, bookmark) in bookmarks.enumerated() {
        if Task.isCancelled { throw CancellationError() }
        switch action {
        case .addToCollection(let name):
            bookmark.collectionName = name
        case .removeFromCollection:
            bookmark.collectionName = nil
            bookmark.collection = nil
        case .addTags(let tags):
            var list = bookmark.decodedTags
            for tag in tags where !tag.trimmingCharacters(in: .whitespaces).isEmpty {
                if !list.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
                    list.append(tag)
                }
            }
            bookmark.decodedTags = list
        case .removeTags(let tags):
            let lowercased = tags.map { $0.lowercased() }
            let filtered = bookmark.decodedTags.filter { !lowercased.contains($0.lowercased()) }
            bookmark.decodedTags = filtered
        case .favorite:
            bookmark.isFavorite = true
        case .unfavorite:
            bookmark.isFavorite = false
        case .archive:
            bookmark.isArchived = true
        case .unarchive:
            bookmark.isArchived = false
        case .delete:
            bookmark.managedObjectContext?.delete(bookmark)
        case .export, .share, .refreshMetadata:
            break
        }
        progress(index + 1, bookmarks.count)
    }
}


