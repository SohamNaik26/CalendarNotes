//
//  EventDetailViewModel.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import Foundation
import CoreData
import Combine
import SwiftUI

// MARK: - Event Detail View Model

class EventDetailViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var title: String = ""
    @Published var startDate: Date = Date()
    @Published var endDate: Date = Date().addingTimeInterval(3600) // 1 hour later
    @Published var category: String = EventCategory.personal.rawValue
    @Published var location: String = ""
    @Published var notes: String = ""
    @Published var isRecurring: Bool = false
    @Published var recurrenceRule: String = ""
    @Published var isAllDay: Bool = false
    
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isSaved = false
    @Published var validationErrors: [String] = []
    
    // MARK: - Properties
    
    private let manager = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var event: CalendarEvent?
    
    var isEditMode: Bool {
        event != nil
    }
    
    var canSave: Bool {
        !title.isEmpty && endDate > startDate && validationErrors.isEmpty
    }
    
    // MARK: - Initialization
    
    init(event: CalendarEvent? = nil) {
        self.event = event
        
        if let event = event {
            loadEventData(event)
        }
        
        setupValidation()
    }
    
    // MARK: - Setup
    
    private func setupValidation() {
        // Validate title
        $title
            .map { title -> [String] in
                var errors: [String] = []
                if title.isEmpty {
                    errors.append("Title is required")
                }
                if title.count > 100 {
                    errors.append("Title is too long (max 100 characters)")
                }
                return errors
            }
            .assign(to: &$validationErrors)
        
        // Auto-adjust end date if it's before start date
        $startDate
            .sink { [weak self] newStartDate in
                guard let self = self else { return }
                if self.endDate <= newStartDate {
                    self.endDate = newStartDate.addingTimeInterval(3600)
                }
            }
            .store(in: &cancellables)
        
        // Handle all-day events
        $isAllDay
            .sink { [weak self] isAllDay in
                guard let self = self else { return }
                if isAllDay {
                    self.startDate = Calendar.current.startOfDay(for: self.startDate)
                    self.endDate = Calendar.current.startOfDay(for: self.endDate)
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Load Event Data
    
    private func loadEventData(_ event: CalendarEvent) {
        title = event.title ?? ""
        startDate = event.startDate ?? Date()
        endDate = event.endDate ?? startDate.addingTimeInterval(3600)
        category = event.category ?? EventCategory.personal.rawValue
        location = event.location ?? ""
        isRecurring = event.isRecurring
        recurrenceRule = event.recurrenceRule ?? ""
        
        // Check if it's an all-day event
        let calendar = Calendar.current
        isAllDay = calendar.component(.hour, from: startDate) == 0 &&
                   calendar.component(.minute, from: startDate) == 0 &&
                   calendar.component(.hour, from: endDate) == 0 &&
                   calendar.component(.minute, from: endDate) == 0
    }
    
    // MARK: - CRUD Operations
    
    func save() async -> Bool {
        guard canSave else {
            errorMessage = "Please fix validation errors before saving"
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            if let event = event {
                // Update existing event
                try manager.update(event) { [weak self] event in
                    guard let self = self else { return }
                    event.title = self.title
                    event.startDate = self.startDate
                    event.endDate = self.endDate
                    event.category = self.category
                    event.location = self.location.isEmpty ? nil : self.location
                    event.isRecurring = self.isRecurring
                    event.recurrenceRule = self.recurrenceRule.isEmpty ? nil : self.recurrenceRule
                }
            } else {
                // Create new event
                _ = try manager.createEvent(
                    title: title,
                    startDate: startDate,
                    endDate: endDate,
                    category: category,
                    location: location.isEmpty ? nil : location,
                    isRecurring: isRecurring,
                    recurrenceRule: recurrenceRule.isEmpty ? nil : recurrenceRule
                )
            }
            
            await MainActor.run {
                isLoading = false
                isSaved = true
            }
            return true
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to save event: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    func delete() async -> Bool {
        guard let event = event else {
            errorMessage = "No event to delete"
            return false
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            try manager.delete(event)
            await MainActor.run {
                isLoading = false
                isSaved = true
            }
            return true
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to delete event: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    func duplicate() async -> Bool {
        guard event != nil else { return false }
        
        // Create a new event with the same details
        _ = event
        event = nil // Reset to create mode
        
        isLoading = true
        errorMessage = nil
        
        do {
            _ = try manager.createEvent(
                title: "\(title) (Copy)",
                startDate: startDate,
                endDate: endDate,
                category: category,
                location: location.isEmpty ? nil : location,
                isRecurring: isRecurring,
                recurrenceRule: recurrenceRule.isEmpty ? nil : recurrenceRule
            )
            
            await MainActor.run {
                isLoading = false
                isSaved = true
            }
            return true
            
        } catch {
            await MainActor.run {
                isLoading = false
                errorMessage = "Failed to duplicate event: \(error.localizedDescription)"
            }
            return false
        }
    }
    
    // MARK: - Validation
    
    func validateDates() -> Bool {
        guard endDate > startDate else {
            errorMessage = "End date must be after start date"
            return false
        }
        return true
    }
    
    func validateTitle() -> Bool {
        guard !title.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Title cannot be empty"
            return false
        }
        return true
    }
    
    func validateAll() -> Bool {
        validationErrors.isEmpty && validateTitle() && validateDates()
    }
    
    // MARK: - Utility Methods
    
    func reset() {
        title = ""
        startDate = Date()
        endDate = Date().addingTimeInterval(3600)
        category = EventCategory.personal.rawValue
        location = ""
        notes = ""
        isRecurring = false
        recurrenceRule = ""
        isAllDay = false
        errorMessage = nil
        validationErrors = []
        isSaved = false
    }
    
    func setDates(start: Date, end: Date? = nil) {
        startDate = start
        endDate = end ?? start.addingTimeInterval(3600)
    }
    
    func setCategory(_ category: EventCategory) {
        self.category = category.rawValue
    }
    
    func makeAllDay() {
        isAllDay = true
        let calendar = Calendar.current
        startDate = calendar.startOfDay(for: startDate)
        endDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate)
    }
    
    func getDuration() -> TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
    
    func getDurationFormatted() -> String {
        let duration = getDuration()
        let hours = Int(duration) / 3600
        let minutes = Int(duration) % 3600 / 60
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
    
    // MARK: - Conflict Detection
    
    func checkForConflicts() async -> [CalendarEvent] {
        do {
            let allEvents = try await manager.fetchAsync(CalendarEvent.fetchRequest())
            return allEvents.filter { otherEvent in
                guard otherEvent.id != event?.id,
                      let otherStart = otherEvent.startDate,
                      let otherEnd = otherEvent.endDate else {
                    return false
                }
                
                // Check if events overlap
                return (startDate < otherEnd && endDate > otherStart)
            }
        } catch {
            return []
        }
    }
}

