//
//  CloudKitNotificationManager.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 22/10/25.
//

import Foundation
import UserNotifications
import CloudKit
import Combine

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - CloudKit Notification Manager

class CloudKitNotificationManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = CloudKitNotificationManager()
    
    // MARK: - Properties
    
    private let notificationCenter = UNUserNotificationCenter.current()
    private let cloudKitManager = CloudKitManager.shared
    
    // MARK: - ObservableObject Conformance
    
    @Published var isNotificationPermissionGranted = false
    
    // MARK: - Initialization
    
    private init() {
        setupNotificationObservers()
    }
    
    // MARK: - Setup
    
    private func setupNotificationObservers() {
        // Listen for CloudKit sync events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSyncCompleted),
            name: .cloudKitSyncCompleted,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSyncError),
            name: .cloudKitSyncError,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleSettingsChanged),
            name: .cloudKitSettingsChanged,
            object: nil
        )
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleSyncCompleted() {
        Task {
            await showSyncCompletedNotification()
        }
    }
    
    @objc private func handleSyncError(_ notification: Notification) {
        guard let errorMessage = notification.userInfo?["error"] as? String else { return }
        
        Task {
            await showSyncErrorNotification(error: errorMessage)
        }
    }
    
    @objc private func handleSettingsChanged() {
        Task {
            await showSettingsChangedNotification()
        }
    }
    
    // MARK: - Notification Creation
    
    @MainActor
    private func showSyncCompletedNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "iCloud Sync Complete"
        content.body = "Your CalendarNotes data has been synced with iCloud"
        content.sound = .default
        content.categoryIdentifier = "CLOUDKIT_SYNC"
        
        let request = UNNotificationRequest(
            identifier: "cloudkit-sync-completed-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to show sync completed notification: \(error)")
        }
    }
    
    @MainActor
    private func showSyncErrorNotification(error: String) async {
        let content = UNMutableNotificationContent()
        content.title = "iCloud Sync Error"
        content.body = "Failed to sync with iCloud: \(error)"
        content.sound = .default
        content.categoryIdentifier = "CLOUDKIT_ERROR"
        
        let request = UNNotificationRequest(
            identifier: "cloudkit-sync-error-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to show sync error notification: \(error)")
        }
    }
    
    @MainActor
    private func showSettingsChangedNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "iCloud Settings Updated"
        content.body = "Your iCloud sync settings have been updated"
        content.sound = .default
        content.categoryIdentifier = "CLOUDKIT_SETTINGS"
        
        let request = UNNotificationRequest(
            identifier: "cloudkit-settings-changed-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to show settings changed notification: \(error)")
        }
    }
    
    // MARK: - Custom Notifications
    
    func showSyncStartedNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "iCloud Sync Started"
        content.body = "Syncing your CalendarNotes data with iCloud..."
        content.sound = .default
        content.categoryIdentifier = "CLOUDKIT_SYNC"
        
        let request = UNNotificationRequest(
            identifier: "cloudkit-sync-started-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to show sync started notification: \(error)")
        }
    }
    
    func showNetworkStatusNotification(isConnected: Bool) async {
        let content = UNMutableNotificationContent()
        
        if isConnected {
            content.title = "Network Connected"
            content.body = "iCloud sync will resume automatically"
        } else {
            content.title = "Network Disconnected"
            content.body = "iCloud sync paused until connection is restored"
        }
        
        content.sound = .default
        content.categoryIdentifier = "CLOUDKIT_NETWORK"
        
        let request = UNNotificationRequest(
            identifier: "cloudkit-network-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to show network status notification: \(error)")
        }
    }
    
    func showAccountStatusNotification(isSignedIn: Bool) async {
        let content = UNMutableNotificationContent()
        
        if isSignedIn {
            content.title = "iCloud Account Available"
            content.body = "You can now sync your CalendarNotes data"
        } else {
            content.title = "iCloud Account Unavailable"
            content.body = "Please sign in to iCloud to enable sync"
        }
        
        content.sound = .default
        content.categoryIdentifier = "CLOUDKIT_ACCOUNT"
        
        let request = UNNotificationRequest(
            identifier: "cloudkit-account-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
        } catch {
            print("Failed to show account status notification: \(error)")
        }
    }
    
    // MARK: - Notification Categories
    
    func setupNotificationCategories() {
        let syncCategory = UNNotificationCategory(
            identifier: "CLOUDKIT_SYNC",
            actions: [
                UNNotificationAction(
                    identifier: "VIEW_SYNC_STATUS",
                    title: "View Status",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let errorCategory = UNNotificationCategory(
            identifier: "CLOUDKIT_ERROR",
            actions: [
                UNNotificationAction(
                    identifier: "RETRY_SYNC",
                    title: "Retry Sync",
                    options: [.foreground]
                ),
                UNNotificationAction(
                    identifier: "VIEW_ERROR",
                    title: "View Error",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let settingsCategory = UNNotificationCategory(
            identifier: "CLOUDKIT_SETTINGS",
            actions: [
                UNNotificationAction(
                    identifier: "OPEN_SETTINGS",
                    title: "Open Settings",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        let networkCategory = UNNotificationCategory(
            identifier: "CLOUDKIT_NETWORK",
            actions: [],
            intentIdentifiers: [],
            options: []
        )
        
        let accountCategory = UNNotificationCategory(
            identifier: "CLOUDKIT_ACCOUNT",
            actions: [
                UNNotificationAction(
                    identifier: "OPEN_ICLOUD_SETTINGS",
                    title: "Open iCloud Settings",
                    options: [.foreground]
                )
            ],
            intentIdentifiers: [],
            options: []
        )
        
        notificationCenter.setNotificationCategories([
            syncCategory,
            errorCategory,
            settingsCategory,
            networkCategory,
            accountCategory
        ])
    }
    
    // MARK: - Notification Actions
    
    func handleNotificationAction(_ actionIdentifier: String) {
        switch actionIdentifier {
        case "VIEW_SYNC_STATUS":
            // Open sync status view
            NotificationCenter.default.post(name: .openSyncStatus, object: nil)
            
        case "RETRY_SYNC":
            // Trigger manual sync
            Task {
                await cloudKitManager.triggerManualSync()
            }
            
        case "VIEW_ERROR":
            // Open error details
            NotificationCenter.default.post(name: .openSyncError, object: nil)
            
        case "OPEN_SETTINGS":
            // Open app settings
            NotificationCenter.default.post(name: .openAppSettings, object: nil)
            
        case "OPEN_ICLOUD_SETTINGS":
            // Open system iCloud settings
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.icloud") {
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #else
            UIApplication.shared.open(url)
            #endif
        }
            
        default:
            break
        }
    }
    
    // MARK: - Permission Management
    
    func requestNotificationPermission() async throws -> Bool {
        let granted = try await notificationCenter.requestAuthorization(
            options: [.alert, .sound, .badge]
        )
        
        if granted {
            setupNotificationCategories()
        }
        
        return granted
    }
    
    // MARK: - Cleanup
    
    func clearAllNotifications() async {
        notificationCenter.removeAllPendingNotificationRequests()
        notificationCenter.removeAllDeliveredNotifications()
    }
    
    func clearSyncNotifications() async {
        let deliveredNotifications = await notificationCenter.deliveredNotifications()
        let syncNotificationIds = deliveredNotifications
            .filter { $0.request.content.categoryIdentifier.contains("CLOUDKIT") }
            .map { $0.request.identifier }
        
        notificationCenter.removeDeliveredNotifications(withIdentifiers: syncNotificationIds)
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let openSyncStatus = Notification.Name("openSyncStatus")
    static let openSyncError = Notification.Name("openSyncError")
    static let openAppSettings = Notification.Name("openAppSettings")
}
