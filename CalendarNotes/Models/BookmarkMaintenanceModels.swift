//
//  BookmarkMaintenanceModels.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation

struct BookmarkHealthSnapshot: Codable, Hashable {
    var generatedAt: Date
    var healthScore: Double
    var brokenLinks: Int
    var totalBookmarks: Int
    var duplicateGroups: Int
    var untaggedCount: Int
    var unassignedCount: Int
    var staleCount: Int
    var suggestions: [BookmarkHealthSuggestion]

    static func placeholder() -> BookmarkHealthSnapshot {
        BookmarkHealthSnapshot(
            generatedAt: Date(),
            healthScore: 76,
            brokenLinks: 5,
            totalBookmarks: 420,
            duplicateGroups: 3,
            untaggedCount: 48,
            unassignedCount: 21,
            staleCount: 67,
            suggestions: [
                BookmarkHealthSuggestion(title: "Add tags", detail: "48 bookmarks are untagged.", action: .openCleanup(type: .untagged)),
                BookmarkHealthSuggestion(title: "Fix links", detail: "5 bookmarks have unreachable URLs.", action: .openLinkChecker),
                BookmarkHealthSuggestion(title: "Review duplicates", detail: "3 duplicate groups detected.", action: .openDuplicates)
            ]
        )
    }
}

struct BookmarkHealthSuggestion: Codable, Hashable, Identifiable {
    enum Action: Codable, Hashable {
        case openLinkChecker
        case openDuplicates
        case openCleanup(type: CleanupCategory)
    }

    var title: String
    var detail: String
    var action: Action
    var id: String { title }
}

enum CleanupCategory: String, Codable, CaseIterable, Identifiable {
    case untagged
    case noCollection
    case neverOpened
    case missingMetadata
    case orphanedPreviews

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .untagged: return "Untagged"
        case .noCollection: return "No Collection"
        case .neverOpened: return "Never Opened"
        case .missingMetadata: return "Missing Metadata"
        case .orphanedPreviews: return "Orphaned Previews"
        }
    }
}

struct MaintenanceTaskSummary: Codable, Hashable, Identifiable {
    enum TaskType: String, Codable {
        case linkCheck
        case duplicateScan
        case cleanup
        case autoArchive
    }

    let id: UUID
    var type: TaskType
    var lastRun: Date?
    var nextRun: Date?
    var status: MaintenanceTaskStatus

    init(id: UUID = UUID(), type: TaskType, lastRun: Date? = nil, nextRun: Date? = nil, status: MaintenanceTaskStatus = .idle) {
        self.id = id
        self.type = type
        self.lastRun = lastRun
        self.nextRun = nextRun
        self.status = status
    }
}

enum MaintenanceTaskStatus: String, Codable {
    case idle
    case running
    case scheduled
    case failed
}

struct BrokenLinkRecord: Codable, Hashable, Identifiable {
    let id: UUID
    let bookmarkID: UUID
    let url: String
    let statusCode: Int?
    let lastChecked: Date
    let failureReason: String?
    let waybackURL: URL?

    init(id: UUID = UUID(), bookmarkID: UUID, url: String, statusCode: Int? = nil, lastChecked: Date = Date(), failureReason: String? = nil, waybackURL: URL? = nil) {
        self.id = id
        self.bookmarkID = bookmarkID
        self.url = url
        self.statusCode = statusCode
        self.lastChecked = lastChecked
        self.failureReason = failureReason
        self.waybackURL = waybackURL
    }
}

struct DuplicateBookmarkGroup: Codable, Hashable, Identifiable {
    enum Strategy: String, Codable {
        case mostRecent
        case oldest
        case mostTagged
    }

    let id: UUID
    var bookmarkIDs: [UUID]
    var representativeID: UUID?
    var similarityScore: Double
    var strategy: Strategy

    init(id: UUID = UUID(), bookmarkIDs: [UUID], representativeID: UUID? = nil, similarityScore: Double, strategy: Strategy = .mostRecent) {
        self.id = id
        self.bookmarkIDs = bookmarkIDs
        self.representativeID = representativeID
        self.similarityScore = similarityScore
        self.strategy = strategy
    }
}
