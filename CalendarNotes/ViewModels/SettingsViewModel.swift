//
//  SettingsViewModel.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 22/10/25.
//

import Foundation
import SwiftUI
import CoreData

#if os(macOS)
import AppKit
#endif
import Combine
import UniformTypeIdentifiers

enum AppearanceMode: String, CaseIterable {
    case light = "Light"
    case dark = "Dark"
    case system = "System"
    
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

enum DefaultCalendarView: String, CaseIterable {
    case month = "Month"
    case week = "Week"
    case day = "Day"
}

enum FirstDayOfWeek: Int, CaseIterable {
    case sunday = 1
    case monday = 2
    case saturday = 7
    
    var displayName: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .saturday: return "Saturday"
        }
    }
}

@MainActor
class SettingsViewModel: ObservableObject {
    @Published private var notificationManager = NotificationManager.shared
    // MARK: - Published Properties
    
    // User Profile
    @AppStorage("userName") var userName: String = ""
    @AppStorage("userEmail") var userEmail: String = ""
    
    // Appearance (now handled by global ThemeManager)
    @AppStorage("defaultCalendarView") var defaultCalendarView: String = DefaultCalendarView.month.rawValue
    @AppStorage("firstDayOfWeek") var firstDayOfWeek: Int = FirstDayOfWeek.sunday.rawValue
    
    // Notifications
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = true
    @AppStorage("eventRemindersEnabled") var eventRemindersEnabled: Bool = true
    @AppStorage("taskRemindersEnabled") var taskRemindersEnabled: Bool = true
    @AppStorage("dailySummaryEnabled") var dailySummaryEnabled: Bool = false
    @AppStorage("reminderTimeMinutes") var reminderTimeMinutes: Int = 15
    @AppStorage("notificationSound") var notificationSound: String = NotificationSound.defaultSound.rawValue
    @AppStorage("dailySummaryTime") var dailySummaryTime: Double = 9 * 3600 // 9 AM in seconds
    
    // iCloud Sync
    @AppStorage("iCloudSyncEnabled") var iCloudSyncEnabled: Bool = false
    @AppStorage("iCloudWiFiOnlySync") var iCloudWiFiOnlySync: Bool = false
    
    // Auto-backup
    @AppStorage("autoBackupEnabled") var autoBackupEnabled: Bool = false
    @AppStorage("lastBackupDate") var lastBackupDate: Double = 0
    
    // EventKit Sync
    @AppStorage("eventKitSyncEnabled") var eventKitSyncEnabled: Bool = false
    @AppStorage("eventKitAutoSyncEnabled") var eventKitAutoSyncEnabled: Bool = true
    @AppStorage("eventKitConflictResolution") var eventKitConflictResolution: String = "newerWins"
    @AppStorage("lastEventKitSyncDate") var lastEventKitSyncDate: Double = 0
    
    // Other settings
    @AppStorage("showCompletedTasks") var showCompletedTasks: Bool = true
    @AppStorage("compactViewMode") var compactViewMode: Bool = false
    
    @Published var showingDataExport = false
    @Published var showingDataImport = false
    @Published var showingClearCacheAlert = false
    @Published var showingDeleteAllDataAlert = false
    @Published var showingBackupSheet = false
    @Published var showingRestoreSheet = false
    @Published var showingContactSupport = false
    
    @Published var isExporting = false
    @Published var isImporting = false
    @Published var exportMessage = ""
    @Published var importMessage = ""
    
    @Published var isSyncing = false
    @Published var syncMessage = ""
    @Published var syncInProgress = false
    
    // Sample Data Generation
    @Published var isGeneratingSampleData = false
    @Published var showingClearSampleDataAlert = false
    @Published var sampleDataMessage = ""
    
    // MARK: - Computed Properties
    
    var currentDefaultView: DefaultCalendarView {
        DefaultCalendarView(rawValue: defaultCalendarView) ?? .month
    }
    
    var currentFirstDayOfWeek: FirstDayOfWeek {
        FirstDayOfWeek(rawValue: firstDayOfWeek) ?? .sunday
    }
    
    var currentNotificationSound: NotificationSound {
        NotificationSound(rawValue: notificationSound) ?? .defaultSound
    }
    
    var dailySummaryDate: Date {
        let calendar = Calendar.current
        let today = Date()
        let hour = Int(dailySummaryTime / 3600)
        let minute = Int((dailySummaryTime.truncatingRemainder(dividingBy: 3600)) / 60)
        
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: today) ?? today
    }
    
    var lastBackupDateFormatted: String {
        if lastBackupDate == 0 {
            return "Never"
        }
        let date = Date(timeIntervalSince1970: lastBackupDate)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    var lastEventKitSyncDateFormatted: String {
        if lastEventKitSyncDate == 0 {
            return "Never"
        }
        let date = Date(timeIntervalSince1970: lastEventKitSyncDate)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // MARK: - Data Management
    
    func exportData() async {
        isExporting = true
        exportMessage = ""
        
        do {
            let coreDataManager = CoreDataManager.shared
            
            // Fetch all data
            let events = try coreDataManager.fetch(CalendarEvent.fetchRequest())
            let notes = try coreDataManager.fetch(Note.fetchRequest())
            let tasks = try coreDataManager.fetch(TodoItem.fetchRequest())
            
            // Create export data structure
            let exportData: [String: Any] = [
                "exportDate": Date().ISO8601Format(),
                "version": AppConstants.appVersion,
                "eventsCount": events.count,
                "notesCount": notes.count,
                "tasksCount": tasks.count,
                "events": events.map { eventToDict($0) },
                "notes": notes.map { noteToDict($0) },
                "tasks": tasks.map { taskToDict($0) }
            ]
            
            // Convert to JSON
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            
            // Save to file
            let fileName = "CalendarNotes_Export_\(Date().ISO8601Format()).json"
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
            try jsonData.write(to: tempURL)
            
            exportMessage = "Data exported successfully to \(fileName)"
            
            // Open save panel
            #if os(macOS)
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.json]
            savePanel.nameFieldStringValue = fileName
            savePanel.begin { response in
                if response == .OK, let url = savePanel.url {
                    do {
                        try jsonData.write(to: url)
                        self.exportMessage = "Data saved to \(url.lastPathComponent)"
                    } catch {
                        self.exportMessage = "Error saving file: \(error.localizedDescription)"
                    }
                }
            }
            #else
            // For iOS, we'll use a different approach - maybe share sheet or document picker
            // For now, just show success message
            self.exportMessage = "Data exported to temporary file: \(fileName)"
            #endif
            
        } catch {
            exportMessage = "Export failed: \(error.localizedDescription)"
        }
        
        isExporting = false
    }
    
    func clearCache() {
        // Clear temporary files and caches
        let fileManager = FileManager.default
        if let cacheURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            do {
                let cacheContents = try fileManager.contentsOfDirectory(at: cacheURL, includingPropertiesForKeys: nil)
                for file in cacheContents {
                    try? fileManager.removeItem(at: file)
                }
            } catch {
                print("Error clearing cache: \(error)")
            }
        }
    }
    
    func deleteAllData() async {
        #if DEBUG
        do {
            try CoreDataManager.shared.resetDatabase()
        } catch {
            print("Error deleting all data: \(error)")
        }
        #endif
    }
    
    func createBackup() async {
        do {
            let coreDataManager = CoreDataManager.shared
            
            // Fetch all data
            let events = try coreDataManager.fetch(CalendarEvent.fetchRequest())
            let notes = try coreDataManager.fetch(Note.fetchRequest())
            let tasks = try coreDataManager.fetch(TodoItem.fetchRequest())
            
            // Create backup data
            let backupData: [String: Any] = [
                "backupDate": Date().ISO8601Format(),
                "version": AppConstants.appVersion,
                "events": events.map { eventToDict($0) },
                "notes": notes.map { noteToDict($0) },
                "tasks": tasks.map { taskToDict($0) },
                "settings": [
                    "userName": userName,
                    "appearanceMode": ThemeManager.shared.currentAppearanceMode.rawValue,
                    "defaultCalendarView": defaultCalendarView,
                    "firstDayOfWeek": firstDayOfWeek,
                    "notificationsEnabled": notificationsEnabled
                ]
            ]
            
            let jsonData = try JSONSerialization.data(withJSONObject: backupData, options: .prettyPrinted)
            
            // Save to app support directory
            if let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let backupDir = appSupportURL.appendingPathComponent("Backups")
                try? FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
                
                let fileName = "Backup_\(Date().ISO8601Format()).json"
                let backupURL = backupDir.appendingPathComponent(fileName)
                try jsonData.write(to: backupURL)
                
                lastBackupDate = Date().timeIntervalSince1970
            }
        } catch {
            print("Backup failed: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    
    private func eventToDict(_ event: CalendarEvent) -> [String: Any] {
        var dict: [String: Any] = [
            "title": event.title ?? "",
            "category": event.category ?? ""
        ]
        if let startDate = event.startDate {
            dict["startDate"] = startDate.ISO8601Format()
        }
        if let endDate = event.endDate {
            dict["endDate"] = endDate.ISO8601Format()
        }
        if let location = event.location {
            dict["location"] = location
        }
        if let notes = event.notes {
            dict["notes"] = notes
        }
        dict["isRecurring"] = event.isRecurring
        if let recurrenceRule = event.recurrenceRule {
            dict["recurrenceRule"] = recurrenceRule
        }
        return dict
    }
    
    private func noteToDict(_ note: Note) -> [String: Any] {
        var dict: [String: Any] = [:]
        if let content = note.content {
            dict["content"] = content
        }
        if let createdDate = note.createdDate {
            dict["createdDate"] = createdDate.ISO8601Format()
        }
        if let linkedDate = note.linkedDate {
            dict["linkedDate"] = linkedDate.ISO8601Format()
        }
        if let tags = note.tags {
            dict["tags"] = tags
        }
        return dict
    }
    
    private func taskToDict(_ task: TodoItem) -> [String: Any] {
        var dict: [String: Any] = [
            "title": task.title ?? "",
            "priority": task.priority ?? "",
            "category": task.category ?? "",
            "isCompleted": task.isCompleted,
            "isRecurring": task.isRecurring
        ]
        if let dueDate = task.dueDate {
            dict["dueDate"] = dueDate.ISO8601Format()
        }
        return dict
    }
    
    func toggleiCloudSync() {
        // This would require more complex implementation
        // For now, just toggle the setting
        iCloudSyncEnabled.toggle()
    }
    
    // MARK: - Notification Management
    
    func requestNotificationPermission() async throws {
        let granted = try await notificationManager.requestNotificationPermission()
        if !granted {
            notificationsEnabled = false
        }
    }
    
    func scheduleAllNotifications() async throws {
        guard notificationsEnabled else { return }
        
        if eventRemindersEnabled {
            try await notificationManager.scheduleAllEventReminders()
        }
        
        if taskRemindersEnabled {
            try await notificationManager.scheduleAllTaskReminders()
        }
        
        if dailySummaryEnabled {
            try await notificationManager.scheduleDailySummaryNotification(
                at: dailySummaryDate,
                settings: NotificationSettings(
                    isEnabled: true,
                    reminderTimes: [.fifteenMinutes],
                    sound: currentNotificationSound
                )
            )
        }
    }
    
    func cancelAllNotifications() async {
        await notificationManager.cancelAllNotifications()
    }
    
    func updateNotificationSettings() async {
        if notificationsEnabled {
            do {
                try await scheduleAllNotifications()
            } catch {
                print("Error updating notification settings: \(error)")
            }
        } else {
            await cancelAllNotifications()
        }
    }
    
    func getPendingNotificationCount() -> Int {
        return notificationManager.getNotificationCount()
    }
    
    func getEventNotificationCount() -> Int {
        return notificationManager.getNotificationCount(for: .eventReminder)
    }
    
    func getTaskNotificationCount() -> Int {
        return notificationManager.getNotificationCount(for: .taskDue) + 
               notificationManager.getNotificationCount(for: .taskOverdue)
    }
    
    // MARK: - EventKit Sync Management
    
    func requestCalendarAccess() async throws -> Bool {
        return try await EventKitManager.shared.requestAccess()
    }
    
    func performEventKitSync() async {
        guard !syncInProgress else { return }
        
        syncInProgress = true
        syncMessage = "Syncing with iOS Calendar..."
        
        do {
            let stats = try await EventKitManager.shared.performFullSync()
            lastEventKitSyncDate = Date().timeIntervalSince1970
            
            syncMessage = """
            Sync completed successfully!
            Created: \(stats.eventsCreated)
            Updated: \(stats.eventsUpdated)
            Deleted: \(stats.eventsDeleted)
            Conflicts: \(stats.conflictsResolved)
            """
            
            if !stats.errors.isEmpty {
                syncMessage += "\nErrors: \(stats.errors.count)"
            }
        } catch {
            syncMessage = "Sync failed: \(error.localizedDescription)"
        }
        
        syncInProgress = false
        
        // Clear message after 5 seconds
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            syncMessage = ""
        }
    }
    
    func toggleEventKitSync() async {
        if eventKitSyncEnabled {
            // Enabling sync - request permission and perform initial sync
            do {
                let granted = try await requestCalendarAccess()
                if granted {
                    EventKitManager.shared.syncEnabled = true
                    await performEventKitSync()
                } else {
                    eventKitSyncEnabled = false
                    syncMessage = "Calendar access denied. Please enable access in System Settings."
                }
            } catch {
                eventKitSyncEnabled = false
                syncMessage = "Failed to enable sync: \(error.localizedDescription)"
            }
        } else {
            // Disabling sync
            EventKitManager.shared.syncEnabled = false
        }
    }
    
    // MARK: - Sample Data Generation
    
    func generateSampleData() async {
        isGeneratingSampleData = true
        sampleDataMessage = ""
        
        do {
            let context = CoreDataManager.shared.viewContext
            try SampleDataGenerator.shared.generateSampleData(context: context)
            sampleDataMessage = "Sample data generated successfully! (30 events, 20 notes, 15 tasks)"
        } catch {
            sampleDataMessage = "Error generating sample data: \(error.localizedDescription)"
        }
        
        isGeneratingSampleData = false
        
        // Clear message after 5 seconds
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            sampleDataMessage = ""
        }
    }
    
    func clearAllSampleData() async {
        do {
            let context = CoreDataManager.shared.viewContext
            try SampleDataGenerator.shared.clearAllSampleData(context: context)
            sampleDataMessage = "All data cleared successfully!"
        } catch {
            sampleDataMessage = "Error clearing data: \(error.localizedDescription)"
        }
        
        // Clear message after 3 seconds
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            sampleDataMessage = ""
        }
    }
}

