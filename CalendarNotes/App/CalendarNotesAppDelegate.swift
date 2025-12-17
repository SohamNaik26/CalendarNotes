//
//  CalendarNotesAppDelegate.swift
//  CalendarNotes
//
//  Created by Cursor AI on 09/11/25.
//

#if os(iOS)

import UIKit

final class CalendarNotesAppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Set window background early to prevent black bars
        setWindowBackgroundColor()
        
        // Also set it when scenes connect
        NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: .main
        ) { _ in
            self.setWindowBackgroundColor()
        }
        
        AppQuickActionService.shared.configureInitialShortcuts()
		
		// Register background sync tasks
		#if os(iOS)
		BackgroundSyncManager.shared.registerBackgroundTasks()
		BackgroundSyncManager.shared.scheduleBackgroundSync()
		BackgroundSyncManager.shared.scheduleBackgroundProcessing()
		#endif
		
		// Legacy sync service registration (keep for compatibility)
		SyncService.shared.registerBackgroundTasks()
		SyncService.shared.scheduleBackgroundSync()
		
		// Attempt realtime connection on launch if allowed
		WebSocketManager.shared.connectIfAllowed()
		
		// Setup memory warning observer
		setupMemoryWarningObserver()
        return true
    }
	
	private func setupMemoryWarningObserver() {
		#if os(iOS)
		NotificationCenter.default.addObserver(
			forName: UIApplication.didReceiveMemoryWarningNotification,
			object: nil,
			queue: .main
		) { [weak self] _ in
			self?.handleMemoryWarning()
		}
		#endif
	}
	
	private func handleMemoryWarning() {
		// Clear image caches
		ImageCacheService.shared.handleMemoryWarningPublic()
		
		// Clear performance monitor stats
		PerformanceMonitor.shared.clearStats()
		
		// Clear any other caches
		// Add more cache clearing as needed
	}
	
	func applicationDidEnterBackground(_ application: UIApplication) {
		#if os(iOS)
		BackgroundSyncManager.shared.scheduleSyncAfterAppEntersBackground()
		#endif
	}

    func application(_ application: UIApplication,
                     performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        let handled = AppQuickActionService.shared.handle(shortcutItem)
        completionHandler(handled)
    }
    
    private func setWindowBackgroundColor() {
        DispatchQueue.main.async {
            // Set window background for all connected scenes
            for scene in UIApplication.shared.connectedScenes {
                if let windowScene = scene as? UIWindowScene {
                    for window in windowScene.windows {
                        // Use the purple gradient start color (#667eea)
                        window.backgroundColor = UIColor(red: 0.4, green: 0.49, blue: 0.92, alpha: 1.0)
                    }
                }
            }
        }
    }
}

#endif


