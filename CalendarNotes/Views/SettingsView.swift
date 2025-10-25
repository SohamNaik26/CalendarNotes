//
//  SettingsView.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 22/10/25.
//

import SwiftUI
import EventKit

#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @StateObject private var calendarService = CalendarService()
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @Environment(\.colorScheme) var systemColorScheme
    
    private var systemBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    private var windowBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    private var controlBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    @Environment(\.themeManager) var themeManager
    @State private var showingNotificationManagement = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Settings")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Customize your CalendarNotes experience")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding()
                .background(systemBackgroundColor)
                
                // Content
                VStack(spacing: 32) {
                    // User Profile Section
                    userProfileSection
                    
                    // Appearance Section
                    appearanceSection
                    
                    // Calendar Preferences
                    calendarPreferencesSection
                    
                    // Notification Preferences
                    notificationPreferencesSection
                    
                    // iCloud & Backup
                    iCloudBackupSection
                    
                    // iCloud Sync
                    iCloudSyncSection
                    
                    // Calendar Integration
                    calendarIntegrationSection
                    
                    // Data Management
                    dataManagementSection
                    
                    // Help & Support
                    helpSupportSection
                    
                    // About Section
                    aboutSection
                }
                .padding()
            }
        }
        .background(windowBackgroundColor)
        .sheet(isPresented: $showingNotificationManagement) {
            NotificationManagementView()
        }
    }
    
    // MARK: - User Profile Section
    
    private var userProfileSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: "person.circle.fill")
                    .foregroundColor(.accentColor)
                Text("User Profile")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            // Section Content
            VStack(spacing: 20) {
                // Avatar and Profile Info
                HStack(spacing: 20) {
                    // Avatar
                    Circle()
                        .fill(Color.accentColor.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.accentColor)
                        )
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(viewModel.userName.isEmpty ? "User Name" : viewModel.userName)
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(viewModel.userEmail.isEmpty ? "email@example.com" : viewModel.userEmail)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                
                // Name Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Name")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("Enter your name", text: $viewModel.userName)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Email Field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    TextField("Enter your email", text: $viewModel.userEmail)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Appearance Section
    
    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: "paintbrush.fill")
                    .foregroundColor(.accentColor)
                Text("Appearance")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            // Section Content
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Theme")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("Theme", selection: Binding(
                        get: { themeManager.currentAppearanceMode },
                        set: { themeManager.setAppearanceMode($0) }
                    )) {
                        ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                
                // Theme preview
                HStack {
                    Text("Current: \(themeManager.currentAppearanceMode.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Circle()
                        .fill(themeManager.currentAppearanceMode == .dark ? Color.black : 
                              themeManager.currentAppearanceMode == .light ? Color.white : 
                              Color.gray)
                        .frame(width: 16, height: 16)
                        .overlay(
                            Circle()
                                .stroke(Color.primary, lineWidth: 1)
                        )
                }
                
                HStack {
                    Text("Compact View")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Toggle("Enable compact view mode", isOn: $viewModel.compactViewMode)
                        .labelsHidden()
                }
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Calendar Preferences Section
    
    private var calendarPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(.accentColor)
                Text("Calendar Preferences")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            // Section Content
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Default View")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("Default View", selection: $viewModel.defaultCalendarView) {
                        ForEach(DefaultCalendarView.allCases, id: \.rawValue) { view in
                            Text(view.rawValue).tag(view.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                }
                
                HStack {
                    Text("First Day of Week")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("First Day of Week", selection: $viewModel.firstDayOfWeek) {
                        ForEach(FirstDayOfWeek.allCases, id: \.rawValue) { day in
                            Text(day.displayName).tag(day.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 150)
                }
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Notification Preferences Section
    
    private var notificationPreferencesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .foregroundColor(.accentColor)
                Text("Notification Preferences")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            // Section Content
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Enable Notifications")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Toggle("Enable Notifications", isOn: $viewModel.notificationsEnabled)
                        .labelsHidden()
                }
                
                if viewModel.notificationsEnabled {
                    Divider()
                        .padding(.vertical, 8)
                    
                    HStack {
                        Text("Event Reminders")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Toggle("Event Reminders", isOn: $viewModel.eventRemindersEnabled)
                            .labelsHidden()
                    }
                    
                    HStack {
                        Text("Task Reminders")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Toggle("Task Reminders", isOn: $viewModel.taskRemindersEnabled)
                            .labelsHidden()
                    }
                    
                    HStack {
                        Text("Daily Summary")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Toggle("Daily Summary", isOn: $viewModel.dailySummaryEnabled)
                            .labelsHidden()
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    HStack {
                        Text("Reminder Time")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Picker("Reminder Time", selection: $viewModel.reminderTimeMinutes) {
                            Text("5 minutes").tag(5)
                            Text("15 minutes").tag(15)
                            Text("30 minutes").tag(30)
                            Text("1 hour").tag(60)
                            Text("1 day").tag(1440)
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                    
                    HStack {
                        Text("Notification Sound")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Picker("Notification Sound", selection: $viewModel.notificationSound) {
                            ForEach(NotificationSound.allCases, id: \.rawValue) { sound in
                                Text(sound.displayName).tag(sound.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 150)
                    }
                    
                    HStack {
                        Text("Daily Summary Time")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        DatePicker("", selection: Binding(
                            get: { viewModel.dailySummaryDate },
                            set: { newDate in
                                let calendar = Calendar.current
                                let hour = calendar.component(.hour, from: newDate)
                                let minute = calendar.component(.minute, from: newDate)
                                viewModel.dailySummaryTime = Double(hour * 3600 + minute * 60)
                            }
                        ), displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .frame(width: 100)
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // Notification Management Buttons
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Button(action: {
                                Task {
                                    do {
                                        try await viewModel.requestNotificationPermission()
                                        try await viewModel.scheduleAllNotifications()
                                    } catch {
                                        print("Error with notifications: \(error)")
                                    }
                                }
                            }) {
                                Label("Enable & Schedule", systemImage: "bell.badge")
                            }
                            .buttonStyle(.bordered)
                            
                            Button(action: {
                                Task {
                                    await viewModel.cancelAllNotifications()
                                }
                            }) {
                                Label("Cancel All", systemImage: "bell.slash")
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        HStack {
                            Text("Pending Notifications:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(viewModel.getPendingNotificationCount())")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        Button(action: {
                            showingNotificationManagement = true
                        }) {
                            Label("Manage Notifications", systemImage: "gear")
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
    }
    
    // MARK: - iCloud Sync Section
    
    private var iCloudSyncSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: "icloud")
                    .foregroundColor(.accentColor)
                Text("iCloud Sync")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            // Sync Status
            CloudKitSyncStatusView()
            
            // Section Content
            VStack(alignment: .leading, spacing: 16) {
                // Enable iCloud Sync
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Enable iCloud Sync")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Sync your data across all devices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("iCloud Sync", isOn: $viewModel.iCloudSyncEnabled)
                        .labelsHidden()
                        .onChange(of: viewModel.iCloudSyncEnabled) {
                            if viewModel.iCloudSyncEnabled {
                                cloudKitManager.enableCloudKitSync()
                            } else {
                                cloudKitManager.disableCloudKitSync()
                            }
                        }
                }
                
                if viewModel.iCloudSyncEnabled {
                    Divider()
                        .padding(.vertical, 8)
                    
                    // WiFi Only Sync
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("WiFi Only Sync")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Sync only when connected to WiFi")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("WiFi Only", isOn: $viewModel.iCloudWiFiOnlySync)
                            .labelsHidden()
                            .onChange(of: viewModel.iCloudWiFiOnlySync) { _, newValue in
                                cloudKitManager.setWiFiOnlySync(newValue)
                            }
                    }
                    
                    // Manual Sync
                    HStack(spacing: 12) {
                        Button(action: {
                            Task {
                                await cloudKitManager.triggerManualSync()
                            }
                        }) {
                            HStack {
                                if cloudKitManager.isSyncing {
                                    ProgressView()
                                        .scaleEffect(0.7)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                }
                                Text(cloudKitManager.isSyncing ? "Syncing..." : "Sync Now")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(!cloudKitManager.canSync() || cloudKitManager.isSyncing)
                        
                        Button("Sync Details") {
                            // This would open the sync details view
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    // Sync Statistics
                    if cloudKitManager.syncStats.totalChanges > 0 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Sync Statistics")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            HStack(spacing: 20) {
                                VStack(alignment: .leading) {
                                    Text("\(cloudKitManager.syncStats.recordsUploaded)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text("Uploaded")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("\(cloudKitManager.syncStats.recordsDownloaded)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text("Downloaded")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("\(cloudKitManager.syncStats.recordsDeleted)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                    Text("Deleted")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(systemBackgroundColor)
                        .cornerRadius(8)
                    }
                }
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
    }
    
    // MARK: - iCloud & Backup Section
    
    private var iCloudBackupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: "icloud.fill")
                    .foregroundColor(.accentColor)
                Text("iCloud & Backup")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            // Section Content
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("iCloud Sync")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Sync your data across devices")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("iCloud Sync", isOn: $viewModel.iCloudSyncEnabled)
                        .labelsHidden()
                        .onChange(of: viewModel.iCloudSyncEnabled) {
                            viewModel.toggleiCloudSync()
                        }
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Auto Backup")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Automatic daily backups")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("Auto Backup", isOn: $viewModel.autoBackupEnabled)
                        .labelsHidden()
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last Backup")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(viewModel.lastBackupDateFormatted)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                HStack(spacing: 12) {
                    Button(action: {
                        Task {
                            await viewModel.createBackup()
                        }
                    }) {
                        Label("Create Backup", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        viewModel.showingRestoreSheet = true
                    }) {
                        Label("Restore Backup", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Calendar Integration Section
    
    private var calendarIntegrationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: "calendar.badge.plus")
                    .foregroundColor(.accentColor)
                Text("Calendar Integration")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            // Section Content
            VStack(alignment: .leading, spacing: 16) {
                // Calendar Access Status
                HStack {
                    Text("Calendar Access")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(authorizationStatusText())
                        .font(.subheadline)
                        .foregroundColor(authorizationStatusColor())
                }
                
                if calendarService.authorizationStatus == .notDetermined {
                    Button(action: {
                        Task {
                            _ = try? await calendarService.requestAccess()
                        }
                    }) {
                        Label("Request Access", systemImage: "lock.open")
                    }
                    .buttonStyle(.bordered)
                } else if calendarService.authorizationStatus == .denied {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Access Denied")
                            .font(.caption)
                            .foregroundColor(.red)
                        Text("Please enable calendar access in System Settings → Privacy & Security → Calendars")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // EventKit Sync Toggle
                if isCalendarAccessGranted() {
                    Divider()
                        .padding(.vertical, 8)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("EventKit Sync")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Two-way sync with iOS Calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Toggle("EventKit Sync", isOn: $viewModel.eventKitSyncEnabled)
                            .labelsHidden()
                            .onChange(of: viewModel.eventKitSyncEnabled) {
                                Task {
                                    await viewModel.toggleEventKitSync()
                                }
                            }
                    }
                    
                    if viewModel.eventKitSyncEnabled {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Auto Sync")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Sync on app launch and background refresh")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Toggle("Auto Sync", isOn: $viewModel.eventKitAutoSyncEnabled)
                                .labelsHidden()
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Conflict Resolution")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("How to handle sync conflicts")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Picker("Conflict Resolution", selection: $viewModel.eventKitConflictResolution) {
                                Text("Newer Wins").tag("newerWins")
                                Text("Local Wins").tag("localWins")
                                Text("Remote Wins").tag("remoteWins")
                            }
                            .pickerStyle(.menu)
                            .frame(width: 150)
                        }
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Last Sync")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text(viewModel.lastEventKitSyncDateFormatted)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Sync Actions
                        HStack(spacing: 12) {
                            Button(action: {
                                Task {
                                    await viewModel.performEventKitSync()
                                }
                            }) {
                                HStack {
                                    if viewModel.syncInProgress {
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    } else {
                                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                                    }
                                }
                            }
                            .buttonStyle(.bordered)
                            .disabled(viewModel.syncInProgress)
                        }
                        
                        if !viewModel.syncMessage.isEmpty {
                            Text(viewModel.syncMessage)
                                .font(.caption)
                                .foregroundColor(viewModel.syncMessage.contains("failed") ? .red : .green)
                                .padding(.top, 4)
                        }
                    }
                }
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Data Management Section
    
    private var dataManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: "externaldrive.fill")
                    .foregroundColor(.accentColor)
                Text("Data Management")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            // Section Content
            VStack(alignment: .leading, spacing: 16) {
                Button(action: {
                    Task {
                        await viewModel.exportData()
                    }
                }) {
                    HStack {
                        Label("Export Data", systemImage: "square.and.arrow.up")
                        Spacer()
                        if viewModel.isExporting {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                }
                .buttonStyle(.bordered)
                
                if !viewModel.exportMessage.isEmpty {
                    Text(viewModel.exportMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                Button(action: {
                    viewModel.showingClearCacheAlert = true
                }) {
                    Label("Clear Cache", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    viewModel.showingDeleteAllDataAlert = true
                }) {
                    Label("Delete All Data", systemImage: "trash.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                
                Divider()
                    .padding(.vertical, 8)
                
                // Sample Data Generation
                Text("Sample Data")
                    .font(.headline)
                    .padding(.top, 8)
                
                Text("Generate sample data for testing and demo purposes.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button(action: {
                    Task {
                        await viewModel.generateSampleData()
                    }
                }) {
                    HStack {
                        Label("Generate Sample Data", systemImage: "sparkles")
                        Spacer()
                        if viewModel.isGeneratingSampleData {
                            ProgressView()
                                .scaleEffect(0.7)
                        }
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isGeneratingSampleData)
                
                if !viewModel.sampleDataMessage.isEmpty {
                    Text(viewModel.sampleDataMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Button(action: {
                    viewModel.showingClearSampleDataAlert = true
                }) {
                    Label("Clear All Sample Data", systemImage: "trash.circle")
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
        .alert("Clear Cache", isPresented: $viewModel.showingClearCacheAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                viewModel.clearCache()
            }
        } message: {
            Text("This will clear temporary files and cached data. Your notes, tasks, and events will not be affected.")
        }
        .alert("Delete All Data", isPresented: $viewModel.showingDeleteAllDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteAllData()
                }
            }
        } message: {
            Text("⚠️ WARNING: This will permanently delete ALL your notes, tasks, and events. This action cannot be undone!")
        }
        .alert("Clear All Sample Data", isPresented: $viewModel.showingClearSampleDataAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                Task {
                    await viewModel.clearAllSampleData()
                }
            }
        } message: {
            Text("This will permanently delete all events, notes, and tasks from your database. This action cannot be undone!")
        }
    }
    
    // MARK: - Help & Support Section
    
    private var helpSupportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.accentColor)
                Text("Help & Support")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            // Section Content
            VStack(alignment: .leading, spacing: 16) {
                Button(action: {
                    if let url = URL(string: "https://calendarnotes.app/help") {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                }) {
                    HStack {
                        Label("User Guide", systemImage: "book")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    if let url = URL(string: "https://calendarnotes.app/faq") {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                }) {
                    HStack {
                        Label("FAQ", systemImage: "questionmark.circle")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.vertical, 8)
                
                Button(action: {
                    viewModel.showingContactSupport = true
                }) {
                    Label("Contact Support", systemImage: "envelope")
                }
                .buttonStyle(.bordered)
                
                Button(action: {
                    if let url = URL(string: "https://calendarnotes.app/feedback") {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                }) {
                    Label("Send Feedback", systemImage: "megaphone")
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
        .sheet(isPresented: $viewModel.showingContactSupport) {
            ContactSupportView()
        }
    }
    
    // MARK: - About Section
    
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.accentColor)
                Text("About")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            // Section Content
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Version")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(AppConstants.appVersion)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Build")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text("1000")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Divider()
                    .padding(.vertical, 8)
                
                Button(action: {
                    if let url = URL(string: "https://calendarnotes.app/privacy") {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                }) {
                    HStack {
                        Label("Privacy Policy", systemImage: "hand.raised")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Button(action: {
                    if let url = URL(string: "https://calendarnotes.app/terms") {
                        #if os(macOS)
                        NSWorkspace.shared.open(url)
                        #else
                        UIApplication.shared.open(url)
                        #endif
                    }
                }) {
                    HStack {
                        Label("Terms of Service", systemImage: "doc.text")
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)
                
                Divider()
                    .padding(.vertical, 8)
                
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("Made with ❤️")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("© 2025 CalendarNotes")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Helper Methods
    
    private func authorizationStatusText() -> String {
        switch calendarService.authorizationStatus {
        case .notDetermined:
            return "Not Requested"
        case .restricted:
            return "Restricted"
        case .denied:
            return "Denied"
        case .authorized:
            return "Authorized"
        case .fullAccess:
            return "Full Access"
        case .writeOnly:
            return "Write Only"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func authorizationStatusColor() -> Color {
        switch calendarService.authorizationStatus {
        case .authorized, .fullAccess:
            return .green
        case .denied:
            return .red
        case .restricted:
            return .orange
        case .writeOnly:
            return .yellow
        case .notDetermined:
            return .secondary
        @unknown default:
            return .secondary
        }
    }
    
    private func isCalendarAccessGranted() -> Bool {
        if #available(macOS 14.0, iOS 17.0, *) {
            return calendarService.authorizationStatus == .fullAccess || 
                   calendarService.authorizationStatus == .writeOnly
        } else {
            return calendarService.authorizationStatus == .authorized
        }
    }
}


// MARK: - Contact Support View

struct ContactSupportView: View {
    @Environment(\.dismiss) var dismiss
    @State private var subject = ""
    @State private var message = ""
    @State private var includeSystemInfo = true
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    Text("We're here to help! Please describe your issue or question.")
                        .foregroundColor(.secondary)
                }
                
                Section {
                    TextField("Brief description of your issue", text: $subject)
                } header: {
                    Text("Subject")
                }
                
                Section {
                    TextEditor(text: $message)
                        .frame(minHeight: 150)
                } header: {
                    Text("Message")
                }
                
                Section {
                    Toggle("Include system information", isOn: $includeSystemInfo)
                    
                    if includeSystemInfo {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("System Info:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("macOS Version: \(ProcessInfo.processInfo.operatingSystemVersionString)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text("App Version: \(AppConstants.appVersion)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Contact Support")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Send") {
                        sendSupportEmail()
                        dismiss()
                    }
                    .disabled(subject.isEmpty || message.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 450)
    }
    
    private func sendSupportEmail() {
        var emailBody = message
        
        if includeSystemInfo {
            emailBody += "\n\n---\nSystem Information:\n"
            emailBody += "macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
            emailBody += "App Version: \(AppConstants.appVersion)\n"
        }
        
        #if os(macOS)
        let service = NSSharingService(named: NSSharingService.Name.composeEmail)
        service?.recipients = ["support@calendarnotes.app"]
        service?.subject = subject
        #else
        // For iOS, we'll use a different approach
        #endif
        
        // In a real app, you would use the sharing service or open mail.app
        print("Support email: \(subject)\n\(emailBody)")
    }
}

#Preview {
    SettingsView()
}


