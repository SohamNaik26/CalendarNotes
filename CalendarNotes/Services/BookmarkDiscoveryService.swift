//
//  BookmarkDiscoveryService.swift
//  CalendarNotes
//

import Foundation
import CoreData

@MainActor
final class BookmarkDiscoveryService {
    static let shared = BookmarkDiscoveryService()
    private init() {}

    private let core = CoreDataManager.shared

    // MARK: - Trending & Popular
    func trending(limit: Int = 10) -> [Bookmark] {
        let ctx = core.viewContext
        let weekStart = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let req: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        req.predicate = NSPredicate(format: "lastOpenedDate >= %@ OR createdDate >= %@", weekStart as NSDate, weekStart as NSDate)
        let items = (try? ctx.fetch(req)) ?? []
        return items.sorted { $0.openCount > $1.openCount }.prefix(limit).map { $0 }
    }

    func popularDomains(limit: Int = 10) -> [(domain: String, count: Int)] {
        let ctx = core.viewContext
        let req: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        let items = (try? ctx.fetch(req)) ?? []
        let counts = items.reduce(into: [String: Int]()) { acc, b in
            if let host = URL(string: b.url ?? "")?.host { acc[host, default: 0] += 1 }
        }
        return counts.sorted { $0.value > $1.value }.prefix(limit).map { ($0.key, $0.value) }
    }

    func risingTags(limit: Int = 10) -> [(tag: String, recentCount: Int)] {
        let ctx = core.viewContext
        let recentStart = Calendar.current.date(byAdding: .day, value: -14, to: Date())!
        let prevStart = Calendar.current.date(byAdding: .day, value: -28, to: Date())!
        let req: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        req.predicate = NSPredicate(format: "createdDate >= %@", prevStart as NSDate)
        let items = (try? ctx.fetch(req)) ?? []
        var recent: [String: Int] = [:]
        var previous: [String: Int] = [:]
        for b in items {
            for t in b.decodedTags {
                if (b.createdDate ?? Date.distantPast) >= recentStart { recent[t, default: 0] += 1 } else { previous[t, default: 0] += 1 }
            }
        }
        let gains = recent.map { (tag, r) -> (String, Int) in (tag, r - (previous[tag] ?? 0)) }
        return gains.sorted { $0.1 > $1.1 }.prefix(limit).map { ($0.0, recent[$0.0] ?? 0) }
    }

    // MARK: - Related
    func related(to bookmark: Bookmark, limit: Int = 6) -> [Bookmark] {
        let ctx = core.viewContext
        let req: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        let items = (try? ctx.fetch(req)) ?? []
        let tags = Set(bookmark.decodedTags)
        let domain = URL(string: bookmark.url ?? "")?.host
        let scored = items.filter { $0 != bookmark }.map { b -> (Bookmark, Int) in
            var s = 0
            if URL(string: b.url ?? "")?.host == domain { s += 2 }
            s += Set(b.decodedTags).intersection(tags).count
            return (b, s)
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map { $0.0 }
    }

    // MARK: - Timeline
    func timeline(by component: Calendar.Component = .weekOfYear) -> [(label: String, items: [Bookmark])] {
        let ctx = core.viewContext
        let req: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
        let items = (try? ctx.fetch(req)) ?? []
        var groups: [String: [Bookmark]] = [:]
        let fmt = DateFormatter(); fmt.dateFormat = component == .month ? "LLLL yyyy" : "w, yyyy"
        for b in items {
            let d = b.createdDate ?? Date()
            let label: String
            if component == .month {
                label = fmt.string(from: d)
            } else {
                label = "Week \(Calendar.current.component(.weekOfYear, from: d)), \(Calendar.current.component(.year, from: d))"
            }
            groups[label, default: []].append(b)
        }
        return groups.sorted { $0.key > $1.key }.map { ($0.key, $0.value) }
    }

    // MARK: - Rediscover
    func onThisDay() -> [Bookmark] {
        let ctx = core.viewContext
        let req: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        let items = (try? ctx.fetch(req)) ?? []
        let today = Calendar.current.dateComponents([.month, .day], from: Date())
        return items.filter { b in
            guard let d = b.createdDate else { return false }
            let c = Calendar.current.dateComponents([.month, .day], from: d)
            return c.month == today.month && c.day == today.day
        }
    }

    func randomSuggestion() -> Bookmark? {
        let ctx = core.viewContext
        let req: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        req.fetchLimit = 200
        let items = (try? ctx.fetch(req)) ?? []
        return items.randomElement()
    }

    func forgottenGems(limit: Int = 10) -> [Bookmark] {
        let ctx = core.viewContext
        let req: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        let items = (try? ctx.fetch(req)) ?? []
        return items.filter { ($0.openCount) == 0 }.prefix(limit).map { $0 }
    }
}


