//
//  TagRelationshipService.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 2025-11-12.
//

import Foundation
import CoreData

/// Service responsible for managing advanced tag relationships including synonyms,
/// hierarchical trees, groups, and related-tag associations.
final class TagRelationshipService {
    enum TagRelationshipError: Error {
        case tagNotFound
        case invalidSynonym
        case duplicateGroup
        case invalidHierarchy
        case associationConflict
    }

    struct SynonymDescriptor: Hashable {
        enum Kind: String { case alias, translation, abbreviation, custom }
        var value: String
        var kind: Kind
        var confidence: Double
        var createdAt: Date
    }

    struct GroupDescriptor: Hashable {
        var id: UUID
        var name: String
        var colorHex: String?
        var icon: String?
        var description: String?
        var sortOrder: Int
        var isSystem: Bool
    }

    struct AssociationDescriptor: Hashable {
        var id: UUID
        var sourceID: UUID
        var targetID: UUID
        var coOccurrenceCount: Int
        var strength: Double
        var lastComputed: Date?
    }

    private let context: NSManagedObjectContext
    private let coreDataManager = CoreDataManager.shared

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Synonyms

    @discardableResult
    func addSynonym(_ value: String,
                    kind: SynonymDescriptor.Kind = .alias,
                    confidence: Double = 1.0,
                    to tag: Tag) throws -> TagSynonym {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TagRelationshipError.invalidSynonym }

        if let existing = tag.synonyms?.compactMap({ $0 as? TagSynonym }).first(where: { $0.value?.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            existing.confidence = confidence as NSNumber
            existing.type = kind.rawValue
            try coreDataManager.save()
            return existing
        }

        let synonym = TagSynonym(context: context)
        synonym.id = UUID()
        synonym.value = trimmed
        synonym.type = kind.rawValue
        synonym.createdDate = Date()
        synonym.confidence = confidence as NSNumber
        synonym.tag = tag

        try coreDataManager.save()
        return synonym
    }

    func removeSynonym(_ synonym: TagSynonym) throws {
        context.delete(synonym)
        try coreDataManager.save()
    }

    func synonyms(for tag: Tag) -> [SynonymDescriptor] {
        guard let rawSynonyms = tag.synonyms as? Set<TagSynonym> else { return [] }
        return rawSynonyms
            .sorted { ($0.createdDate ?? .distantPast) < ($1.createdDate ?? .distantPast) }
            .map { synonym in
                SynonymDescriptor(
                    value: synonym.value ?? "",
                    kind: SynonymDescriptor.Kind(rawValue: synonym.type ?? SynonymDescriptor.Kind.alias.rawValue) ?? .alias,
                    confidence: synonym.confidence?.doubleValue ?? 1.0,
                    createdAt: synonym.createdDate ?? .distantPast
                )
            }
    }

    // MARK: - Hierarchy

    func assignParent(_ parent: Tag?, to child: Tag) throws {
        guard parent?.objectID != child.objectID else {
            throw TagRelationshipError.invalidHierarchy
        }
        child.parent = parent
        try coreDataManager.save()
    }

    func descendants(of tag: Tag, depth: Int = 3) -> [Tag] {
        guard depth > 0, let children = tag.children as? Set<Tag>, !children.isEmpty else {
            return []
        }
        var result: [Tag] = []
        for child in children {
            result.append(child)
            result.append(contentsOf: descendants(of: child, depth: depth - 1))
        }
        return Array(Set(result))
    }

    func ancestors(of tag: Tag) -> [Tag] {
        var result: [Tag] = []
        var current = tag.parent
        while let parent = current, !result.contains(where: { $0.objectID == parent.objectID }) {
            result.append(parent)
            current = parent.parent
        }
        return result
    }

    // MARK: - Groups

    @discardableResult
    func createGroup(_ descriptor: GroupDescriptor) throws -> TagGroup {
        let group = TagGroup(context: context)
        group.id = descriptor.id
        group.name = descriptor.name
        group.color = descriptor.colorHex
        group.icon = descriptor.icon
        group.groupDescription = descriptor.description
        group.sortOrder = Int32(descriptor.sortOrder)
        group.isSystem = descriptor.isSystem
        try coreDataManager.save()
        return group
    }

    func ensureGroup(named name: String) throws -> TagGroup {
        if let existing = fetchGroup(named: name) { return existing }
        return try createGroup(
            GroupDescriptor(
                id: UUID(),
                name: name,
                colorHex: nil,
                icon: nil,
                description: nil,
                sortOrder: 0,
                isSystem: false
            )
        )
    }

    func fetchGroup(named name: String) -> TagGroup? {
        let request: NSFetchRequest<TagGroup> = TagGroup.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[cd] %@", name)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }

    func add(_ tag: Tag, to group: TagGroup) throws {
        let groups = tag.groups?.adding(group) as? NSSet ?? NSSet(object: group)
        tag.groups = groups
        try coreDataManager.save()
    }

    func remove(_ tag: Tag, from group: TagGroup) throws {
        guard let groups = tag.groups as? Set<TagGroup> else { return }
        tag.groups = NSSet(set: groups.filter { $0.objectID != group.objectID })
        try coreDataManager.save()
    }

    func groups(for tag: Tag) -> [TagGroup] {
        (tag.groups as? Set<TagGroup>)?.sorted { $0.name ?? "" < $1.name ?? "" } ?? []
    }

    // MARK: - Associations

    @discardableResult
    func recordAssociation(from source: Tag, to target: Tag, increment: Int = 1) throws -> TagAssociation {
        guard source.objectID != target.objectID else {
            throw TagRelationshipError.associationConflict
        }

        let request: NSFetchRequest<TagAssociation> = TagAssociation.fetchRequest()
        request.predicate = NSPredicate(format: "source == %@ AND target == %@", source, target)
        request.fetchLimit = 1

        let association = (try? context.fetch(request))?.first ?? TagAssociation(context: context)
        if association.source == nil {
            association.id = UUID()
            association.source = source
            association.target = target
        }

        let newCount = Int(association.coOccurrenceCount) + increment
        association.coOccurrenceCount = Int32(max(newCount, 0))
        association.lastComputed = Date()
        association.strength = NSNumber(value: Double(max(association.coOccurrenceCount, 0)) / Double(max(source.usageCount, 1)))

        try coreDataManager.save()
        return association
    }

    func relatedTags(for tag: Tag, minimumStrength: Double = 0.05, limit: Int = 10) -> [Tag] {
        guard let outbound = tag.associationsAsSource as? Set<TagAssociation>, !outbound.isEmpty else {
            return []
        }

        return outbound
            .filter { ($0.strength?.doubleValue ?? 0) >= minimumStrength }
            .sorted { ($0.strength?.doubleValue ?? 0) > ($1.strength?.doubleValue ?? 0) }
            .compactMap { $0.target }
            .prefix(limit)
            .map { $0 }
    }
}
