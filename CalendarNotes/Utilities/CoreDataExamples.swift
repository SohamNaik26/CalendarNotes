//
//  CoreDataExamples.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//
//  This file contains example implementations showing how to use CoreDataManager
//

import Foundation
import CoreData
import SwiftUI
import Combine

// MARK: - Example ViewModel Implementation

class ExampleNotesViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let manager = CoreDataManager.shared
    
    // MARK: - CRUD Operations
    
    func loadNotes() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            notes = try await manager.fetchAsync(Note.fetchRequest())
        } catch {
            errorMessage = "Failed to load notes: \(error.localizedDescription)"
        }
    }
    
    func loadNotes(for date: Date) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            notes = try manager.fetchNotes(linkedToDate: date)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func addNote(content: String, linkedDate: Date? = nil, tags: String? = nil) {
        do {
            let note = try manager.createNote(content: content, linkedDate: linkedDate, tags: tags)
            notes.insert(note, at: 0)
        } catch {
            errorMessage = "Failed to create note: \(error.localizedDescription)"
        }
    }
    
    func updateNote(_ note: Note, newContent: String) {
        do {
            try manager.update(note) { note in
                note.content = newContent
            }
            // Refresh the note in the array
            if let index = notes.firstIndex(where: { $0.id == note.id }) {
                notes[index] = note
            }
        } catch {
            errorMessage = "Failed to update note: \(error.localizedDescription)"
        }
    }
    
    func deleteNote(_ note: Note) {
        do {
            try manager.delete(note)
            notes.removeAll { $0.id == note.id }
        } catch {
            errorMessage = "Failed to delete note: \(error.localizedDescription)"
        }
    }
    
    func searchNotes(query: String) async {
        guard !query.isEmpty else {
            await loadNotes()
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            notes = try manager.fetchNotes(containingText: query)
        } catch {
            errorMessage = "Search failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Example Background Operations

class ExampleDataImporter {
    private let manager = CoreDataManager.shared
    
    /// Example: Import multiple events in background
    func importEvents(_ eventDataArray: [(title: String, start: Date, end: Date, category: String)]) async throws {
        try await manager.performBackgroundTask { context in
            for eventData in eventDataArray {
                _ = CalendarEvent(
                    context: context,
                    title: eventData.title,
                    startDate: eventData.start,
                    endDate: eventData.end,
                    category: eventData.category
                )
            }
            
            // Save all at once
            if context.hasChanges {
                try context.save()
            }
        }
    }
    
    /// Example: Import notes from JSON
    func importNotesFromJSON(data: Data) async throws {
        struct NoteData: Codable {
            let content: String
            let tags: String?
            let linkedDate: Date?
        }
        
        let decoder = JSONDecoder()
        let notesData = try decoder.decode([NoteData].self, from: data)
        
        try await manager.performBackgroundTask { context in
            for noteData in notesData {
                _ = Note(
                    context: context,
                    content: noteData.content,
                    linkedDate: noteData.linkedDate,
                    tags: noteData.tags
                )
            }
            
            if context.hasChanges {
                try context.save()
            }
        }
    }
}

// MARK: - Example Statistics Provider

class ExampleStatisticsProvider: ObservableObject {
    @Published var totalNotes: Int = 0
    @Published var totalEvents: Int = 0
    @Published var pendingTasks: Int = 0
    @Published var completedTasks: Int = 0
    @Published var overdueTasks: Int = 0
    
    private let manager = CoreDataManager.shared
    
    func loadStatistics() async {
        do {
            // Count notes
            let notesRequest: NSFetchRequest<Note> = Note.fetchRequest()
            totalNotes = try manager.countObjects(for: notesRequest)
            
            // Count events
            let eventsRequest: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
            totalEvents = try manager.countObjects(for: eventsRequest)
            
            // Count pending tasks
            let pendingRequest: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
            pendingRequest.predicate = NSPredicate(format: "isCompleted == NO")
            pendingTasks = try manager.countObjects(for: pendingRequest)
            
            // Count completed tasks
            let completedRequest: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
            completedRequest.predicate = NSPredicate(format: "isCompleted == YES")
            completedTasks = try manager.countObjects(for: completedRequest)
            
            // Count overdue tasks
            let overdueRequest: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
            overdueRequest.predicate = NSPredicate(format: "dueDate < %@ AND isCompleted == NO", Date() as NSDate)
            overdueTasks = try manager.countObjects(for: overdueRequest)
            
        } catch {
            print("Failed to load statistics: \(error)")
        }
    }
}

// MARK: - Example Custom Queries

class ExampleCustomQueries {
    private let manager = CoreDataManager.shared
    
    /// Get all events happening today
    func getTodayEvents() throws -> [CalendarEvent] {
        try manager.fetchEvents(for: Date())
    }
    
    /// Get this week's events
    func getWeekEvents() throws -> [CalendarEvent] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: today)!
        
        return try manager.fetchEvents(from: today, to: weekEnd)
    }
    
    /// Get urgent tasks
    func getUrgentTasks() throws -> [TodoItem] {
        try manager.fetchTodoItems(byPriority: "Urgent")
    }
    
    /// Get notes with specific tag
    func getNotes(withTag tag: String) throws -> [Note] {
        try manager.fetchNotes(withTag: tag)
    }
    
    /// Get recent notes (last 7 days)
    func getRecentNotes() throws -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        request.predicate = NSPredicate(format: "createdDate >= %@", sevenDaysAgo as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdDate, ascending: false)]
        
        return try manager.fetch(request)
    }
}

// MARK: - Example Batch Operations

class ExampleBatchOperations {
    private let manager = CoreDataManager.shared
    
    /// Clean up old completed tasks
    func cleanupOldCompletedTasks(olderThanDays days: Int) async throws {
        let context = manager.newBackgroundContext()
        
        try await context.perform {
            let date = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
            let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
            request.predicate = NSPredicate(format: "isCompleted == YES AND dueDate < %@", date as NSDate)
            
            let tasks = try context.fetch(request)
            tasks.forEach { context.delete($0) }
            
            if context.hasChanges {
                try context.save()
            }
        }
    }
    
    /// Archive old events
    func archiveOldEvents(olderThanMonths months: Int) async throws {
        let archiveDate = Calendar.current.date(byAdding: .month, value: -months, to: Date())!
        
        // In a real app, you might move these to an Archive entity instead of deleting
        let request: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
        request.predicate = NSPredicate(format: "endDate < %@", archiveDate as NSDate)
        
        try manager.batchDelete(request)
    }
    
    /// Update all tasks in a category
    func updateCategory(from oldCategory: String, to newCategory: String) async throws {
        try manager.batchUpdate(
            entityName: "TodoItem",
            propertiesToUpdate: ["category": newCategory],
            predicate: NSPredicate(format: "category == %@", oldCategory)
        )
    }
}

// MARK: - Example SwiftUI Integration

struct ExampleNotesListView: View {
    @StateObject private var viewModel = ExampleNotesViewModel()
    @State private var showingAddNote = false
    @State private var searchText = ""
    
    var body: some View {
        NavigationView {
            VStack {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if let error = viewModel.errorMessage {
                    Text("Error: \(error)")
                        .foregroundColor(.red)
                } else {
                    List {
                        ForEach(viewModel.notes, id: \.id) { note in
                            VStack(alignment: .leading) {
                                Text(note.content ?? "")
                                    .font(.body)
                                
                                if let createdDate = note.createdDate {
                                    Text(createdDate.formatted())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onDelete { indexSet in
                            indexSet.forEach { index in
                                viewModel.deleteNote(viewModel.notes[index])
                            }
                        }
                    }
                }
            }
            .navigationTitle("Notes")
            .searchable(text: $searchText)
            .onChange(of: searchText) { oldValue, newValue in
                Task {
                    await viewModel.searchNotes(query: newValue)
                }
            }
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: { showingAddNote = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .task {
                await viewModel.loadNotes()
            }
        }
    }
}

// MARK: - Example Error Handling

class ExampleErrorHandler {
    private let manager = CoreDataManager.shared
    
    func handleOperation() {
        do {
            try manager.createNote(content: "Test note")
        } catch CoreDataError.saveFailed(let message) {
            print("Save error: \(message)")
            // Show user-friendly message
        } catch CoreDataError.fetchFailed(let message) {
            print("Fetch error: \(message)")
        } catch {
            print("Unexpected error: \(error)")
        }
    }
    
    func handleAsyncOperation() async {
        do {
            let notes = try await manager.fetchAsync(Note.fetchRequest())
            print("Loaded \(notes.count) notes")
        } catch {
            // Handle error appropriately
            print("Error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension CoreDataManager {
    static func createSampleData() {
        let manager = CoreDataManager.shared
        
        // Sample notes
        _ = try? manager.createNote(content: "Remember to review the proposal", tags: "work, important")
        _ = try? manager.createNote(content: "Ideas for the weekend", tags: "personal")
        _ = try? manager.createNote(content: "Meeting notes from Monday", linkedDate: Date(), tags: "work, meetings")
        
        // Sample events
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        _ = try? manager.createEvent(
            title: "Team Standup",
            startDate: tomorrow,
            endDate: tomorrow.addingTimeInterval(1800),
            category: "Work",
            location: "Virtual"
        )
        
        _ = try? manager.createEvent(
            title: "Lunch with Sarah",
            startDate: tomorrow.addingTimeInterval(3600 * 5),
            endDate: tomorrow.addingTimeInterval(3600 * 6),
            category: "Personal",
            location: "Cafe Downtown"
        )
        
        // Sample todos
        _ = try? manager.createTodoItem(
            title: "Complete project documentation",
            priority: "High",
            category: "Work",
            dueDate: tomorrow
        )
        
        _ = try? manager.createTodoItem(
            title: "Buy groceries",
            priority: "Medium",
            category: "Personal",
            dueDate: Date()
        )
        
        _ = try? manager.createTodoItem(
            title: "Call dentist",
            priority: "Low",
            category: "Health",
            dueDate: Calendar.current.date(byAdding: .day, value: 2, to: Date())
        )
        
        print("✅ Sample data created")
    }
}
#endif

