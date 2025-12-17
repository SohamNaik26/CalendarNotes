//
//  SampleDataGenerator.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 25/10/25.
//

import Foundation
import CoreData
import SwiftUI

class SampleDataGenerator {
    static let shared = SampleDataGenerator()
    
    private init() {}
    
    // MARK: - Sample Data Arrays
    
    private let eventTitles = [
        "Team Meeting", "Client Presentation", "Lunch with Colleagues", "Gym Session",
        "Book Club", "Grocery Shopping", "Doctor Appointment", "Project Deadline",
        "Conference Call", "Yoga Class", "Dinner Date", "Code Review",
        "Training Session", "Dentist Visit", "Coffee with Friend", "Birthday Party",
        "Movie Night", "Concert", "Art Exhibit", "Cooking Class",
        "Wedding", "Graduation Ceremony", "Job Interview", "Vacation Planning",
        "Study Group", "Volunteer Work", "Shopping Trip", "Haircut",
        "Therapy Session", "Brunch Date"
    ]
    
    private let locations = [
        "Conference Room A", "Starbucks", "Central Park", "Yoga Studio",
        "Home Office", "Restaurant Downtown", "Medical Center", "Gym",
        "Library", "Coffee Shop", "Beach", "Office Building",
        "Online", "Museum", "Theater", nil, nil, nil
    ]
    
    private let categories = ["Work", "Personal", "Health", "Social", "Family", "Education"]
    
    private let noteContents = [
        "Great insights from today's meeting about project timeline",
        "Remember to follow up on the email from last week",
        "Found an interesting article about SwiftUI best practices",
        "Shopping list: milk, eggs, bread, chicken, vegetables",
        "Recipe ideas for the weekend dinner party",
        "Thoughts on the book I'm currently reading",
        "Meeting notes from the quarterly review",
        "Ideas for the next vacation destination",
        "Important reminders for the week ahead",
        "Interesting quotes and inspiration for the day",
        "Notes from the conference presentation",
        "Health and wellness goals for the month",
        "Budget planning for the upcoming expenses",
        "Career goals and development plan",
        "Home improvement project ideas",
        "Birthday gift ideas for friends and family",
        "Travel itinerary and packing list",
        "Workout routine and nutrition plan",
        "Weekly reflection and gratitude journal",
        "Technical notes from the coding session"
    ]
    
    private let noteTags = [
        "work,meeting", "personal,tasks", "learning,swift", "shopping,groceries",
        "cooking,recipes", "reading,books", "work,notes", "travel,planning",
        "reminders,todo", "inspiration,quotes", "conference,learning",
        "health,wellness", "finance,budget", "career,development",
        "home,projects", "gifts,personal", "travel,vacation",
        "fitness,health", "journal,gratitude", "coding,technical"
    ]
    
    private let taskTitles = [
        "Complete quarterly report", "Pay utility bills", "Schedule dentist appointment",
        "Buy groceries", "Call mom", "Review project proposal", "Update resume",
        "Book flight tickets", "Prepare presentation slides", "Clean the house",
        "Finish reading book chapter", "Update project documentation", "Send thank you notes",
        "Plan weekend activities", "Review and approve invoices", "Organize home office",
        "Set up automatic payments", "Research vacation destinations", "Update emergency contacts",
        "Plan surprise party", "Learn new programming language", "Organize photo albums",
        "Write blog post", "Schedule car service", "Cancel unused subscriptions",
        "Attend online course", "Update social media profiles", "Plan meal prep for week",
        "Review and update insurance", "Complete online certification"
    ]
    
    private let priorities = ["Low", "Medium", "High", "Urgent"]
    
    // MARK: - Generate Methods
    
    func generateSampleData(context: NSManagedObjectContext) throws {
        let calendar = Calendar.current
        let now = Date()
        
        // Get current month range
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: now))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        let daysInMonth = calendar.dateComponents([.day], from: startOfMonth, to: endOfMonth).day ?? 30
        
        // Generate 30 random events
        try generateEvents(count: 30, startDate: startOfMonth, endDate: endOfMonth, daysInMonth: daysInMonth, context: context)
        
        // Generate 20 sample notes
        try generateNotes(count: 20, context: context)
        
        // Generate 15 tasks
        try generateTasks(count: 15, context: context)
        
        // Save all changes
        try CoreDataManager.shared.save(context: context)
    }
    
    private func generateEvents(count: Int, startDate: Date, endDate: Date, daysInMonth: Int, context: NSManagedObjectContext) throws {
        for _ in 0..<count {
            // Random day in the month (0-29)
            let randomDay = Int.random(in: 0..<daysInMonth)
            guard let eventDate = Calendar.current.date(byAdding: .day, value: randomDay, to: startDate) else {
                continue
            }
            
            // Random hour between 8 AM and 8 PM
            let hour = Int.random(in: 8...20)
            let minute = [0, 15, 30, 45].randomElement()!
            guard let startDateTime = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: eventDate) else {
                continue
            }
            
            // Duration between 1 and 4 hours
            let durationHours = [1, 1.5, 2, 2.5, 3, 4].randomElement()!
            guard let endDateTime = Calendar.current.date(byAdding: .hour, value: Int(durationHours), to: startDateTime) else {
                continue
            }
            
            let title = eventTitles.randomElement()!
            let category = categories.randomElement()!
            let location = locations.randomElement() ?? nil
            let notes = Bool.random() ? "Additional notes for the event" : nil
            
            // Some events are recurring (about 20%)
            let isRecurring = Int.random(in: 0..<100) < 20
            let recurrenceRule = isRecurring ? generateRecurrenceRule() : nil
            
            _ = CalendarEvent(
                context: context,
                title: title,
                startDate: startDateTime,
                endDate: endDateTime,
                category: category,
                location: location,
                notes: notes,
                isRecurring: isRecurring,
                recurrenceRule: recurrenceRule
            )
        }
    }
    
    private func generateNotes(count: Int, context: NSManagedObjectContext) throws {
        let calendar = Calendar.current
        let now = Date()
        
        // Create notes over the past 2 months
        let daysBack = 60
        let startDate = calendar.date(byAdding: .day, value: -daysBack, to: now)!
        
        for _ in 0..<count {
            let randomDay = Int.random(in: 0..<daysBack)
            guard let noteDate = calendar.date(byAdding: .day, value: randomDay, to: startDate) else {
                continue
            }
            
            let content = noteContents.randomElement()!
            let tags = noteTags.randomElement()!
            
            // 60% of notes have linked dates (40% don't)
            let linkedDate = Int.random(in: 0..<100) < 60 ? noteDate : nil
            
            _ = Note(
                context: context,
                content: content,
                linkedDate: linkedDate,
                tags: tags
            )
        }
    }
    
    private func generateTasks(count: Int, context: NSManagedObjectContext) throws {
        let calendar = Calendar.current
        let now = Date()
        
        // Create tasks over the past 2 weeks and future 2 weeks
        let daysRange = -14...14
        
        for _ in 0..<count {
            let randomDay = Int.random(in: daysRange)
            guard let taskDate = calendar.date(byAdding: .day, value: randomDay, to: now) else {
                continue
            }
            
            // Set time to various times throughout the day
            let hour = Int.random(in: 9...17)
            let minute = [0, 15, 30, 45].randomElement()!
            guard let dueDate = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: taskDate) else {
                continue
            }
            
            let title = taskTitles.randomElement()!
            let priority = priorities.randomElement()!
            let category = categories.randomElement()!
            
            // 30% of tasks are completed
            let isCompleted = Int.random(in: 0..<100) < 30
            
            // 15% of tasks are recurring
            let isRecurring = Int.random(in: 0..<100) < 15
            
            _ = TodoItem(
                context: context,
                title: title,
                priority: priority,
                category: category,
                dueDate: dueDate,
                isCompleted: isCompleted,
                isRecurring: isRecurring
            )
        }
    }
    
    private func generateRecurrenceRule() -> String {
        let patterns = ["daily", "weekly", "monthly", "yearly"]
        return patterns.randomElement()!
    }
    
    // MARK: - Clear All Data
    
    func clearAllSampleData(context: NSManagedObjectContext) throws {
        // Fetch all objects
        let eventRequest: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
        let noteRequest: NSFetchRequest<Note> = Note.fetchRequest()
        let taskRequest: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
        
        let events = try context.fetch(eventRequest)
        let notes = try context.fetch(noteRequest)
        let tasks = try context.fetch(taskRequest)
        
        // Delete all
        events.forEach { context.delete($0) }
        notes.forEach { context.delete($0) }
        tasks.forEach { context.delete($0) }
        
        // Save
        try CoreDataManager.shared.save(context: context)
    }
}