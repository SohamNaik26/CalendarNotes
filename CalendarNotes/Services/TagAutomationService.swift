//
//  TagAutomationService.swift
//  CalendarNotes
//
//  Handles automatic tagging based on URL patterns, content heuristics, ML suggestions,
//  and trending detection.
//

import Foundation
import CoreData

final class TagAutomationService {
    enum RuleType: String {
        case urlPattern
        case keyword
        case contentCategory
        case machineLearning
    }

    @MainActor
    struct RuleDescriptor: Identifiable {
        let id: UUID
        var name: String
        var type: RuleType
        var pattern: String?
        var tags: [String]
        var isEnabled: Bool
        var confidenceThreshold: Double
        var lastMatched: Date?
        var metadata: [String: Any]

        init(rule: TagAutomationRule) {
            id = rule.id ?? UUID()
            name = rule.name ?? "Rule"
            type = RuleType(rawValue: rule.ruleType ?? RuleType.urlPattern.rawValue) ?? .urlPattern
            pattern = rule.pattern
            tags = (rule.tags as? Set<Tag>)?.compactMap { $0.name } ?? []
            isEnabled = rule.isEnabled
            confidenceThreshold = rule.confidenceThreshold?.doubleValue ?? 0.8
            lastMatched = rule.lastMatchedDate
            metadata = (rule.metadataJSON.flatMap { try? JSONSerialization.jsonObject(with: Data($0.utf8)) as? [String: Any] }) ?? [:]
        }
    }

    private let context: NSManagedObjectContext
    private let coreDataManager = CoreDataManager.shared
    private let templateService: TagTemplateService

    init(context: NSManagedObjectContext, templateService: TagTemplateService? = nil) {
        self.context = context
        self.templateService = templateService ?? TagTemplateService(context: context)
    }

    @MainActor
    func allRules() -> [RuleDescriptor] {
        let request: NSFetchRequest<TagAutomationRule> = TagAutomationRule.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
        let rules = (try? context.fetch(request)) ?? []
        return rules.map(RuleDescriptor.init(rule:))
    }

    @discardableResult
    func upsertRule(_ descriptor: RuleDescriptor) throws -> TagAutomationRule {
        let request: NSFetchRequest<TagAutomationRule> = TagAutomationRule.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", descriptor.id as CVarArg)
        request.fetchLimit = 1

        let rule = (try? context.fetch(request))?.first ?? TagAutomationRule(context: context)
        rule.id = descriptor.id
        rule.name = descriptor.name
        rule.ruleType = descriptor.type.rawValue
        rule.pattern = descriptor.pattern
        rule.isEnabled = descriptor.isEnabled
        rule.confidenceThreshold = descriptor.confidenceThreshold as NSNumber
        if let metadataData = try? JSONSerialization.data(withJSONObject: descriptor.metadata, options: []) {
            rule.metadataJSON = String(data: metadataData, encoding: .utf8)
        }
        rule.createdDate = rule.createdDate ?? Date()
        rule.lastMatchedDate = descriptor.lastMatched

        // Replace tags relationship
        if let existing = rule.tags as? Set<Tag>, !existing.isEmpty {
            existing.forEach { rule.removeFromTags($0) }
        }
        for tagName in descriptor.tags {
            if let tag = fetchTag(named: tagName) {
                rule.addToTags(tag)
            }
        }

        try coreDataManager.save()
        return rule
    }

    func deleteRule(id: UUID) throws {
        let request: NSFetchRequest<TagAutomationRule> = TagAutomationRule.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let rule = try context.fetch(request).first {
            context.delete(rule)
            try coreDataManager.save()
        }
    }

    // MARK: - Automation Execution

    func suggestedTags(for bookmark: Bookmark, contentAnalyzer: BookmarkContentAnalyzer) -> [(tag: String, confidence: Double)] {
        var suggestions: [(String, Double)] = []
        suggestions.append(contentsOf: evaluateURLRules(urlString: bookmark.url ?? ""))
        suggestions.append(contentsOf: evaluateKeywordRules(text: bookmark.notes ?? ""))
        suggestions.append(contentsOf: contentAnalyzer.automaticTags(for: bookmark))
        suggestions.append(contentsOf: trendingSuggestions(for: bookmark))

        // Combine duplicates by taking max confidence
        let grouped = Dictionary(grouping: suggestions, by: { $0.0.lowercased() })
        return grouped.compactMap { key, values in
            let best = values.max(by: { $0.1 < $1.1 })
            guard let best else { return nil }
            return (tag: values.first?.0 ?? key, confidence: best.1)
        }
        .sorted { $0.confidence > $1.confidence }
    }

    func applySuggestions(_ suggestions: [(tag: String, confidence: Double)], to bookmark: Bookmark, threshold: Double = 0.7) {
        var tagList = bookmark.decodedTags
        for suggestion in suggestions where suggestion.confidence >= threshold {
            if !tagList.contains(where: { $0.caseInsensitiveCompare(suggestion.tag) == .orderedSame }) {
                tagList.append(suggestion.tag)
            }
        }
        bookmark.decodedTags = tagList
        try? coreDataManager.save()
    }

    private func evaluateURLRules(urlString: String) -> [(String, Double)] {
        guard !urlString.isEmpty else { return [] }
        let request: NSFetchRequest<TagAutomationRule> = TagAutomationRule.fetchRequest()
        request.predicate = NSPredicate(format: "ruleType == %@ AND isEnabled == YES", RuleType.urlPattern.rawValue)
        let rules = (try? context.fetch(request)) ?? []

        return rules.flatMap { rule -> [(String, Double)] in
            guard let pattern = rule.pattern,
                  let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                return []
            }
            let range = NSRange(location: 0, length: urlString.utf16.count)
            guard regex.firstMatch(in: urlString, options: [], range: range) != nil else { return [] }
            let tags = (rule.tags as? Set<Tag>)?.compactMap { $0.name } ?? []
            let confidence = rule.confidenceThreshold?.doubleValue ?? 0.8
            return tags.map { ($0, confidence) }
        }
    }

    private func evaluateKeywordRules(text: String) -> [(String, Double)] {
        guard !text.isEmpty else { return [] }
        let request: NSFetchRequest<TagAutomationRule> = TagAutomationRule.fetchRequest()
        request.predicate = NSPredicate(format: "ruleType == %@ AND isEnabled == YES", RuleType.keyword.rawValue)
        let rules = (try? context.fetch(request)) ?? []
        let lower = text.lowercased()

        return rules.flatMap { rule -> [(String, Double)] in
            guard let pattern = rule.pattern?.lowercased(), !pattern.isEmpty else { return [] }
            guard lower.contains(pattern) else { return [] }
            let tags = (rule.tags as? Set<Tag>)?.compactMap { $0.name } ?? []
            let confidence = max(rule.confidenceThreshold?.doubleValue ?? 0.5, 0.5)
            return tags.map { ($0, confidence) }
        }
    }

    private func trendingSuggestions(for bookmark: Bookmark) -> [(String, Double)] {
        guard let collectionKey = bookmark.collectionName ?? bookmark.collection?.name else { return [] }
        let suggestions = templateService.collectionSuggestions(collectionName: collectionKey)
        return suggestions.map { ($0, 0.6) }
    }

    private func fetchTag(named name: String) -> Tag? {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[cd] %@", name)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }
}

/// Simple heuristic-based content analyzer (placeholder for ML integration).
final class BookmarkContentAnalyzer {
    func automaticTags(for bookmark: Bookmark) -> [(String, Double)] {
        var suggestions: [(String, Double)] = []
        if let urlString = bookmark.url?.lowercased() {
            if urlString.contains("github.com") {
                suggestions.append(("developer", 0.85))
                let stats = bookmark.gitHubStatistics
                if let language = stats.language?.lowercased(), !language.isEmpty {
                    suggestions.append((language, 0.75))
                }
            }
            if urlString.contains("youtube.com") || urlString.contains("youtu.be") {
                suggestions.append(("video", 0.8))
            }
        }

        if let notes = bookmark.notes?.lowercased() {
            if notes.contains("recipe") {
                suggestions.append(("cooking", 0.7))
            }
            if notes.contains("swiftui") {
                suggestions.append(("swiftui", 0.9))
            }
        }
        return suggestions
    }
}
