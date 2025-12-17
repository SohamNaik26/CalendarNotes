//
//  TagExtension.swift
//  CalendarNotes
//

import Foundation
import CoreData

extension Tag {
    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        name: String,
        color: String? = nil,
        usageCount: Int32 = 0
    ) {
        self.init(context: context)
        self.id = id
        self.name = name
        self.color = color
        self.usageCount = usageCount
    }

    var synonymValues: [String] {
        (synonyms as? Set<TagSynonym>)?.compactMap { $0.value } ?? []
    }

    var primaryDisplayName: String {
        name ?? synonymValues.first ?? "Untitled"
    }

    var normalizedDisplayName: String {
        let base = primaryDisplayName.lowercased()
        if let normalizedName, !normalizedName.isEmpty {
            return normalizedName
        }
        return base
    }

    var parentTag: Tag? {
        parent
    }

    var childTags: [Tag] {
        (children as? Set<Tag>)?.sorted { ($0.name ?? "") < ($1.name ?? "") } ?? []
    }

    var tagGroups: [TagGroup] {
        (groups as? Set<TagGroup>)?.sorted { ($0.name ?? "") < ($1.name ?? "") } ?? []
    }

    var relatedAssociations: [TagAssociation] {
        let outbound = (associationsAsSource as? Set<TagAssociation>) ?? []
        let inbound = (associationsAsTarget as? Set<TagAssociation>) ?? []
        return Array(outbound.union(inbound))
    }

    func markUsed(on date: Date = Date()) {
        lastUsedDate = date
        usageCount += 1
    }
}

// Note: Tag already conforms to Identifiable through Core Data generated code


