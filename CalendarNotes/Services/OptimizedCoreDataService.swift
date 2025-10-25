//
//  OptimizedCoreDataService.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 23/10/25.
//

import Foundation
import CoreData
import Combine

// MARK: - Performance Optimized Core Data Service

class OptimizedCoreDataService: ObservableObject {
    private let persistenceController: PersistenceController
    private let backgroundContext: NSManagedObjectContext
    
    // MARK: - Caching
    private var eventsCache: [String: [CalendarEvent]] = [:]
    private var notesCache: [String: [Note]] = [:]
    private var tasksCache: [String: [TodoItem]] = [:]
    private let cacheQueue = DispatchQueue(label: "com.calendarnotes.cache", attributes: .concurrent)
    
    // MARK: - Pagination
    private let defaultPageSize = 50
    private let maxCacheSize = 1000
    
    var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.backgroundContext = persistenceController.container.newBackgroundContext()
        
        // Configure background context
        backgroundContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        backgroundContext.automaticallyMergesChangesFromParent = true
    }
    
    // MARK: - Cache Management
    
    private func cacheKey(for events: [CalendarEvent], dateRange: (start: Date?, end: Date?)) -> String {
        let startKey = dateRange.start?.timeIntervalSince1970.description ?? "nil"
        let endKey = dateRange.end?.timeIntervalSince1970.description ?? "nil"
        return "events_\(startKey)_\(endKey)"
    }
    
    private func cacheKey(for notes: [Note], date: Date?) -> String {
        let dateKey = date?.timeIntervalSince1970.description ?? "all"
        return "notes_\(dateKey)"
    }
    
    private func cacheKey(for tasks: [TodoItem], completed: Bool?) -> String {
        let completedKey = completed?.description ?? "all"
        return "tasks_\(completedKey)"
    }
    
    private func clearOldCache() {
        cacheQueue.async(flags: .barrier) {
            // Clear cache if it gets too large
            if self.eventsCache.count > self.maxCacheSize {
                self.eventsCache.removeAll()
            }
            if self.notesCache.count > self.maxCacheSize {
                self.notesCache.removeAll()
            }
            if self.tasksCache.count > self.maxCacheSize {
                self.tasksCache.removeAll()
            }
        }
    }
    
    // MARK: - Optimized Calendar Events
    
    func fetchEvents(from startDate: Date? = nil, to endDate: Date? = nil, page: Int = 0, pageSize: Int? = nil) -> [CalendarEvent] {
        let cacheKey = self.cacheKey(for: [], dateRange: (startDate, endDate))
        
        // Check cache first
        if let cached = cacheQueue.sync(execute: { eventsCache[cacheKey] }) {
            let startIndex = page * (pageSize ?? defaultPageSize)
            let endIndex = min(startIndex + (pageSize ?? defaultPageSize), cached.count)
            return Array(cached[startIndex..<endIndex])
        }
        
        let request: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
        
        var predicates: [NSPredicate] = []
        if let startDate = startDate {
            predicates.append(NSPredicate(format: "startDate >= %@", startDate as NSDate))
        }
        if let endDate = endDate {
            predicates.append(NSPredicate(format: "endDate <= %@", endDate as NSDate))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        // Optimize fetch request
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CalendarEvent.startDate, ascending: true)]
        request.fetchBatchSize = 20 // Batch fetching for better memory management
        request.relationshipKeyPathsForPrefetching = ["category"] // Prefetch relationships
        
        // Limit results for initial load
        if page == 0 {
            request.fetchLimit = pageSize ?? defaultPageSize
        }
        
        do {
            let results = try viewContext.fetch(request)
            
            // Cache the results
            cacheQueue.async(flags: .barrier) {
                self.eventsCache[cacheKey] = results
            }
            
            clearOldCache()
            return results
        } catch {
            print("Error fetching events: \(error)")
            return []
        }
    }
    
    func fetchEventsAsync(from startDate: Date? = nil, to endDate: Date? = nil, page: Int = 0, pageSize: Int? = nil) -> AnyPublisher<[CalendarEvent], Error> {
        return Future { [weak self] promise in
            DispatchQueue.global(qos: .userInitiated).async {
                let results = self?.fetchEvents(from: startDate, to: endDate, page: page, pageSize: pageSize) ?? []
                promise(.success(results))
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    // MARK: - Optimized Notes
    
    func fetchNotes(linkedToDate date: Date? = nil, page: Int = 0, pageSize: Int? = nil, searchText: String? = nil) -> [Note] {
        let cacheKey = self.cacheKey(for: [], date: date)
        
        // Check cache first (but not for search results)
        if searchText == nil, let cached = cacheQueue.sync(execute: { notesCache[cacheKey] }) {
            let startIndex = page * (pageSize ?? defaultPageSize)
            let endIndex = min(startIndex + (pageSize ?? defaultPageSize), cached.count)
            return Array(cached[startIndex..<endIndex])
        }
        
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        
        var predicates: [NSPredicate] = []
        
        if let date = date {
            let startOfDay = date.startOfDay()
            let endOfDay = date.endOfDay()
            predicates.append(NSPredicate(format: "linkedDate >= %@ AND linkedDate <= %@", startOfDay as NSDate, endOfDay as NSDate))
        }
        
        if let searchText = searchText, !searchText.isEmpty {
            predicates.append(NSPredicate(format: "content CONTAINS[cd] %@", searchText))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        // Optimize fetch request
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdDate, ascending: false)]
        request.fetchBatchSize = 20
        request.propertiesToFetch = ["content", "createdDate", "linkedDate", "tags"] // Only fetch needed properties
        
        // Limit results for pagination
        if page == 0 {
            request.fetchLimit = pageSize ?? defaultPageSize
        }
        
        do {
            let results = try viewContext.fetch(request)
            
            // Cache the results (only if not a search)
            if searchText == nil {
                cacheQueue.async(flags: .barrier) {
                    self.notesCache[cacheKey] = results
                }
            }
            
            clearOldCache()
            return results
        } catch {
            print("Error fetching notes: \(error)")
            return []
        }
    }
    
    func fetchNotesAsync(linkedToDate date: Date? = nil, page: Int = 0, pageSize: Int? = nil, searchText: String? = nil) -> AnyPublisher<[Note], Error> {
        return Future { [weak self] promise in
            DispatchQueue.global(qos: .userInitiated).async {
                let results = self?.fetchNotes(linkedToDate: date, page: page, pageSize: pageSize, searchText: searchText) ?? []
                promise(.success(results))
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    // MARK: - Optimized Todo Items
    
    func fetchTodoItems(completed: Bool? = nil, page: Int = 0, pageSize: Int? = nil, category: String? = nil) -> [TodoItem] {
        let cacheKey = self.cacheKey(for: [], completed: completed)
        
        // Check cache first
        if let cached = cacheQueue.sync(execute: { tasksCache[cacheKey] }) {
            let startIndex = page * (pageSize ?? defaultPageSize)
            let endIndex = min(startIndex + (pageSize ?? defaultPageSize), cached.count)
            return Array(cached[startIndex..<endIndex])
        }
        
        let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
        
        var predicates: [NSPredicate] = []
        if let completed = completed {
            predicates.append(NSPredicate(format: "isCompleted == %@", NSNumber(value: completed)))
        }
        if let category = category {
            predicates.append(NSPredicate(format: "category == %@", category))
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        // Optimize fetch request
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TodoItem.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \TodoItem.dueDate, ascending: true)
        ]
        request.fetchBatchSize = 20
        request.propertiesToFetch = ["title", "priority", "category", "dueDate", "isCompleted", "isRecurring"]
        
        // Limit results for pagination
        if page == 0 {
            request.fetchLimit = pageSize ?? defaultPageSize
        }
        
        do {
            let results = try viewContext.fetch(request)
            
            // Cache the results
            cacheQueue.async(flags: .barrier) {
                self.tasksCache[cacheKey] = results
            }
            
            clearOldCache()
            return results
        } catch {
            print("Error fetching todo items: \(error)")
            return []
        }
    }
    
    func fetchTodoItemsAsync(completed: Bool? = nil, page: Int = 0, pageSize: Int? = nil, category: String? = nil) -> AnyPublisher<[TodoItem], Error> {
        return Future { [weak self] promise in
            DispatchQueue.global(qos: .userInitiated).async {
                let results = self?.fetchTodoItems(completed: completed, page: page, pageSize: pageSize, category: category) ?? []
                promise(.success(results))
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    // MARK: - Background Operations
    
    func createEventAsync(title: String, startDate: Date, endDate: Date, category: String, location: String? = nil, notes: String? = nil, isRecurring: Bool = false, recurrenceRule: String? = nil) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            self?.backgroundContext.perform {
                do {
                    let context = self?.backgroundContext ?? NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
                    _ = CalendarEvent(context: context, title: title, startDate: startDate, endDate: endDate, category: category, location: location, notes: notes, isRecurring: isRecurring, recurrenceRule: recurrenceRule)
                    try self?.backgroundContext.save()
                    
                    // Clear relevant cache
                    self?.clearEventsCache()
                    
                    promise(.success(()))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    func createNoteAsync(content: String, linkedDate: Date? = nil, tags: String? = nil) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            self?.backgroundContext.perform {
                do {
                    let context = self?.backgroundContext ?? NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
                    _ = Note(context: context, content: content, linkedDate: linkedDate, tags: tags)
                    try self?.backgroundContext.save()
                    
                    // Clear relevant cache
                    self?.clearNotesCache()
                    
                    promise(.success(()))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    func createTodoItemAsync(title: String, priority: String, category: String, dueDate: Date? = nil, isCompleted: Bool = false, isRecurring: Bool = false) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            self?.backgroundContext.perform {
                do {
                    let context = self?.backgroundContext ?? NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
                    _ = TodoItem(context: context, title: title, priority: priority, category: category, dueDate: dueDate, isCompleted: isCompleted, isRecurring: isRecurring)
                    try self?.backgroundContext.save()
                    
                    // Clear relevant cache
                    self?.clearTasksCache()
                    
                    promise(.success(()))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    // MARK: - Cache Clearing
    
    private func clearEventsCache() {
        cacheQueue.async(flags: .barrier) {
            self.eventsCache.removeAll()
        }
    }
    
    private func clearNotesCache() {
        cacheQueue.async(flags: .barrier) {
            self.notesCache.removeAll()
        }
    }
    
    private func clearTasksCache() {
        cacheQueue.async(flags: .barrier) {
            self.tasksCache.removeAll()
        }
    }
    
    func clearAllCache() {
        cacheQueue.async(flags: .barrier) {
            self.eventsCache.removeAll()
            self.notesCache.removeAll()
            self.tasksCache.removeAll()
        }
    }
    
    // MARK: - Statistics
    
    func getCacheStatistics() -> (events: Int, notes: Int, tasks: Int) {
        return cacheQueue.sync {
            (events: eventsCache.count, notes: notesCache.count, tasks: tasksCache.count)
        }
    }
}

// MARK: - Batch Operations

extension OptimizedCoreDataService {
    
    func batchCreateNotes(_ notesData: [(content: String, linkedDate: Date?, tags: String?)]) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            self?.backgroundContext.perform {
                do {
                    for noteData in notesData {
                        let context = self?.backgroundContext ?? NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
                        _ = Note(context: context, content: noteData.content, linkedDate: noteData.linkedDate, tags: noteData.tags)
                    }
                    try self?.backgroundContext.save()
                    
                    // Clear relevant cache
                    self?.clearNotesCache()
                    
                    promise(.success(()))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
    
    func batchCreateEvents(_ eventsData: [(title: String, startDate: Date, endDate: Date, category: String, location: String?, notes: String?, isRecurring: Bool, recurrenceRule: String?)]) -> AnyPublisher<Void, Error> {
        return Future { [weak self] promise in
            self?.backgroundContext.perform {
                do {
                    for eventData in eventsData {
                        let context = self?.backgroundContext ?? NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
                        _ = CalendarEvent(context: context, title: eventData.title, startDate: eventData.startDate, endDate: eventData.endDate, category: eventData.category, location: eventData.location, notes: eventData.notes, isRecurring: eventData.isRecurring, recurrenceRule: eventData.recurrenceRule)
                    }
                    try self?.backgroundContext.save()
                    
                    // Clear relevant cache
                    self?.clearEventsCache()
                    
                    promise(.success(()))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .receive(on: DispatchQueue.main)
        .eraseToAnyPublisher()
    }
}

