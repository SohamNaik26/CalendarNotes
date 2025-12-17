import Foundation
import CoreData

@MainActor
final class BookmarkLinkService {
    static let shared = BookmarkLinkService()
    private init() {}
    
    enum TargetType: String { case event, note, task }
    
    private let core = CoreDataManager.shared
    
    // MARK: - Public API
    
    func link(_ bookmark: Bookmark, to event: CalendarEvent) throws -> BookmarkLink {
        if let existing = bookmark.linkObjects.first(where: { $0.event == event }) {
            return existing
        }
        let link = BookmarkLink(context: core.viewContext)
        link.id = UUID()
        link.createdDate = Date()
        link.linkType = TargetType.event.rawValue
        link.bookmark = bookmark
        link.event = event
        try core.save()
        return link
    }
    
    func link(_ bookmark: Bookmark, to note: Note) throws -> BookmarkLink {
        if let existing = bookmark.linkObjects.first(where: { $0.note == note }) {
            return existing
        }
        let link = BookmarkLink(context: core.viewContext)
        link.id = UUID()
        link.createdDate = Date()
        link.linkType = TargetType.note.rawValue
        link.bookmark = bookmark
        link.note = note
        try core.save()
        return link
    }
    
    func link(_ bookmark: Bookmark, to task: TodoItem) throws -> BookmarkLink {
        if let existing = bookmark.linkObjects.first(where: { $0.task == task }) {
            return existing
        }
        let link = BookmarkLink(context: core.viewContext)
        link.id = UUID()
        link.createdDate = Date()
        link.linkType = TargetType.task.rawValue
        link.bookmark = bookmark
        link.task = task
        try core.save()
        return link
    }
    
    func unlink(_ link: BookmarkLink) throws {
        guard let context = link.managedObjectContext else { return }
        context.delete(link)
        try core.save()
    }
    
    func links(for bookmark: Bookmark) -> [BookmarkLink] {
        bookmark.linkObjects
    }
    
    func bookmarks(for event: CalendarEvent) -> [Bookmark] {
        let set = event.value(forKey: "bookmarkLinks") as? Set<BookmarkLink> ?? []
        return set.compactMap { $0.bookmark }
    }
    
    func bookmarks(for note: Note) -> [Bookmark] {
        let set = note.value(forKey: "bookmarkLinks") as? Set<BookmarkLink> ?? []
        return set.compactMap { $0.bookmark }
    }
    
    func bookmarks(for task: TodoItem) -> [Bookmark] {
        let set = task.value(forKey: "bookmarkLinks") as? Set<BookmarkLink> ?? []
        return set.compactMap { $0.bookmark }
    }
    
    func existingLink(bookmark: Bookmark, to event: CalendarEvent) -> BookmarkLink? {
        bookmark.linkObjects.first { $0.event == event }
    }
    
    func existingLink(bookmark: Bookmark, to note: Note) -> BookmarkLink? {
        bookmark.linkObjects.first { $0.note == note }
    }
    
    func existingLink(bookmark: Bookmark, to task: TodoItem) -> BookmarkLink? {
        bookmark.linkObjects.first { $0.task == task }
    }

    func link(_ bookmarks: [Bookmark], to event: CalendarEvent) throws {
        for bookmark in bookmarks {
            _ = try link(bookmark, to: event)
        }
    }

    func link(_ bookmarks: [Bookmark], to note: Note) throws {
        for bookmark in bookmarks {
            _ = try link(bookmark, to: note)
        }
    }

    func link(_ bookmarks: [Bookmark], to task: TodoItem) throws {
        for bookmark in bookmarks {
            _ = try link(bookmark, to: task)
        }
    }
}
