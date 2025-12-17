//
//  NotificationExtensions.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 22/10/25.
//

import Foundation
import CoreData

// MARK: - CalendarEvent Notification Extensions

extension CalendarEvent {
    var notificationSettings: NotificationSettings {
        get {
            // Parse from JSON if stored
            if let settingsData = notificationSettingsData,
               let data = settingsData.data(using: .utf8),
               let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
                return settings
            }
            return NotificationSettings.defaultSettings
        }
        set {
            // Store as JSON
            if let data = try? JSONEncoder().encode(newValue),
               let jsonString = String(data: data, encoding: .utf8) {
                notificationSettingsData = jsonString
            }
        }
    }
    
    var hasNotificationsScheduled: Bool {
        return NotificationManager.shared.isNotificationScheduled(for: self)
    }
    
    func scheduleNotifications() async throws {
        let settings = notificationSettings
        guard settings.isEnabled else { return }
        
        for reminderTime in settings.reminderTimes {
            try await NotificationManager.shared.scheduleEventReminder(
                for: self,
                reminderTime: reminderTime,
                settings: settings
            )
        }
    }
    
    func cancelNotifications() async {
        await NotificationManager.shared.cancelEventNotifications(for: self)
    }
    
    func updateNotificationSettings(_ settings: NotificationSettings) async throws {
        notificationSettings = settings
        
        // Cancel existing notifications
        await cancelNotifications()
        
        // Schedule new notifications if enabled
        if settings.isEnabled {
            try await scheduleNotifications()
        }
    }
}

// MARK: - TodoItem Notification Extensions

extension TodoItem {
    var notificationSettings: NotificationSettings {
        get {
            // Parse from JSON if stored
            if let settingsData = notificationSettingsData,
               let data = settingsData.data(using: .utf8),
               let settings = try? JSONDecoder().decode(NotificationSettings.self, from: data) {
                return settings
            }
            return NotificationSettings.defaultSettings
        }
        set {
            // Store as JSON
            if let data = try? JSONEncoder().encode(newValue),
               let jsonString = String(data: data, encoding: .utf8) {
                notificationSettingsData = jsonString
            }
        }
    }
    
    var hasNotificationsScheduled: Bool {
        return NotificationManager.shared.isNotificationScheduled(for: self)
    }
    
    func scheduleNotifications() async throws {
        let settings = notificationSettings
        guard settings.isEnabled else { return }
        
        // Schedule due date notification
        if let dueDate = dueDate, dueDate > Date() {
            try await NotificationManager.shared.scheduleTaskDueNotification(for: self, settings: settings)
        }
        
        // Schedule overdue notification if already overdue
        if let dueDate = dueDate, dueDate < Date() {
            try await NotificationManager.shared.scheduleTaskOverdueNotification(for: self, settings: settings)
        }
    }
    
    func cancelNotifications() async {
        await NotificationManager.shared.cancelTaskNotifications(for: self)
    }
    
    func updateNotificationSettings(_ settings: NotificationSettings) async throws {
        notificationSettings = settings
        
        // Cancel existing notifications
        await cancelNotifications()
        
        // Schedule new notifications if enabled
        if settings.isEnabled {
            try await scheduleNotifications()
        }
    }
    
    func markAsCompleted() async throws {
        isCompleted = true
        // Note: completionDate is not available in TodoItem model, using isCompleted flag
        
        // Cancel notifications for completed task
        await cancelNotifications()
        
        // Save to Core Data
        try CoreDataManager.shared.save()
    }
}

// MARK: - NotificationSettings Codable

extension NotificationSettings: Codable {
    enum CodingKeys: String, CodingKey {
        case isEnabled
        case reminderTimes
        case sound
        case customMessage
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
        reminderTimes = try container.decodeIfPresent([NotificationReminderTime].self, forKey: .reminderTimes) ?? [.fifteenMinutes]
        sound = try container.decodeIfPresent(NotificationSound.self, forKey: .sound) ?? .defaultSound
        customMessage = try container.decodeIfPresent(String.self, forKey: .customMessage)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(reminderTimes, forKey: .reminderTimes)
        try container.encode(sound, forKey: .sound)
        try container.encodeIfPresent(customMessage, forKey: .customMessage)
    }
}

// MARK: - NotificationReminderTime Codable

extension NotificationReminderTime: Codable {
    enum CodingKeys: String, CodingKey {
        case rawValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try container.decode(Int.self, forKey: .rawValue)
        
        guard let reminderTime = NotificationReminderTime(rawValue: rawValue) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid NotificationReminderTime rawValue: \(rawValue)"
                )
            )
        }
        
        self = reminderTime
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawValue, forKey: .rawValue)
    }
}

// MARK: - NotificationSound Codable

extension NotificationSound: Codable {
    enum CodingKeys: String, CodingKey {
        case rawValue
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let rawValue = try container.decode(String.self, forKey: .rawValue)
        
        guard let sound = NotificationSound(rawValue: rawValue) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Invalid NotificationSound rawValue: \(rawValue)"
                )
            )
        }
        
        self = sound
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(rawValue, forKey: .rawValue)
    }
}

