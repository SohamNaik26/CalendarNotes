//
//  TagManagerViewModel.swift
//  CalendarNotes
//
//  ViewModel for advanced tag management including relationships, analytics,
//  automation, templates, and bulk operations.
//

import Foundation
import SwiftUI
import CoreData
import Combine

@MainActor
final class TagManagerViewModel: ObservableObject {
    // MARK: - Nested Types

    enum FilterMode: String, CaseIterable {
        case and = "AND"
        case or = "OR"
    }

    struct TagUsageStat: Identifiable {
        let id: UUID
        let tag: Tag
        let count: Int
        let percentage: Double
        let lastUsed: Date?
    }

    struct TagNetworkEdge: Identifiable {
        let id: String
        let sourceID: UUID
        let targetID: UUID
        let sourceName: String
        let targetName: String
        let strength: Double

        init(source: Tag, target: Tag, strength: Double) {
            self.sourceID = source.id ?? UUID()
            self.targetID = target.id ?? UUID()
            self.sourceName = source.name ?? source.primaryDisplayName
            self.targetName = target.name ?? target.primaryDisplayName
            self.strength = strength
            self.id = "\(sourceID.uuidString)->\(targetID.uuidString)"
        }
    }

    struct TagUsageHeatmapCell: Identifiable {
        let id = UUID()
        let dayOfWeek: Int // 0 = Sunday
        let hour: Int
        let count: Int
    }

    // MARK: - Published State

    @Published var tags: [Tag] = []
    @Published var searchText: String = "" {
        didSet { loadTags() }
    }
    @Published var selectedTags: Set<Tag> = []
    @Published var filterMode: FilterMode = .or
    @Published var selectedFilterTags: Set<Tag> = []

    @Published var analyticsSnapshot: TagAnalyticsSnapshot?
    @Published var tagUsageStats: [TagUsageStat] = []
    @Published var totalBookmarks: Int = 0

    @Published var networkEdges: [TagNetworkEdge] = []
    @Published var heatmapCells: [TagUsageHeatmapCell] = []
    @Published var templates: [TagTemplateModel] = []
    @Published var automationRules: [TagAutomationService.RuleDescriptor] = []
    @Published var tagGroups: [TagGroup] = []
    @Published var trendingTags: [TagAnalyticsSnapshot.Usage] = []
    @Published var growthTimeline: [TagAnalyticsSnapshot.TrendPoint] = []
    @Published var unusedTags: [TagAnalyticsSnapshot.Usage] = []

    @Published var lastOperationMessage: String?

    // MARK: - Private Dependencies

    private let context: NSManagedObjectContext
    private let coreDataManager = CoreDataManager.shared
    private let relationshipService: TagRelationshipService
    private let analyticsService: TagAnalyticsService
    private let templateService: TagTemplateService
    private let automationService: TagAutomationService
    private let contentAnalyzer = BookmarkContentAnalyzer()

    // MARK: - Initialisation

    init(context: NSManagedObjectContext) {
        self.context = context
        self.relationshipService = TagRelationshipService(context: context)
        self.analyticsService = TagAnalyticsService(context: context)
        self.templateService = TagTemplateService(context: context)
        self.automationService = TagAutomationService(context: context, templateService: templateService)
        loadAllData()
    }

    // MARK: - Public API

    func loadTags() {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        var predicates: [NSPredicate] = []
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let term = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            let predicate = NSPredicate(format: "name CONTAINS[cd] %@ OR normalizedName CONTAINS[cd] %@", term, term)
            predicates.append(predicate)
        }
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        request.sortDescriptors = [
            NSSortDescriptor(key: "usageCount", ascending: false),
            NSSortDescriptor(key: "normalizedName", ascending: true)
        ]

        tags = (try? context.fetch(request)) ?? []
        refreshDerivedData()
    }

    func createTag(name: String, color: String? = nil, groups: [TagGroup] = []) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let tag = Tag(context: context, name: trimmedName, color: color)
        tag.normalizedName = trimmedName.lowercased()
        tag.createdDate = Date()
        tag.lastUsedDate = nil
        for group in groups {
            try relationshipService.add(tag, to: group)
        }

        try coreDataManager.save()
        loadAllData()
        lastOperationMessage = "Created tag \(trimmedName)"
    }

    func renameTag(_ tag: Tag, to newName: String) throws {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }

        let oldName = tag.name ?? ""
        tag.name = trimmedName
        tag.normalizedName = trimmedName.lowercased()

        // Update bookmarks referencing this tag
        let bookmarkRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        let bookmarks = (try? context.fetch(bookmarkRequest)) ?? []
        for bookmark in bookmarks {
            if bookmark.decodedTags.contains(where: { $0.caseInsensitiveCompare(oldName) == .orderedSame }) {
                var tagsList = bookmark.decodedTags
                if let index = tagsList.firstIndex(where: { $0.caseInsensitiveCompare(oldName) == .orderedSame }) {
                    tagsList[index] = trimmedName
                }
                bookmark.decodedTags = tagsList
            }
        }

        try coreDataManager.save()
        loadAllData()
        lastOperationMessage = "Renamed tag to \(trimmedName)"
    }

    func mergeTags(source: Tag, into destination: Tag) throws {
        guard source.objectID != destination.objectID else { return }

        // Move synonyms
        if let sourceSynonyms = source.synonyms as? Set<TagSynonym> {
            for synonym in sourceSynonyms {
                if let value = synonym.value {
                    _ = try? relationshipService.addSynonym(value, kind: .alias, to: destination)
                }
            }
        }
        if let sourceName = source.name, !sourceName.isEmpty {
            _ = try? relationshipService.addSynonym(sourceName, kind: .alias, to: destination)
        }

        // Move groups
        for group in source.tagGroups {
            try relationshipService.add(destination, to: group)
        }

        // Reassign children to destination
        for child in source.childTags {
            child.parent = destination
        }

        // Update bookmarks
        let bookmarkRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        let bookmarks = (try? context.fetch(bookmarkRequest)) ?? []
        for bookmark in bookmarks {
            if bookmark.decodedTags.contains(where: { $0.caseInsensitiveCompare(source.primaryDisplayName) == .orderedSame }) {
                detach(tag: source, from: bookmark)
                attach(tag: destination, to: bookmark)
                logUsageEvent(for: destination, bookmark: bookmark, action: "merged")
            }
        }

        // Record associations
        for association in source.relatedAssociations {
            if let target = association.target, target.objectID != destination.objectID {
                _ = try? relationshipService.recordAssociation(from: destination, to: target, increment: Int(association.coOccurrenceCount))
            }
        }

        context.delete(source)
        try coreDataManager.save()
        loadAllData()
        lastOperationMessage = "Merged tag into \(destination.primaryDisplayName)"
    }

    func splitTag(_ tag: Tag, into names: [String]) throws {
        let trimmed = names.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        guard !trimmed.isEmpty else { return }

        let bookmarkRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        let bookmarks = (try? context.fetch(bookmarkRequest)) ?? []
        var newTags: [Tag] = []

        for name in trimmed {
            let newTag = Tag(context: context, name: name)
            newTag.normalizedName = name.lowercased()
            newTag.createdDate = Date()
            newTag.color = tag.color
            newTag.parent = tag.parent
            newTag.groups = tag.groups
            newTags.append(newTag)
        }

        for bookmark in bookmarks {
            if bookmark.decodedTags.contains(where: { $0.caseInsensitiveCompare(tag.primaryDisplayName) == .orderedSame }) {
                detach(tag: tag, from: bookmark)
                for newTag in newTags {
                    attach(tag: newTag, to: bookmark)
                    logUsageEvent(for: newTag, bookmark: bookmark, action: "split")
                }
            }
        }

        context.delete(tag)
        try coreDataManager.save()
        loadAllData()
        lastOperationMessage = "Split tag into \(trimmed.joined(separator: ", "))"
    }

    func findAndReplaceTags(search: String, replacements: [String], caseInsensitive: Bool = true) throws {
        let trimmedSearch = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSearch.isEmpty else { return }
        let trimmedReplacements = replacements.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

        let bookmarkRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        let bookmarks = (try? context.fetch(bookmarkRequest)) ?? []

        for bookmark in bookmarks {
            var list = bookmark.decodedTags
            let matches = list.enumerated().filter { index, name in
                if caseInsensitive {
                    return name.caseInsensitiveCompare(trimmedSearch) == .orderedSame
                }
                return name == trimmedSearch
            }
            guard !matches.isEmpty else { continue }

            // Remove occurrences
            for (index, _) in matches.reversed() {
                list.remove(at: index)
            }

            // Add replacements
            for replacement in trimmedReplacements where !list.contains(where: { $0.caseInsensitiveCompare(replacement) == .orderedSame }) {
                list.append(replacement)
            }

            bookmark.decodedTags = list

            // Update relations
            if let oldTag = fetchTag(named: trimmedSearch) {
                detach(tag: oldTag, from: bookmark)
            }
            for replacement in trimmedReplacements {
                if let newTag = fetchOrCreateTag(named: replacement) {
                    attach(tag: newTag, to: bookmark)
                    logUsageEvent(for: newTag, bookmark: bookmark, action: "find-replace")
                }
            }
        }

        try coreDataManager.save()
        loadAllData()
        lastOperationMessage = "Replaced \(trimmedSearch)"
    }

    func deleteTag(_ tag: Tag) throws {
        let bookmarkRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        let bookmarks = (try? context.fetch(bookmarkRequest)) ?? []
        for bookmark in bookmarks {
            detach(tag: tag, from: bookmark)
        }
        context.delete(tag)
        try coreDataManager.save()
        loadAllData()
        lastOperationMessage = "Deleted tag"
    }

    func setTagColor(_ tag: Tag, color: String) throws {
        tag.color = color
        try coreDataManager.save()
        loadTags()
        lastOperationMessage = "Updated color"
    }

    func addTagToBookmarks(_ tag: Tag, bookmarks: [Bookmark]) throws {
        for bookmark in bookmarks {
            attach(tag: tag, to: bookmark)
            logUsageEvent(for: tag, bookmark: bookmark, action: "bulk-add")
        }
        try coreDataManager.save()
        refreshDerivedData()
    }

    func removeTagFromBookmarks(_ tag: Tag, bookmarks: [Bookmark]) throws {
        for bookmark in bookmarks {
            detach(tag: tag, from: bookmark)
            logUsageEvent(for: tag, bookmark: bookmark, action: "bulk-remove")
        }
        try coreDataManager.save()
        refreshDerivedData()
    }

    func replaceTagAcrossBookmarks(oldTag: Tag, newTag: Tag) throws {
        let bookmarkRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        let bookmarks = (try? context.fetch(bookmarkRequest)) ?? []
        for bookmark in bookmarks {
            if bookmark.decodedTags.contains(where: { $0.caseInsensitiveCompare(oldTag.primaryDisplayName) == .orderedSame }) {
                detach(tag: oldTag, from: bookmark)
                attach(tag: newTag, to: bookmark)
                logUsageEvent(for: newTag, bookmark: bookmark, action: "bulk-replace")
            }
        }
        try coreDataManager.save()
        refreshDerivedData()
    }

    func applyTemplate(_ template: TagTemplateModel, to bookmarks: [Bookmark]) {
        templateService.applyTemplate(template, to: bookmarks)
        refreshDerivedData()
    }

    func autoTag(_ bookmarks: [Bookmark]) {
        for bookmark in bookmarks {
            let suggestions = automationService.suggestedTags(for: bookmark, contentAnalyzer: contentAnalyzer)
            automationService.applySuggestions(suggestions, to: bookmark)
            for suggestion in suggestions {
                if let tag = fetchOrCreateTag(named: suggestion.tag) {
                    attach(tag: tag, to: bookmark)
                    logUsageEvent(for: tag, bookmark: bookmark, action: "auto-tag")
                }
            }
        }
        try? coreDataManager.save()
        refreshDerivedData()
    }

    func filterBookmarks(by tags: Set<Tag>, mode: FilterMode) throws -> [Bookmark] {
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        let tagNames = tags.flatMap { [$0.primaryDisplayName] + $0.synonymValues }

        guard !tagNames.isEmpty else {
            return (try? context.fetch(request)) ?? []
        }

        if mode == .and {
            var predicates: [NSPredicate] = []
            for tagName in tagNames {
                let relationPredicate = NSPredicate(format: "ANY tagRelations.name ==[cd] %@", tagName)
                let jsonPredicate = NSPredicate(format: "tags CONTAINS[cd] %@", tagName)
                predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [relationPredicate, jsonPredicate]))
            }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        } else {
            var predicates: [NSPredicate] = []
            for tagName in tagNames {
                let relationPredicate = NSPredicate(format: "ANY tagRelations.name ==[cd] %@", tagName)
                let jsonPredicate = NSPredicate(format: "tags CONTAINS[cd] %@", tagName)
                predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [relationPredicate, jsonPredicate]))
            }
            request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        }

        return try context.fetch(request)
    }

    func getPopularTags(limit: Int = 10) -> [Tag] {
        if let snapshot = analyticsSnapshot {
            let ids = Set(snapshot.usageTop.prefix(limit).map { $0.tagID })
            return tags.filter { ids.contains($0.id ?? UUID()) }
        }
        return Array(tags.prefix(limit))
    }

    func getRecentTags(limit: Int = 10) -> [Tag] {
        let sorted = tags.sorted { ($0.lastUsedDate ?? $0.createdDate ?? .distantPast) > ($1.lastUsedDate ?? $1.createdDate ?? .distantPast) }
        return Array(sorted.prefix(limit))
    }

    func exportTags() -> Data? {
        let exportPayload: [[String: Any]] = tags.map { tag in
            [
                "id": tag.id?.uuidString ?? UUID().uuidString,
                "name": tag.name ?? "",
                "color": tag.color ?? "",
                "usageCount": tag.usageCount,
                "synonyms": tag.synonymValues,
                "parent": tag.parentTag?.id?.uuidString as Any,
                "groups": tag.tagGroups.compactMap { $0.name },
                "lastUsed": tag.lastUsedDate?.ISO8601Format() as Any
            ].compactMapValues { $0 }
        }

        let exportDict: [String: Any] = [
            "version": 2,
            "exportDate": Date().ISO8601Format(),
            "tags": exportPayload
        ]

        return try? JSONSerialization.data(withJSONObject: exportDict, options: .prettyPrinted)
    }

    func importTags(from data: Data) throws {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tagsData = json["tags"] as? [[String: Any]] else {
            throw TagImportError.invalidFormat
        }

        for tagDict in tagsData {
            guard let name = tagDict["name"] as? String, !name.isEmpty else { continue }
            let color = tagDict["color"] as? String
            let synonyms = tagDict["synonyms"] as? [String] ?? []
            let groups = tagDict["groups"] as? [String] ?? []

            let tag = fetchOrCreateTag(named: name)
            tag?.color = color
            tag?.normalizedName = name.lowercased()
            tag?.createdDate = tag?.createdDate ?? Date()

            for synonym in synonyms {
                _ = try? relationshipService.addSynonym(synonym, kind: .alias, to: tag ?? Tag(context: context, name: name))
            }

            for groupName in groups {
                let group = try relationshipService.ensureGroup(named: groupName)
                if let tag { try relationshipService.add(tag, to: group) }
            }
        }

        try coreDataManager.save()
        loadAllData()
    }

    func addSynonym(_ value: String, to tag: Tag, kind: TagRelationshipService.SynonymDescriptor.Kind = .alias, confidence: Double = 1.0) {
        do {
            _ = try relationshipService.addSynonym(value, kind: kind, confidence: confidence, to: tag)
            try coreDataManager.save()
            loadAllData()
            lastOperationMessage = "Added synonym"
        } catch {
            lastOperationMessage = "Failed to add synonym"
        }
    }

    func removeSynonym(_ synonym: TagSynonym) {
        do {
            try relationshipService.removeSynonym(synonym)
            try coreDataManager.save()
            loadAllData()
            lastOperationMessage = "Removed synonym"
        } catch {
            lastOperationMessage = "Failed to remove synonym"
        }
    }

    func assignParent(_ parent: Tag?, to child: Tag) {
        do {
            try relationshipService.assignParent(parent, to: child)
            try coreDataManager.save()
            loadAllData()
            lastOperationMessage = parent == nil ? "Cleared parent" : "Updated parent"
        } catch {
            lastOperationMessage = "Failed to update parent"
        }
    }

    func add(tag: Tag, toGroupNamed name: String) {
        do {
            let group = try relationshipService.ensureGroup(named: name)
            try relationshipService.add(tag, to: group)
            try coreDataManager.save()
            refreshGroups()
            lastOperationMessage = "Added to group"
        } catch {
            lastOperationMessage = "Failed to add group"
        }
    }

    func remove(tag: Tag, from group: TagGroup) {
        do {
            try relationshipService.remove(tag, from: group)
            try coreDataManager.save()
            refreshGroups()
            lastOperationMessage = "Removed from group"
        } catch {
            lastOperationMessage = "Failed to remove group"
        }
    }

    func createGroup(name: String, colorHex: String? = nil, icon: String? = nil, description: String? = nil) {
        do {
            _ = try relationshipService.createGroup(
                .init(
                    id: UUID(),
                    name: name,
                    colorHex: colorHex,
                    icon: icon,
                    description: description,
                    sortOrder: 0,
                    isSystem: false
                )
            )
            try coreDataManager.save()
            refreshGroups()
            lastOperationMessage = "Created group"
        } catch {
            lastOperationMessage = "Failed to create group"
        }
    }

    // MARK: - Private Helpers

    private func loadAllData() {
        loadTags()
        refreshDerivedData()
    }

    private func refreshDerivedData() {
        updateStatistics()
        refreshGroups()
        refreshTemplates()
        refreshAutomationRules()
        refreshAnalytics()
    }

    private func updateStatistics() {
        let bookmarkRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        let bookmarks = (try? context.fetch(bookmarkRequest)) ?? []
        totalBookmarks = bookmarks.count

        tagUsageStats = tags.map { tag in
            let id = tag.id ?? UUID()
            let count = Int(tag.usageCount)
            let percentage = totalBookmarks > 0 ? Double(count) / Double(totalBookmarks) * 100 : 0
            return TagUsageStat(id: id, tag: tag, count: count, percentage: percentage, lastUsed: tag.lastUsedDate)
        }.sorted { $0.count > $1.count }
    }

    private func refreshGroups() {
        let request: NSFetchRequest<TagGroup> = TagGroup.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        tagGroups = (try? context.fetch(request)) ?? []
    }

    private func refreshTemplates() {
        templates = templateService.templates()
    }

    private func refreshAutomationRules() {
        automationRules = automationService.allRules()
    }

    private func refreshAnalytics() {
        let snapshot = analyticsService.generateSnapshot(window: .last30Days)
        analyticsSnapshot = snapshot
        trendingTags = snapshot.trendingTags
        growthTimeline = snapshot.growthTimeline
        unusedTags = snapshot.unusedTags
        networkEdges = buildNetworkEdges()
        heatmapCells = buildHeatmapCells()
    }

    private func buildNetworkEdges() -> [TagNetworkEdge] {
        tags.flatMap { tag in
            tag.relatedAssociations.compactMap { association -> TagNetworkEdge? in
                guard let target = association.target, target.objectID != tag.objectID else { return nil }
                let strength = association.strength?.doubleValue ?? 0
                return TagNetworkEdge(source: tag, target: target, strength: strength)
            }
        }
        .sorted { $0.strength > $1.strength }
    }

    private func buildHeatmapCells(window: TagAnalyticsService.SamplingWindow = .last30Days) -> [TagUsageHeatmapCell] {
        let startDate = Date().addingTimeInterval(-window.interval)
        let request: NSFetchRequest<TagUsageEvent> = TagUsageEvent.fetchRequest()
        request.predicate = NSPredicate(format: "timestamp >= %@", startDate as NSDate)
        let events = (try? context.fetch(request)) ?? []
        guard !events.isEmpty else { return [] }

        var buckets: [String: Int] = [:]
        let calendar = Calendar.current
        for event in events {
            guard let timestamp = event.timestamp else { continue }
            let comps = calendar.dateComponents([.weekday, .hour], from: timestamp)
            let day = ((comps.weekday ?? 1) - 1 + 7) % 7
            let hour = comps.hour ?? 0
            let key = "\(day)-\(hour)"
            buckets[key, default: 0] += 1
        }

        return buckets.map { key, value in
            let parts = key.split(separator: "-")
            let day = Int(parts.first ?? "0") ?? 0
            let hour = Int(parts.last ?? "0") ?? 0
            return TagUsageHeatmapCell(dayOfWeek: day, hour: hour, count: value)
        }.sorted { ($0.dayOfWeek, $0.hour) < ($1.dayOfWeek, $1.hour) }
    }

    private func attach(tag: Tag, to bookmark: Bookmark) {
        guard let name = tag.name else { return }
        var list = bookmark.decodedTags
        if !list.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
            list.append(name)
            bookmark.decodedTags = list
        }
        bookmark.mutableSetValue(forKey: "tagRelations").add(tag)
        tag.markUsed()
    }

    private func detach(tag: Tag, from bookmark: Bookmark) {
        guard let name = tag.name else { return }
        var list = bookmark.decodedTags
        list.removeAll { $0.caseInsensitiveCompare(name) == .orderedSame }
        bookmark.decodedTags = list
        bookmark.mutableSetValue(forKey: "tagRelations").remove(tag)
    }

    private func logUsageEvent(for tag: Tag, bookmark: Bookmark?, action: String) {
        let event = TagUsageEvent(context: context)
        event.id = UUID()
        event.tag = tag
        event.timestamp = Date()
        event.action = action
        event.bookmark = bookmark
        event.bookmarkID = bookmark?.id
        event.source = bookmark?.url
    }

    private func fetchOrCreateTag(named name: String) -> Tag? {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[cd] %@", name)
        request.fetchLimit = 1
        if let existing = try? context.fetch(request), let tag = existing.first {
            return tag
        }
        let tag = Tag(context: context, name: name)
        tag.normalizedName = name.lowercased()
        tag.createdDate = Date()
        return tag
    }

    private func fetchTag(named name: String) -> Tag? {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[cd] %@", name)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }
}

enum TagImportError: LocalizedError {
    case invalidFormat

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Invalid tag import format"
        }
    }
}
