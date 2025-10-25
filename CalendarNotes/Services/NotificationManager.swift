//
//  NotificationManager.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 22/10/25.
//

import Foundation
import UserNotifications
import SwiftUI
import Combine

// MARK: - Notification Types

enum NotificationType: String, CaseIterable {
    case eventReminder = "eventReminder"
    case taskDue = "taskDue"
    case taskOverdue = "taskOverdue"
    case dailySummary = "dailySummary"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .eventReminder: return "Event Reminder"
        case .taskDue: return "Task Due"
        case .taskOverdue: return "Task Overdue"
        case .dailySummary: return "Daily Summary"
        case .custom: return "Custom"
        }
    }
}

enum NotificationReminderTime: Int, CaseIterable {
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120
    case oneDay = 1440
    case twoDays = 2880
    
    var displayName: String {
        switch self {
        case .fiveMinutes: return "5 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .thirtyMinutes: return "30 minutes"
        case .oneHour: return "1 hour"
        case .twoHours: return "2 hours"
        case .oneDay: return "1 day"
        case .twoDays: return "2 days"
        }
    }
}

enum NotificationSound: String, CaseIterable {
    case defaultSound = "default"
    case gentle = "gentle"
    case urgent = "urgent"
    case soft = "soft"
    case chime = "chime"
    
    var displayName: String {
        switch self {
        case .defaultSound: return "Default"
        case .gentle: return "Gentle"
        case .urgent: return "Urgent"
        case .soft: return "Soft"
        case .chime: return "Chime"
        }
    }
    
    var soundName: String {
        switch self {
        case .defaultSound: return "default"
        case .gentle: return "gentle_chime.aiff"
        case .urgent: return "urgent_alert.aiff"
        case .soft: return "soft_notification.aiff"
        case .chime: return "bell_chime.aiff"
        }
    }
}

// MARK: - Notification Data Models

struct NotificationRequest {
    let id: String
    let title: String
    let body: String
    let date: Date
    let type: NotificationType
    let sound: NotificationSound
    let categoryIdentifier: String?
    let userInfo: [String: Any]
    let isRepeating: Bool
    let repeatInterval: TimeInterval?
}

struct NotificationSettings {
    var isEnabled: Bool = true
    var reminderTimes: [NotificationReminderTime] = [.fifteenMinutes]
    var sound: NotificationSound = .defaultSound
    var customMessage: String?
    
    nonisolated static let defaultSettings = NotificationSettings()
}

// MARK: - Notification Manager

@MainActor
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    @Published var authorizationStatus: UNAuthorizationStatus = .notDetermined
    @Published var isNotificationsEnabled: Bool = false
    @Published var pendingNotifications: [UNNotificationRequest] = []
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let coreDataManager = CoreDataManager.shared
    
    // MARK: - Initialization
    
    private init() {
        setupNotificationCategories()
        Task {
            checkAuthorizationStatus()
            await loadPendingNotifications()
        }
    }
    
    // MARK: - Authorization
    
    func requestNotificationPermission() async throws -> Bool {
        let granted = try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge, .provisional])
        await MainActor.run {
            self.authorizationStatus = granted ? .authorized : .denied
            self.isNotificationsEnabled = granted
        }
        return granted
    }
    
    func checkAuthorizationStatus() {
        Task {
            let settings = await notificationCenter.notificationSettings()
            await MainActor.run {
                self.authorizationStatus = settings.authorizationStatus
                self.isNotificationsEnabled = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Notification Categories Setup
    
    private func setupNotificationCategories() {
        // Event reminder category
        let viewEventAction = UNNotificationAction(
            identifier: "VIEW_EVENT_ACTION",
            title: "View",
            options: [.foreground]
        )
        let snoozeEventAction = UNNotificationAction(
            identifier: "SNOOZE_EVENT_ACTION",
            title: "Snooze 15 min",
            options: []
        )
        
        let eventCategory = UNNotificationCategory(
            identifier: "EVENT_REMINDER",
            actions: [viewEventAction, snoozeEventAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Task due category
        let viewTaskAction = UNNotificationAction(
            identifier: "VIEW_TASK_ACTION",
            title: "View",
            options: [.foreground]
        )
        let completeTaskAction = UNNotificationAction(
            identifier: "COMPLETE_TASK_ACTION",
            title: "Complete",
            options: []
        )
        let snoozeTaskAction = UNNotificationAction(
            identifier: "SNOOZE_TASK_ACTION",
            title: "Snooze 1 hour",
            options: []
        )
        
        let taskCategory = UNNotificationCategory(
            identifier: "TASK_DUE",
            actions: [viewTaskAction, completeTaskAction, snoozeTaskAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Daily summary category
        let viewSummaryAction = UNNotificationAction(
            identifier: "VIEW_SUMMARY_ACTION",
            title: "View",
            options: [.foreground]
        )
        
        let summaryCategory = UNNotificationCategory(
            identifier: "DAILY_SUMMARY",
            actions: [viewSummaryAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        
        // Register categories
        notificationCenter.setNotificationCategories([
            eventCategory,
            taskCategory,
            summaryCategory
        ])
    }
    
    // MARK: - Notification Scheduling
    
    func scheduleNotification(_ request: NotificationRequest) async throws {
        guard isNotificationsEnabled else {
            throw NotificationError.notificationsDisabled
        }
        
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = request.sound == .defaultSound ? .default : UNNotificationSound(named: UNNotificationSoundName(request.sound.soundName))
        content.categoryIdentifier = request.categoryIdentifier ?? ""
        content.userInfo = request.userInfo
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: request.date.timeIntervalSinceNow,
            repeats: request.isRepeating
        )
        
        let notificationRequest = UNNotificationRequest(
            identifier: request.id,
            content: content,
            trigger: trigger
        )
        
        try await notificationCenter.add(notificationRequest)
        await loadPendingNotifications()
    }
    
    func scheduleEventReminder(for event: CalendarEvent, reminderTime: NotificationReminderTime, settings: NotificationSettings = .defaultSettings) async throws {
        guard let startDate = event.startDate else { return }
        
        let reminderDate = startDate.addingTimeInterval(-TimeInterval(reminderTime.rawValue * 60))
        
        // Don't schedule if the reminder time has already passed
        guard reminderDate > Date() else { return }
        
        let request = NotificationRequest(
            id: "event_\(event.id?.uuidString ?? UUID().uuidString)_\(reminderTime.rawValue)",
            title: "Event Reminder",
            body: "\(event.title ?? "Untitled Event") starts in \(reminderTime.displayName)",
            date: reminderDate,
            type: .eventReminder,
            sound: settings.sound,
            categoryIdentifier: "EVENT_REMINDER",
            userInfo: [
                "eventId": event.id?.uuidString ?? "",
                "eventTitle": event.title ?? "",
                "reminderTime": reminderTime.rawValue
            ],
            isRepeating: false,
            repeatInterval: nil
        )
        
        try await scheduleNotification(request)
    }
    
    func scheduleTaskDueNotification(for task: TodoItem, settings: NotificationSettings = .defaultSettings) async throws {
        guard let dueDate = task.dueDate else { return }
        
        // Don't schedule if the due date has already passed
        guard dueDate > Date() else { return }
        
        let request = NotificationRequest(
            id: "task_due_\(task.id?.uuidString ?? UUID().uuidString)",
            title: "Task Due",
            body: "\(task.title ?? "Untitled Task") is due now",
            date: dueDate,
            type: .taskDue,
            sound: settings.sound,
            categoryIdentifier: "TASK_DUE",
            userInfo: [
                "taskId": task.id?.uuidString ?? "",
                "taskTitle": task.title ?? "",
                "dueDate": dueDate.timeIntervalSince1970
            ],
            isRepeating: false,
            repeatInterval: nil
        )
        
        try await scheduleNotification(request)
    }
    
    func scheduleTaskOverdueNotification(for task: TodoItem, settings: NotificationSettings = .defaultSettings) async throws {
        guard let dueDate = task.dueDate, dueDate < Date() else { return }
        
        let request = NotificationRequest(
            id: "task_overdue_\(task.id?.uuidString ?? UUID().uuidString)",
            title: "Task Overdue",
            body: "\(task.title ?? "Untitled Task") is overdue",
            date: Date(),
            type: .taskOverdue,
            sound: .urgent,
            categoryIdentifier: "TASK_DUE",
            userInfo: [
                "taskId": task.id?.uuidString ?? "",
                "taskTitle": task.title ?? "",
                "dueDate": dueDate.timeIntervalSince1970
            ],
            isRepeating: true,
            repeatInterval: 3600 // Repeat every hour
        )
        
        try await scheduleNotification(request)
    }
    
    func scheduleDailySummaryNotification(at time: Date, settings: NotificationSettings = .defaultSettings) async throws {
        // Cancel existing daily summary notifications
        await cancelDailySummaryNotifications()
        
        let request = NotificationRequest(
            id: "daily_summary_\(Date().timeIntervalSince1970)",
            title: "Daily Summary",
            body: "Here's your schedule for today",
            date: time,
            type: .dailySummary,
            sound: settings.sound,
            categoryIdentifier: "DAILY_SUMMARY",
            userInfo: [
                "type": "daily_summary",
                "date": time.timeIntervalSince1970
            ],
            isRepeating: true,
            repeatInterval: 86400 // Repeat daily
        )
        
        try await scheduleNotification(request)
    }
    
    // MARK: - Bulk Operations
    
    func scheduleAllEventReminders() async throws {
        let events = try coreDataManager.fetch(CalendarEvent.fetchRequest())
        
        for event in events {
            if let startDate = event.startDate, startDate > Date() {
                // Schedule multiple reminder times
                for reminderTime in [NotificationReminderTime.fifteenMinutes, .oneHour, .oneDay] {
                    try await scheduleEventReminder(for: event, reminderTime: reminderTime)
                }
            }
        }
    }
    
    func scheduleAllTaskReminders() async throws {
        let tasks = try coreDataManager.fetch(TodoItem.fetchRequest())
        
        for task in tasks {
            if !task.isCompleted {
                try await scheduleTaskDueNotification(for: task)
                
                // Schedule overdue notification if task is overdue
                if let dueDate = task.dueDate, dueDate < Date() {
                    try await scheduleTaskOverdueNotification(for: task)
                }
            }
        }
    }
    
    func cancelAllNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
        await loadPendingNotifications()
    }
    
    func cancelEventNotifications(for event: CalendarEvent) async {
        let eventId = event.id?.uuidString ?? ""
        let identifiers = pendingNotifications.compactMap { request in
            if let userInfo = request.content.userInfo as? [String: Any],
               let requestEventId = userInfo["eventId"] as? String,
               requestEventId == eventId {
                return request.identifier
            }
            return nil
        }
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        await loadPendingNotifications()
    }
    
    func cancelTaskNotifications(for task: TodoItem) async {
        let taskId = task.id?.uuidString ?? ""
        let identifiers = pendingNotifications.compactMap { request in
            if let userInfo = request.content.userInfo as? [String: Any],
               let requestTaskId = userInfo["taskId"] as? String,
               requestTaskId == taskId {
                return request.identifier
            }
            return nil
        }
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        await loadPendingNotifications()
    }
    
    func cancelDailySummaryNotifications() async {
        let identifiers = pendingNotifications.compactMap { request in
            if request.identifier.hasPrefix("daily_summary_") {
                return request.identifier
            }
            return nil
        }
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: identifiers)
        await loadPendingNotifications()
    }
    
    // MARK: - Notification Management
    
    func loadPendingNotifications() async {
        let requests = await notificationCenter.pendingNotificationRequests()
        await MainActor.run {
            self.pendingNotifications = requests
        }
    }
    
    func handleNotificationResponse(_ response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        
        switch response.actionIdentifier {
        case "VIEW_EVENT_ACTION":
            if let eventId = userInfo["eventId"] as? String {
                await handleEventView(eventId: eventId)
            }
            
        case "VIEW_TASK_ACTION":
            if let taskId = userInfo["taskId"] as? String {
                await handleTaskView(taskId: taskId)
            }
            
        case "COMPLETE_TASK_ACTION":
            if let taskId = userInfo["taskId"] as? String {
                await handleTaskComplete(taskId: taskId)
            }
            
        case "SNOOZE_EVENT_ACTION":
            if let eventId = userInfo["eventId"] as? String {
                await handleEventSnooze(eventId: eventId, minutes: 15)
            }
            
        case "SNOOZE_TASK_ACTION":
            if let taskId = userInfo["taskId"] as? String {
                await handleTaskSnooze(taskId: taskId, minutes: 60)
            }
            
        case "VIEW_SUMMARY_ACTION":
            await handleDailySummaryView()
            
        default:
            // Handle default tap
            if let eventId = userInfo["eventId"] as? String {
                await handleEventView(eventId: eventId)
            } else if let taskId = userInfo["taskId"] as? String {
                await handleTaskView(taskId: taskId)
            }
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleEventView(eventId: String) async {
        // Navigate to event detail view
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToEvent"),
            object: nil,
            userInfo: ["eventId": eventId]
        )
    }
    
    private func handleTaskView(taskId: String) async {
        // Navigate to task detail view
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToTask"),
            object: nil,
            userInfo: ["taskId": taskId]
        )
    }
    
    private func handleTaskComplete(taskId: String) async {
        do {
            let tasks = try coreDataManager.fetch(TodoItem.fetchRequest())
            if let task = tasks.first(where: { $0.id?.uuidString == taskId }) {
                task.isCompleted = true
                // Note: completionDate is not available in TodoItem model
                try coreDataManager.save()
                
                // Cancel future notifications for this task
                await cancelTaskNotifications(for: task)
            }
        } catch {
            print("Error completing task: \(error)")
        }
    }
    
    private func handleEventSnooze(eventId: String, minutes: Int) async {
        // Reschedule notification for later
        do {
            let events = try coreDataManager.fetch(CalendarEvent.fetchRequest())
            if let event = events.first(where: { $0.id?.uuidString == eventId }) {
                let snoozeDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
                
                let request = NotificationRequest(
                    id: "snooze_event_\(eventId)_\(Date().timeIntervalSince1970)",
                    title: "Event Reminder",
                    body: "\(event.title ?? "Untitled Event") starts soon",
                    date: snoozeDate,
                    type: .eventReminder,
                    sound: .defaultSound,
                    categoryIdentifier: "EVENT_REMINDER",
                    userInfo: [
                        "eventId": eventId,
                        "eventTitle": event.title ?? "",
                        "isSnooze": true
                    ],
                    isRepeating: false,
                    repeatInterval: nil
                )
                
                try await scheduleNotification(request)
            }
        } catch {
            print("Error snoozing event: \(error)")
        }
    }
    
    private func handleTaskSnooze(taskId: String, minutes: Int) async {
        // Reschedule notification for later
        do {
            let tasks = try coreDataManager.fetch(TodoItem.fetchRequest())
            if let task = tasks.first(where: { $0.id?.uuidString == taskId }) {
                let snoozeDate = Date().addingTimeInterval(TimeInterval(minutes * 60))
                
                let request = NotificationRequest(
                    id: "snooze_task_\(taskId)_\(Date().timeIntervalSince1970)",
                    title: "Task Reminder",
                    body: "\(task.title ?? "Untitled Task") is due soon",
                    date: snoozeDate,
                    type: .taskDue,
                    sound: .defaultSound,
                    categoryIdentifier: "TASK_DUE",
                    userInfo: [
                        "taskId": taskId,
                        "taskTitle": task.title ?? "",
                        "isSnooze": true
                    ],
                    isRepeating: false,
                    repeatInterval: nil
                )
                
                try await scheduleNotification(request)
            }
        } catch {
            print("Error snoozing task: \(error)")
        }
    }
    
    private func handleDailySummaryView() async {
        // Navigate to today's view
        NotificationCenter.default.post(
            name: NSNotification.Name("NavigateToToday"),
            object: nil
        )
    }
    
    // MARK: - Utility Methods
    
    func getNotificationCount() -> Int {
        return pendingNotifications.count
    }
    
    func getNotificationCount(for type: NotificationType) -> Int {
        return pendingNotifications.filter { request in
            if let userInfo = request.content.userInfo as? [String: Any],
               let notificationType = userInfo["type"] as? String {
                return NotificationType(rawValue: notificationType) == type
            }
            return false
        }.count
    }
    
    func isNotificationScheduled(for event: CalendarEvent) -> Bool {
        let eventId = event.id?.uuidString ?? ""
        return pendingNotifications.contains { request in
            if let userInfo = request.content.userInfo as? [String: Any],
               let requestEventId = userInfo["eventId"] as? String {
                return requestEventId == eventId
            }
            return false
        }
    }
    
    func isNotificationScheduled(for task: TodoItem) -> Bool {
        let taskId = task.id?.uuidString ?? ""
        return pendingNotifications.contains { request in
            if let userInfo = request.content.userInfo as? [String: Any],
               let requestTaskId = userInfo["taskId"] as? String {
                return requestTaskId == taskId
            }
            return false
        }
    }
}

// MARK: - Notification Errors

enum NotificationError: Error, LocalizedError {
    case notificationsDisabled
    case invalidDate
    case schedulingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .notificationsDisabled:
            return "Notifications are disabled. Please enable them in Settings."
        case .invalidDate:
            return "Invalid notification date. Date must be in the future."
        case .schedulingFailed(let message):
            return "Failed to schedule notification: \(message)"
        }
    }
}

// MARK: - Extensions

