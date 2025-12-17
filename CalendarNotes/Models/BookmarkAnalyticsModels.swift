//
//  BookmarkAnalyticsModels.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation

struct BookmarkAnalyticsSnapshot: Codable, Hashable {
    var generatedAt: Date
    var totalsSeries: [BookmarkMetricPoint]
    var collections: [BookmarkCategoricalMetric]
    var domains: [BookmarkCategoricalMetric]
    var tags: [BookmarkCategoricalMetric]
    var readingHeatmap: [BookmarkHeatmapCell]
    var behavioral: BookmarkBehavioralAnalytics
    var collectionsAnalytics: [BookmarkCollectionInsight]
    var tagAnalytics: [BookmarkTagInsight]
    var personalInsights: [BookmarkInsight]

    static func placeholder() -> BookmarkAnalyticsSnapshot {
        BookmarkAnalyticsSnapshot(
            generatedAt: Date(),
            totalsSeries: BookmarkMetricPoint.placeholderSeries(days: 14),
            collections: [
                BookmarkCategoricalMetric(label: "Articles", value: 28),
                BookmarkCategoricalMetric(label: "Videos", value: 12),
                BookmarkCategoricalMetric(label: "Research", value: 9)
            ],
            domains: [
                BookmarkCategoricalMetric(label: "example.com", value: 10),
                BookmarkCategoricalMetric(label: "news.site", value: 8),
                BookmarkCategoricalMetric(label: "dev.blog", value: 6)
            ],
            tags: [
                BookmarkCategoricalMetric(label: "swift", value: 12),
                BookmarkCategoricalMetric(label: "productivity", value: 9),
                BookmarkCategoricalMetric(label: "reading", value: 7)
            ],
            readingHeatmap: BookmarkHeatmapCell.placeholderWeek(),
            behavioral: BookmarkBehavioralAnalytics(
                mostActiveHours: [BookmarkCategoricalMetric(label: "09", value: 6), BookmarkCategoricalMetric(label: "21", value: 5)],
                mostActiveDays: [BookmarkCategoricalMetric(label: "Tue", value: 7), BookmarkCategoricalMetric(label: "Thu", value: 6)],
                averagePerWeek: 14,
                readingPatterns: [BookmarkCategoricalMetric(label: "Morning", value: 0.6), BookmarkCategoricalMetric(label: "Evening", value: 0.4)],
                completionRate: 0.52
            ),
            collectionsAnalytics: [
                BookmarkCollectionInsight(title: "Fastest Growing", detail: "Articles (+8 this week)", score: 0.8),
                BookmarkCollectionInsight(title: "Most Organized", detail: "Research (92% tagged)", score: 0.9)
            ],
            tagAnalytics: [
                BookmarkTagInsight(name: "swift", trend: .rising, changeValue: 0.22),
                BookmarkTagInsight(name: "ai", trend: .emerging, changeValue: 0.35)
            ],
            personalInsights: [
                BookmarkInsight(title: "Reading Habits", detail: "You save most bookmarks on weekday mornings."),
                BookmarkInsight(title: "Favorite Topics", detail: "Swift, productivity, and research content dominate your reading list." )
            ]
        )
    }
}

struct BookmarkMetricPoint: Codable, Hashable {
    var date: Date
    var value: Double

    static func placeholderSeries(days: Int) -> [BookmarkMetricPoint] {
        let calendar = Calendar.current
        return (0..<days).compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { return nil }
            return BookmarkMetricPoint(date: date, value: Double.random(in: 10...40))
        }.sorted { $0.date < $1.date }
    }
}

struct BookmarkCategoricalMetric: Codable, Hashable, Identifiable {
    var label: String
    var value: Double
    var id: String { label }
}

struct BookmarkHeatmapCell: Codable, Hashable, Identifiable {
    var weekday: Int
    var hour: Int
    var count: Int
    var id: String { "\(weekday)-\(hour)" }

    static func placeholderWeek() -> [BookmarkHeatmapCell] {
        (0..<7).flatMap { day in
            (0..<24).compactMap { hour -> BookmarkHeatmapCell? in
                let count = Int.random(in: 0...5)
                guard count > 0 else { return nil }
                return BookmarkHeatmapCell(weekday: day, hour: hour, count: count)
            }
        }
    }
}

struct BookmarkBehavioralAnalytics: Codable, Hashable {
    var mostActiveHours: [BookmarkCategoricalMetric]
    var mostActiveDays: [BookmarkCategoricalMetric]
    var averagePerWeek: Double
    var readingPatterns: [BookmarkCategoricalMetric]
    var completionRate: Double
}

struct BookmarkCollectionInsight: Codable, Hashable, Identifiable {
    var title: String
    var detail: String
    var score: Double
    var id: String { title }
}

struct BookmarkTagInsight: Codable, Hashable, Identifiable {
    enum Trend: String, Codable {
        case rising
        case stable
        case declining
        case emerging
    }

    var name: String
    var trend: Trend
    var changeValue: Double
    var id: String { name }
}

struct BookmarkInsight: Codable, Hashable, Identifiable {
    var title: String
    var detail: String
    var id: String { title }
}
