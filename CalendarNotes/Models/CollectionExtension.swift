//
//  CollectionExtension.swift
//  CalendarNotes
//

import Foundation
import CoreData

extension Collection {
    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        name: String,
        color: String = "#999999",
        icon: String? = nil,
        sortOrder: Int32 = 0,
        parent: Collection? = nil,
        isSystem: Bool = false,
        systemIdentifier: String? = nil,
        theme: CollectionTheme = CollectionTheme(),
        featuredConfiguration: CollectionFeaturedConfiguration = CollectionFeaturedConfiguration(),
        presentationSettings: CollectionPresentationSettings = CollectionPresentationSettings(),
        layoutMode: CollectionLayoutMode = .masonry,
        heroBookmarkID: UUID? = nil,
        headerImage: Data? = nil,
        coverImage: Data? = nil,
        statisticsSnapshot: CollectionStatisticsSnapshot? = nil
    ) {
        self.init(context: context)
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.sortOrder = sortOrder
        self.parent = parent
        self.isSystem = isSystem
        self.systemIdentifier = systemIdentifier
        self.themeJSON = Collection.encodeTheme(theme)
        self.featuredConfigurationJSON = Collection.encodeFeaturedConfiguration(featuredConfiguration)
        self.presentationSettingsJSON = Collection.encodePresentationSettings(presentationSettings)
        self.statisticsCacheJSON = Collection.encodeStatistics(statisticsSnapshot)
        self.preferredLayoutMode = layoutMode.rawValue
        self.heroBookmarkID = heroBookmarkID ?? featuredConfiguration.heroBookmarkID
        self.headerImage = headerImage
        self.coverImage = coverImage
    }

    var isProjectCollection: Bool {
        isProject
    }

    var projectStatusValue: ProjectStatus {
        get { ProjectStatus(rawValue: projectStatusRawValue ?? ProjectStatus.planning.rawValue) ?? .planning }
        set { projectStatusRawValue = newValue.rawValue }
    }

    var projectProgress: Double {
        get {
            let stored = self.value(forKey: "projectProgressValue") as? NSNumber
            return min(max(stored?.doubleValue ?? 0, 0), 1)
        }
        set {
            let clamped = min(max(newValue, 0), 1)
            setValue(NSNumber(value: clamped), forKey: "projectProgressValue")
        }
    }

    var projectSummaryText: String {
        get { projectSummary ?? "" }
        set { projectSummary = newValue.isEmpty ? nil : newValue }
    }

    var projectMilestonesOrdered: [ProjectMilestone] {
        let milestonesSet = milestones as? Set<ProjectMilestone> ?? []
        return milestonesSet.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                let leftDate = lhs.dueDate ?? .distantFuture
                let rightDate = rhs.dueDate ?? .distantFuture
                return leftDate < rightDate
            }
            return lhs.sortOrder < rhs.sortOrder
        }
    }

    func updateProgressFromMilestones() {
        let items = projectMilestonesOrdered
        guard !items.isEmpty else {
            setValue(nil, forKey: "projectProgressValue")
            return
        }
        let completed = items.filter { $0.isCompleted }.count
        projectProgress = Double(completed) / Double(items.count)
    }

    var recommendationSettingsValue: RecommendationSettings {
        if let existing = recommendationSettings {
            return existing
        }
        let settings = RecommendationSettings(context: managedObjectContext ?? CoreDataManager.shared.viewContext)
        settings.id = UUID()
        settings.createdDate = Date()
        settings.updatedDate = Date()
        settings.frequency = 1
        settings.notificationsEnabled = true
        settings.allowSimilarContent = true
        settings.allowReadingPattern = true
        settings.allowTagAffinity = true
        settings.allowDomainFrequency = true
        settings.allowTrending = true
        settings.allowRediscovery = true
        settings.allowSerendipity = true
        settings.collection = self
        return settings
    }

    var isReadLaterCollection: Bool {
        systemIdentifier == ReadLaterService.Constants.systemIdentifier
    }

    var themeConfiguration: CollectionTheme {
        get { Collection.decodeTheme(themeJSON) ?? CollectionTheme() }
        set { themeJSON = Collection.encodeTheme(newValue) }
    }

    var featuredConfiguration: CollectionFeaturedConfiguration {
        get { Collection.decodeFeaturedConfiguration(featuredConfigurationJSON) ?? CollectionFeaturedConfiguration(heroBookmarkID: heroBookmarkID) }
        set {
            featuredConfigurationJSON = Collection.encodeFeaturedConfiguration(newValue)
            heroBookmarkID = newValue.heroBookmarkID
        }
    }

    var presentationSettings: CollectionPresentationSettings {
        get { Collection.decodePresentationSettings(presentationSettingsJSON) ?? CollectionPresentationSettings() }
        set { presentationSettingsJSON = Collection.encodePresentationSettings(newValue) }
    }

    var statisticsSnapshot: CollectionStatisticsSnapshot? {
        get { Collection.decodeStatistics(statisticsCacheJSON) }
        set { statisticsCacheJSON = Collection.encodeStatistics(newValue) }
    }

    var layoutMode: CollectionLayoutMode {
        get { CollectionLayoutMode(rawValue: preferredLayoutMode ?? "") ?? .masonry }
        set { preferredLayoutMode = newValue.rawValue }
    }

    var pinnedBookmarkIDs: [UUID] {
        get { featuredConfiguration.pinnedBookmarkIDs }
        set {
            var config = featuredConfiguration
            config.pinnedBookmarkIDs = newValue
            featuredConfiguration = config
        }
    }

    var featuredBookmarkIDs: [UUID] {
        get { featuredConfiguration.featuredBookmarkIDs }
        set {
            var config = featuredConfiguration
            config.featuredBookmarkIDs = newValue
            featuredConfiguration = config
        }
    }
}

extension Collection {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func encodeTheme(_ theme: CollectionTheme?) -> String? {
        guard let theme else { return nil }
        return try? encoder.encode(theme).base64EncodedString()
    }

    static func decodeTheme(_ encoded: String?) -> CollectionTheme? {
        guard
            let encoded,
            let data = Data(base64Encoded: encoded),
            let theme = try? decoder.decode(CollectionTheme.self, from: data)
        else {
            return nil
        }
        return theme
    }

    static func encodePresentationSettings(_ settings: CollectionPresentationSettings?) -> String? {
        guard let settings else { return nil }
        return try? encoder.encode(settings).base64EncodedString()
    }

    static func decodePresentationSettings(_ encoded: String?) -> CollectionPresentationSettings? {
        guard
            let encoded,
            let data = Data(base64Encoded: encoded),
            let settings = try? decoder.decode(CollectionPresentationSettings.self, from: data)
        else {
            return nil
        }
        return settings
    }

    static func encodeStatistics(_ snapshot: CollectionStatisticsSnapshot?) -> String? {
        guard let snapshot else { return nil }
        return try? encoder.encode(snapshot).base64EncodedString()
    }

    static func decodeStatistics(_ encoded: String?) -> CollectionStatisticsSnapshot? {
        guard
            let encoded,
            let data = Data(base64Encoded: encoded),
            let snapshot = try? decoder.decode(CollectionStatisticsSnapshot.self, from: data)
        else {
            return nil
        }
        return snapshot
    }

    static func encodeFeaturedConfiguration(_ configuration: CollectionFeaturedConfiguration?) -> String? {
        guard let configuration else { return nil }
        return try? encoder.encode(configuration).base64EncodedString()
    }

    static func decodeFeaturedConfiguration(_ encoded: String?) -> CollectionFeaturedConfiguration? {
        guard
            let encoded,
            let data = Data(base64Encoded: encoded),
            let configuration = try? decoder.decode(CollectionFeaturedConfiguration.self, from: data)
        else {
            return nil
        }
        return configuration
    }

}


