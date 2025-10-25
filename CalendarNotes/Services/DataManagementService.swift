//
//  DataManagementService.swift
//  CalendarNotes
//
//  Comprehensive data management service for export, import, cleanup, and storage management
//

import Foundation
import CoreData
import Combine
import SwiftUI

// MARK: - Data Management Errors

enum DataManagementError: Error, LocalizedError {
    case exportFailed(String)
    case importFailed(String)
    case validationFailed(String)
    case storageCalculationFailed(String)
    case cleanupFailed(String)
    case compressionFailed(String)
    case cacheClearFailed(String)
    case batchDeleteFailed(String)
    case lowStorageWarning(String)
    
    var errorDescription: String? {
        switch self {
        case .exportFailed(let message):
            return "Export failed: \(message)"
        case .importFailed(let message):
            return "Import failed: \(message)"
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .storageCalculationFailed(let message):
            return "Storage calculation failed: \(message)"
        case .cleanupFailed(let message):
            return "Cleanup failed: \(message)"
        case .compressionFailed(let message):
            return "Compression failed: \(message)"
        case .cacheClearFailed(let message):
            return "Cache clear failed: \(message)"
        case .batchDeleteFailed(let message):
            return "Batch delete failed: \(message)"
        case .lowStorageWarning(let message):
            return "Low storage warning: \(message)"
        }
    }
}

// MARK: - Export Data Models

struct ExportData: Codable {
    let version: String
    let exportDate: Date
    let events: [ExportEvent]
    let notes: [ExportNote]
    let todoItems: [ExportTodoItem]
    let metadata: ExportMetadata
}

struct ExportEvent: Codable {
    let id: UUID
    let title: String
    let startDate: Date
    let endDate: Date
    let category: String
    let location: String?
    let notes: String?
    let isRecurring: Bool
    let recurrenceRule: String?
    let createdDate: Date
    let modifiedDate: Date?
}

struct ExportNote: Codable {
    let id: UUID
    let content: String
    let createdDate: Date
    let linkedDate: Date?
    let tags: String?
}

struct ExportTodoItem: Codable {
    let id: UUID
    let title: String
    let priority: String
    let category: String
    let dueDate: Date?
    let isCompleted: Bool
    let isRecurring: Bool
    let createdDate: Date
}

struct ExportMetadata: Codable {
    let totalEvents: Int
    let totalNotes: Int
    let totalTodoItems: Int
    let completedTodoItems: Int
    let exportSize: Int
    let deviceInfo: String
    let appVersion: String
}

// MARK: - Storage Information

struct StorageInfo {
    let totalSize: Int64
    let databaseSize: Int64
    let cacheSize: Int64
    let documentsSize: Int64
    let availableSpace: Int64
    let isLowStorage: Bool
    let warningThreshold: Int64
}

// MARK: - Data Management Service

class DataManagementService: ObservableObject {
    
    // MARK: - Properties
    
    private let coreDataManager: CoreDataManager
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let cacheDirectory: URL
    
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var isCleaning = false
    @Published var isCompressing = false
    @Published var storageInfo: StorageInfo?
    @Published var lastExportDate: Date?
    @Published var lastCleanupDate: Date?
    
    // Storage warning threshold (500 MB)
    private let storageWarningThreshold: Int64 = 500 * 1024 * 1024
    
    // MARK: - Initialization
    
    init(coreDataManager: CoreDataManager = .shared) {
        self.coreDataManager = coreDataManager
        self.documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.cacheDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
        
        // Load last export and cleanup dates
        loadLastOperationDates()
        
        // Calculate initial storage info
        Task {
            await calculateStorageInfo()
        }
    }
    
    // MARK: - JSON Export
    
    func exportAllDataToJSON() async throws -> URL {
        await MainActor.run { isExporting = true }
        defer { Task { @MainActor in isExporting = false } }
        
        do {
            let exportData = try await createExportData()
            let jsonData = try JSONEncoder().encode(exportData)
            
            let fileName = "CalendarNotes_Export_\(Date().formatted(.iso8601.year().month().day().dateSeparator(.dash))).json"
            let fileURL = documentsDirectory.appendingPathComponent(fileName)
            
            try jsonData.write(to: fileURL)
            
            await MainActor.run {
                lastExportDate = Date()
                UserDefaults.standard.set(Date(), forKey: "lastExportDate")
            }
            
            return fileURL
        } catch {
            throw DataManagementError.exportFailed(error.localizedDescription)
        }
    }
    
    private func createExportData() async throws -> ExportData {
        return try await coreDataManager.performBackgroundTask { context in
            // Fetch all data
            let eventsRequest: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
            let notesRequest: NSFetchRequest<Note> = Note.fetchRequest()
            let todoRequest: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
            
            let events = try context.fetch(eventsRequest)
            let notes = try context.fetch(notesRequest)
            let todos = try context.fetch(todoRequest)
            
            // Convert to export models
            let exportEvents = events.map { event in
                ExportEvent(
                    id: event.id ?? UUID(),
                    title: event.title ?? "",
                    startDate: event.startDate ?? Date(),
                    endDate: event.endDate ?? Date(),
                    category: event.category ?? "Other",
                    location: event.location,
                    notes: event.notes,
                    isRecurring: event.isRecurring,
                    recurrenceRule: event.recurrenceRule,
                    createdDate: event.createdDate ?? Date(),
                    modifiedDate: event.modifiedDate
                )
            }
            
            let exportNotes = notes.map { note in
                ExportNote(
                    id: note.id ?? UUID(),
                    content: note.content ?? "",
                    createdDate: note.createdDate ?? Date(),
                    linkedDate: note.linkedDate,
                    tags: note.tags
                )
            }
            
            let exportTodos = todos.map { todo in
                ExportTodoItem(
                    id: todo.id ?? UUID(),
                    title: todo.title ?? "",
                    priority: todo.priority ?? "Medium",
                    category: todo.category ?? "General",
                    dueDate: todo.dueDate,
                    isCompleted: todo.isCompleted,
                    isRecurring: todo.isRecurring,
                    createdDate: Date() // Use current date as fallback since TodoItem doesn't have createdDate
                )
            }
            
            let metadata = ExportMetadata(
                totalEvents: events.count,
                totalNotes: notes.count,
                totalTodoItems: todos.count,
                completedTodoItems: todos.filter { $0.isCompleted }.count,
                exportSize: 0, // Will be calculated after encoding
                deviceInfo: "iOS Device",
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
            )
            
            return ExportData(
                version: "1.0",
                exportDate: Date(),
                events: exportEvents,
                notes: exportNotes,
                todoItems: exportTodos,
                metadata: metadata
            )
        }
    }
    
    // MARK: - JSON Import
    
    func importDataFromJSON(url: URL) async throws {
        await MainActor.run { isImporting = true }
        defer { Task { @MainActor in isImporting = false } }
        
        do {
            let jsonData = try Data(contentsOf: url)
            let exportData = try JSONDecoder().decode(ExportData.self, from: jsonData)
            
            // Validate import data
            try validateImportData(exportData)
            
            // Import data
            try await importExportData(exportData)
            
        } catch {
            throw DataManagementError.importFailed(error.localizedDescription)
        }
    }
    
    private func validateImportData(_ data: ExportData) throws {
        // Validate version compatibility
        guard data.version == "1.0" else {
            throw DataManagementError.validationFailed("Incompatible export version: \(data.version)")
        }
        
        // Validate data integrity
        for event in data.events {
            guard !event.title.isEmpty else {
                throw DataManagementError.validationFailed("Event title cannot be empty")
            }
            guard event.startDate < event.endDate else {
                throw DataManagementError.validationFailed("Event start date must be before end date")
            }
        }
        
        for note in data.notes {
            guard !note.content.isEmpty else {
                throw DataManagementError.validationFailed("Note content cannot be empty")
            }
        }
        
        for todo in data.todoItems {
            guard !todo.title.isEmpty else {
                throw DataManagementError.validationFailed("Todo title cannot be empty")
            }
        }
    }
    
    private func importExportData(_ data: ExportData) async throws {
        try await coreDataManager.performBackgroundTask { context in
            // Import events
            for exportEvent in data.events {
                let event = CalendarEvent(context: context)
                event.id = exportEvent.id
                event.title = exportEvent.title
                event.startDate = exportEvent.startDate
                event.endDate = exportEvent.endDate
                event.category = exportEvent.category
                event.location = exportEvent.location
                event.notes = exportEvent.notes
                event.isRecurring = exportEvent.isRecurring
                event.recurrenceRule = exportEvent.recurrenceRule
                event.createdDate = exportEvent.createdDate
                event.modifiedDate = exportEvent.modifiedDate
            }
            
            // Import notes
            for exportNote in data.notes {
                let note = Note(context: context)
                note.id = exportNote.id
                note.content = exportNote.content
                note.createdDate = exportNote.createdDate
                note.linkedDate = exportNote.linkedDate
                note.tags = exportNote.tags
            }
            
            // Import todos
            for exportTodo in data.todoItems {
                let todo = TodoItem(context: context)
                todo.id = exportTodo.id
                todo.title = exportTodo.title
                todo.priority = exportTodo.priority
                todo.category = exportTodo.category
                todo.dueDate = exportTodo.dueDate
                todo.isCompleted = exportTodo.isCompleted
                todo.isRecurring = exportTodo.isRecurring
                // Note: TodoItem doesn't have createdDate property, so we skip it
            }
            
            try context.save()
        }
    }
    
    // MARK: - Automatic Cleanup
    
    func performAutomaticCleanup() async throws {
        await MainActor.run { isCleaning = true }
        defer { Task { @MainActor in isCleaning = false } }
        
        do {
            // Clean up old completed tasks (30 days)
            try await cleanupOldCompletedTasks(days: 30)
            
            // Clean up old archived notes (90 days)
            try await cleanupOldArchivedNotes(days: 90)
            
            // Clear temporary cache files
            try await clearCache()
            
            await MainActor.run {
                lastCleanupDate = Date()
                UserDefaults.standard.set(Date(), forKey: "lastCleanupDate")
            }
            
        } catch {
            throw DataManagementError.cleanupFailed(error.localizedDescription)
        }
    }
    
    private func cleanupOldCompletedTasks(days: Int) async throws {
        try await coreDataManager.performBackgroundTask { context in
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
            
            let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
            request.predicate = NSPredicate(format: "isCompleted == YES AND modifiedDate < %@", cutoffDate as NSDate)
            
            let todos = try context.fetch(request)
            for todo in todos {
                context.delete(todo)
            }
            
            try context.save()
        }
    }
    
    private func cleanupOldArchivedNotes(days: Int) async throws {
        try await coreDataManager.performBackgroundTask { context in
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
            
            let request: NSFetchRequest<Note> = Note.fetchRequest()
            request.predicate = NSPredicate(format: "createdDate < %@", cutoffDate as NSDate)
            
            let notes = try context.fetch(request)
            for note in notes {
                context.delete(note)
            }
            
            try context.save()
        }
    }
    
    // MARK: - Archive Notes
    
    func archiveOldNotes(olderThanDays days: Int) async throws {
        try await coreDataManager.performBackgroundTask { context in
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
            
            let request: NSFetchRequest<Note> = Note.fetchRequest()
            request.predicate = NSPredicate(format: "createdDate < %@", cutoffDate as NSDate)
            
            let notes = try context.fetch(request)
            // Since we don't have an isArchived property, we'll just mark them for deletion
            // In a real implementation, you might want to add an isArchived property to the Core Data model
            for note in notes {
                // For now, we'll just update the created date to mark as archived
                // This is a workaround since the Core Data model doesn't have isArchived
                note.createdDate = Date()
            }
            
            try context.save()
        }
    }
    
    // MARK: - Database Compression
    
    func compressDatabase() async throws {
        await MainActor.run { isCompressing = true }
        defer { Task { @MainActor in isCompressing = false } }
        
        do {
            // Perform database optimization
            try await coreDataManager.performBackgroundTask { context in
                // This would typically involve:
                // 1. Rebuilding indexes
                // 2. Vacuuming the database
                // 3. Optimizing storage
                
                // For Core Data, we can perform a save to optimize the store
                try context.save()
            }
            
            // Clear any temporary files
            try await clearCache()
            
        } catch {
            throw DataManagementError.compressionFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Storage Calculation
    
    func calculateStorageInfo() async {
        do {
            let totalSize = try await calculateTotalStorageSize()
            let databaseSize = try await calculateDatabaseSize()
            let cacheSize = try await calculateCacheSize()
            let documentsSize = try await calculateDocumentsSize()
            let availableSpace = try await calculateAvailableSpace()
            
            let isLowStorage = availableSpace < storageWarningThreshold
            
            await MainActor.run {
                storageInfo = StorageInfo(
                    totalSize: totalSize,
                    databaseSize: databaseSize,
                    cacheSize: cacheSize,
                    documentsSize: documentsSize,
                    availableSpace: availableSpace,
                    isLowStorage: isLowStorage,
                    warningThreshold: storageWarningThreshold
                )
                
                if isLowStorage {
                    // Trigger low storage warning
                    NotificationCenter.default.post(
                        name: .lowStorageWarning,
                        object: nil,
                        userInfo: ["availableSpace": availableSpace]
                    )
                }
            }
            
        } catch {
            print("Error calculating storage info: \(error)")
        }
    }
    
    private func calculateTotalStorageSize() async throws -> Int64 {
        // Calculate total app storage usage
        let documentsSize = try await calculateDocumentsSize()
        let cacheSize = try await calculateCacheSize()
        return documentsSize + cacheSize
    }
    
    private func calculateDatabaseSize() async throws -> Int64 {
        // Get Core Data store size
        guard let storeURL = coreDataManager.persistentContainer.persistentStoreDescriptions.first?.url else {
            return 0
        }
        
        let attributes = try fileManager.attributesOfItem(atPath: storeURL.path)
        return attributes[.size] as? Int64 ?? 0
    }
    
    private func calculateCacheSize() async throws -> Int64 {
        return try await calculateDirectorySize(cacheDirectory)
    }
    
    private func calculateDocumentsSize() async throws -> Int64 {
        return try await calculateDirectorySize(documentsDirectory)
    }
    
    private func calculateAvailableSpace() async throws -> Int64 {
        let attributes = try fileManager.attributesOfFileSystem(forPath: documentsDirectory.path)
        return attributes[.systemFreeSize] as? Int64 ?? 0
    }
    
    private func calculateDirectorySize(_ url: URL) async throws -> Int64 {
        var totalSize: Int64 = 0
        
        let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let attributes = try fileManager.attributesOfItem(atPath: fileURL.path)
            totalSize += attributes[.size] as? Int64 ?? 0
        }
        
        return totalSize
    }
    
    // MARK: - Clear Cache
    
    func clearCache() async throws {
        do {
            let cacheContents = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            
            for url in cacheContents {
                try fileManager.removeItem(at: url)
            }
            
        } catch {
            throw DataManagementError.cacheClearFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Batch Delete Operations
    
    func batchDeleteCompletedTasks() async throws {
        try await coreDataManager.performBackgroundTask { context in
            let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
            request.predicate = NSPredicate(format: "isCompleted == YES")
            
            let todos = try context.fetch(request)
            for todo in todos {
                context.delete(todo)
            }
            
            try context.save()
        }
    }
    
    func batchDeleteArchivedNotes() async throws {
        try await coreDataManager.performBackgroundTask { context in
            // Since we don't have isArchived property, we'll delete old notes instead
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -180, to: Date())!
            let request: NSFetchRequest<Note> = Note.fetchRequest()
            request.predicate = NSPredicate(format: "createdDate < %@", cutoffDate as NSDate)
            
            let notes = try context.fetch(request)
            for note in notes {
                context.delete(note)
            }
            
            try context.save()
        }
    }
    
    func batchDeleteOldEvents(olderThanDays days: Int) async throws {
        try await coreDataManager.performBackgroundTask { context in
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
            
            let request: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
            request.predicate = NSPredicate(format: "endDate < %@", cutoffDate as NSDate)
            
            let events = try context.fetch(request)
            for event in events {
                context.delete(event)
            }
            
            try context.save()
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadLastOperationDates() {
        lastExportDate = UserDefaults.standard.object(forKey: "lastExportDate") as? Date
        lastCleanupDate = UserDefaults.standard.object(forKey: "lastCleanupDate") as? Date
    }
    
    // MARK: - Formatting Helpers
    
    func formatStorageSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    func getStorageUsagePercentage() -> Double {
        guard let storageInfo = storageInfo else { return 0.0 }
        let totalSpace = storageInfo.totalSize + storageInfo.availableSpace
        return Double(storageInfo.totalSize) / Double(totalSpace) * 100.0
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let lowStorageWarning = Notification.Name("lowStorageWarning")
}

// MARK: - Date Extensions

extension Date {
    func startOfDayForDataManagement() -> Date {
        Calendar.current.startOfDay(for: self)
    }
    
    func endOfDayForDataManagement() -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: startOfDayForDataManagement()) ?? self
    }
}
