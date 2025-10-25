//
//  CalendarNotesApp.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import SwiftUI
import CoreData
import UserNotifications

#if os(macOS)
import AppKit
#else
import UIKit
#endif
import EventKit

@main
struct CalendarNotesApp: App {
    // Use CoreDataManager for all Core Data operations
    let coreDataManager = CoreDataManager.shared
    let notificationManager = NotificationManager.shared
    let eventKitManager = EventKitManager.shared
    let cloudKitManager = CloudKitManager.shared
    let cloudKitNotificationManager = CloudKitNotificationManager.shared
    
    init() {
        // Optional: Create sample data for development
        #if DEBUG
        // Uncomment to populate with sample data on first launch
        // CoreDataManager.createSampleData()
        #endif
        
        // Setup notification handling
        setupNotificationHandling()
        
        // Setup CloudKit notifications
        setupCloudKitNotifications()
        
        // Perform initial EventKit sync on app launch
        performInitialSync()
        
        // Perform initial CloudKit sync on app launch
        performInitialCloudKitSync()
    }
    
    private var appDidBecomeActiveNotification: Notification.Name {
        #if os(macOS)
        return NSApplication.didBecomeActiveNotification
        #else
        return UIApplication.didBecomeActiveNotification
        #endif
    }

    var body: some Scene {
        WindowGroup {
            LaunchScreenContainer()
                .environment(\.managedObjectContext, coreDataManager.viewContext)
        }
    }
    
    private func setupNotificationHandling() {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        
        // Register for notification response handling
        NotificationCenter.default.addObserver(
            forName: .init("NotificationResponse"),
            object: nil,
            queue: .main
        ) { notification in
            if let response = notification.object as? UNNotificationResponse {
                Task {
                    await notificationManager.handleNotificationResponse(response)
                }
            }
        }
    }
    
    private func performInitialSync() {
        Task {
            await performEventKitSyncIfNeeded()
        }
    }
    
    @MainActor
    private func performEventKitSyncIfNeeded() async {
        // Check if auto sync is enabled
        let autoSyncEnabled = UserDefaults.standard.bool(forKey: "eventKitAutoSyncEnabled")
        let syncEnabled = UserDefaults.standard.bool(forKey: "eventKitSyncEnabled")
        
        guard syncEnabled && autoSyncEnabled else { return }
        
        // Check if we have calendar access
        eventKitManager.checkAuthorizationStatus()
        
        // Check authorization status based on OS version
        let hasAccess: Bool
        if #available(macOS 14.0, iOS 17.0, *) {
            hasAccess = eventKitManager.authorizationStatus == .fullAccess || 
                       eventKitManager.authorizationStatus == .writeOnly
        } else {
            hasAccess = eventKitManager.authorizationStatus == .authorized
        }
        
        guard hasAccess else {
            return
        }
        
        // Check if enough time has passed since last sync (avoid too frequent syncs)
        let lastSyncDate = UserDefaults.standard.object(forKey: "lastEventKitSyncDate") as? Date
        let minimumSyncInterval: TimeInterval = 300 // 5 minutes
        
        if let lastSync = lastSyncDate,
           Date().timeIntervalSince(lastSync) < minimumSyncInterval {
            return
        }
        
        // Perform sync in background
        do {
            print("🔄 Performing automatic EventKit sync...")
            _ = try await eventKitManager.performFullSync()
            print("✅ Automatic EventKit sync completed")
        } catch {
            print("❌ EventKit sync failed: \(error.localizedDescription)")
        }
    }
    
    private func setupCloudKitNotifications() {
        Task {
            do {
                _ = try await cloudKitNotificationManager.requestNotificationPermission()
                cloudKitNotificationManager.setupNotificationCategories()
            } catch {
                print("Failed to setup CloudKit notifications: \(error)")
            }
        }
    }
    
    private func performInitialCloudKitSync() {
        Task { @MainActor in
            await performInitialCloudKitSyncAsync()
        }
    }
    
    @MainActor
    private func performInitialCloudKitSyncAsync() async {
        // Check if CloudKit sync is enabled
        let cloudKitEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        guard cloudKitEnabled else { return }
        
        // Check if we can sync
        guard cloudKitManager.canSync() else { return }
        
        // Perform sync in background
        do {
            print("🔄 Performing initial CloudKit sync...")
            try await cloudKitManager.performSync()
            print("✅ Initial CloudKit sync completed")
        } catch {
            print("❌ CloudKit sync failed: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func performCloudKitSyncIfNeeded() async {
        // Check if CloudKit sync is enabled
        let cloudKitEnabled = UserDefaults.standard.bool(forKey: "iCloudSyncEnabled")
        guard cloudKitEnabled else { return }
        
        // Check if we can sync
        guard cloudKitManager.canSync() else { return }
        
        // Check if enough time has passed since last sync (avoid too frequent syncs)
        let lastSyncDate = UserDefaults.standard.object(forKey: "lastCloudKitSyncDate") as? Date
        let minimumSyncInterval: TimeInterval = 300 // 5 minutes
        
        if let lastSync = lastSyncDate,
           Date().timeIntervalSince(lastSync) < minimumSyncInterval {
            return
        }
        
        // Perform sync in background
        do {
            print("🔄 Performing automatic CloudKit sync...")
            try await cloudKitManager.performSync()
            UserDefaults.standard.set(Date(), forKey: "lastCloudKitSyncDate")
            print("✅ Automatic CloudKit sync completed")
        } catch {
            print("❌ CloudKit sync failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Notification Delegate

class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    // Handle notification when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        #if os(macOS)
        if #available(macOS 11.0, *) {
            completionHandler([.list, .sound, .banner])
        } else {
            completionHandler([.sound, .banner])
        }
        #else
        completionHandler([.banner, .sound, .badge])
        #endif
    }
    
    // Handle notification tap/interaction
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Post notification to be handled by NotificationManager
        NotificationCenter.default.post(
            name: .init("NotificationResponse"),
            object: response
        )
        
        completionHandler()
    }
}
