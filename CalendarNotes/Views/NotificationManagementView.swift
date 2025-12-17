//
//  NotificationManagementView.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 22/10/25.
//

import SwiftUI
import UserNotifications

struct NotificationManagementView: View {
    @StateObject private var notificationManager = NotificationManager.shared
    @State private var showingScheduleAll = false
    @State private var showingCancelAll = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Text("Notification Management")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Text("\(notificationManager.getNotificationCount()) pending")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Quick Actions
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    Button(action: {
                        showingScheduleAll = true
                    }) {
                        Label("Schedule All", systemImage: "bell.badge")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        showingCancelAll = true
                    }) {
                        Label("Cancel All", systemImage: "bell.slash")
                    }
                    .buttonStyle(.bordered)
                }
                
                Button(action: {
                    Task {
                        await notificationManager.loadPendingNotifications()
                    }
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            
            Divider()
            
            // Notification Statistics
            VStack(alignment: .leading, spacing: 8) {
                Text("Statistics")
                    .font(.headline)
                
                HStack {
                    Text("Event Reminders:")
                        .font(.subheadline)
                    Spacer()
                    Text("\(notificationManager.getNotificationCount(for: .eventReminder))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Task Due:")
                        .font(.subheadline)
                    Spacer()
                    Text("\(notificationManager.getNotificationCount(for: .taskDue))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Task Overdue:")
                        .font(.subheadline)
                    Spacer()
                    Text("\(notificationManager.getNotificationCount(for: .taskOverdue))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Daily Summary:")
                        .font(.subheadline)
                    Spacer()
                    Text("\(notificationManager.getNotificationCount(for: .dailySummary))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }
            
            Divider()
            
            // Pending Notifications List
            VStack(alignment: .leading, spacing: 8) {
                Text("Pending Notifications")
                    .font(.headline)
                
                if notificationManager.pendingNotifications.isEmpty {
                    Text("No pending notifications")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .italic()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(notificationManager.pendingNotifications, id: \.identifier) { request in
                                NotificationItemView(request: request)
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }
        }
        .padding()
        .alert("Schedule All Notifications", isPresented: $showingScheduleAll) {
            Button("Cancel", role: .cancel) { }
            Button("Schedule", role: .destructive) {
                Task {
                    do {
                        try await notificationManager.scheduleAllEventReminders()
                        try await notificationManager.scheduleAllTaskReminders()
                        await notificationManager.loadPendingNotifications()
                    } catch {
                        print("Error scheduling notifications: \(error)")
                    }
                }
            }
        } message: {
            Text("This will schedule notifications for all events and tasks. Existing notifications will be replaced.")
        }
        .alert("Cancel All Notifications", isPresented: $showingCancelAll) {
            Button("Cancel", role: .cancel) { }
            Button("Cancel All", role: .destructive) {
                Task {
                    await notificationManager.cancelAllNotifications()
                }
            }
        } message: {
            Text("This will cancel all pending notifications. This action cannot be undone.")
        }
    }
}

struct NotificationItemView: View {
    let request: UNNotificationRequest
    
    var body: some View {
        HStack(spacing: 12) {
            // Notification Icon
            Image(systemName: iconForRequest(request))
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            // Notification Content
            VStack(alignment: .leading, spacing: 2) {
                Text(request.content.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(request.content.body)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Time until notification
            if let trigger = request.trigger as? UNTimeIntervalNotificationTrigger {
                let timeInterval = trigger.timeInterval
                if timeInterval > 0 {
                    Text(timeString(from: timeInterval))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private func iconForRequest(_ request: UNNotificationRequest) -> String {
        if let userInfo = request.content.userInfo as? [String: Any] {
            if userInfo["eventId"] != nil {
                return "calendar"
            } else if userInfo["taskId"] != nil {
                return "checkmark.circle"
            }
        }
        
        if request.identifier.contains("daily_summary") {
            return "sun.max"
        }
        
        return "bell"
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval.truncatingRemainder(dividingBy: 3600)) / 60
        let days = hours / 24
        
        if days > 0 {
            return "\(days)d"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(minutes)m"
        }
    }
}

#Preview {
    NotificationManagementView()
        .frame(width: 400, height: 500)
}
