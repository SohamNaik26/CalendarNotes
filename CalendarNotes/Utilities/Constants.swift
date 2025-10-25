//
//  Constants.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import Foundation

enum AppConstants {
    static let appName = "CalendarNotes"
    static let appVersion = "1.0.0"
    
    enum DateFormat {
        static let short = "MMM d, yyyy"
        static let long = "MMMM d, yyyy"
        static let time = "h:mm a"
        static let dateTime = "MMM d, yyyy h:mm a"
    }
    
    enum UserDefaultsKeys {
        // User Profile
        static let userName = "userName"
        static let userEmail = "userEmail"
        
        // Appearance
        static let appearanceMode = "appearanceMode"
        static let defaultCalendarView = "defaultCalendarView"
        static let firstDayOfWeek = "firstDayOfWeek"
        static let compactViewMode = "compactViewMode"
        
        // Notifications
        static let notificationsEnabled = "notificationsEnabled"
        static let eventRemindersEnabled = "eventRemindersEnabled"
        static let taskRemindersEnabled = "taskRemindersEnabled"
        static let dailySummaryEnabled = "dailySummaryEnabled"
        static let reminderTimeMinutes = "reminderTimeMinutes"
        
        // Sync & Backup
        static let iCloudSyncEnabled = "iCloudSyncEnabled"
        static let autoBackupEnabled = "autoBackupEnabled"
        static let lastBackupDate = "lastBackupDate"
        static let lastSyncDate = "lastSyncDate"
        
        // Other
        static let showCompletedTasks = "showCompletedTasks"
    }
    
    enum NotificationIdentifiers {
        static let eventReminder = "eventReminder"
        static let taskDue = "taskDue"
        static let dailySummary = "dailySummary"
    }
}

