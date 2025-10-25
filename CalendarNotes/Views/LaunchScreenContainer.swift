//
//  LaunchScreenContainer.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 25/10/25.
//

import SwiftUI
import CoreData

/// Container that shows launch screen on app start, then transitions to main app
struct LaunchScreenContainer: View {
    @State private var showLaunchScreen = true
    @State private var showMainApp = false
    
    // Core Data context
    @Environment(\.managedObjectContext) var managedObjectContext
    
    var body: some View {
        ZStack {
            if showLaunchScreen {
                LaunchScreenView()
                    .transition(.opacity)
            }
            
            if showMainApp {
                MainTabView()
                    .environment(\.managedObjectContext, managedObjectContext)
                    .withTheme()
                    .onReceive(NotificationCenter.default.publisher(for: appDidBecomeActiveNotification)) { _ in
                        // Refresh notification status when app becomes active
                        Task {
                            await NotificationManager.shared.loadPendingNotifications()
                        }
                    }
                    .transition(.opacity)
            }
        }
        .onAppear {
            // Show launch screen for 1.5 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    showLaunchScreen = false
                    showMainApp = true
                }
            }
        }
    }
    
    private var appDidBecomeActiveNotification: Notification.Name {
        #if os(macOS)
        return NSApplication.didBecomeActiveNotification
        #else
        return UIApplication.didBecomeActiveNotification
        #endif
    }
}
