//
//  BookmarkCalendarLinkService.swift
//  CalendarNotes
//

import Foundation
import CoreData

@MainActor
final class BookmarkCalendarLinkService {
    static let shared = BookmarkCalendarLinkService()
    private init() {}

    private let coreData = CoreDataManager.shared
    private let linkService = BookmarkLinkService.shared

    // MARK: - Link to date
    func link(_ bookmark: Bookmark, to date: Date) throws {
        bookmark.linkedCalendarDate = date
        try coreData.save()
    }

    func unlinkDate(_ bookmark: Bookmark) throws {
        bookmark.linkedCalendarDate = nil
        try coreData.save()
    }

    func link(_ bookmarks: [Bookmark], to date: Date) throws {
        for b in bookmarks { b.linkedCalendarDate = date }
        try coreData.save()
    }

    func link(_ bookmarks: [Bookmark], toRange start: Date, end: Date) throws {
        let days = max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0)
        for (idx, b) in bookmarks.enumerated() {
            if let d = Calendar.current.date(byAdding: .day, value: idx % (days + 1), to: start) { b.linkedCalendarDate = d }
        }
        try coreData.save()
    }

    func createEvent(from bookmark: Bookmark) throws -> CalendarEvent {
        let start = bookmark.linkedCalendarDate ?? Date()
        let end = Calendar.current.date(byAdding: .minute, value: 45, to: start) ?? start.addingTimeInterval(45 * 60)
        let title = bookmark.title ?? readableTitle(from: bookmark.url)
        let notes = [
            bookmark.bookmarkDescription,
            bookmark.url.map { "Link: \($0)" }
        ]
            .compactMap { $0 }
            .joined(separator: "\n")
        let event = try coreData.createEvent(
            title: title,
            startDate: start,
            endDate: end,
            category: "Bookmarks",
            location: nil,
            notes: notes.isEmpty ? nil : notes,
            isRecurring: false,
            recurrenceRule: nil
        )
        bookmark.linkedEventID = event.id
        bookmark.linkedCalendarDate = start
        try coreData.save()
        _ = try linkService.link(bookmark, to: event)
        return event
    }

    // MARK: - Attach to event
    func attach(_ bookmark: Bookmark, to event: CalendarEvent) throws {
        // Store event's date and put URL into notes for quick reference
        bookmark.linkedCalendarDate = event.startDate
        var notes = event.notes ?? ""
        let line = "\nBookmark: \(bookmark.title ?? bookmark.url ?? "") — \(bookmark.url ?? "")"
        if !notes.contains(line) { notes += line }
        event.notes = notes
        _ = try? linkService.link(bookmark, to: event)
        try coreData.save()
        EventAnalysisService.shared.analyze(event: event)
    }

    // MARK: - Queries
    func bookmarks(on date: Date, in ctx: NSManagedObjectContext? = nil) -> [Bookmark] {
        let context = ctx ?? coreData.viewContext
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start)!
        let req: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        req.predicate = NSPredicate(format: "linkedCalendarDate >= %@ AND linkedCalendarDate < %@", start as NSDate, end as NSDate)
        return (try? context.fetch(req)) ?? []
    }

    func countsByDate(rangeStart: Date, rangeEnd: Date) -> [Date: Int] {
        var counts: [Date: Int] = [:]
        let ctx = coreData.viewContext
        let req: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        req.predicate = NSPredicate(format: "linkedCalendarDate >= %@ AND linkedCalendarDate <= %@", rangeStart as NSDate, rangeEnd as NSDate)
        let items = (try? ctx.fetch(req)) ?? []
        for b in items {
            if let d = b.linkedCalendarDate {
                let day = Calendar.current.startOfDay(for: d)
                counts[day, default: 0] += 1
            }
        }
        return counts
    }

    private func readableTitle(from string: String?) -> String {
        guard
            let string,
            let url = URL(string: string)
        else { return "Bookmark" }
        var host = url.host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
        host = host.split(separator: ".").first.map(String.init) ?? host
        let path = url.deletingPathExtension().lastPathComponent
        if path.isEmpty || path == "/" { return host.capitalized }
        return path
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .capitalized
    }
}


