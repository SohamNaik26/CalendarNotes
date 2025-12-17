//
//  BookmarkTaskLinkService.swift
//  CalendarNotes
//

import Foundation
import CoreData

@MainActor
final class BookmarkTaskLinkService {
    static let shared = BookmarkTaskLinkService()
    private init() {}

    private let core = CoreDataManager.shared
    private let linkService = BookmarkLinkService.shared

    // MARK: - Create "Read Later" task
    func createReadLaterTask(from bookmark: Bookmark, due: Date? = nil) throws -> TodoItem {
        let domain = URL(string: bookmark.url ?? "")?.host ?? ""
        let titleBase = bookmark.title ?? (domain.isEmpty ? "Bookmark" : domain)
        let title = "\(titleBase) — Read Later"
        let dueDate = due ?? Calendar.current.date(byAdding: .day, value: 1, to: Date())
        let item = TodoItem(context: core.viewContext, title: title, priority: TodoItem.Priority.medium.rawValue, category: "Reading", dueDate: dueDate, isCompleted: false, isRecurring: false)
        try core.save()
        _ = try linkService.link(bookmark, to: item)
        return item
    }

    // MARK: - Attach reference link to existing task
    func attach(_ bookmark: Bookmark, to task: TodoItem) throws {
        // Minimal attachment: append domain to title and set category to Research
        let domain = URL(string: bookmark.url ?? "")?.host ?? ""
        if !domain.isEmpty {
            let current = task.title ?? "Task"
            if !current.contains(domain) { task.title = current + " (\(domain))" }
        }
        task.category = "Research"
        _ = try linkService.link(bookmark, to: task)
        try core.save()
    }

    // MARK: - Batch schedule (daily reading)
    func scheduleDailyReading(from bookmarks: [Bookmark], start: Date, perDay: Int = 1) throws {
        guard !bookmarks.isEmpty else { return }
        var dayIndex = 0
        for (idx, b) in bookmarks.enumerated() {
            let dayOffset = (idx / max(1, perDay))
            if let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: start) {
                _ = try createReadLaterTask(from: b, due: date)
            }
            dayIndex += 1
        }
    }

    // MARK: - Sync: mark bookmarks done when tasks completed
    func markBookmarksDoneForCompletedTasks(since days: Int = 30) throws {
        // Not supported without a text notes field on TodoItem; noop for now.
    }

    // MARK: - Stats
    func bookmarksReadThisWeek() -> Int {
        let ctx = core.viewContext
        let start = Calendar.current.date(from: Calendar.current.dateComponents([.yearForWeekOfYear,.weekOfYear], from: Date()))!
        let req: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        req.predicate = NSPredicate(format: "isArchived == YES AND lastModifiedDate >= %@", start as NSDate)
        return (try? ctx.count(for: req)) ?? 0
    }
}


