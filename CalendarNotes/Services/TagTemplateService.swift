//
//  TagTemplateService.swift
//  CalendarNotes
//
//  Manages reusable tag templates and collection-specific suggestions.
//

import Foundation
import CoreData

@MainActor
struct TagTemplateModel: Identifiable, Hashable {
    let id: UUID
    var name: String
    var description: String
    var tags: [String]
    var collectionIdentifier: String?
    var isSystem: Bool
    var createdDate: Date
    var lastUsedDate: Date?

    init(entity: TagTemplateEntity) {
        id = entity.id ?? UUID()
        name = entity.name ?? "Template"
        description = entity.templateDescription ?? ""
        tags = (entity.tags as? Set<Tag>)?.compactMap { $0.name } ?? []
        collectionIdentifier = entity.collectionIdentifier
        isSystem = entity.isSystem
        createdDate = entity.createdDate ?? .distantPast
        lastUsedDate = entity.lastUsedDate
        if tags.isEmpty, let json = entity.tagNamesJSON,
           let data = json.data(using: .utf8),
           let array = try? JSONSerialization.jsonObject(with: data) as? [String] {
            tags = array
        }
    }
}

final class TagTemplateService {
    private let context: NSManagedObjectContext
    private let coreDataManager = CoreDataManager.shared

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    @MainActor
    func templates(for collectionIdentifier: String? = nil) -> [TagTemplateModel] {
        let request: NSFetchRequest<TagTemplateEntity> = TagTemplateEntity.fetchRequest()
        if let collectionIdentifier {
            request.predicate = NSPredicate(
                format: "collectionIdentifier == %@ OR collectionIdentifier == nil",
                collectionIdentifier
            )
        }
        request.sortDescriptors = [
            NSSortDescriptor(key: "isSystem", ascending: false),
            NSSortDescriptor(key: "lastUsedDate", ascending: false)
        ]
        let entities = (try? context.fetch(request)) ?? []
        return entities.map(TagTemplateModel.init(entity:))
    }

    @discardableResult
    func upsertTemplate(name: String,
                        description: String,
                        tags: [String],
                        collectionIdentifier: String? = nil,
                        isSystem: Bool = false,
                        templateID: UUID? = nil) throws -> TagTemplateEntity {
        let request: NSFetchRequest<TagTemplateEntity> = TagTemplateEntity.fetchRequest()
        if let templateID {
            request.predicate = NSPredicate(format: "id == %@", templateID as CVarArg)
        } else {
            request.predicate = NSPredicate(format: "name ==[cd] %@ AND collectionIdentifier == %@", name, collectionIdentifier ?? "")
        }
        request.fetchLimit = 1

        let entity = (try? context.fetch(request))?.first ?? TagTemplateEntity(context: context)
        entity.id = templateID ?? entity.id ?? UUID()
        entity.name = name
        entity.templateDescription = description
        entity.collectionIdentifier = collectionIdentifier
        entity.isSystem = isSystem
        entity.createdDate = entity.createdDate ?? Date()
        entity.lastUsedDate = Date()
        entity.tagNamesJSON = encode(tags: tags)

        // Replace relationship to concrete tags when available
        if let existing = entity.tags as? Set<Tag>, !existing.isEmpty {
            existing.forEach { entity.removeFromTags($0) }
        }
        for tagName in tags {
            if let tag = fetchTag(named: tagName) {
                entity.addToTags(tag)
            }
        }

        try coreDataManager.save()
        return entity
    }

    func deleteTemplate(id: UUID) throws {
        let request: NSFetchRequest<TagTemplateEntity> = TagTemplateEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        if let template = try context.fetch(request).first {
            context.delete(template)
            try coreDataManager.save()
        }
    }

    func applyTemplate(_ template: TagTemplateModel, to bookmarks: [Bookmark]) {
        let tagNames = template.tags
        for bookmark in bookmarks {
            var list = bookmark.decodedTags
            for tag in tagNames where !list.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
                list.append(tag)
            }
            bookmark.decodedTags = list
        }
        try? coreDataManager.save()
    }

    func collectionSuggestions(collectionName: String) -> [String] {
        templates(for: collectionName)
            .flatMap { $0.tags }
            .reduce(into: [:]) { counts, tag in
                counts[tag, default: 0] += 1
            }
            .sorted { $0.value > $1.value }
            .map { $0.key }
    }

    private func encode(tags: [String]) -> String? {
        guard !tags.isEmpty,
              let data = try? JSONSerialization.data(withJSONObject: tags, options: []) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func fetchTag(named name: String) -> Tag? {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[cd] %@", name)
        request.fetchLimit = 1
        return (try? context.fetch(request))?.first
    }
}
