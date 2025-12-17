//
//  TagAnalyticsService.swift
//  CalendarNotes
//
//  Provides rich analytics for tag usage, diversity, growth, and cleanup operations.
//

import Foundation
import CoreData

struct TagAnalyticsSnapshot: Identifiable {
    struct Usage: Identifiable {
        let id: UUID
        let tagID: UUID
        let name: String
        let count: Int
        let percentage: Double
        let lastUsed: Date?
    }

    struct TrendPoint: Identifiable {
        let id = UUID()
        let date: Date
        let count: Int
    }

    let id = UUID()
    let createdAt: Date
    let totalTags: Int
    let totalBookmarks: Int
    let diversityScore: Double
    let trendingTags: [Usage]
    let unusedTags: [Usage]
    let usageTop: [Usage]
    let growthTimeline: [TrendPoint]
}

final class TagAnalyticsService {
    enum SamplingWindow {
        case last7Days
        case last30Days
        case last12Months

        var calendarComponent: Calendar.Component {
            switch self {
            case .last7Days, .last30Days: return .day
            case .last12Months: return .month
            }
        }

        var bucketCount: Int {
            switch self {
            case .last7Days: return 7
            case .last30Days: return 30
            case .last12Months: return 12
            }
        }

        var interval: TimeInterval {
            switch self {
            case .last7Days: return 7 * 24 * 60 * 60
            case .last30Days: return 30 * 24 * 60 * 60
            case .last12Months: return 365 * 24 * 60 * 60
            }
        }
    }

    private let context: NSManagedObjectContext
    private let cacheQueue = DispatchQueue(label: "TagAnalyticsService.Cache")

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func generateSnapshot(window: SamplingWindow = .last30Days) -> TagAnalyticsSnapshot {
        let tagRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
        let bookmarkRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()

        let tags = (try? context.fetch(tagRequest)) ?? []
        let bookmarks = (try? context.fetch(bookmarkRequest)) ?? []
        let totalBookmarks = bookmarks.count

        let usageEntries: [TagAnalyticsSnapshot.Usage] = tags.map { tag in
            let id = tag.id ?? UUID()
            let count = Int(tag.usageCount)
            let percentage = totalBookmarks > 0 ? Double(count) / Double(totalBookmarks) : 0
            return .init(
                id: id,
                tagID: id,
                name: tag.name ?? "",
                count: count,
                percentage: percentage,
                lastUsed: tag.lastUsedDate
            )
        }

        let diversityScore = calculateDiversityScore(bookmarks: bookmarks, tags: tags)
        let unused = usageEntries.filter { $0.count == 0 }.sorted { $0.name < $1.name }
        let trending = computeTrendingTags(window: window, limit: 10)
        let timeline = computeGrowthTimeline(window: window, tags: tags)
        let top = usageEntries.sorted { $0.count > $1.count }.prefix(15)

        return TagAnalyticsSnapshot(
            createdAt: Date(),
            totalTags: tags.count,
            totalBookmarks: totalBookmarks,
            diversityScore: diversityScore,
            trendingTags: trending,
            unusedTags: Array(unused),
            usageTop: Array(top),
            growthTimeline: timeline
        )
    }

    // MARK: - Helpers

    private func calculateDiversityScore(bookmarks: [Bookmark], tags: [Tag]) -> Double {
        guard !bookmarks.isEmpty else { return 0 }
        let uniqueTags = Set(tags.compactMap { $0.name?.lowercased() })
        guard !uniqueTags.isEmpty else { return 0 }

        let perBookmarkTagCounts = bookmarks.map { bookmark -> Int in
            let relationCount = (bookmark.tagRelations as? Set<Tag>)?.count ?? 0
            let decodedCount = bookmark.decodedTags.count
            return max(relationCount, decodedCount)
        }

        let averageTagsPerBookmark = Double(perBookmarkTagCounts.reduce(0, +)) / Double(perBookmarkTagCounts.count)
        let normalizedByTagUniverse = min(averageTagsPerBookmark / Double(uniqueTags.count), 1.0)
        let evennessPenalty = computeEvennessPenalty(tags: tags)
        return (normalizedByTagUniverse * 0.7 + evennessPenalty * 0.3) * 100
    }

    private func computeEvennessPenalty(tags: [Tag]) -> Double {
        let counts = tags.map { max(Int($0.usageCount), 0) }
        let total = counts.reduce(0, +)
        guard total > 0 else { return 0 }

        let probabilities = counts.map { Double($0) / Double(total) }
        let entropy = -probabilities
            .filter { $0 > 0 }
            .reduce(0.0) { $0 + $1 * log2($1) }
        let maxEntropy = log2(Double(max(counts.count, 1)))
        guard maxEntropy > 0 else { return 0 }
        return entropy / maxEntropy
    }

    private func computeTrendingTags(window: SamplingWindow, limit: Int) -> [TagAnalyticsSnapshot.Usage] {
        let startDate = Date().addingTimeInterval(-window.interval)
        let request: NSFetchRequest<TagUsageEvent> = TagUsageEvent.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp >= %@", startDate as NSDate)

        guard let events = try? context.fetch(request), !events.isEmpty else { return [] }
        let grouped = Dictionary(grouping: events, by: { $0.tag?.id ?? UUID() })

        let scored = grouped.compactMap { (key, events) -> TagAnalyticsSnapshot.Usage? in
            guard let tag = events.first?.tag else { return nil }
            let count = events.count
            let percentage = Double(count) / Double(events.count)
            return .init(
                id: UUID(),
                tagID: key,
                name: tag.name ?? "",
                count: count,
                percentage: percentage,
                lastUsed: events.sorted(by: { ($0.timestamp ?? .distantPast) > ($1.timestamp ?? .distantPast) }).first?.timestamp
            )
        }

        return scored.sorted { $0.count > $1.count }.prefix(limit).map { $0 }
    }

    private func computeGrowthTimeline(window: SamplingWindow, tags: [Tag]) -> [TagAnalyticsSnapshot.TrendPoint] {
        let startDate = Calendar.current.date(byAdding: .second, value: -Int(window.interval), to: Date()) ?? Date()
        let eventsRequest: NSFetchRequest<TagUsageEvent> = TagUsageEvent.fetchRequest()
        eventsRequest.predicate = NSPredicate(format: "timestamp >= %@", startDate as NSDate)
        let events = (try? context.fetch(eventsRequest)) ?? []

        guard window.bucketCount > 0 else { return [] }
        var buckets: [TagAnalyticsSnapshot.TrendPoint] = []
        let calendar = Calendar.current

        for i in 0..<window.bucketCount {
            let bucketDate = calendar.date(byAdding: window.calendarComponent, value: -i, to: Date()) ?? Date()
            let inBucket = events.filter { event in
                guard let timestamp = event.timestamp else { return false }
                switch window.calendarComponent {
                case .day:
                    return calendar.isDate(timestamp, inSameDayAs: bucketDate)
                case .month:
                    let targetComp = calendar.dateComponents([.year, .month], from: bucketDate)
                    let eventComp = calendar.dateComponents([.year, .month], from: timestamp)
                    return targetComp == eventComp
                default:
                    return false
                }
            }
            buckets.append(.init(date: bucketDate, count: inBucket.count))
        }

        return buckets.sorted { $0.date < $1.date }
    }

    // MARK: - Cleanup

    func deleteUnusedTags() throws {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "usageCount == 0")
        let unused = try context.fetch(request)
        unused.forEach { context.delete($0) }
        try context.save()
    }
}
