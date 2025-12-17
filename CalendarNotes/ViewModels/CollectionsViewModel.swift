//
//  CollectionsViewModel.swift
//  CalendarNotes
//

import Foundation
import Combine
import CoreData

@MainActor
final class CollectionsViewModel: ObservableObject {
    enum SystemCollection: CaseIterable, Identifiable {
        case all, favorites, recent, readLater, archive, untagged
        var id: String { key }
        var title: String {
            switch self {
            case .all: return "All Bookmarks"
            case .favorites: return "Favorites ⭐"
            case .recent: return "Recent 🕐"
            case .readLater: return "Read Later 📚"
            case .archive: return "Archive 📦"
            case .untagged: return "Untagged"
            }
        }
        var key: String { String(describing: self) }
    }

    struct Node: Identifiable, Hashable {
        let id: UUID
        var name: String
        var icon: String
        var colorHex: String
        var depth: Int
        var children: [Node]
        var count: Int
        var isSystem: Bool
        var system: SystemCollection?
        var childrenOptional: [Node]? { children.isEmpty ? nil : children }
    }

    @Published private(set) var rootNodes: [Node] = []
    @Published private(set) var query: String = ""

    private let core = CoreDataManager.shared
    private let context: NSManagedObjectContext
    private var allNodes: [Node] = []

    init(context: NSManagedObjectContext) { self.context = context }

    func reload() async {
        var nodes: [Node] = []
        for sys in SystemCollection.allCases {
            nodes.append(Node(
                id: UUID(),
                name: sys.title,
                icon: "folder",
                colorHex: "#888888",
                depth: 0,
                children: [],
                count: countFor(system: sys),
                isSystem: true,
                system: sys
            ))
        }

        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "sortOrder", ascending: true),
            NSSortDescriptor(key: "name", ascending: true)
        ]
        request.includesPendingChanges = false
        request.returnsObjectsAsFaults = false
        request.relationshipKeyPathsForPrefetching = ["children", "parent"]

        let collections = (try? context.fetch(request)) ?? []
        let byParent = Dictionary(grouping: collections, by: { $0.parent?.objectID })
        let roots = byParent[nil] ?? []

        func makeNode(_ coll: Collection, depth: Int) -> Node {
            let children = (byParent[coll.objectID] ?? []).map { makeNode($0, depth: depth + 1) }
            let count = countFor(collection: coll)
            let theme = coll.themeConfiguration
            let icon = coll.icon ?? (theme.iconStyle == .outlined ? "folder" : "folder.fill")
            let colorHex = theme.primaryColorHex.isEmpty ? (coll.color ?? "#999999") : theme.primaryColorHex
            return Node(
                id: coll.id ?? UUID(),
                name: coll.name ?? "Collection",
                icon: icon,
                colorHex: colorHex,
                depth: depth,
                children: children,
                count: count,
                isSystem: false,
                system: nil
            )
        }

        nodes.append(contentsOf: roots.map { makeNode($0, depth: 0) })
        allNodes = nodes
        applySearchFilter()
    }

    func updateSearch(_ text: String) {
        query = text
        applySearchFilter()
    }

    private func filter(_ nodes: [Node], by query: String) -> [Node] {
        nodes.compactMap { node in
            let match = node.name.localizedCaseInsensitiveContains(query)
            let filteredChildren = filter(node.children, by: query)
            if match || !filteredChildren.isEmpty {
                var copy = node
                copy.children = filteredChildren
                return copy
            }
            return nil
        }
    }

    private func countFor(system: SystemCollection) -> Int {
        switch system {
        case .all:
            return countBookmarks(matching: nil)
        case .favorites:
            return countBookmarks(matching: NSPredicate(format: "isFavorite == YES"))
        case .recent:
            let cutoff = Date().addingTimeInterval(-7 * 24 * 3600)
            return countBookmarks(matching: NSPredicate(format: "createdDate >= %@", cutoff as NSDate))
        case .readLater:
            return countBookmarks(matching: NSPredicate(format: "isReadLater == YES"))
        case .archive:
            return countBookmarks(matching: NSPredicate(format: "isArchived == YES"))
        case .untagged:
            let emptyTags = NSPredicate(format: "tags == nil OR tags == ''")
            let noRelations = NSPredicate(format: "SUBQUERY(tagRelations, $tag, TRUEPREDICATE).@count == 0")
            return countBookmarks(matching: NSCompoundPredicate(andPredicateWithSubpredicates: [emptyTags, noRelations]))
        }
    }

    func rename(_ node: Node, to newName: String) {
        guard !node.isSystem else { return }
        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", node.id as CVarArg)
        if let coll = (try? context.fetch(request))?.first {
            coll.name = newName
            try? core.save()
        }
    }

    func addSubcollection(to node: Node, name: String) {
        guard !node.isSystem else { return }
        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", node.id as CVarArg)
        if let parent = (try? context.fetch(request))?.first {
            let child = Collection(context: context)
            child.id = UUID()
            child.name = name
            child.parent = parent
            try? core.save()
        }
    }

    func delete(_ node: Node) {
        guard !node.isSystem else { return }
        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", node.id as CVarArg)
        if let coll = (try? context.fetch(request))?.first {
            context.delete(coll)
            try? core.save()
        }
    }
}


// MARK: - Private Helpers

private extension CollectionsViewModel {
    func applySearchFilter() {
        if query.isEmpty {
            rootNodes = allNodes
        } else {
            rootNodes = filter(allNodes, by: query)
        }
    }

    func countFor(collection: Collection) -> Int {
        guard let name = collection.name else { return 0 }
        let byRelation = NSPredicate(format: "collection == %@", collection)
        let byName = NSPredicate(format: "collectionName == %@", name)
        let predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [byRelation, byName])
        return countBookmarks(matching: predicate)
    }

    func countBookmarks(matching predicate: NSPredicate?) -> Int {
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        request.predicate = predicate
        request.includesPendingChanges = false
        request.resultType = .countResultType
        return (try? context.count(for: request)) ?? 0
    }
}


