//
//  CoreDataManager.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import Foundation
@preconcurrency import CoreData
import Combine
import os.log

// MARK: - Core Data Errors

enum CoreDataError: Error {
    case saveFailed(String)
    case fetchFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case batchOperationFailed(String)
    case invalidContext
    case objectNotFound
    
    var localizedDescription: String {
        switch self {
        case .saveFailed(let message):
            return "Save failed: \(message)"
        case .fetchFailed(let message):
            return "Fetch failed: \(message)"
        case .updateFailed(let message):
            return "Update failed: \(message)"
        case .deleteFailed(let message):
            return "Delete failed: \(message)"
        case .batchOperationFailed(let message):
            return "Batch operation failed: \(message)"
        case .invalidContext:
            return "Invalid managed object context"
        case .objectNotFound:
            return "Object not found in the database"
        }
    }
}

// MARK: - Core Data Manager

class CoreDataManager {
    
    // MARK: - Singleton
    
    static let shared = CoreDataManager()
    
    // MARK: - Properties
    
    let persistentContainer: NSPersistentCloudKitContainer
    private let backgroundQueue = DispatchQueue(label: "com.calendarnotes.coredata.background", qos: .userInitiated)
    
    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }
    
    // CloudKit sync status publisher
    @Published private(set) var isSyncing: Bool = false
    
    // MARK: - Initialization
    
    private init() {
        persistentContainer = NSPersistentCloudKitContainer(name: "CalendarNotes")
        
        // Configure CloudKit container (setup but not enabled yet)
        configurePersistentStore()
        
        persistentContainer.loadPersistentStores { [weak self] storeDescription, error in
            guard let self = self else { return }
            if let error = error as NSError? {
                // Attempt recovery by destroying the incompatible store, then retry once
                let storeURL = storeDescription.url
                print("⚠️ Failed to load persistent store: \(error.localizedDescription)")
                if let storeURL = storeURL {
                    do {
                        try self.destroyPersistentStore(at: storeURL)
                        print("🗑️ Destroyed incompatible store. Retrying load…")
                        var retryError: NSError?
                        self.persistentContainer.loadPersistentStores { _, err in
                            retryError = err as NSError?
                        }
                        if let retryError = retryError {
                            print("❌ Retry failed: \(retryError.localizedDescription). Falling back to in-memory store.")
                            try? self.setupInMemoryStore()
                        }
                    } catch {
                        print("❌ Could not destroy store: \(error.localizedDescription). Falling back to in-memory store.")
                        try? self.setupInMemoryStore()
                    }
                } else {
                    print("❌ Store URL unavailable. Falling back to in-memory store.")
                    try? self.setupInMemoryStore()
                }
            }
            
            // Configure view context
            self.persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
            self.persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            
            print("✅ Core Data stack initialized")
            print("📁 Store location: \(storeDescription.url?.absoluteString ?? "Unknown")")
        }
        
        // Setup notifications for sync monitoring
        setupSyncMonitoring()
    }
    
    // MARK: - Configuration
    
    private func configurePersistentStore() {
        guard let description = persistentContainer.persistentStoreDescriptions.first else {
            return
        }
        
        // Enable lightweight migration to handle model changes without crashing
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        // CloudKit configuration - disabled for personal development team
        // To enable CloudKit, you need a paid Apple Developer account
        // Uncomment the following code when you have access to CloudKit:
        /*
        let isCloudKitEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        if isCloudKitEnabled {
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: "iCloud.com.calendarnotes.app"
            )
        } else {
            description.cloudKitContainerOptions = nil
        }
        */
        
        // Explicitly disable CloudKit for now
        description.cloudKitContainerOptions = nil
        
        // Enable persistent history tracking
        description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)
    }
    
    private func setupSyncMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: persistentContainer.persistentStoreCoordinator
        )
    }

    /// Destroys the SQLite persistent store at the provided URL (and its sidecar files)
    private func destroyPersistentStore(at url: URL) throws {
        let coordinator = persistentContainer.persistentStoreCoordinator
        // Remove if already added
        if let existing = coordinator.persistentStore(for: url) {
            try coordinator.remove(existing)
        }
        let options: [AnyHashable: Any] = [:]
        try coordinator.destroyPersistentStore(at: url, type: .sqlite, options: options)
        // Also remove -shm and -wal if present
        let fm = FileManager.default
        let shm = url.deletingPathExtension().appendingPathExtension("sqlite-shm")
        let wal = url.deletingPathExtension().appendingPathExtension("sqlite-wal")
        try? fm.removeItem(at: shm)
        try? fm.removeItem(at: wal)
    }

    /// Configures the container to use an in-memory store as a last resort, so the app can still open
    private func setupInMemoryStore() throws {
        guard let description = persistentContainer.persistentStoreDescriptions.first else { return }
        description.url = URL(fileURLWithPath: "/dev/null")
        var setupError: NSError?
        persistentContainer.loadPersistentStores { _, err in
            setupError = err as NSError?
        }
        if let setupError = setupError { throw setupError }
    }
    
    @objc private func handleRemoteChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            self?.isSyncing = true
            // Merge changes
            self?.viewContext.perform {
                self?.isSyncing = false
            }
        }
    }
    
    // MARK: - Context Management
    
    /// Creates a new background context for performing operations off the main thread
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = persistentContainer.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }
    
    /// Creates a background context optimized for imports
    func newImportContext() -> NSManagedObjectContext {
        return DatabaseOptimizer.shared.createImportContext(from: persistentContainer)
    }
    
    /// Creates a background context optimized for sync operations
    func newSyncContext() -> NSManagedObjectContext {
        return DatabaseOptimizer.shared.createSyncContext(from: persistentContainer)
    }
    
    /// Creates a background context for general background processing
    func newBackgroundProcessingContext() -> NSManagedObjectContext {
        return DatabaseOptimizer.shared.createBackgroundContext(from: persistentContainer)
    }
    
    /// Performs a task on a background context
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            persistentContainer.performBackgroundTask { context in
                do {
                    let result = try block(context)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Save Operations
    
    /// Save context with error handling (use background context for heavy saves)
    func save(context: NSManagedObjectContext? = nil) throws {
        let contextToSave = context ?? viewContext
        
        guard contextToSave.hasChanges else { return }
        
        return try TimeProfiler.shared.measure("CoreData.save") {
            do {
                try contextToSave.save()
            } catch {
                throw CoreDataError.saveFailed(error.localizedDescription)
            }
        }
    }
    
    /// Save context asynchronously on background thread
    func saveAsync(context: NSManagedObjectContext? = nil) async throws {
        return try await TimeProfiler.shared.measureAsync("CoreData.saveAsync") {
            try await performBackgroundTask { backgroundContext in
                guard backgroundContext.hasChanges else { return }
                
                do {
                    try backgroundContext.save()
                } catch {
                    throw CoreDataError.saveFailed(error.localizedDescription)
                }
            }
        }
    }
    
    // MARK: - Fetch Operations
    
    /// Generic fetch request (synchronous - use background context)
    func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>, context: NSManagedObjectContext? = nil) throws -> [T] {
        let contextToUse = context ?? viewContext
        
        // Optimize fetch request
        DatabaseOptimizer.shared.optimizeFetchRequest(
            request,
            batchSize: 50,
            returnsObjectsAsFaults: false
        )
        
        // Add fetch limit to prevent loading too much data
        if request.fetchLimit == 0 {
            request.fetchLimit = 1000 // Default limit
        }
        
        return try DatabaseOptimizer.shared.measureQuery(
            name: "CoreData.fetch.\(T.entity().name ?? "Unknown")",
            threshold: 0.5,
            alertThreshold: 2.0
        ) {
            try TimeProfiler.shared.measure("CoreData.fetch.\(T.entity().name ?? "Unknown")") {
                do {
                    return try contextToUse.fetch(request)
                } catch {
                    throw CoreDataError.fetchFailed(error.localizedDescription)
                }
            }
        }
    }
    
    /// Async fetch on background thread
    func fetchAsync<T: NSManagedObject>(_ request: NSFetchRequest<T>, context: NSManagedObjectContext? = nil) async throws -> [T] {
        // Optimize fetch request
        DatabaseOptimizer.shared.optimizeFetchRequest(
            request,
            batchSize: 50,
            returnsObjectsAsFaults: false
        )
        
        // Add fetch limit
        if request.fetchLimit == 0 {
            request.fetchLimit = 1000
        }
        
        return try await DatabaseOptimizer.shared.measureQueryAsync(
            name: "CoreData.fetchAsync.\(T.entity().name ?? "Unknown")",
            threshold: 0.5,
            alertThreshold: 2.0
        ) {
            try await TimeProfiler.shared.measureAsync("CoreData.fetchAsync.\(T.entity().name ?? "Unknown")") {
                try await performBackgroundTask { backgroundContext in
                    do {
                        return try backgroundContext.fetch(request)
                    } catch {
                        throw CoreDataError.fetchFailed(error.localizedDescription)
                    }
                }
            }
        }
    }
    
    /// Fetch single object by ID
    func fetchObject<T: NSManagedObject>(with objectID: NSManagedObjectID, context: NSManagedObjectContext? = nil) throws -> T? {
        let contextToUse = context ?? viewContext
        
        do {
            let object = try contextToUse.existingObject(with: objectID)
            return object as? T
        } catch {
            throw CoreDataError.fetchFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Delete Operations
    
    /// Delete a single object (use background context for better performance)
    func delete<T: NSManagedObject>(_ object: T, context: NSManagedObjectContext? = nil) throws {
        return try TimeProfiler.shared.measure("CoreData.delete") {
            let contextToUse = context ?? viewContext
            contextToUse.delete(object)
            try save(context: contextToUse)
        }
    }
    
    /// Delete multiple objects (use batch delete for better performance)
    func delete<T: NSManagedObject>(_ objects: [T], context: NSManagedObjectContext? = nil) throws {
        guard !objects.isEmpty else { return }
        
        // Use batch delete for large deletions
        if objects.count > 50 {
            let objectIDs = objects.compactMap { $0.objectID }
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: T.entity().name ?? "")
            fetchRequest.predicate = NSPredicate(format: "SELF IN %@", objectIDs)
            try batchDelete(fetchRequest as! NSFetchRequest<T>)
        } else {
            return try TimeProfiler.shared.measure("CoreData.deleteMultiple") {
                let contextToUse = context ?? viewContext
                objects.forEach { contextToUse.delete($0) }
                try save(context: contextToUse)
            }
        }
    }
    
    /// Batch delete
    func batchDelete<T: NSManagedObject>(_ fetchRequest: NSFetchRequest<T>) throws {
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)
        deleteRequest.resultType = .resultTypeObjectIDs
        
        do {
            let result = try viewContext.execute(deleteRequest) as? NSBatchDeleteResult
            let objectIDArray = result?.result as? [NSManagedObjectID] ?? []
            let changes = [NSDeletedObjectsKey: objectIDArray]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
        } catch {
            throw CoreDataError.batchOperationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Update Operations
    
    /// Update object and save
    func update<T: NSManagedObject>(_ object: T, updates: (T) -> Void, context: NSManagedObjectContext? = nil) throws {
        let contextToUse = context ?? viewContext
        updates(object)
        try save(context: contextToUse)
    }
    
    /// Batch update
    func batchUpdate(entityName: String, propertiesToUpdate: [AnyHashable: Any], predicate: NSPredicate? = nil) throws {
        let batchUpdateRequest = NSBatchUpdateRequest(entityName: entityName)
        batchUpdateRequest.propertiesToUpdate = propertiesToUpdate
        batchUpdateRequest.predicate = predicate
        batchUpdateRequest.resultType = .updatedObjectIDsResultType
        
        do {
            let result = try viewContext.execute(batchUpdateRequest) as? NSBatchUpdateResult
            let objectIDArray = result?.result as? [NSManagedObjectID] ?? []
            let changes = [NSUpdatedObjectsKey: objectIDArray]
            NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [viewContext])
        } catch {
            throw CoreDataError.batchOperationFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Calendar Event Queries
    
    func fetchEvents(from startDate: Date? = nil, to endDate: Date? = nil, context: NSManagedObjectContext? = nil) throws -> [CalendarEvent] {
        let request: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
        
        var predicates: [NSPredicate] = []
        if let startDate = startDate {
            predicates.append(NSPredicate(format: "startDate >= %@", startDate as NSDate))
        }
        if let endDate = endDate {
            predicates.append(NSPredicate(format: "startDate <= %@", endDate as NSDate))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CalendarEvent.startDate, ascending: true)]
        
        // Optimize fetch request with prefetching
        DatabaseOptimizer.shared.optimizeFetchRequest(
            request,
            batchSize: 50,
            prefetchRelationships: ["category"],
            returnsObjectsAsFaults: false
        )
        
        return try fetch(request, context: context)
    }
    
    func fetchEvents(for date: Date, context: NSManagedObjectContext? = nil) throws -> [CalendarEvent] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        return try fetchEvents(from: startOfDay, to: endOfDay, context: context)
    }
    
    func fetchRecurringEvents(context: NSManagedObjectContext? = nil) throws -> [CalendarEvent] {
        let request: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
        request.predicate = NSPredicate(format: "isRecurring == YES")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CalendarEvent.startDate, ascending: true)]
        
        return try fetch(request, context: context)
    }
    
    // MARK: - Note Queries
    
    func fetchNotes(linkedToDate date: Date? = nil, context: NSManagedObjectContext? = nil) throws -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        
        if let date = date {
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
            request.predicate = NSPredicate(format: "linkedDate >= %@ AND linkedDate < %@", startOfDay as NSDate, endOfDay as NSDate)
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdDate, ascending: false)]
        
        return try fetch(request, context: context)
    }
    
    func fetchNotes(containingText text: String, context: NSManagedObjectContext? = nil) throws -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "content CONTAINS[cd] %@", text)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdDate, ascending: false)]
        
        return try fetch(request, context: context)
    }
    
    func fetchNotes(withTag tag: String, context: NSManagedObjectContext? = nil) throws -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "tags CONTAINS[cd] %@", tag)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdDate, ascending: false)]
        
        return try fetch(request, context: context)
    }
    
    // MARK: - Todo Item Queries
    
    func fetchTodoItems(completed: Bool? = nil, context: NSManagedObjectContext? = nil) throws -> [TodoItem] {
        let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
        
        if let completed = completed {
            request.predicate = NSPredicate(format: "isCompleted == %@", NSNumber(value: completed))
        }
        
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TodoItem.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \TodoItem.dueDate, ascending: true)
        ]
        
        return try fetch(request, context: context)
    }
    
    func fetchTodoItems(dueBy date: Date, context: NSManagedObjectContext? = nil) throws -> [TodoItem] {
        let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
        request.predicate = NSPredicate(format: "dueDate <= %@ AND isCompleted == NO", date as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TodoItem.dueDate, ascending: true)]
        
        return try fetch(request, context: context)
    }
    
    func fetchTodoItems(byPriority priority: String, context: NSManagedObjectContext? = nil) throws -> [TodoItem] {
        let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
        request.predicate = NSPredicate(format: "priority == %@ AND isCompleted == NO", priority)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TodoItem.dueDate, ascending: true)]
        
        return try fetch(request, context: context)
    }
    
    func fetchOverdueTodoItems(context: NSManagedObjectContext? = nil) throws -> [TodoItem] {
        let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
        request.predicate = NSPredicate(format: "dueDate < %@ AND isCompleted == NO", Date() as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TodoItem.dueDate, ascending: true)]
        
        return try fetch(request, context: context)
    }
    
    // MARK: - Batch Operations
    
    /// Delete all completed todos
    func deleteCompletedTodos() throws {
        let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
        request.predicate = NSPredicate(format: "isCompleted == YES")
        try batchDelete(request)
    }
    
    /// Delete old notes (older than specified days)
    func deleteOldNotes(olderThanDays days: Int) throws {
        let date = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        request.predicate = NSPredicate(format: "createdDate < %@", date as NSDate)
        try batchDelete(request)
    }
    
    /// Mark all overdue tasks as high priority
    func escalateOverdueTasks() throws {
        let predicate = NSPredicate(format: "dueDate < %@ AND isCompleted == NO AND priority != %@", Date() as NSDate, "Urgent")
        try batchUpdate(entityName: "TodoItem", propertiesToUpdate: ["priority": "High"], predicate: predicate)
    }
    
    // MARK: - Statistics and Counts
    
    func countObjects<T: NSManagedObject>(for fetchRequest: NSFetchRequest<T>, context: NSManagedObjectContext? = nil) throws -> Int {
        let contextToUse = context ?? viewContext
        
        do {
            return try contextToUse.count(for: fetchRequest)
        } catch {
            throw CoreDataError.fetchFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Preview Support
    
    static var preview: CoreDataManager {
        let manager = CoreDataManager()
        let context = manager.viewContext
        
        // Create sample data
        for i in 1...5 {
            _ = Note(context: context, content: "Sample note \(i)", linkedDate: Date(), tags: "sample,test")
            _ = CalendarEvent(context: context, title: "Event \(i)", startDate: Date(), endDate: Date().addingTimeInterval(3600), category: "Personal")
            _ = TodoItem(context: context, title: "Task \(i)", priority: "Medium", category: "Personal")
        }
        // Sample Collections
        let work = Collection(context: context, name: "Work", color: "#4285F4")
        let personal = Collection(context: context, name: "Personal", color: "#34A853")
        // Sample Tags
        let _ = Tag(context: context, name: "reading")
        let _ = Tag(context: context, name: "swift")
        let _ = Tag(context: context, name: "research")
        // Sample Bookmarks
        let b1 = Bookmark(context: context, url: "https://developer.apple.com/documentation/coredata", title: "Core Data Docs", tags: ["swift","research"], collection: work, collectionName: "Work", isFavorite: true)
        let b2 = Bookmark(context: context, url: "https://swift.org", title: "Swift.org", tags: ["swift"], collection: personal, collectionName: "Personal")
        b1.tagRelations = NSSet(array: [])
        b2.tagRelations = NSSet(array: [])
        
        try? manager.save()
        return manager
    }
    
    // MARK: - Reset Database (Development Only)
    
    #if DEBUG
    func resetDatabase() throws {
        let entities = persistentContainer.managedObjectModel.entities
        
        for entity in entities {
            guard let entityName = entity.name else { continue }
            
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            
            do {
                try viewContext.execute(deleteRequest)
                try viewContext.save()
            } catch {
                throw CoreDataError.batchOperationFailed("Failed to reset \(entityName): \(error.localizedDescription)")
            }
        }
        
        print("🗑️ Database reset complete")
    }
    #endif
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - Convenience Extensions

extension CoreDataManager {
    
    /// Create and save a new Calendar Event
    @discardableResult
    func createEvent(title: String, startDate: Date, endDate: Date, category: String, location: String? = nil, notes: String? = nil, isRecurring: Bool = false, recurrenceRule: String? = nil) throws -> CalendarEvent {
        let event = CalendarEvent(context: viewContext, title: title, startDate: startDate, endDate: endDate, category: category, location: location, notes: notes, isRecurring: isRecurring, recurrenceRule: recurrenceRule)
        EventAnalysisService.shared.analyze(event: event, autoSave: false)
        try save()
        return event
    }
    
    /// Create and save a new Note
    @discardableResult
    func createNote(content: String, linkedDate: Date? = nil, tags: String? = nil) throws -> Note {
        let note = Note(context: viewContext, content: content, linkedDate: linkedDate, tags: tags)
        NoteAnalysisService.shared.analyze(note: note, autoSave: false)
        try save()
        return note
    }
    
    /// Create and save a new Todo Item
    @discardableResult
    func createTodoItem(title: String, priority: String, category: String, dueDate: Date? = nil, isCompleted: Bool = false, isRecurring: Bool = false) throws -> TodoItem {
        let todo = TodoItem(context: viewContext, title: title, priority: priority, category: category, dueDate: dueDate, isCompleted: isCompleted, isRecurring: isRecurring)
        try save()
        return todo
    }
}

// MARK: - Bookmark Operations

extension CoreDataManager {
    // Create Bookmark
    @discardableResult
    func createBookmark(
        url: String,
        title: String,
        description: String? = nil,
        tags: [String] = [],
        collectionName: String? = nil,
        isFavorite: Bool = false,
        isArchived: Bool = false,
        notes: String? = nil,
        linkedCalendarDate: Date? = nil,
        linkedEventID: UUID? = nil,
        linkedNoteID: UUID? = nil
    ) throws -> Bookmark {
        let collection: Collection?
        if let collectionName = collectionName, !collectionName.isEmpty {
            collection = try findOrCreateCollection(named: collectionName)
        } else {
            collection = nil
        }
        let sanitizedURL = URLPrivacySanitizer.sanitized(url)
        let bookmark = Bookmark(
            context: viewContext,
            url: sanitizedURL,
            title: title,
            bookmarkDescription: description,
            tags: tags,
            collection: collection,
            collectionName: collectionName,
            isFavorite: isFavorite,
            isArchived: isArchived,
            notes: notes,
            linkedCalendarDate: linkedCalendarDate,
            linkedEventID: linkedEventID,
            linkedNoteID: linkedNoteID
        )
        try save()
        NotificationCenter.default.post(name: .bookmarksDidChange, object: bookmark.objectID)
        // Link Tag entities if they exist or create them
        if !tags.isEmpty {
            try setTags(tags, for: bookmark)
        }
        return bookmark
    }

    // Fetch Bookmarks with filters
    func fetchBookmarks(
        inCollection collectionName: String? = nil,
        withTag tagName: String? = nil,
        isFavorite: Bool? = nil,
        isArchived: Bool? = nil,
        searchText: String? = nil,
        contentType: BookmarkContentType? = nil,
        limit: Int? = nil,
        offset: Int? = nil,
        sortDescriptors: [NSSortDescriptor]? = nil,
        batchSize: Int? = nil
    ) throws -> [Bookmark] {
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        var predicates: [NSPredicate] = []
        if let collectionName = collectionName, !collectionName.isEmpty {
            let p1 = NSPredicate(format: "collection.name == %@", collectionName)
            let p2 = NSPredicate(format: "collectionName == %@", collectionName)
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [p1, p2]))
        }
        if let tagName = tagName, !tagName.isEmpty {
            let pRelation = NSPredicate(format: "ANY tagRelations.name == %@", tagName)
            let pJson = NSPredicate(format: "tags CONTAINS[cd] %@", tagName)
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [pRelation, pJson]))
        }
        if let isFavorite = isFavorite {
            predicates.append(NSPredicate(format: "isFavorite == %@", NSNumber(value: isFavorite)))
        }
        if let isArchived = isArchived {
            predicates.append(NSPredicate(format: "isArchived == %@", NSNumber(value: isArchived)))
        }
        if let searchText = searchText, !searchText.isEmpty {
            let pTitle = NSPredicate(format: "title CONTAINS[cd] %@", searchText)
            let pUrl = NSPredicate(format: "url CONTAINS[cd] %@", searchText)
            let pNotes = NSPredicate(format: "notes CONTAINS[cd] %@", searchText)
            let pDesc = NSPredicate(format: "bookmarkDescription CONTAINS[cd] %@", searchText)
            predicates.append(NSCompoundPredicate(orPredicateWithSubpredicates: [pTitle, pUrl, pNotes, pDesc]))
        }
        if let contentType {
            predicates.append(NSPredicate(format: "contentType == %@", contentType.rawValue))
        }
        if !predicates.isEmpty { request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates) }
        if let descriptors = sortDescriptors, !descriptors.isEmpty {
            request.sortDescriptors = descriptors
        } else {
            request.sortDescriptors = [
                NSSortDescriptor(keyPath: \Bookmark.isFavorite, ascending: false),
                NSSortDescriptor(keyPath: \Bookmark.lastOpenedDate, ascending: false),
                NSSortDescriptor(keyPath: \Bookmark.lastModifiedDate, ascending: false)
            ]
        }
        
        // Optimize fetch request with prefetching
        DatabaseOptimizer.shared.optimizeFetchRequest(
            request,
            batchSize: batchSize ?? 50,
            prefetchRelationships: ["collection", "tagRelations"],
            returnsObjectsAsFaults: false
        )
        
        if let limit = limit { request.fetchLimit = limit }
        if let offset = offset { request.fetchOffset = offset }
        
        return try fetch(request)
    }

    func fetchBookmark(id: UUID) throws -> Bookmark? {
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try fetch(request).first
    }

    func fetchCollection(id: UUID) throws -> Collection? {
        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try fetch(request).first
    }

    // Update bookmark open stats
    func markBookmarkOpened(_ bookmark: Bookmark) throws {
        try update(bookmark) { b in
            b.lastOpenedDate = Date()
            b.openCount += 1
        }
    }

    // Toggle favorite/archive
    func setBookmark(_ bookmark: Bookmark, favorite: Bool) throws {
        try update(bookmark) { $0.isFavorite = favorite }
    }
    func setBookmark(_ bookmark: Bookmark, archived: Bool) throws {
        try update(bookmark) { $0.isArchived = archived }
    }
    
    func setBookmark(_ bookmark: Bookmark, watched: Bool) throws {
        try update(bookmark) { b in
            b.setValue(watched, forKey: "isWatched")
        }
    }
    
    // Move to collection
    func moveBookmark(_ bookmark: Bookmark, toCollectionName name: String?) throws {
        try update(bookmark) { b in
            if let name = name, !name.isEmpty {
                let target = try? self.findOrCreateCollection(named: name)
                b.collection = target
                b.collectionName = name
            } else {
                b.collection = nil
                b.collectionName = nil
            }
        }
    }

    // Manage tags (String array JSON and Tag relationship)
    func setTags(_ tags: [String], for bookmark: Bookmark) throws {
        let unique = Array(Set(tags)).sorted()
        let tagObjects = try unique.map { try findOrCreateTag(named: $0) }
        try update(bookmark) { b in
            b.tagRelations = NSSet(array: tagObjects)
            b.decodedTags = unique
        }
    }
    func addTag(_ name: String, to bookmark: Bookmark) throws {
        var list = bookmark.decodedTags
        if !list.contains(name) { list.append(name) }
        try setTags(list, for: bookmark)
    }
    func removeTag(_ name: String, from bookmark: Bookmark) throws {
        let list = bookmark.decodedTags.filter { $0.caseInsensitiveCompare(name) != .orderedSame }
        try setTags(list, for: bookmark)
    }

    // Helpers: Collections / Tags
    func findOrCreateCollection(named name: String) throws -> Collection {
        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[cd] %@", name)
        request.fetchLimit = 1
        if let existing = try fetch(request).first { return existing }
        let created = Collection(context: viewContext, name: name)
        try save()
        return created
    }

    func findOrCreateTag(named name: String) throws -> Tag {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[cd] %@", name)
        request.fetchLimit = 1
        if let existing = try fetch(request).first { return existing }
        let created = Tag(context: viewContext, name: name)
        try save()
        return created
    }

    func updateBookmarkAssets(
        objectID: NSManagedObjectID,
        previewData: Data?,
        faviconData: Data?,
        title: String?,
        description: String?,
        contentType: BookmarkContentType?,
        contentSubtype: String?,
        contentMetadata: BookmarkContentMetadata?
    ) async {
        await persistentContainer.performBackgroundTask { [self] context in
            guard let bookmark = try? context.existingObject(with: objectID) as? Bookmark else { return }
            if let previewData = previewData {
                bookmark.previewImage = previewData
            }
            if let faviconData = faviconData {
                bookmark.favicon = faviconData
            }
            if let title = title, (bookmark.title?.isEmpty ?? true) {
                bookmark.title = title
            }
            if let description = description, (bookmark.bookmarkDescription?.isEmpty ?? true) {
                bookmark.bookmarkDescription = description
            }
            if let contentType {
                bookmark.contentType = contentType.rawValue
            }
            if let contentSubtype {
                bookmark.contentSubtype = contentSubtype
            }
            if let contentMetadata {
                bookmark.contentMetadata = Bookmark.encodeMetadata(contentMetadata)
                self.applyContentMetadata(contentMetadata, to: bookmark)
            }
            if context.hasChanges {
                try? context.save()
            }
        }
    }
    
    private func applyContentMetadata(_ metadata: BookmarkContentMetadata, to bookmark: Bookmark) {
        if let video = metadata.video, let duration = video.duration {
            bookmark.setValue(duration, forKey: "videoDuration")
        }
        if let pdf = metadata.pdf {
            if let pageCount = pdf.pageCount {
                bookmark.setValue(Int32(pageCount), forKey: "pdfPageCount")
            }
            bookmark.setValue(pdf.allowsAnnotations, forKey: "pdfHasAnnotations")
            if let text = pdf.extractedTextPreview, !text.isEmpty {
                bookmark.setValue(text, forKey: "pdfOCRText")
            }
        }
        if let image = metadata.image {
            if let width = image.width {
                bookmark.setValue(Int32(width), forKey: "imageWidth")
            }
            if let height = image.height {
                bookmark.setValue(Int32(height), forKey: "imageHeight")
            }
            if let fileSize = image.fileSizeBytes {
                bookmark.setValue(Int64(fileSize), forKey: "imageFileSize")
            }
        }
        if let recipe = metadata.recipe {
            if !recipe.ingredients.isEmpty {
                bookmark.recipeIngredients = recipe.ingredients
            }
            if let cookTime = recipe.cookTimeMinutes {
                bookmark.setValue(Int32(cookTime), forKey: "recipeCookTimeMinutes")
            } else if let total = recipe.totalTimeMinutes {
                bookmark.setValue(Int32(total), forKey: "recipeCookTimeMinutes")
            }
        }
        if let repository = metadata.repository {
            if let stars = repository.stars {
                bookmark.setValue(Int32(stars), forKey: "gitHubStars")
            }
            if let forks = repository.forks {
                bookmark.setValue(Int32(forks), forKey: "gitHubForks")
            }
            if let language = repository.language, !language.isEmpty {
                bookmark.gitHubLanguage = language
            }
            if let updated = repository.lastUpdated {
                bookmark.gitHubLastUpdated = updated
            }
        }
        if let product = metadata.product {
            if let price = product.price {
                bookmark.setValue(NSDecimalNumber(decimal: price), forKey: "productPrice")
            }
            if let currency = product.currencyCode {
                bookmark.productCurrency = currency
            }
        }
        if let social = metadata.social {
            if let platform = social.platform {
                bookmark.socialPlatform = platform
            }
            if let author = social.authorHandle {
                bookmark.socialAuthor = author
            }
        }
    }
}

