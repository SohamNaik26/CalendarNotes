//
//  CoreDataService.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import Foundation
import CoreData
import Combine

class CoreDataService: ObservableObject {
    private let persistenceController: PersistenceController
    
    var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Calendar Events
    func createEvent(title: String, startDate: Date, endDate: Date, category: String, location: String? = nil, notes: String? = nil, isRecurring: Bool = false, recurrenceRule: String? = nil) throws {
        _ = CalendarEvent(context: viewContext, title: title, startDate: startDate, endDate: endDate, category: category, location: location, notes: notes, isRecurring: isRecurring, recurrenceRule: recurrenceRule)
        try viewContext.save()
    }
    
    func fetchEvents(from startDate: Date? = nil, to endDate: Date? = nil) -> [CalendarEvent] {
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
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CalendarEvent.startDate, ascending: true)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching events: \(error)")
            return []
        }
    }
    
    func deleteEvent(_ event: CalendarEvent) throws {
        viewContext.delete(event)
        try viewContext.save()
    }
    
    // MARK: - Notes
    func createNote(content: String, linkedDate: Date? = nil, tags: String? = nil) throws {
        _ = Note(context: viewContext, content: content, linkedDate: linkedDate, tags: tags)
        try viewContext.save()
    }
    
    func fetchNotes(linkedToDate date: Date? = nil) -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        
        if let date = date {
            let startOfDay = Calendar.current.startOfDay(for: date)
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
            request.predicate = NSPredicate(format: "linkedDate >= %@ AND linkedDate <= %@", startOfDay as NSDate, endOfDay as NSDate)
        }
        
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdDate, ascending: false)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching notes: \(error)")
            return []
        }
    }
    
    func deleteNote(_ note: Note) throws {
        viewContext.delete(note)
        try viewContext.save()
    }
    
    // MARK: - Todo Items
    func createTodoItem(title: String, priority: String, category: String, dueDate: Date? = nil, isCompleted: Bool = false, isRecurring: Bool = false) throws {
        _ = TodoItem(context: viewContext, title: title, priority: priority, category: category, dueDate: dueDate, isCompleted: isCompleted, isRecurring: isRecurring)
        try viewContext.save()
    }
    
    func fetchTodoItems(completed: Bool? = nil) -> [TodoItem] {
        let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
        
        if let completed = completed {
            request.predicate = NSPredicate(format: "isCompleted == %@", NSNumber(value: completed))
        }
        
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TodoItem.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \TodoItem.dueDate, ascending: true)
        ]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching todo items: \(error)")
            return []
        }
    }
    
    func fetchAllTodoItems() -> [TodoItem] {
        let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TodoItem.dueDate, ascending: true)]
        
        do {
            return try viewContext.fetch(request)
        } catch {
            print("Error fetching all todo items: \(error)")
            return []
        }
    }
    
    func toggleTodoCompletion(_ todo: TodoItem) throws {
        todo.isCompleted.toggle()
        try viewContext.save()
    }
    
    func deleteTodoItem(_ todo: TodoItem) throws {
        viewContext.delete(todo)
        try viewContext.save()
    }
    
    // MARK: - Save Context
    func save() throws {
        if viewContext.hasChanges {
            try viewContext.save()
        }
    }
}

