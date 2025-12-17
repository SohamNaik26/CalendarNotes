//
//  SmartCollectionService.swift
//  CalendarNotes
//

import Foundation
import CoreData

@MainActor
final class SmartCollectionService {
    static let shared = SmartCollectionService()
    private init() {}
    
    private let core = CoreDataManager.shared
    
    func saveRules(_ rules: CollectionEditorViewModel.SmartCollectionRules, for collection: Collection) {
        guard let id = collection.id?.uuidString else { return }
        let key = "collection_smartRules_\(id)"
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func loadRules(for collection: Collection) -> CollectionEditorViewModel.SmartCollectionRules? {
        guard let id = collection.id?.uuidString else { return nil }
        let key = "collection_smartRules_\(id)"
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CollectionEditorViewModel.SmartCollectionRules.self, from: data)
    }
    
    func ensurePredefinedCollections() {
        let ctx = core.viewContext
        let predefined: [(String, (inout CollectionEditorViewModel.SmartCollectionRules) -> Void)] = [
            ("Never opened", { r in r.isEnabled = true }),
            ("Frequently accessed", { r in r.isEnabled = true }),
            ("No tags", { r in r.isEnabled = true }),
            ("This week", { r in r.isEnabled = true }),
            ("Needs review", { r in r.isEnabled = true })
        ]
        for (name, configure) in predefined {
            let req: NSFetchRequest<Collection> = Collection.fetchRequest()
            req.predicate = NSPredicate(format: "name ==[cd] %@", name)
            let exists = ((try? ctx.fetch(req)) ?? []).first
            if exists == nil {
                let c = Collection(context: ctx)
                c.id = UUID()
                c.name = name
                c.icon = "tray"
                c.color = "#999999"
                var r = CollectionEditorViewModel.SmartCollectionRules()
                configure(&r)
                saveRules(r, for: c)
            }
        }
        try? core.save()
    }
}


