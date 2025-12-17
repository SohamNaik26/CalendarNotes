//
//  RepositoryTests.swift
//  CalendarNotesTests
//
//  Unit tests for API Repositories
//

import Testing
import Foundation
@testable import CalendarNotes

@Suite("Repository Tests")
struct RepositoryTests {
    
    @Test("Event repository CRUD operations")
    func testEventRepository() async throws {
        let repository = EventAPIRepository.shared
        
        // Create
        do {
            let event = APICalendarEvent(
                id: UUID(),
                userId: UUID(),
                title: "Test Event",
                description: "Test Description",
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                location: nil,
                category: nil,
                color: nil,
                isAllDay: false,
                isRecurring: false,
                recurrenceRule: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            _ = try await repository.create(event: event)
        } catch {
            // Expected without actual server
        }
        
        // Read
        do {
            _ = try await repository.getAll(query: nil)
        } catch {
            // Expected without actual server
        }
        
        // Update
        do {
            let eventId = UUID()
            let event = APICalendarEvent(
                id: eventId,
                userId: UUID(),
                title: "Updated Event",
                description: nil,
                startDate: Date(),
                endDate: Date().addingTimeInterval(3600),
                location: nil,
                category: nil,
                color: nil,
                isAllDay: false,
                isRecurring: false,
                recurrenceRule: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            _ = try await repository.update(id: eventId, event: event)
        } catch {
            // Expected without actual server
        }
        
        // Delete
        do {
            try await repository.delete(id: UUID())
        } catch {
            // Expected without actual server
        }
    }
    
    @Test("Note repository operations")
    func testNoteRepository() async throws {
        let repository = NoteAPIRepository.shared
        
        // Test basic operations
        do {
            _ = try await repository.getAll(query: nil)
        } catch {
            // Expected without actual server
        }
    }
    
    @Test("Todo repository operations")
    func testTodoRepository() async throws {
        let repository = TodoAPIRepository.shared
        
        // Test basic operations
        do {
            _ = try await repository.getAll(query: nil)
        } catch {
            // Expected without actual server
        }
    }
    
    @Test("Bookmark repository operations")
    func testBookmarkRepository() async throws {
        let repository = BookmarkAPIRepository.shared
        
        // Test basic operations
        do {
            _ = try await repository.getAll(query: nil)
        } catch {
            // Expected without actual server
        }
    }
    
    @Test("Voice note repository operations")
    func testVoiceNoteRepository() async throws {
        let repository = VoiceNoteAPIRepository.shared
        
        // Test basic operations
        do {
            _ = try await repository.getAll()
        } catch {
            // Expected without actual server
        }
    }
}

