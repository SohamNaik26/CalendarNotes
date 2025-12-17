//
//  Persistence.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//
//  DEPRECATED: This file is kept for compatibility only.
//  Use CoreDataManager.shared instead.

import CoreData

struct PersistenceController {
    // Use CoreDataManager's container to avoid duplicate initialization
    static let shared = PersistenceController()

    @MainActor
    static let preview: PersistenceController = {
        return PersistenceController(inMemory: true)
    }()

    let container: NSPersistentCloudKitContainer

    init(inMemory: Bool = false) {
        // Use the existing CoreDataManager container instead of creating a new one
        container = CoreDataManager.shared.persistentContainer
    }
}
