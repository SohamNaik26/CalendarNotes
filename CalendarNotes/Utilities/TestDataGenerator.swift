//
//  TestDataGenerator.swift
//  CalendarNotes
//
//  Created for comprehensive testing
//

import Foundation
import CoreData

/// Generates realistic test data for comprehensive testing
final class TestDataGenerator {
    static let shared = TestDataGenerator()
    
    private let dateFormatter = ISO8601DateFormatter()
    private let random = SystemRandomNumberGenerator()
    
    private init() {}
    
    // MARK: - User Generation
    
    func generateUser(id: String? = nil, email: String? = nil, fullName: String? = nil) -> User {
        let userId = id ?? UUID().uuidString
        let userEmail = email ?? "testuser\(Int.random(in: 1000...9999))@example.com"
        let userName = fullName ?? generateRandomName()
        
        return User(
            id: userId,
            email: userEmail,
            fullName: userName,
            profileImageUrl: nil,
            createdAt: Date(),
            emailVerified: false
        )
    }
    
    // MARK: - Event Generation
    
    func generateEvent(
        id: UUID = UUID(),
        title: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        category: String? = nil
    ) -> TestCalendarEvent {
        let eventTitle = title ?? generateRandomEventTitle()
        let start = startDate ?? Date().addingTimeInterval(Double.random(in: -86400...86400))
        let duration = TimeInterval.random(in: 1800...14400) // 30 min to 4 hours
        let end = endDate ?? start.addingTimeInterval(duration)
        
        return TestCalendarEvent(
            id: id,
            title: eventTitle,
            description: generateRandomDescription(),
            startDate: start,
            endDate: end,
            category: category ?? generateRandomCategory(),
            location: Bool.random() ? generateRandomLocation() : nil,
            isAllDay: Bool.random(),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func generateEvents(count: Int, startDate: Date? = nil) -> [TestCalendarEvent] {
        (0..<count).map { index in
            let date = startDate?.addingTimeInterval(Double(index * 3600)) ?? Date()
            return generateEvent(startDate: date)
        }
    }
    
    // MARK: - Note Generation
    
    func generateNote(
        id: UUID = UUID(),
        title: String? = nil,
        content: String? = nil,
        linkedDate: Date? = nil
    ) -> TestNote {
        let noteTitle = title ?? generateRandomNoteTitle()
        let noteContent = content ?? generateRandomNoteContent()
        
        return TestNote(
            id: id,
            title: noteTitle,
            content: noteContent,
            linkedDate: linkedDate,
            tags: generateRandomTags(count: Int.random(in: 0...5)),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func generateNotes(count: Int) -> [TestNote] {
        (0..<count).map { _ in generateNote() }
    }
    
    // MARK: - Todo Generation
    
    func generateTodo(
        id: UUID = UUID(),
        title: String? = nil,
        completed: Bool? = nil,
        priority: TodoPriority? = nil,
        dueDate: Date? = nil
    ) -> TestTodoItem {
        let todoTitle = title ?? generateRandomTodoTitle()
        let isCompleted = completed ?? Bool.random()
        let todoPriority = priority ?? generateRandomPriority()
        let todoDueDate = dueDate ?? (Bool.random() ? Date().addingTimeInterval(Double.random(in: 0...604800)) : nil)
        
        return TestTodoItem(
            id: id,
            title: todoTitle,
            description: Bool.random() ? generateRandomDescription() : nil,
            completed: isCompleted,
            priority: todoPriority,
            dueDate: todoDueDate,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func generateTodos(count: Int, completedRatio: Double = 0.3) -> [TestTodoItem] {
        (0..<count).map { _ in
            let completed = Double.random(in: 0...1) < completedRatio
            return generateTodo(completed: completed)
        }
    }
    
    // MARK: - Bookmark Generation
    
    func generateBookmark(
        id: UUID = UUID(),
        url: String? = nil,
        title: String? = nil,
        favorite: Bool? = nil
    ) -> TestBookmark {
        let bookmarkURL = url ?? generateRandomURL()
        let bookmarkTitle = title ?? generateRandomBookmarkTitle()
        
        return TestBookmark(
            id: id,
            url: bookmarkURL,
            title: bookmarkTitle,
            description: Bool.random() ? generateRandomDescription() : nil,
            favorite: favorite ?? Bool.random(),
            archived: false,
            tags: generateRandomTags(count: Int.random(in: 0...3)),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func generateBookmarks(count: Int) -> [TestBookmark] {
        (0..<count).map { _ in generateBookmark() }
    }
    
    // MARK: - Voice Note Generation
    
    func generateVoiceNote(
        id: UUID = UUID(),
        title: String? = nil,
        duration: TimeInterval? = nil,
        transcribed: Bool = false
    ) -> TestVoiceNote {
        let noteTitle = title ?? generateRandomVoiceNoteTitle()
        let noteDuration = duration ?? TimeInterval.random(in: 10...300)
        
        return TestVoiceNote(
            id: id,
            title: noteTitle,
            duration: noteDuration,
            transcription: transcribed ? generateRandomTranscription() : nil,
            audioURL: nil,
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func generateVoiceNotes(count: Int) -> [TestVoiceNote] {
        (0..<count).map { _ in generateVoiceNote() }
    }
    
    // MARK: - Collection Generation
    
    func generateCollection(
        id: UUID = UUID(),
        name: String? = nil,
        description: String? = nil
    ) -> TestCollection {
        let collectionName = name ?? generateRandomCollectionName()
        
        return TestCollection(
            id: id,
            name: collectionName,
            description: description ?? generateRandomDescription(),
            color: generateRandomColor(),
            createdAt: Date(),
            updatedAt: Date()
        )
    }
    
    func generateCollections(count: Int) -> [TestCollection] {
        (0..<count).map { _ in generateCollection() }
    }
    
    // MARK: - Sync Scenario Generation
    
    func generateSyncScenario(
        localChanges: Int = 10,
        remoteChanges: Int = 10,
        conflicts: Int = 2
    ) -> SyncScenario {
        let localEvents = generateEvents(count: localChanges)
        let remoteEvents = generateEvents(count: remoteChanges)
        
        // Create conflicts by reusing some IDs
        var conflictingEvents: [TestCalendarEvent] = []
        if conflicts > 0 {
            for i in 0..<min(conflicts, localEvents.count, remoteEvents.count) {
                let localEvent = localEvents[i]
                let remoteEvent = generateEvent(
                    id: localEvent.id,
                    title: "Conflicting Title \(i)",
                    startDate: localEvent.startDate.addingTimeInterval(3600)
                )
                conflictingEvents.append(remoteEvent)
            }
        }
        
        return SyncScenario(
            localEvents: localEvents,
            remoteEvents: remoteEvents,
            conflictingEvents: conflictingEvents,
            localNotes: generateNotes(count: localChanges),
            remoteNotes: generateNotes(count: remoteChanges),
            localTodos: generateTodos(count: localChanges),
            remoteTodos: generateTodos(count: remoteChanges),
            localBookmarks: generateBookmarks(count: localChanges),
            remoteBookmarks: generateBookmarks(count: remoteChanges)
        )
    }
    
    // MARK: - Large Dataset Generation
    
    func generateLargeDataset(
        events: Int = 1000,
        notes: Int = 1000,
        todos: Int = 1000,
        bookmarks: Int = 1000,
        voiceNotes: Int = 100
    ) -> LargeTestDataset {
        return LargeTestDataset(
            events: generateEvents(count: events),
            notes: generateNotes(count: notes),
            todos: generateTodos(count: todos),
            bookmarks: generateBookmarks(count: bookmarks),
            voiceNotes: generateVoiceNotes(count: voiceNotes)
        )
    }
    
    // MARK: - Helper Methods
    
    private func generateRandomName() -> String {
        let firstNames = ["John", "Jane", "Michael", "Sarah", "David", "Emily", "James", "Emma", "Robert", "Olivia"]
        let lastNames = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis", "Rodriguez", "Martinez"]
        return "\(firstNames.randomElement()!) \(lastNames.randomElement()!)"
    }
    
    private func generateRandomEventTitle() -> String {
        let prefixes = ["Meeting", "Conference", "Workshop", "Lunch", "Dinner", "Call", "Review", "Planning"]
        let suffixes = ["with Team", "with Client", "Review Session", "Planning Session", "Standup", "Retrospective"]
        return "\(prefixes.randomElement()!) \(suffixes.randomElement()!)"
    }
    
    private func generateRandomNoteTitle() -> String {
        let titles = ["Daily Notes", "Meeting Notes", "Ideas", "Thoughts", "Reminders", "Journal Entry", "Quick Note"]
        return titles.randomElement()!
    }
    
    private func generateRandomNoteContent() -> String {
        let paragraphs = [
            "This is a test note with some content.",
            "Here are some thoughts and ideas.",
            "Important information to remember.",
            "Quick note about today's activities.",
            "Meeting notes and action items."
        ]
        return paragraphs.randomElement()!
    }
    
    private func generateRandomTodoTitle() -> String {
        let todos = ["Complete project", "Review code", "Write documentation", "Fix bug", "Update dependencies", "Test feature"]
        return todos.randomElement()!
    }
    
    private func generateRandomBookmarkTitle() -> String {
        let titles = ["Interesting Article", "Useful Resource", "Tutorial", "Documentation", "Blog Post", "Reference"]
        return titles.randomElement()!
    }
    
    private func generateRandomVoiceNoteTitle() -> String {
        let titles = ["Voice Memo", "Quick Note", "Reminder", "Thought", "Idea"]
        return titles.randomElement()!
    }
    
    private func generateRandomCollectionName() -> String {
        let names = ["Work", "Personal", "Research", "Travel", "Recipes", "Projects", "Ideas", "Archive"]
        return names.randomElement()!
    }
    
    private func generateRandomDescription() -> String {
        let descriptions = [
            "This is a detailed description of the item.",
            "Additional information and context.",
            "Notes and observations about this item.",
            "Important details to remember."
        ]
        return descriptions.randomElement()!
    }
    
    private func generateRandomCategory() -> String {
        let categories = ["Work", "Personal", "Health", "Education", "Travel", "Family", "Hobby"]
        return categories.randomElement()!
    }
    
    private func generateRandomLocation() -> String {
        let locations = ["Office", "Home", "Cafe", "Park", "Restaurant", "Conference Room", "Remote"]
        return locations.randomElement()!
    }
    
    private func generateRandomTags(count: Int) -> [String] {
        let allTags = ["important", "urgent", "work", "personal", "project", "meeting", "idea", "todo", "reference"]
        return Array(allTags.shuffled().prefix(count))
    }
    
    private func generateRandomPriority() -> TodoPriority {
        let priorities: [TodoPriority] = [.low, .medium, .high]
        return priorities.randomElement()!
    }
    
    private func generateRandomURL() -> String {
        let domains = ["example.com", "test.com", "demo.org", "sample.net"]
        let paths = ["article", "post", "page", "resource", "tutorial"]
        return "https://\(domains.randomElement()!)/\(paths.randomElement()!)/\(Int.random(in: 1...1000))"
    }
    
    private func generateRandomColor() -> String {
        let colors = ["#FF5733", "#33FF57", "#3357FF", "#FF33F5", "#F5FF33", "#33FFF5"]
        return colors.randomElement()!
    }
    
    private func generateRandomTranscription() -> String {
        let transcriptions = [
            "This is a test transcription of a voice note.",
            "Here's what I was thinking about during the recording.",
            "Quick reminder about the meeting tomorrow.",
            "Important points to remember from the discussion."
        ]
        return transcriptions.randomElement()!
    }
}

// MARK: - Test Data Models

struct SyncScenario {
    let localEvents: [TestCalendarEvent]
    let remoteEvents: [TestCalendarEvent]
    let conflictingEvents: [TestCalendarEvent]
    let localNotes: [TestNote]
    let remoteNotes: [TestNote]
    let localTodos: [TestTodoItem]
    let remoteTodos: [TestTodoItem]
    let localBookmarks: [TestBookmark]
    let remoteBookmarks: [TestBookmark]
}

struct LargeTestDataset {
    let events: [TestCalendarEvent]
    let notes: [TestNote]
    let todos: [TestTodoItem]
    let bookmarks: [TestBookmark]
    let voiceNotes: [TestVoiceNote]
}

// MARK: - Test Model Extensions

// Note: These test models are simplified versions for testing
// They use a Test prefix to avoid conflicts with Core Data entities

struct TestCalendarEvent: Codable {
    let id: UUID
    let title: String
    let description: String?
    let startDate: Date
    let endDate: Date
    let category: String?
    let location: String?
    let isAllDay: Bool
    let createdAt: Date
    let updatedAt: Date
}

struct TestNote: Codable {
    let id: UUID
    let title: String
    let content: String
    let linkedDate: Date?
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
}

struct TestTodoItem: Codable {
    let id: UUID
    let title: String
    let description: String?
    let completed: Bool
    let priority: TodoPriority
    let dueDate: Date?
    let createdAt: Date
    let updatedAt: Date
}

enum TodoPriority: String, Codable {
    case low, medium, high
}

struct TestBookmark: Codable {
    let id: UUID
    let url: String
    let title: String
    let description: String?
    let favorite: Bool
    let archived: Bool
    let tags: [String]
    let createdAt: Date
    let updatedAt: Date
}

struct TestVoiceNote: Codable {
    let id: UUID
    let title: String
    let duration: TimeInterval
    let transcription: String?
    let audioURL: URL?
    let createdAt: Date
    let updatedAt: Date
}

struct TestCollection: Codable {
    let id: UUID
    let name: String
    let description: String?
    let color: String
    let createdAt: Date
    let updatedAt: Date
}

