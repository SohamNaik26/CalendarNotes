//
//  CoreDataManager.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import Foundation
@preconcurrency import CoreData
import Combine

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
            if let error = error as NSError? {
                // In production, handle this gracefully
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            
            // Configure view context
            self?.persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
            self?.persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
            
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
    
    /// Save context with error handling
    func save(context: NSManagedObjectContext? = nil) throws {
        let contextToSave = context ?? viewContext
        
        guard contextToSave.hasChanges else { return }
        
        do {
            try contextToSave.save()
        } catch {
            throw CoreDataError.saveFailed(error.localizedDescription)
        }
    }
    
    /// Save context asynchronously
    func saveAsync(context: NSManagedObjectContext? = nil) async throws {
        let contextToSave = context ?? viewContext
        
        try await contextToSave.perform {
            guard contextToSave.hasChanges else { return }
            
            do {
                try contextToSave.save()
            } catch {
                throw CoreDataError.saveFailed(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Fetch Operations
    
    /// Generic fetch request
    func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>, context: NSManagedObjectContext? = nil) throws -> [T] {
        let contextToUse = context ?? viewContext
        
        do {
            return try contextToUse.fetch(request)
        } catch {
            throw CoreDataError.fetchFailed(error.localizedDescription)
        }
    }
    
    /// Async fetch
    func fetchAsync<T: NSManagedObject>(_ request: NSFetchRequest<T>, context: NSManagedObjectContext? = nil) async throws -> [T] {
        let contextToUse = context ?? viewContext
        
        return try await contextToUse.perform {
            do {
                return try contextToUse.fetch(request)
            } catch {
                throw CoreDataError.fetchFailed(error.localizedDescription)
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
    
    /// Delete a single object
    func delete<T: NSManagedObject>(_ object: T, context: NSManagedObjectContext? = nil) throws {
        let contextToUse = context ?? viewContext
        contextToUse.delete(object)
        try save(context: contextToUse)
    }
    
    /// Delete multiple objects
    func delete<T: NSManagedObject>(_ objects: [T], context: NSManagedObjectContext? = nil) throws {
        let contextToUse = context ?? viewContext
        objects.forEach { contextToUse.delete($0) }
        try save(context: contextToUse)
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
        try save()
        return event
    }
    
    /// Create and save a new Note
    @discardableResult
    func createNote(content: String, linkedDate: Date? = nil, tags: String? = nil) throws -> Note {
        let note = Note(context: viewContext, content: content, linkedDate: linkedDate, tags: tags)
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

