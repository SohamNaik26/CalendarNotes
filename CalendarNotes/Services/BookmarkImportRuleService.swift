//
//  BookmarkImportRuleService.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation
import Combine
import SwiftUI

/// Handles persistence and evaluation of bookmark import automation rules.
@MainActor
final class BookmarkImportRuleService: ObservableObject {
    static let shared = BookmarkImportRuleService()

    @Published private(set) var rules: [BookmarkImportRule]

    private let storage = BookmarkImportRuleStore()

    private init() {
        rules = storage.load()
        normalizePriorities()
    }

    func add(_ rule: BookmarkImportRule) {
        rules.append(rule)
        normalizePriorities()
        storage.persist(rules: rules)
    }

    func update(_ rule: BookmarkImportRule) {
        guard let idx = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[idx] = rule
        normalizePriorities()
        storage.persist(rules: rules)
    }

    func remove(ruleID: UUID) {
        rules.removeAll { $0.id == ruleID }
        normalizePriorities()
        storage.persist(rules: rules)
    }

    func toggle(ruleID: UUID, isEnabled: Bool) {
        guard let idx = rules.firstIndex(where: { $0.id == ruleID }) else { return }
        rules[idx].isEnabled = isEnabled
        storage.persist(rules: rules)
    }

    func moveRule(fromOffsets: IndexSet, toOffset: Int) {
        rules.move(fromOffsets: fromOffsets, toOffset: toOffset)
        normalizePriorities()
        storage.persist(rules: rules)
    }

    func rule(for id: UUID) -> BookmarkImportRule? {
        rules.first(where: { $0.id == id })
    }

    /// Finds all rules that match the given URL, ordered by priority.
    func matchingRules(for urlString: String) -> [BookmarkImportRule] {
        guard let url = URL(string: urlString) else { return [] }
        return rules
            .filter { $0.isEnabled && match(rule: $0, url: url) }
            .sorted { $0.priority > $1.priority }
    }

    private func match(rule: BookmarkImportRule, url: URL) -> Bool {
        switch rule.strategy {
        case .host:
            return url.host?.caseInsensitiveCompare(rule.pattern) == .orderedSame
        case .domain:
            guard let host = url.host?.lowercased() else { return false }
            return host == rule.pattern.lowercased() || host.hasSuffix(".\(rule.pattern.lowercased())")
        case .pathPrefix:
            return url.path.lowercased().hasPrefix(rule.pattern.lowercased())
        case .queryContains:
            guard let query = url.query?.lowercased() else { return false }
            return query.contains(rule.pattern.lowercased())
        case .regex:
            return (try? NSRegularExpression(pattern: rule.pattern, options: [.caseInsensitive]))?
                .firstMatch(in: url.absoluteString, range: NSRange(location: 0, length: url.absoluteString.count)) != nil
        }
    }

    private func normalizePriorities() {
        let sorted = rules.sorted { $0.priority > $1.priority }
        let count = sorted.count
        rules = sorted.enumerated().map { idx, rule in
            var updated = rule
            updated.priority = count - idx
            return updated
        }
    }
}

// MARK: - Persistence

private final class BookmarkImportRuleStore {
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let storageURL: URL

    init() {
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ??
            fileManager.temporaryDirectory
        storageURL = directory.appendingPathComponent("bookmark-import-rules.json")
        encoder.outputFormatting = [.prettyPrinted]
    }

    func load() -> [BookmarkImportRule] {
        guard let data = try? Data(contentsOf: storageURL) else { return [] }
        guard let decoded = try? decoder.decode([BookmarkImportRule].self, from: data) else { return [] }
        return decoded
    }

    func persist(rules: [BookmarkImportRule]) {
        guard let data = try? encoder.encode(rules) else { return }
        try? fileManager.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: storageURL)
    }
}

