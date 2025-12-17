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
#if os(iOS)
    @UIApplicationDelegateAdaptor(CalendarNotesAppDelegate.self) private var appDelegate
#endif
    // Use CoreDataManager for all Core Data operations
    let coreDataManager = CoreDataManager.shared
    
    // Managers are safe to initialize - NotificationManager.init() is guarded in DEBUG mode
    let notificationManager = NotificationManager.shared
    let eventKitManager = EventKitManager.shared
    let cloudKitManager = CloudKitManager.shared
    let cloudKitNotificationManager = CloudKitNotificationManager.shared
    
    @StateObject private var shortcutActionHandler = ShortcutActionHandler.shared
#if os(iOS)
    @StateObject private var orientationManager = OrientationManager()
#endif
#if os(iOS)
    @Environment(\.scenePhase) private var scenePhase
#endif
    
    init() {
        Task { @MainActor in AppLaunchMetrics.shared.markLaunchStart() }
        PerformanceMonitor.shared.startOperation("app.launch")
        // Ensure auth API base URL default for Simulator/macOS
        #if targetEnvironment(simulator) || os(macOS)
        UserDefaults.standard.register(defaults: ["auth.api.baseURL": "http://localhost:3000"])
        #endif
        
        // Configure Google OAuth Client ID if not already set
        // TODO: Replace with your actual Google OAuth Client ID from Google Cloud Console
        // You can also set this in Info.plist or via UserDefaults
        if UserDefaults.standard.string(forKey: "google.oauth.clientId") == nil {
            // Set your Google OAuth Client ID here or in Info.plist
            // UserDefaults.standard.set("YOUR_CLIENT_ID.apps.googleusercontent.com", forKey: "google.oauth.clientId")
        }
        BookmarkBackupScheduler.shared.start()
        BookmarkBackupScheduler.shared.handleAppLaunch()
        // Keep DEBUG launch minimal to avoid startup blockers while we diagnose
        #if DEBUG
        // Minimal init: skip notifications, EventKit, and CloudKit on Debug
        #else
        // Setup notification handling
        setupNotificationHandling()
        // Setup CloudKit notifications
        setupCloudKitNotifications()
        // Perform initial EventKit sync on app launch
        performInitialSync()
        // Perform initial CloudKit sync on app launch
        performInitialCloudKitSync()
        #endif
    }
    
    private var appDidBecomeActiveNotification: Notification.Name {
        #if os(macOS)
        return NSApplication.didBecomeActiveNotification
        #else
        return UIApplication.didBecomeActiveNotification
        #endif
    }

    @ViewBuilder
    private var rootSceneView: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            IPadMainView()
        } else {
            RootView()
        }
        #else
        RootView()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            rootSceneView
                .environmentObject(AuthManager.shared)
                .environment(\.managedObjectContext, coreDataManager.viewContext)
                .environmentObject(shortcutActionHandler)
                .environmentObject(SyncManager.shared)
                .environmentObject(WebSocketManager.shared)
                #if os(iOS)
                .environmentObject(orientationManager)
                .onAppear {
                    // Set window background to match gradient start color to prevent black bars
                    setWindowBackground()
                }
                .onChange(of: AuthManager.shared.authState) { _, _ in
                    // Update window background when auth state changes
                    setWindowBackground()
                }
                #endif
                .task {
                    await MainActor.run {
                        SaveQueueIngestService.shared.start()
                    }
                }
                .task {
                    await MainActor.run {
                        SmartCollectionService.shared.ensurePredefinedCollections()
                    }
                }
                .onOpenURL { url in
                    Task { @MainActor in
                        if let parsed = DeepLinkRouter.shared.parse(url: url) {
                            await DeepLinkRouter.shared.handle(parsed)
                        }
                    }
                }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL {
                        Task { @MainActor in
                            if let parsed = DeepLinkRouter.shared.parse(url: url) {
                                await DeepLinkRouter.shared.handle(parsed)
                            }
                        }
                    }
                }
#if os(iOS)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    switch phase {
                    case .active:
                        AppQuickActionService.shared.updateDynamicQuickActions()
                    case .background:
                        BackgroundSyncManager.shared.scheduleSyncAfterAppEntersBackground()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
#endif
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Bookmark") {
                    shortcutActionHandler.perform(.newBookmark)
                }
                .keyboardShortcut("n", modifiers: .command)
                
                Button("New Collection") {
                    shortcutActionHandler.perform(.newCollection)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])
            }
            
            CommandMenu("Find & Refresh") {
                Button("Find in Bookmarks") {
                    shortcutActionHandler.perform(.focusSearch)
                }
                .keyboardShortcut("f", modifiers: .command)
                
                Button("Refresh") {
                    shortcutActionHandler.perform(.refresh)
                }
                .keyboardShortcut("r", modifiers: .command)
            }
            
            CommandGroup(replacing: .appSettings) {
                Button("Settings") {
                    shortcutActionHandler.perform(.openSettings)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            
            CommandMenu("Window") {
#if os(macOS)
                Button("New Window") {
                    NSDocumentController.shared.newDocument(nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift, .option])

                Button("Toggle Sidebar") {
                    NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .option])
#endif
                Button("Close Modal") {
                    shortcutActionHandler.perform(.closeModal)
                }
                .keyboardShortcut("w", modifiers: .command)
            }
            
            CommandMenu("Bookmarks") {
                Button("Open Bookmark") {
                    shortcutActionHandler.perform(.openBookmark)
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Button("Edit Bookmark") {
                    shortcutActionHandler.perform(.editBookmark)
                }
                .keyboardShortcut("e", modifiers: .command)
                
                Button("Delete Bookmark") {
                    shortcutActionHandler.perform(.deleteBookmark)
                }
                .keyboardShortcut("d", modifiers: .command)
                
                Button("Toggle Favorite") {
                    shortcutActionHandler.perform(.toggleFavorite)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                
                Button("Copy URL") {
                    shortcutActionHandler.perform(.copyURL)
                }
                .keyboardShortcut("c", modifiers: .command)
                
                Divider()
                
                Button("Select All") {
                    shortcutActionHandler.perform(.selectAll)
                }
                .keyboardShortcut("a", modifiers: .command)
            }
            
            CommandMenu("Navigate Tabs") {
                ForEach(0..<5) { index in
                    Button("Switch to Tab \(index + 1)") {
                        shortcutActionHandler.perform(.switchTab(index))
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
                Divider()
                Button("Back") {
                    shortcutActionHandler.perform(.navigateBack)
                }
                .keyboardShortcut(KeyEquivalent("["), modifiers: .command)
                
                Button("Forward") {
                    shortcutActionHandler.perform(.navigateForward)
                }
                .keyboardShortcut(KeyEquivalent("]"), modifiers: .command)
            }
        }
#if os(macOS)
        WindowGroup("Bookmarks", id: "macBookmarksWindow") {
            MacRootSplitView()
                .environment(\.managedObjectContext, coreDataManager.viewContext)
                .withTheme()
        }
#endif
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
    
    #if os(iOS)
    @MainActor
    private func setWindowBackground() {
        // Set window background to match gradient start color to prevent black bars
        // Try multiple times to catch the window when it's ready
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            for window in windowScene.windows {
                // Use the purple gradient start color (#667eea)
                window.backgroundColor = UIColor(red: 0.4, green: 0.49, blue: 0.92, alpha: 1.0)
            }
        }
    }
    #endif
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
