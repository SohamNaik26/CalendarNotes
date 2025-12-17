//
//  CalendarNotesTests.swift
//  CalendarNotesTests
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import Testing
import CoreData
@testable import CalendarNotes

struct CalendarNotesTests {

    @Test func testCoreDataManagerInitialization() async throws {
        // Test that CoreDataManager can be initialized
        let manager = CoreDataManager.shared
        #expect(manager != nil)
        
        // Test that viewContext is available
        let context = manager.viewContext
        #expect(context != nil)
    }
    
    @Test func testNoteCreation() async throws {
        let manager = CoreDataManager.shared
        let context = manager.viewContext
        
        // Create a test note
        let testContent = "Test note content"
        let note = Note(context: context, content: testContent, linkedDate: Date(), tags: "test")
        
        // Verify note was created
        #expect(note.content == testContent)
        #expect(note.createdDate != nil)
        
        // Clean up
        context.delete(note)
        try? context.save()
    }
    
    @Test func testCalendarViewModelInitialization() async throws {
        // Test that CalendarViewModel can be initialized
        let viewModel = await CalendarViewModel()
        #expect(viewModel != nil)
        
        // Test initial state
        #expect(viewModel.events.isEmpty)
        #expect(viewModel.tasks.isEmpty)
        #expect(viewModel.selectedDate != nil)
    }
    
    @Test func testDateRangeCalculation() async throws {
        let viewModel = await CalendarViewModel()
        let calendar = Calendar.current
        
        // Test day view mode
        viewModel.viewMode = .day
        viewModel.currentDate = Date()
        let (start, end) = viewModel.getDateRange()
        
        let expectedStart = calendar.startOfDay(for: Date())
        #expect(calendar.isDate(start, inSameDayAs: expectedStart))
    }
    
    @Test func testEventFiltering() async throws {
        let viewModel = await CalendarViewModel()
        
        // Initially, all categories should be selected
        #expect(viewModel.selectedCategories.count > 0)
        
        // Toggle a category
        let firstCategory = viewModel.selectedCategories.first!
        viewModel.toggleCategory(firstCategory)
        
        // Category should be deselected
        #expect(!viewModel.selectedCategories.contains(firstCategory))
    }
    
    @Test func testTaskCompletionToggle() async throws {
        let manager = CoreDataManager.shared
        let context = manager.viewContext
        
        // Create a test task
        let task = TodoItem(context: context, title: "Test Task", priority: "Medium", category: "Test")
        task.isCompleted = false
        
        // Toggle completion
        let initialState = task.isCompleted
        task.isCompleted.toggle()
        
        #expect(task.isCompleted != initialState)
        
        // Clean up
        context.delete(task)
        try? context.save()
    }
    
    @Test func testErrorHandling() async throws {
        // Test that error handling doesn't crash the app
        let manager = CoreDataManager.shared
        
        // Attempt to fetch with invalid predicate (should not crash)
        do {
            let request: NSFetchRequest<Note> = Note.fetchRequest()
            request.predicate = NSPredicate(format: "invalidProperty == %@", "value")
            _ = try manager.fetch(request)
        } catch {
            // Expected to fail, but should not crash
            #expect(error != nil)
        }
    }
}
