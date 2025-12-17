//
//  DatabaseOptimizer.swift
//  CalendarNotes
//
//  Database query optimization utility with batch operations, prefetching, and performance monitoring
//

import Foundation
import CoreData
import os.log

// MARK: - Database Optimizer

class DatabaseOptimizer {
    static let shared = DatabaseOptimizer()
    
    // Configuration
    private let defaultBatchSize = 100
    private let defaultFetchBatchSize = 50
    private let logger = Logger(subsystem: "com.calendarnotes", category: "DatabaseOptimizer")
    
    private init() {}
    
    // MARK: - Batch Fetch Operations
    
    /// Fetches objects in batches to avoid loading too much data at once
    func batchFetch<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        batchSize: Int = 100,
        context: NSManagedObjectContext,
        progress: ((Int, Int) -> Void)? = nil
    ) async throws -> [T] {
        let startTime = Date()
        
        // Configure request for batch fetching
        request.fetchBatchSize = min(batchSize, defaultFetchBatchSize)
        request.returnsObjectsAsFaults = false
        
        var allResults: [T] = []
        var offset = 0
        var hasMore = true
        
        while hasMore {
            request.fetchOffset = offset
            request.fetchLimit = batchSize
            
            let batch = try context.fetch(request)
            allResults.append(contentsOf: batch)
            
            progress?(allResults.count, offset + batch.count)
            
            hasMore = batch.count == batchSize
            offset += batchSize
            
            // Yield to prevent blocking
            await Task.yield()
        }
        
        let duration = Date().timeIntervalSince(startTime)
        logger.info("Batch fetch completed: \(allResults.count) objects in \(String(format: "%.3f", duration))s")
        
        return allResults
    }
    
    // MARK: - Batch Insert Operations
    
    /// Performs bulk insert using NSBatchInsertRequest
    func batchInsert(
        entityName: String,
        objects: [[String: Any]],
        context: NSManagedObjectContext
    ) async throws -> Int {
        let startTime = Date()
        
        guard !objects.isEmpty else { return 0 }
        
        // Use NSBatchInsertRequest for efficient bulk inserts
        let batchInsert = NSBatchInsertRequest(entityName: entityName, objects: objects)
        batchInsert.resultType = .objectIDs
        
        let result = try context.execute(batchInsert) as? NSBatchInsertResult
        let objectIDs = result?.result as? [NSManagedObjectID] ?? []
        
        // Merge changes to view context
        let changes = [NSInsertedObjectsKey: objectIDs]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
        
        let duration = Date().timeIntervalSince(startTime)
        logger.info("Batch insert completed: \(objectIDs.count) objects in \(String(format: "%.3f", duration))s")
        
        return objectIDs.count
    }
    
    // MARK: - Batch Update Operations
    
    /// Performs bulk update using NSBatchUpdateRequest
    func batchUpdate(
        entityName: String,
        propertiesToUpdate: [AnyHashable: Any],
        predicate: NSPredicate? = nil,
        context: NSManagedObjectContext
    ) async throws -> Int {
        let startTime = Date()
        
        let batchUpdate = NSBatchUpdateRequest(entityName: entityName)
        batchUpdate.propertiesToUpdate = propertiesToUpdate
        batchUpdate.predicate = predicate
        batchUpdate.resultType = .updatedObjectIDsResultType
        
        let result = try context.execute(batchUpdate) as? NSBatchUpdateResult
        let objectIDs = result?.result as? [NSManagedObjectID] ?? []
        
        // Merge changes to view context
        let changes = [NSUpdatedObjectsKey: objectIDs]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
        
        let duration = Date().timeIntervalSince(startTime)
        logger.info("Batch update completed: \(objectIDs.count) objects in \(String(format: "%.3f", duration))s")
        
        return objectIDs.count
    }
    
    // MARK: - Batch Delete Operations
    
    /// Performs bulk delete using NSBatchDeleteRequest
    func batchDelete<T: NSManagedObject>(
        _ fetchRequest: NSFetchRequest<T>,
        context: NSManagedObjectContext
    ) async throws -> Int {
        let startTime = Date()
        
        let batchDelete = NSBatchDeleteRequest(fetchRequest: fetchRequest as! NSFetchRequest<NSFetchRequestResult>)
        batchDelete.resultType = .resultTypeObjectIDs
        
        let result = try context.execute(batchDelete) as? NSBatchDeleteResult
        let objectIDs = result?.result as? [NSManagedObjectID] ?? []
        
        // Merge changes to view context
        let changes = [NSDeletedObjectsKey: objectIDs]
        NSManagedObjectContext.mergeChanges(fromRemoteContextSave: changes, into: [context])
        
        let duration = Date().timeIntervalSince(startTime)
        logger.info("Batch delete completed: \(objectIDs.count) objects in \(String(format: "%.3f", duration))s")
        
        return objectIDs.count
    }
    
    // MARK: - Optimized Fetch Request Configuration
    
    /// Configures a fetch request with optimal settings
    func optimizeFetchRequest<T: NSManagedObject>(
        _ request: NSFetchRequest<T>,
        batchSize: Int? = nil,
        prefetchRelationships: [String]? = nil,
        propertiesToFetch: [String]? = nil,
        returnsObjectsAsFaults: Bool = false
    ) {
        // Set batch size for memory efficiency
        request.fetchBatchSize = batchSize ?? defaultFetchBatchSize
        
        // Prefetch relationships to avoid N+1 queries
        if let relationships = prefetchRelationships {
            request.relationshipKeyPathsForPrefetching = relationships
        }
        
        // Fetch only needed properties for partial objects
        if let properties = propertiesToFetch {
            request.propertiesToFetch = properties
        }
        
        // Set faulting behavior
        request.returnsObjectsAsFaults = returnsObjectsAsFaults
        
        // Don't include pending changes for better performance
        request.includesPendingChanges = false
        
        // Refresh refetched objects
        request.shouldRefreshRefetchedObjects = true
    }
    
    // MARK: - Prefetch Relationships
    
    /// Prefetches relationships to avoid N+1 query problems
    func prefetchRelationships<T: NSManagedObject>(
        for objects: [T],
        relationshipKeys: [String],
        context: NSManagedObjectContext
    ) {
        guard !objects.isEmpty, !relationshipKeys.isEmpty else { return }
        
        context.performAndWait {
            for object in objects {
                for key in relationshipKeys {
                    // Access relationship to trigger fetch
                    _ = object.value(forKey: key)
                }
            }
        }
    }
    
    // MARK: - Query Performance Monitoring
    
    /// Measures query execution time and logs if slow
    func measureQuery<T>(
        name: String,
        threshold: TimeInterval = 0.5,
        alertThreshold: TimeInterval = 2.0,
        operation: () throws -> T
    ) rethrows -> T {
        let startTime = Date()
        let result = try operation()
        let duration = Date().timeIntervalSince(startTime)
        
        // Log slow queries
        if duration > threshold {
            logger.warning("Slow query detected: \(name) took \(String(format: "%.3f", duration))s")
            PerformanceMonitor.shared.recordQueryTime(query: name, duration: duration)
        }
        
        // Alert on very slow queries
        if duration > alertThreshold {
            logger.error("⚠️ Very slow query: \(name) took \(String(format: "%.3f", duration))s")
            #if DEBUG
            print("⚠️ [DB PERFORMANCE] Query '\(name)' exceeded alert threshold: \(String(format: "%.3f", duration))s")
            #endif
        }
        
        return result
    }
    
    /// Async version of measureQuery
    func measureQueryAsync<T>(
        name: String,
        threshold: TimeInterval = 0.5,
        alertThreshold: TimeInterval = 2.0,
        operation: () async throws -> T
    ) async rethrows -> T {
        let startTime = Date()
        let result = try await operation()
        let duration = Date().timeIntervalSince(startTime)
        
        if duration > threshold {
            logger.warning("Slow query detected: \(name) took \(String(format: "%.3f", duration))s")
            PerformanceMonitor.shared.recordQueryTime(query: name, duration: duration)
        }
        
        if duration > alertThreshold {
            logger.error("⚠️ Very slow query: \(name) took \(String(format: "%.3f", duration))s")
            #if DEBUG
            print("⚠️ [DB PERFORMANCE] Query '\(name)' exceeded alert threshold: \(String(format: "%.3f", duration))s")
            #endif
        }
        
        return result
    }
}

// MARK: - Background Context Factory

extension DatabaseOptimizer {
    
    /// Creates a background context optimized for imports
    func createImportContext(from container: NSPersistentContainer) -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = false // Disable for bulk operations
        context.undoManager = nil // No undo for imports
        return context
    }
    
    /// Creates a background context optimized for sync operations
    func createSyncContext(from container: NSPersistentContainer) -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        context.undoManager = nil
        return context
    }
    
    /// Creates a background context for general background processing
    func createBackgroundContext(from container: NSPersistentContainer) -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        context.automaticallyMergesChangesFromParent = true
        return context
    }
}

// MARK: - Query Optimization Examples

extension DatabaseOptimizer {
    
    /// Example: BAD - Fetch all, filter in Swift
    func badFetchExample(context: NSManagedObjectContext) throws -> [CalendarEvent] {
        // BAD: Fetches all events, then filters in memory
        let request: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
        let allEvents = try context.fetch(request)
        let now = Date()
        return allEvents.filter { ($0.startDate ?? now) >= now }
    }
    
    /// Example: GOOD - Filter at database level
    func goodFetchExample(context: NSManagedObjectContext) throws -> [CalendarEvent] {
        // GOOD: Filters at database level using predicate
        let request: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
        request.predicate = NSPredicate(format: "startDate >= %@", Date() as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CalendarEvent.startDate, ascending: true)]
        optimizeFetchRequest(request, batchSize: 50, returnsObjectsAsFaults: false)
        return try context.fetch(request)
    }
    
    /// Example: BAD - Separate query for each item (N+1 problem)
    func badRelationshipFetchExample(context: NSManagedObjectContext) throws -> [Bookmark] {
        // BAD: Fetches bookmarks, then queries collection for each
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        let bookmarks = try context.fetch(request)
        // This would trigger a separate query for each bookmark's collection
        return bookmarks
    }
    
    /// Example: GOOD - Prefetch relationships
    func goodRelationshipFetchExample(context: NSManagedObjectContext) throws -> [Bookmark] {
        // GOOD: Prefetches relationships in one query
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        optimizeFetchRequest(
            request,
            batchSize: 50,
            prefetchRelationships: ["collection", "tagRelations"],
            returnsObjectsAsFaults: false
        )
        return try context.fetch(request)
    }
}

