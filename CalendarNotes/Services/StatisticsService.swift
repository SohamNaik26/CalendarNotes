//
//  StatisticsService.swift
//  CalendarNotes
//

import Foundation
import CoreData
import SwiftUI

struct StatisticsSummary {
    let totalBookmarks: Int
    let bookmarksThisMonth: Int
    let bookmarksThisWeek: Int
    let favoriteCount: Int
    let mostActiveCollection: String?
    let topTags: [(String, Int)]
    let topDomains: [(String, Int)]
}

struct TimeSeriesPoint: Identifiable { let id = UUID(); let date: Date; let count: Int }
struct CategorySlice: Identifiable { let id = UUID(); let name: String; let count: Int }

@MainActor
final class StatisticsService {
    static let shared = StatisticsService()
    private init() {}
    
    private let core = CoreDataManager.shared
    
    // MARK: - Summary
    func summary() -> StatisticsSummary {
        let ctx = core.viewContext
        let all: [Bookmark] = (try? ctx.fetch(Bookmark.fetchRequest())) ?? []
        let total = all.count
        let fav = all.filter { $0.isFavorite }.count
        let cal = Calendar.current
        let now = Date()
        let thisMonth = all.filter { if let d = $0.createdDate { return cal.isDate(d, equalTo: now, toGranularity: .month) } ; return false }.count
        let thisWeek = all.filter { if let d = $0.createdDate { return cal.isDate(d, equalTo: now, toGranularity: .weekOfYear) } ; return false }.count
        let mostActiveCollection = mostActiveCollectionName(from: all)
        let tags = topTags(from: all, limit: 10)
        let domains = topDomains(from: all, limit: 10)
        return StatisticsSummary(totalBookmarks: total, bookmarksThisMonth: thisMonth, bookmarksThisWeek: thisWeek, favoriteCount: fav, mostActiveCollection: mostActiveCollection, topTags: tags, topDomains: domains)
    }
    
    // MARK: - Datasets
    func bookmarksOverTime(days: Int = 90) -> [TimeSeriesPoint] {
        let ctx = core.viewContext
        let all: [Bookmark] = (try? ctx.fetch(Bookmark.fetchRequest())) ?? []
        let cal = Calendar.current
        let start = cal.date(byAdding: .day, value: -days+1, to: Date()) ?? Date()
        var buckets: [Date: Int] = [:]
        for i in 0..<days {
            if let day = cal.date(byAdding: .day, value: i, to: start) {
                buckets[cal.startOfDay(for: day)] = 0
            }
        }
        for b in all {
            if let d = b.createdDate { let key = cal.startOfDay(for: d); if buckets[key] != nil { buckets[key]! += 1 } }
        }
        return buckets.keys.sorted().map { TimeSeriesPoint(date: $0, count: buckets[$0] ?? 0) }
    }
    
    func collectionsDistribution(top: Int = 8) -> [CategorySlice] {
        let ctx = core.viewContext
        let all: [Bookmark] = (try? ctx.fetch(Bookmark.fetchRequest())) ?? []
        var countBy: [String: Int] = [:]
        for b in all {
            let name = b.collectionName ?? "Unfiled"
            countBy[name, default: 0] += 1
        }
        let sorted = countBy.sorted { $0.value > $1.value }
        return Array(sorted.prefix(top)).map { CategorySlice(name: $0.key, count: $0.value) }
    }
    
    func topDomains(from bookmarks: [Bookmark]? = nil, limit: Int = 10) -> [(String, Int)] {
        let list: [Bookmark] = bookmarks ?? ((try? core.viewContext.fetch(Bookmark.fetchRequest())) ?? [])
        var countBy: [String: Int] = [:]
        for b in list {
            if let s = b.url, let u = URL(string: s), let h = u.host { countBy[h, default: 0] += 1 }
        }
        return Array(countBy.sorted { $0.value > $1.value }.prefix(limit))
    }
    
    func topTags(from bookmarks: [Bookmark], limit: Int) -> [(String, Int)] {
        var countBy: [String: Int] = [:]
        for b in bookmarks {
            let names = b.decodedTags
            for n in names { countBy[n, default: 0] += 1 }
        }
        return Array(countBy.sorted { $0.value > $1.value }.prefix(limit))
    }
    
    // MARK: - Insights
    func averagePerWeek() -> Double {
        let ctx = core.viewContext
        let all: [Bookmark] = (try? ctx.fetch(Bookmark.fetchRequest())) ?? []
        guard let first = all.compactMap({ $0.createdDate }).min() else { return 0 }
        let weeks = max(1.0, Date().timeIntervalSince(first) / (7*24*3600))
        return Double(all.count) / weeks
    }
    
    func longestSavingStreak() -> Int {
        let ctx = core.viewContext
        let dates: [Date] = ((try? ctx.fetch(Bookmark.fetchRequest())) ?? [])
            .compactMap { $0.createdDate }
            .map { Calendar.current.startOfDay(for: $0) }
            .sorted()
        var best = 0, current = 0
        var prev: Date?
        for d in dates {
            if let p = prev, Calendar.current.date(byAdding: .day, value: 1, to: p) == d { current += 1 } else { current = 1 }
            best = max(best, current); prev = d
        }
        return best
    }
    
    func mostActiveCollectionName(from list: [Bookmark]) -> String? {
        var countBy: [String: Int] = [:]
        for b in list { countBy[b.collectionName ?? "Unfiled", default: 0] += 1 }
        return countBy.max(by: { $0.value < $1.value })?.key
    }
    
    // MARK: - Compare Periods
    func count(in range: DateInterval) -> Int {
        let req: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        req.predicate = NSPredicate(format: "createdDate >= %@ AND createdDate <= %@", range.start as NSDate, range.end as NSDate)
        return (try? core.viewContext.count(for: req)) ?? 0
    }
}


