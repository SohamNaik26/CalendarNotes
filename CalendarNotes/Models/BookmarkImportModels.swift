//
//  BookmarkImportModels.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation
import UniformTypeIdentifiers

/// Describes the mechanism that originated a bookmark import.
enum BookmarkImportSourceType: String, Codable, CaseIterable, Identifiable {
    case browserExtension
    case browserTabs
    case browserFolder
    case clipboardWatcher
    case emailIngest
    case rssFeed
    case pocket
    case instapaper
    case readItLater
    case textFile
    case pdf
    case emailFile
    case noteFile
    case manualUpload

    var id: String { rawValue }

    /// Human readable name for UI.
    var displayName: String {
        switch self {
        case .browserExtension: return "Browser Extension"
        case .browserTabs: return "Open Tabs"
        case .browserFolder: return "Browser Folder"
        case .clipboardWatcher: return "Clipboard Watcher"
        case .emailIngest: return "Email"
        case .rssFeed: return "RSS Feed"
        case .pocket: return "Pocket"
        case .instapaper: return "Instapaper"
        case .readItLater: return "Read-it-later"
        case .textFile: return "Text File"
        case .pdf: return "PDF"
        case .emailFile: return "Email File"
        case .noteFile: return "Notes"
        case .manualUpload: return "Manual"
        }
    }
}

/// Lifecycle state of an import job.
enum BookmarkImportJobStatus: String, Codable {
    case queued
    case running
    case completed
    case failed
    case cancelled
    case rolledBack
}

/// Metadata for a single import job; persisted for history and rollbacks.
struct BookmarkImportJob: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    var completedAt: Date?
    var source: BookmarkImportSourceType
    var itemCount: Int
    var status: BookmarkImportJobStatus
    var summary: String
    var errorDescription: String?
    var optionsSummary: [String: String]
    var artifactURL: URL?
    var relatedFileTypes: [UTType]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        completedAt: Date? = nil,
        source: BookmarkImportSourceType,
        itemCount: Int = 0,
        status: BookmarkImportJobStatus = .queued,
        summary: String = "",
        errorDescription: String? = nil,
        optionsSummary: [String: String] = [:],
        artifactURL: URL? = nil,
        relatedFileTypes: [UTType] = []
    ) {
        self.id = id
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.source = source
        self.itemCount = itemCount
        self.status = status
        self.summary = summary
        self.errorDescription = errorDescription
        self.optionsSummary = optionsSummary
        self.artifactURL = artifactURL
        self.relatedFileTypes = relatedFileTypes
    }
}

/// Lightweight representation of a rule that should be evaluated for imported URLs.
struct BookmarkImportRule: Identifiable, Codable, Hashable {
    enum Action: String, Codable, CaseIterable {
        case assignCollection
        case addTags
        case skip
        case archive
        case updateExisting
    }

    enum MatchStrategy: String, Codable, CaseIterable {
        case host
        case domain
        case pathPrefix
        case regex
        case queryContains
    }

    let id: UUID
    var name: String
    var strategy: MatchStrategy
    var pattern: String
    var actions: [Action]
    var parameters: [String: String]
    var isEnabled: Bool
    var priority: Int

    init(
        id: UUID = UUID(),
        name: String,
        strategy: MatchStrategy,
        pattern: String,
        actions: [Action],
        parameters: [String: String] = [:],
        isEnabled: Bool = true,
        priority: Int = 0
    ) {
        self.id = id
        self.name = name
        self.strategy = strategy
        self.pattern = pattern
        self.actions = actions
        self.parameters = parameters
        self.isEnabled = isEnabled
        self.priority = priority
    }
}

/// Request payload when performing an import from an external service.
struct BookmarkExternalImportRequest {
    let source: BookmarkImportSourceType
    let payload: Data?
    let contextDescription: String
    let options: ImportOptions
}

