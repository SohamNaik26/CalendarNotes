//
//  AutomationRule.swift
//  CalendarNotes
//

import Foundation
import CoreData

// MARK: - Rule Models

struct AutomationRule: Identifiable, Codable {
    let id: UUID
    var name: String
    var isEnabled: Bool
    var trigger: Trigger
    var actions: [Action]
    var createdAt: Date
    var lastExecuted: Date?
    var executionCount: Int
    
    init(id: UUID = UUID(), name: String, isEnabled: Bool = true, trigger: Trigger, actions: [Action], createdAt: Date = Date(), lastExecuted: Date? = nil, executionCount: Int = 0) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.trigger = trigger
        self.actions = actions
        self.createdAt = createdAt
        self.lastExecuted = lastExecuted
        self.executionCount = executionCount
    }
}

// MARK: - Triggers

enum Trigger: Codable, Equatable {
    case addedToCollection(String) // Collection name
    case taggedWith(String) // Tag name
    case fromDomain(String) // Domain
    case savedAtTime(TimeRange) // Time range
    case notOpenedInDays(Int) // Days
    case matchesAll([Trigger]) // AND
    case matchesAny([Trigger]) // OR
    
    enum TimeRange: Codable, Equatable {
        case specificTime(hour: Int, minute: Int)
        case timeRange(startHour: Int, startMinute: Int, endHour: Int, endMinute: Int)
        case weekdays([Int]) // 0 = Sunday, 6 = Saturday
    }
}

// MARK: - Actions

enum Action: Codable, Equatable {
    case moveToCollection(String) // Collection name
    case addTags([String]) // Tag names
    case removeTags([String]) // Tag names
    case markAsFavorite(Bool) // true = favorite, false = unfavorite
    case archive(Bool) // true = archive, false = unarchive
    case delete
    case sendNotification(String) // Message
    case createTask(String?) // Task title (optional)
    case createCalendarEvent(String?, Date?) // Event title, date (optional)
    case addNote(String) // Note content
}

// MARK: - Execution Log

struct RuleExecutionLog: Identifiable, Codable {
    let id: UUID
    let ruleId: UUID
    let ruleName: String
    let bookmarkId: String
    let bookmarkTitle: String
    let executedAt: Date
    let success: Bool
    let errorMessage: String?
    let actionsPerformed: [String] // Action descriptions
    
    init(id: UUID = UUID(), ruleId: UUID, ruleName: String, bookmarkId: String, bookmarkTitle: String, executedAt: Date = Date(), success: Bool, errorMessage: String? = nil, actionsPerformed: [String] = []) {
        self.id = id
        self.ruleId = ruleId
        self.ruleName = ruleName
        self.bookmarkId = bookmarkId
        self.bookmarkTitle = bookmarkTitle
        self.executedAt = executedAt
        self.success = success
        self.errorMessage = errorMessage
        self.actionsPerformed = actionsPerformed
    }
}

// MARK: - Predefined Templates

struct AutomationTemplate: Identifiable {
    let id: String
    let name: String
    let description: String
    let rule: AutomationRule
    
    static let all: [AutomationTemplate] = [
        AutomationTemplate(
            id: "auto-organize-domain",
            name: "Auto-organize by domain",
            description: "Automatically move bookmarks to collections based on their domain",
            rule: AutomationRule(
                name: "Auto-organize by domain",
                trigger: .fromDomain(""),
                actions: [.moveToCollection("")]
            )
        ),
        AutomationTemplate(
            id: "auto-archive-old",
            name: "Auto-archive old bookmarks",
            description: "Archive bookmarks that haven't been opened in 90 days",
            rule: AutomationRule(
                name: "Auto-archive old bookmarks",
                trigger: .notOpenedInDays(90),
                actions: [.archive(true)]
            )
        ),
        AutomationTemplate(
            id: "create-reading-tasks",
            name: "Create reading tasks from read-later",
            description: "Create tasks for bookmarks added to 'Read Later' collection",
            rule: AutomationRule(
                name: "Create reading tasks from read-later",
                trigger: .addedToCollection("Read Later"),
                actions: [.createTask(nil)]
            )
        ),
        AutomationTemplate(
            id: "tag-work-hours",
            name: "Tag work bookmarks saved during work hours",
            description: "Add 'work' tag to bookmarks saved on weekdays between 9 AM and 5 PM",
            rule: AutomationRule(
                name: "Tag work bookmarks saved during work hours",
                trigger: .matchesAll([
                    .savedAtTime(.timeRange(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0)),
                    .savedAtTime(.weekdays([1, 2, 3, 4, 5])) // Mon-Fri
                ]),
                actions: [.addTags(["work"])]
            )
        )
    ]
}


