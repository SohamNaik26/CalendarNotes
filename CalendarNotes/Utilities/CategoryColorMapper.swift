//
//  CategoryColorMapper.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 22/10/25.
//

import Foundation
import EventKit
import SwiftUI

// MARK: - Category Color Mapping

struct CategoryColorMapper {
    
    /// Maps CalendarNotes category names to EventKit calendar colors
    static func ekColor(for category: String) -> CGColor {
        #if os(macOS)
        switch category.lowercased() {
        case "work", "business":
            return NSColor.blue.cgColor
        case "personal":
            return NSColor.green.cgColor
        case "family":
            return NSColor.orange.cgColor
        case "health", "fitness":
            return NSColor.red.cgColor
        case "education", "learning":
            return NSColor.purple.cgColor
        case "finance":
            return NSColor.systemGreen.cgColor
        case "social":
            return NSColor.systemPink.cgColor
        case "travel":
            return NSColor.systemTeal.cgColor
        case "home":
            return NSColor.brown.cgColor
        case "entertainment", "hobby":
            return NSColor.systemIndigo.cgColor
        default:
            return NSColor.gray.cgColor
        }
        #else
        switch category.lowercased() {
        case "work", "business":
            return UIColor.blue.cgColor
        case "personal":
            return UIColor.green.cgColor
        case "family":
            return UIColor.orange.cgColor
        case "health", "fitness":
            return UIColor.red.cgColor
        case "education", "learning":
            return UIColor.purple.cgColor
        case "finance":
            return UIColor.systemGreen.cgColor
        case "social":
            return UIColor.systemPink.cgColor
        case "travel":
            return UIColor.systemTeal.cgColor
        case "home":
            return UIColor.brown.cgColor
        case "entertainment", "hobby":
            return UIColor.systemIndigo.cgColor
        default:
            return UIColor.gray.cgColor
        }
        #endif
    }
    
    /// Maps CalendarNotes category names to SwiftUI colors for display
    static func swiftUIColor(for category: String) -> Color {
        switch category.lowercased() {
        case "work", "business":
            return .blue
        case "personal":
            return .green
        case "family":
            return .orange
        case "health", "fitness":
            return .red
        case "education", "learning":
            return .purple
        case "finance":
            #if os(macOS)
            return Color(NSColor.systemGreen)
            #else
            return .green
            #endif
        case "social":
            #if os(macOS)
            return Color(NSColor.systemPink)
            #else
            return .pink
            #endif
        case "travel":
            #if os(macOS)
            return Color(NSColor.systemTeal)
            #else
            return .teal
            #endif
        case "home":
            return .brown
        case "entertainment", "hobby":
            #if os(macOS)
            return Color(NSColor.systemIndigo)
            #else
            return .indigo
            #endif
        default:
            return .gray
        }
    }
    
    /// Gets a display name for a category
    static func displayName(for category: String) -> String {
        return category.capitalized
    }
    
    /// All available categories
    static let categories = [
        "Work",
        "Personal",
        "Family",
        "Health",
        "Education",
        "Finance",
        "Social",
        "Travel",
        "Home",
        "Entertainment",
        "Other"
    ]
    
    /// Suggests a category based on event title or notes (simple keyword matching)
    static func suggestCategory(title: String, notes: String? = nil) -> String {
        let text = (title + " " + (notes ?? "")).lowercased()
        
        if text.contains("meeting") || text.contains("work") || text.contains("project") || text.contains("office") {
            return "Work"
        } else if text.contains("doctor") || text.contains("gym") || text.contains("workout") || text.contains("health") {
            return "Health"
        } else if text.contains("family") || text.contains("kids") || text.contains("parents") {
            return "Family"
        } else if text.contains("class") || text.contains("study") || text.contains("learn") || text.contains("course") {
            return "Education"
        } else if text.contains("bank") || text.contains("payment") || text.contains("bill") || text.contains("tax") {
            return "Finance"
        } else if text.contains("friend") || text.contains("party") || text.contains("dinner") || text.contains("lunch") {
            return "Social"
        } else if text.contains("flight") || text.contains("hotel") || text.contains("vacation") || text.contains("trip") {
            return "Travel"
        } else if text.contains("cleaning") || text.contains("repair") || text.contains("maintenance") {
            return "Home"
        } else if text.contains("movie") || text.contains("game") || text.contains("concert") || text.contains("hobby") {
            return "Entertainment"
        }
        
        return "Personal"
    }
}

// MARK: - Calendar Priority Mapping

struct CalendarPriorityMapper {
    
    /// Maps priority levels to numeric values for EventKit
    static func priorityValue(for priority: String) -> Int {
        switch priority.lowercased() {
        case "urgent", "high":
            return 1
        case "medium", "normal":
            return 5
        case "low":
            return 9
        default:
            return 5
        }
    }
    
    /// Maps numeric priority values back to string representations
    static func priorityString(for value: Int) -> String {
        switch value {
        case 1...3:
            return "High"
        case 4...6:
            return "Medium"
        case 7...9:
            return "Low"
        default:
            return "Medium"
        }
    }
}

// MARK: - Recurrence Pattern Helpers

struct RecurrencePatternHelper {
    
    /// Formats recurrence rules for human-readable display
    static func formatRecurrenceRule(_ rule: EKRecurrenceRule?) -> String {
        guard let rule = rule else { return "Does not repeat" }
        
        var description = ""
        
        switch rule.frequency {
        case .daily:
            description = "Daily"
        case .weekly:
            description = "Weekly"
        case .monthly:
            description = "Monthly"
        case .yearly:
            description = "Yearly"
        @unknown default:
            description = "Custom"
        }
        
        if rule.interval > 1 {
            description = "Every \(rule.interval) \(frequencyUnit(for: rule.frequency))"
        }
        
        if let end = rule.recurrenceEnd {
            if let endDate = end.endDate {
                let formatter = DateFormatter()
                formatter.dateStyle = .medium
                description += " until \(formatter.string(from: endDate))"
            } else {
                let occurrenceCount = end.occurrenceCount
                if occurrenceCount > 0 {
                    description += " for \(occurrenceCount) times"
                }
            }
        }
        
        return description
    }
    
    private static func frequencyUnit(for frequency: EKRecurrenceFrequency) -> String {
        switch frequency {
        case .daily:
            return "days"
        case .weekly:
            return "weeks"
        case .monthly:
            return "months"
        case .yearly:
            return "years"
        @unknown default:
            return "intervals"
        }
    }
    
    /// Creates a recurrence rule from a simple string pattern
    static func createRecurrenceRule(from pattern: String) -> EKRecurrenceRule? {
        var frequency: EKRecurrenceFrequency
        
        switch pattern.uppercased() {
        case "DAILY":
            frequency = .daily
        case "WEEKLY":
            frequency = .weekly
        case "MONTHLY":
            frequency = .monthly
        case "YEARLY":
            frequency = .yearly
        default:
            return nil
        }
        
        return EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: 1,
            end: nil
        )
    }
    
    /// Available recurrence patterns for user selection
    static let patterns = [
        "Does not repeat",
        "Daily",
        "Weekly",
        "Monthly",
        "Yearly"
    ]
}

// MARK: - EventKit Availability Helper

struct EventKitAvailabilityHelper {
    
    /// Checks if EventKit is available on the current platform
    static var isAvailable: Bool {
        #if os(iOS) || os(macOS)
        return true
        #else
        return false
        #endif
    }
    
    /// Gets the appropriate calendar title for a category
    static func calendarTitle(for category: String) -> String {
        return "CalendarNotes - \(category)"
    }
    
    /// Checks if a calendar exists for a given category
    static func hasCalendar(for category: String, in eventStore: EKEventStore) -> Bool {
        let calendars = eventStore.calendars(for: .event)
        let title = calendarTitle(for: category)
        return calendars.contains { $0.title == title }
    }
    
    /// Creates or retrieves a calendar for a category
    static func getOrCreateCalendar(for category: String, in eventStore: EKEventStore) -> EKCalendar? {
        let calendars = eventStore.calendars(for: .event)
        let title = calendarTitle(for: category)
        
        // Try to find existing calendar
        if let existingCalendar = calendars.first(where: { $0.title == title }) {
            return existingCalendar
        }
        
        // Create new calendar
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = title
        newCalendar.cgColor = CategoryColorMapper.ekColor(for: category)
        
        // Set the calendar source
        if let source = eventStore.defaultCalendarForNewEvents?.source {
            newCalendar.source = source
        } else if let source = eventStore.sources.first {
            newCalendar.source = source
        } else {
            return nil
        }
        
        do {
            try eventStore.saveCalendar(newCalendar, commit: true)
            return newCalendar
        } catch {
            print("Failed to create calendar: \(error)")
            return nil
        }
    }
}

