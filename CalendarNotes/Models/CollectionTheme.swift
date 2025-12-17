//
//  CollectionTheme.swift
//  CalendarNotes
//
//  Defines theme, layout, and presentation metadata for bookmark collections.
//

import Foundation
struct CollectionTheme: Codable, Equatable {
    enum BackgroundStyle: String, Codable, CaseIterable {
        case solid
        case gradient
        case image
        case pattern
    }

    enum IconStyle: String, Codable, CaseIterable {
        case filled
        case outlined
        case custom
    }

    enum AccentStyle: String, Codable, CaseIterable {
        case subtle
        case vibrant
        case monochrome
        case glass
    }

    var backgroundStyle: BackgroundStyle
    var primaryColorHex: String
    var secondaryColorHex: String?
    var accentColorHex: String?
    var gradientAngle: Double
    var usesVibrancy: Bool
    var iconStyle: IconStyle
    var accentStyle: AccentStyle
    var backgroundImageIdentifier: String?
    var headerImageIdentifier: String?
    var coverImageIdentifier: String?
    var showHeroSection: Bool
    var showBadgeCounts: Bool
    var enableDepthShadow: Bool

    init(
        backgroundStyle: BackgroundStyle = .solid,
        primaryColorHex: String = "#4C6EF5",
        secondaryColorHex: String? = nil,
        accentColorHex: String? = nil,
        gradientAngle: Double = 40,
        usesVibrancy: Bool = false,
        iconStyle: IconStyle = .filled,
        accentStyle: AccentStyle = .subtle,
        backgroundImageIdentifier: String? = nil,
        headerImageIdentifier: String? = nil,
        coverImageIdentifier: String? = nil,
        showHeroSection: Bool = true,
        showBadgeCounts: Bool = true,
        enableDepthShadow: Bool = true
    ) {
        self.backgroundStyle = backgroundStyle
        self.primaryColorHex = primaryColorHex
        self.secondaryColorHex = secondaryColorHex
        self.accentColorHex = accentColorHex
        self.gradientAngle = gradientAngle
        self.usesVibrancy = usesVibrancy
        self.iconStyle = iconStyle
        self.accentStyle = accentStyle
        self.backgroundImageIdentifier = backgroundImageIdentifier
        self.headerImageIdentifier = headerImageIdentifier
        self.coverImageIdentifier = coverImageIdentifier
        self.showHeroSection = showHeroSection
        self.showBadgeCounts = showBadgeCounts
        self.enableDepthShadow = enableDepthShadow
    }
}

struct CollectionPresentationSettings: Codable, Equatable {
    var autoAdvanceEnabled: Bool
    var autoAdvanceInterval: TimeInterval
    var isLooping: Bool
    var includeNotesAsCaptions: Bool
    var includeTagsOverlay: Bool
    var includeAnalyticsOverlay: Bool
    var allowExternalDisplay: Bool
    var exportIncludeNotes: Bool
    var exportIncludeMetadata: Bool

    init(
        autoAdvanceEnabled: Bool = false,
        autoAdvanceInterval: TimeInterval = 10,
        isLooping: Bool = true,
        includeNotesAsCaptions: Bool = true,
        includeTagsOverlay: Bool = true,
        includeAnalyticsOverlay: Bool = false,
        allowExternalDisplay: Bool = true,
        exportIncludeNotes: Bool = true,
        exportIncludeMetadata: Bool = true
    ) {
        self.autoAdvanceEnabled = autoAdvanceEnabled
        self.autoAdvanceInterval = autoAdvanceInterval
        self.isLooping = isLooping
        self.includeNotesAsCaptions = includeNotesAsCaptions
        self.includeTagsOverlay = includeTagsOverlay
        self.includeAnalyticsOverlay = includeAnalyticsOverlay
        self.allowExternalDisplay = allowExternalDisplay
        self.exportIncludeNotes = exportIncludeNotes
        self.exportIncludeMetadata = exportIncludeMetadata
    }
}

struct CollectionStatisticsSnapshot: Codable, Equatable {
    struct DomainCount: Codable, Equatable {
        let domain: String
        let count: Int
    }

    struct TagCount: Codable, Equatable {
        let tag: String
        let count: Int
    }

    var totalBookmarks: Int
    var mostRecentAddedAt: Date?
    var mostVisitedBookmarkID: UUID?
    var topDomains: [DomainCount]
    var tagCloud: [TagCount]
    var generatedAt: Date

    init(
        totalBookmarks: Int = 0,
        mostRecentAddedAt: Date? = nil,
        mostVisitedBookmarkID: UUID? = nil,
        topDomains: [DomainCount] = [],
        tagCloud: [TagCount] = [],
        generatedAt: Date = Date()
    ) {
        self.totalBookmarks = totalBookmarks
        self.mostRecentAddedAt = mostRecentAddedAt
        self.mostVisitedBookmarkID = mostVisitedBookmarkID
        self.topDomains = topDomains
        self.tagCloud = tagCloud
        self.generatedAt = generatedAt
    }
}

enum CollectionLayoutMode: String, CaseIterable, Codable, Identifiable {
    case masonry
    case magazine
    case compactList
    case card
    case timeline
    case kanban

    var id: String { rawValue }
}

struct CollectionFeaturedConfiguration: Codable, Equatable {
    var pinnedBookmarkIDs: [UUID]
    var heroBookmarkID: UUID?
    var featuredBookmarkIDs: [UUID]

    init(
        pinnedBookmarkIDs: [UUID] = [],
        heroBookmarkID: UUID? = nil,
        featuredBookmarkIDs: [UUID] = []
    ) {
        self.pinnedBookmarkIDs = pinnedBookmarkIDs
        self.heroBookmarkID = heroBookmarkID
        self.featuredBookmarkIDs = featuredBookmarkIDs
    }
}


