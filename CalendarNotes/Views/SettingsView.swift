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
    @ObservedObject private var syncPolicyStore = SyncPolicyStore.shared
    @StateObject private var authManager = AuthManager.shared
    @EnvironmentObject private var syncManager: SyncManager
    @Environment(\.colorScheme) var systemColorScheme
    @State private var showingSignIn = false
    
    @State private var showingDeepLinkDocs = false
    @State private var offlineStorageSizeMB: Double = Double(OfflineDownloadManager.shared.totalOfflineSize()) / 1_048_576.0
    @State private var autoDeleteOfflineAfter30Days: Bool = UserDefaults.standard.bool(forKey: "offlineAutoDeleteAfter30Days")
    @State private var showingEncryptionSheet = false
    @State private var encryptionPassword = ""
    @State private var encryptionConfirmPassword = ""
    @State private var encryptionHint = ""
    @State private var showingManualBackupSheet = false
    @State private var manualBackupPassword = ""
    @State private var pendingBackupAction: BackupAction?
    @State private var actionPasswordInput = ""
    @State private var selectedRestoreModeSheet: BackupRestoreMode = .merge
    @State private var exportedBackupURL: URL?
    @State private var showingExportShareSheet = false
    @State private var showingPreviewSheet = false
    @State private var previewManifestTitle = ""
    @State private var encryptionErrorMessage: String?
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
    @State private var showingBookmarkImportSheet = false
    @State private var showingBookmarkExportSheet = false
    @State private var showingMaintenanceDashboard = false
    @State private var showingBookmarkResetConfirmation = false
    @State private var showingDeleteAllBookmarksAlert = false
    @State private var readingSettings = ReadingAppearanceSettings.current
    @StateObject private var voiceNoteStorageService = VoiceNoteStorageService.shared
    @StateObject private var voiceNoteCleanupService = VoiceNoteCleanupService.shared
    @State private var selectedQuota: VoiceNoteStorageService.StorageQuota = .small
    @State private var showingCleanupCandidates = false
    @State private var showingErrorTrackingDashboard = false
    
    private enum BackupAction: Identifiable {
        case restore(BackupManifest)
        case preview(BackupManifest)
        case exportJSON(BackupManifest)
        case exportHTML(BackupManifest)
        
        var id: String {
            switch self {
            case .restore(let manifest):
                return "restore-\(manifest.id)"
            case .preview(let manifest):
                return "preview-\(manifest.id)"
            case .exportJSON(let manifest):
                return "export-json-\(manifest.id)"
            case .exportHTML(let manifest):
                return "export-html-\(manifest.id)"
            }
        }
        
        var manifest: BackupManifest {
            switch self {
            case .restore(let manifest), .preview(let manifest), .exportJSON(let manifest), .exportHTML(let manifest):
                return manifest
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Header
                Text("Settings")
                    .font(.system(size: 34, weight: .bold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                
                // Content
                VStack(spacing: 16) {
                    // User Account Card
                    userAccountCard
                    
                    // Appearance Card
                    appearanceCard
                    
                    // Notifications Card
                    notificationsCard
                    
                    // Calendar Preferences Card
                    calendarPreferencesCard
                    
                    // Sign Out Button
                    signOutButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }
        }
        .background(windowBackgroundColor)
        .ignoresSafeArea(.all, edges: [.top, .bottom])
        .sheet(isPresented: $showingNotificationManagement) {
            NotificationManagementView()
                .presentationCornerRadius(20)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingDeepLinkDocs) {
            DeepLinkDocumentationView()
                .presentationCornerRadius(20)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingMaintenanceDashboard) {
            BookmarkMaintenanceDashboardView()
                .presentationCornerRadius(20)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingErrorTrackingDashboard) {
            ErrorTrackingDashboardView()
                .presentationCornerRadius(20)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: readingSettings) { _, newValue in
            newValue.persist()
        }
    }
    
    // MARK: - User Account Card
    
    private var userAccountCard: some View {
        VStack(spacing: 16) {
            // Avatar with initials
            ZStack {
                Circle()
                    .fill(DesignSystem.accentColor)
                    .frame(width: 60, height: 60)
                
                Text("SN")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            // Name and email
            VStack(spacing: 4) {
                Text(authManager.isAuthenticated ? (authManager.currentUser?.fullName ?? "Soham Naik") : "Soham Naik")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                
                Text(authManager.isAuthenticated ? (authManager.currentUser?.email ?? "naiksoham267@gmail.com") : "naiksoham267@gmail.com")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Color(white: 0.95))
        .cornerRadius(16)
    }
    
    // MARK: - Appearance Card
    
    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                    .font(.system(size: 16))
                Text("Appearance")
                    .font(.system(size: 17, weight: .semibold))
            }
            
            // Theme selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Theme")
                    .font(.system(size: 15))
                
                Picker("Theme", selection: Binding(
                    get: { themeManager.currentAppearanceMode },
                    set: { themeManager.setAppearanceMode($0) }
                )) {
                    Text("Light").tag(AppearanceMode.light)
                    Text("Dark").tag(AppearanceMode.dark)
                    Text("System").tag(AppearanceMode.system)
                }
                .pickerStyle(.segmented)
            }
            
            // Accent color selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Accent Color")
                    .font(.system(size: 15))
                
                HStack(spacing: 12) {
                    accentColorSwatch(color: Color(red: 0.67, green: 0.49, blue: 0.92), isSelected: true)
                    accentColorSwatch(color: .green, isSelected: false)
                    accentColorSwatch(color: .pink, isSelected: false)
                    accentColorSwatch(color: .orange, isSelected: false)
                    accentColorSwatch(color: Color(red: 0.9, green: 0.6, blue: 0.9), isSelected: false)
                }
            }
            
            // Compact view toggle
            HStack {
                Text("Compact View")
                    .font(.system(size: 15))
                Spacer()
                Toggle("", isOn: $viewModel.compactViewMode)
                    .labelsHidden()
            }
        }
        .padding(20)
        .background(Color(white: 0.95))
        .cornerRadius(16)
    }
    
    private func accentColorSwatch(color: Color, isSelected: Bool) -> some View {
        Circle()
            .fill(color)
            .frame(width: 40, height: 40)
            .overlay(
                Circle()
                    .stroke(isSelected ? Color.white : Color.clear, lineWidth: 3)
            )
            .overlay(
                Circle()
                    .stroke(Color.black.opacity(0.1), lineWidth: 1)
            )
    }
    
    // MARK: - Notifications Card
    
    private var notificationsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "bell.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 16))
                Text("Notifications")
                    .font(.system(size: 17, weight: .semibold))
            }
            
            // Event Reminders
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Event Reminders")
                            .font(.system(size: 15))
                        Text("Get notified before events")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $viewModel.eventRemindersEnabled)
                        .labelsHidden()
                }
            }
            
            // Task Reminders
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Task Reminders")
                            .font(.system(size: 15))
                        Text("Get notified about due tasks")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Toggle("", isOn: $viewModel.taskRemindersEnabled)
                        .labelsHidden()
                }
            }
        }
        .padding(20)
        .background(Color(white: 0.95))
        .cornerRadius(16)
    }
    
    // MARK: - Calendar Preferences Card
    
    private var calendarPreferencesCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "calendar")
                    .foregroundColor(.yellow)
                    .font(.system(size: 16))
                Text("Calendar Preferences")
                    .font(.system(size: 17, weight: .semibold))
            }
            
            // Default View
            VStack(alignment: .leading, spacing: 8) {
                Text("Default View")
                    .font(.system(size: 15))
                
                Picker("Default View", selection: $viewModel.defaultCalendarView) {
                    ForEach(DefaultCalendarView.allCases, id: \.rawValue) { view in
                        Text(view.rawValue).tag(view.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
            
            // First Day of Week
            VStack(alignment: .leading, spacing: 8) {
                Text("First Day of Week")
                    .font(.system(size: 15))
                
                Picker("First Day of Week", selection: $viewModel.firstDayOfWeek) {
                    ForEach(FirstDayOfWeek.allCases, id: \.rawValue) { day in
                        Text(day.displayName).tag(day.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }
        }
        .padding(20)
        .background(Color(white: 0.95))
        .cornerRadius(16)
    }
    
    // MARK: - Sign Out Button
    
    private var signOutButton: some View {
        Button(action: {
            if authManager.isAuthenticated {
                Task {
                    await authManager.logout()
                }
            } else {
                showingSignIn = true
            }
        }) {
            Text(authManager.isAuthenticated ? "Sign Out" : "Sign In")
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(.red)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.clear)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingSignIn) {
            AuthenticationView()
        }
    }
    
    #if os(iOS)
    // MARK: - Orientation Section
    
    private var orientationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "iphone.landscape")
                    .foregroundColor(.accentColor)
                Text("Orientation")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Preferred orientation")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Menu(viewModel.orientationPreference.displayName) {
                    ForEach(OrientationPreference.allCases, id: \.self) { pref in
                        Button(pref.displayName) {
                            viewModel.orientationPreference = pref
                        }
                    }
                }
            }
        }
        .padding()
        .background(controlBackgroundColor)
        .cornerRadius(16)
    }
    #endif
    
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
    
    private var readingModeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "text.book.closed.fill")
                    .foregroundColor(.accentColor)
                Text("Reading Mode")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Font family")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("Font", selection: $readingSettings.fontFamily) {
                        ForEach(ReadingAppearanceSettings.FontFamily.allCases) { family in
                            Text(family.displayName).tag(family)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 260)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Slider(value: $readingSettings.fontSize, in: 14...28, step: 1) {
                        Text("Font size")
                    }
                    HStack {
                        Text("Font size")
                        Spacer()
                        Text("\(Int(readingSettings.fontSize)) pt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Slider(value: $readingSettings.lineHeight, in: 1.2...2.0, step: 0.05) {
                        Text("Line spacing")
                    }
                    HStack {
                        Text("Line spacing")
                        Spacer()
                        Text(String(format: "%.2f", readingSettings.lineHeight))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                HStack {
                    Text("Alignment")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("Alignment", selection: $readingSettings.alignment) {
                        ForEach(ReadingAppearanceSettings.TextAlignmentOption.allCases) { alignment in
                            Text(alignment.displayName).tag(alignment)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
                HStack {
                    Text("Theme")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("Theme", selection: $readingSettings.theme) {
                        ForEach(ReadingAppearanceSettings.Theme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 300)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Slider(value: $readingSettings.margin, in: 10...60, step: 2) {
                        Text("Margins")
                    }
                    HStack {
                        Text("Margins")
                        Spacer()
                        Text("\(Int(readingSettings.margin)) pt")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: readingSettings.margin * 0.6) {
                    Text("Preview")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    VStack(alignment: .leading, spacing: readingSettings.margin * 0.8) {
                        Text("Every great reading session starts with the right ambiance.")
                            .font(readingSettings.headingFont())
                            .multilineTextAlignment(readingSettings.alignment.textAlignment)
                        Text("Tune the typography, spacing, and colors to make the Read Later experience fit your style—whether you're skimming a quick brief or diving into a longform article.")
                            .font(readingSettings.bodyFont())
                            .lineSpacing(readingSettings.lineHeight * 2)
                            .multilineTextAlignment(readingSettings.alignment.textAlignment)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(readingSettings.theme.backgroundColor)
                    .foregroundColor(readingSettings.theme.foregroundColor)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.accentColor.opacity(0.1))
                    )
                }
                Button("Reset to defaults") {
                    readingSettings = ReadingAppearanceSettings(
                        fontFamily: .serif,
                        fontSize: 17,
                        lineHeight: 1.4,
                        theme: .day,
                        margin: 20,
                        alignment: .leading
                    )
                }
                #if os(macOS)
                .buttonStyle(.link)
                #else
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                #endif
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
                        .onChange(of: viewModel.iCloudSyncEnabled) { _, isEnabled in
                            if isEnabled {
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
    
    @ViewBuilder
    private var offlineSyncSection: some View {
        let policy = syncPolicyStore.policy
        let downloadManager = OfflineDownloadManager.shared
        let (isSyncing, syncProgress): (Bool, Double?) = {
            switch syncManager.state {
            case .syncing(let progress):
                return (true, progress)
            default:
                return (false, nil)
            }
        }()
        
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.horizontal.circle.fill")
                    .foregroundColor(.accentColor)
                Text("Offline & Sync")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Connection", systemImage: "wifi")
                            .foregroundColor(syncManager.connectionQuality.tintColor)
                        Spacer()
                        Text(syncManager.connectionQuality.displayName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Label("Last Sync", systemImage: "clock.arrow.circlepath")
                        Spacer()
                        if let last = syncManager.statistics.lastSuccessfulSync {
                            Text(last.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Never")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Label("Pending Changes", systemImage: "tray.full")
                        Spacer()
                        Text("\(syncManager.pendingChanges)")
                            .font(.subheadline)
                            .foregroundColor(syncManager.pendingChanges > 0 ? .cnStatusWarning : .secondary)
                    }
                    
                    if let progress = syncProgress {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                    }
                    
                    HStack {
                        Button {
                            syncManager.triggerManualSync()
                        } label: {
                            Label(isSyncing ? "Syncing…" : "Sync Now", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSyncing)
                        
                        if case .failed(let error) = syncManager.state {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.cnStatusError)
                        }
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: Binding(
                        get: { policy.wifiOnly },
                        set: { newValue in
                            syncPolicyStore.update { policy in
                                policy.wifiOnly = newValue
                            }
                        }
                    )) {
                        VStack(alignment: .leading) {
                            Text("Sync on Wi-Fi Only")
                                .fontWeight(.medium)
                            Text("Avoid cellular data usage by waiting for Wi-Fi.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle(isOn: Binding(
                        get: { policy.lowDataMode },
                        set: { newValue in
                            syncPolicyStore.update { policy in
                                policy.lowDataMode = newValue
                            }
                        }
                    )) {
                        VStack(alignment: .leading) {
                            Text("Low Data Mode")
                                .fontWeight(.medium)
                            Text("Sync metadata only and defer image downloads.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Toggle(isOn: Binding(
                        get: { policy.backgroundSyncEnabled },
                        set: { newValue in
                            syncPolicyStore.update { policy in
                                policy.backgroundSyncEnabled = newValue
                            }
                        }
                    )) {
                        VStack(alignment: .leading) {
                            Text("Background Sync")
                                .fontWeight(.medium)
                            Text("Allow CalendarNotes to refresh content in the background.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Sync Frequency")
                            .fontWeight(.medium)
                        Spacer()
                        Picker("Frequency", selection: Binding(
                            get: { policy.frequency },
                            set: { newValue in
                                syncPolicyStore.update { policy in
                                    policy.frequency = newValue
                                }
                            }
                        )) {
                            ForEach(SyncPolicy.Frequency.allCases, id: \.self) { frequency in
                                Text(frequency.rawValue.capitalized)
                                    .tag(frequency)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Offline Downloads", systemImage: "internaldrive")
                        Spacer()
                        Text(String(format: "%.1f MB", offlineStorageSizeMB))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Button("Trim to 250 MB") {
                            downloadManager.manageStorage(maximumSize: 250 * 1_048_576)
                            refreshOfflineStorageSize()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Clear Downloads") {
                            downloadManager.removeOldDownloads(keeping: 0)
                            refreshOfflineStorageSize()
                        }
                        .buttonStyle(.bordered)
                        .tint(.cnStatusError)
                    }
                    
                    Toggle("Auto-delete after 30 days", isOn: $autoDeleteOfflineAfter30Days)
                        .onChange(of: autoDeleteOfflineAfter30Days) { _, isEnabled in
                            UserDefaults.standard.set(isEnabled, forKey: "offlineAutoDeleteAfter30Days")
                            if isEnabled {
                                downloadManager.removeOldDownloads(keeping: 500 * 1_048_576)
                                refreshOfflineStorageSize()
                            }
                        }
                }
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
            .onAppear {
                refreshOfflineStorageSize()
            }
        }
    }

    // MARK: - iCloud & Backup Section
    
    private var iCloudBackupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "internaldrive.fill")
                    .foregroundColor(.accentColor)
                Text("Backups")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            VStack(alignment: .leading, spacing: 20) {
                Toggle(isOn: Binding(
                    get: { viewModel.backupStatusState.autoBackupEnabled },
                    set: { viewModel.setAutoBackupEnabled($0) }
                )) {
                    Text("Enable Daily Automatic Backups")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Storage Preference")
                            .font(.subheadline)
                        Text(viewModel.backupOptionsState.storagePreference.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Menu {
                        ForEach(BackupStoragePreference.allCases, id: \.self) { preference in
                            Button(preference.rawValue.capitalized) {
                                viewModel.setStoragePreference(preference)
                            }
                        }
                    } label: {
                        Label("Location", systemImage: "folder")
                    }
                }
                
                Toggle("Incremental Backups", isOn: Binding(
                    get: { viewModel.backupOptionsState.incremental },
                    set: { viewModel.setIncrementalBackup($0) }
                ))
                .font(.subheadline)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("Included Content")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    VStack(alignment: .leading, spacing: 8) {
                        backupContentToggle(title: "Metadata", option: .metadata)
                        backupContentToggle(title: "Preview Images", option: .previewImages)
                        backupContentToggle(title: "User Notes", option: .userNotes)
                        backupContentToggle(title: "Collections", option: .collections)
                        backupContentToggle(title: "Tags", option: .tags)
                        backupContentToggle(title: "Highlights", option: .highlights)
                    }
                    .padding(12)
                    .background(controlBackgroundColor)
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(isOn: Binding(
                        get: { viewModel.backupOptionsState.encryptWithPassword },
                        set: { enabled in
                            if enabled {
                                encryptionPassword = ""
                                encryptionConfirmPassword = ""
                                encryptionHint = viewModel.backupPasswordHint ?? ""
                                showingEncryptionSheet = true
                            } else {
                                viewModel.configureEncryption(enable: false, password: nil, hint: nil)
                            }
                        }
                    )) {
                        Text("Encrypt Backups")
                            .font(.subheadline)
                    }
                    if let hint = viewModel.backupPasswordHint, !hint.isEmpty {
                        Text("Password hint: \(hint)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Button {
                            manualBackupPassword = ""
                            if viewModel.backupOptionsState.encryptWithPassword && !viewModel.hasStoredBackupPassword {
                                showingManualBackupSheet = true
                            } else {
                                viewModel.runManualBackup(password: nil)
                            }
                        } label: {
                            Label(viewModel.isBackupRunningState ? "Backing up…" : "Backup Now", systemImage: "arrow.down.doc")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(viewModel.isBackupRunningState)
                        
                        Button {
                            viewModel.calculateBackupSizeEstimate()
                        } label: {
                            Label("Estimate Size", systemImage: "scalemass")
                        }
                        .buttonStyle(.bordered)
                        .disabled(viewModel.isCalculatingBackupSize)
                    }
                    if viewModel.isCalculatingBackupSize {
                        ProgressView().progressViewStyle(.linear)
                    }
                    if viewModel.calculatedBackupSize > 0 {
                        Text("Estimated size: \(formattedSize(viewModel.calculatedBackupSize))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    if let error = viewModel.backupErrorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                
                VStack(alignment: .leading, spacing: 6) {
                    Text("Backup Status")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Last backup: \(lastBackupDescription)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Stored backups: \(viewModel.backupHistory.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    if let auto = viewModel.backupStatusState.lastAutomaticBackup {
                        Text("Last automatic backup: \(formatDate(auto))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Backup History")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    if viewModel.backupHistory.isEmpty {
                        Text("No backups created yet.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.backupHistory) { manifest in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(backupTitle(for: manifest))
                                            .font(.body)
                                        Text("Size: \(formattedSize(manifest.size)) • \(manifest.type.rawValue.capitalized) • \(manifest.storageLocation == .local ? "Local" : "iCloud")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Menu {
                                        Button("Preview") {
                                            if manifest.encrypted && !viewModel.hasStoredBackupPassword {
                                                // Show password sheet
                                                pendingBackupAction = .preview(manifest)
                                                previewManifestTitle = backupTitle(for: manifest)
                                                actionPasswordInput = ""
                                            } else {
                                                // Go directly to preview
                                                previewManifestTitle = backupTitle(for: manifest)
                                                showingPreviewSheet = true
                                                viewModel.backupPreviewSummary = nil
                                                viewModel.isBackupPreviewLoading = true
                                                Task {
                                                    await viewModel.previewBackup(manifest: manifest, password: nil)
                                                }
                                            }
                                        }
                                        Button("Restore") {
                                            pendingBackupAction = .restore(manifest)
                                            selectedRestoreModeSheet = .merge
                                            actionPasswordInput = ""
                                        }
                                        Button("Export JSON") {
                                            if manifest.encrypted && !viewModel.hasStoredBackupPassword {
                                                // Show password sheet
                                                pendingBackupAction = .exportJSON(manifest)
                                                actionPasswordInput = ""
                                            } else {
                                                // Export directly
                                                Task {
                                                    if let url = await viewModel.exportBackup(manifest: manifest, format: .json, password: nil) {
                                                        exportedBackupURL = url
                                                        #if os(iOS)
                                                        showingExportShareSheet = true
                                                        #endif
                                                    }
                                                }
                                            }
                                        }
                                        Button("Export HTML") {
                                            if manifest.encrypted && !viewModel.hasStoredBackupPassword {
                                                // Show password sheet
                                                pendingBackupAction = .exportHTML(manifest)
                                                actionPasswordInput = ""
                                            } else {
                                                // Export directly
                                                Task {
                                                    if let url = await viewModel.exportBackup(manifest: manifest, format: .html, password: nil) {
                                                        exportedBackupURL = url
                                                        #if os(iOS)
                                                        showingExportShareSheet = true
                                                        #endif
                                                    }
                                                }
                                            }
                                        }
                                        Divider()
                                        Button(role: .destructive) {
                                            viewModel.deleteBackup(manifest: manifest)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .font(.title3)
                                    }
                                }
                            }
                            .padding(12)
                            .background(controlBackgroundColor)
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
        .sheet(isPresented: $showingEncryptionSheet) {
            encryptionSheet
                .presentationCornerRadius(20)
        }
        .sheet(isPresented: $showingManualBackupSheet) {
            manualBackupSheet
                .presentationCornerRadius(20)
        }
        .sheet(item: $pendingBackupAction) { action in
            backupActionSheet(for: action)
                .presentationCornerRadius(20)
        }
        .sheet(isPresented: $showingPreviewSheet) {
            backupPreviewSheet
                .presentationCornerRadius(20)
        }
        #if os(iOS)
        .sheet(isPresented: $showingExportShareSheet) {
            if let url = exportedBackupURL {
                ShareSheet(activityItems: [url])
            }
        }
        #else
        .onChange(of: exportedBackupURL) { _, url in
            guard let url else { return }
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
        #endif
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
                            .onChange(of: viewModel.eventKitSyncEnabled) { _, _ in
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

                Button(action: { showingDeepLinkDocs = true }) {
                    Label("Deep Link API", systemImage: "link")
                }
                .buttonStyle(.borderedProminent)
                
                #if DEBUG
                Divider()
                    .padding(.vertical, 8)
                
                Button(action: { showingErrorTrackingDashboard = true }) {
                    Label("Error Tracking Dashboard", systemImage: "exclamationmark.triangle")
                }
                .buttonStyle(.bordered)
                #endif
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
    

    private var bookmarkSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "bookmark.fill")
                    .foregroundColor(.accentColor)
                Text("Bookmark Settings")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Default collection")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("Default collection", selection: $viewModel.bookmarkDefaultCollection) {
                        Text("None").tag("")
                        ForEach(viewModel.bookmarkCollections, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }

                Toggle("Auto-fetch metadata", isOn: $viewModel.bookmarkAutoFetchMetadata)

                HStack {
                    Text("Auto-download preview images")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("Auto-download preview images", selection: Binding(
                        get: { viewModel.bookmarkPreviewDownloadMode },
                        set: { viewModel.bookmarkPreviewDownloadMode = $0 }
                    )) {
                        ForEach(BookmarkPreviewDownloadMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }

                HStack {
                    Text("Keep preview images for")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("Keep preview images for", selection: Binding(
                        get: { viewModel.bookmarkPreviewRetention },
                        set: { newValue in
                            viewModel.bookmarkPreviewRetention = newValue
                            viewModel.applyPreviewRetentionPolicy()
                        }
                    )) {
                        ForEach(BookmarkPreviewRetentionPolicy.allCases, id: \.rawValue) { policy in
                            Text(policy.displayName).tag(policy)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }

                HStack {
                    Text("Default view")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("Default view", selection: Binding(
                        get: { viewModel.bookmarkDefaultView },
                        set: { viewModel.bookmarkDefaultView = $0 }
                    )) {
                        Text("Grid").tag(BookmarksViewModel.LayoutMode.grid)
                        Text("List").tag(BookmarksViewModel.LayoutMode.list)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }

                HStack {
                    Text("Grid columns")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("Grid columns", selection: Binding(
                        get: { max(2, min(viewModel.bookmarkGridColumns, 4)) },
                        set: { viewModel.bookmarkGridColumns = max(2, min($0, 4)) }
                    )) {
                        ForEach([2, 3, 4], id: \.self) { count in
                            Text("\(count)").tag(count)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                    .disabled(viewModel.bookmarkDefaultView != .grid)
                }

                HStack {
                    Text("Sort order default")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("Sort order", selection: Binding(
                        get: { viewModel.bookmarkSortOrder },
                        set: { viewModel.bookmarkSortOrder = $0 }
                    )) {
                        ForEach(BookmarksViewModel.Sort.allCases, id: \.self) { sort in
                            Text(sort.rawValue.capitalized).tag(sort)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }

                HStack {
                    Text("Open links in")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("Open links in", selection: Binding(
                        get: { viewModel.bookmarkOpenMode },
                        set: { viewModel.bookmarkOpenMode = $0 }
                    )) {
                        ForEach(BookmarkOpenMode.allCases, id: \.self) { mode in
                            Text(mode.displayName).tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Swipe actions")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    ForEach(BookmarkSwipeAction.allCases, id: \.self) { action in
                        Toggle(action.label, isOn: Binding(
                            get: { viewModel.bookmarkSwipeActions.contains(action) },
                            set: { viewModel.setSwipeAction(action, enabled: $0) }
                        ))
                    }
                }

                Toggle("Duplicate detection", isOn: $viewModel.bookmarkDuplicateDetection)
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
        .alert("Reset Bookmark Settings", isPresented: $showingBookmarkResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                viewModel.resetBookmarkSettings()
            }
        } message: {
            Text("Restore all bookmark preferences to their defaults? This will not delete saved bookmarks.")
        }
        .alert("Delete All Bookmarks", isPresented: $showingDeleteAllBookmarksAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.deleteAllBookmarks()
            }
        } message: {
            Text("This will permanently remove every bookmark and cached preview. This action cannot be undone.")
        }
    }

    private var bookmarkPrivacySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.accentColor)
                Text("Bookmark Privacy")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    viewModel.clearBookmarkBrowsingHistory()
                } label: {
                    Label("Clear browsing history", systemImage: "clock.arrow.circlepath")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isBookmarkMaintenanceRunning)

                Button {
                    viewModel.clearCachedBookmarkImages()
                } label: {
                    Label("Clear cached images", systemImage: "photo")
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isBookmarkMaintenanceRunning)

                Button {
                    viewModel.clearBookmarkSearchHistory()
                } label: {
                    Label("Clear search history", systemImage: "magnifyingglass.circle")
                }
                .buttonStyle(.bordered)

                Toggle("Private collections require Face ID / Touch ID", isOn: $viewModel.bookmarkRequireBiometric)

                if viewModel.isBookmarkMaintenanceRunning {
                    ProgressView()
                        .progressViewStyle(.linear)
                }

                if !viewModel.bookmarkActionMessage.isEmpty {
                    Text(viewModel.bookmarkActionMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        showingMaintenanceDashboard = true
                    } label: {
                        Label("Open Maintenance Dashboard", systemImage: "wrench.and.screwdriver")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isBookmarkMaintenanceRunning)

                    Button {
                        viewModel.clearBookmarkBrowsingHistory()
                    } label: {
                        Label("Clear browsing history", systemImage: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isBookmarkMaintenanceRunning)

                    Button {
                        viewModel.clearCachedBookmarkImages()
                    } label: {
                        Label("Clear cached images", systemImage: "photo")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isBookmarkMaintenanceRunning)

                    Button {
                        viewModel.clearBookmarkSearchHistory()
                    } label: {
                        Label("Clear search history", systemImage: "magnifyingglass.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isBookmarkMaintenanceRunning)
                }
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
    }

    private var bookmarkImportExportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .foregroundColor(.accentColor)
                Text("Bookmark Import & Export")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            VStack(alignment: .leading, spacing: 16) {
                Toggle("Quick access to import", isOn: $viewModel.bookmarkQuickImportShortcut)
                Toggle("Quick access to export", isOn: $viewModel.bookmarkQuickExportShortcut)

                HStack(spacing: 12) {
                    Button {
                        showingBookmarkImportSheet = true
                    } label: {
                        Label("Open Import", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        showingBookmarkExportSheet = true
                    } label: {
                        Label("Open Export", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }

                Divider()

                HStack {
                    Text("Default import format")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("Default import format", selection: Binding(
                        get: { viewModel.bookmarkDefaultImportFormat },
                        set: { viewModel.bookmarkDefaultImportFormat = $0 }
                    )) {
                        ForEach(BookmarkDataFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }

                HStack {
                    Text("Default export format")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Picker("Default export format", selection: Binding(
                        get: { viewModel.bookmarkDefaultExportFormat },
                        set: { viewModel.bookmarkDefaultExportFormat = $0 }
                    )) {
                        ForEach(BookmarkDataFormat.allCases, id: \.self) { format in
                            Text(format.displayName).tag(format)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 200)
                }
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
    }

    private var bookmarkStorageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "tray.full")
                    .foregroundColor(.accentColor)
                Text("Bookmark Storage")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            VStack(alignment: .leading, spacing: 12) {
                storageRow(title: "Total bookmarks", value: "\(viewModel.bookmarkCount)")
                storageRow(title: "Storage used by bookmarks", value: formattedBytes(viewModel.bookmarkStorageBytes))
                storageRow(title: "Storage used by images", value: formattedBytes(viewModel.bookmarkImageCacheBytes))
                storageRow(title: "Metadata cache", value: formattedBytes(viewModel.bookmarkMetadataCacheBytes))

                HStack(spacing: 12) {
                    Button {
                        viewModel.refreshBookmarkStats()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)

                    Button {
                        viewModel.clearCachedBookmarkImages()
                    } label: {
                        Label("Clear cache", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isBookmarkMaintenanceRunning)
                }

                Button(role: .destructive) {
                    viewModel.deleteArchivedBookmarks()
                } label: {
                    Label("Delete archived bookmarks", systemImage: "archivebox")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isBookmarkMaintenanceRunning)
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
    }

    private var bookmarkAdvancedSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "gearshape.2.fill")
                    .foregroundColor(.accentColor)
                Text("Bookmark Advanced")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            VStack(alignment: .leading, spacing: 12) {
                Toggle("Enable experimental features", isOn: $viewModel.bookmarkExperimentalFeatures)
                Toggle("Debug mode", isOn: $viewModel.bookmarkDebugMode)

                Button {
                    showingBookmarkResetConfirmation = true
                } label: {
                    Label("Reset all bookmark settings", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    showingDeleteAllBookmarksAlert = true
                } label: {
                    Label("Delete all bookmarks", systemImage: "trash.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isBookmarkMaintenanceRunning)
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
    }

    private func storageRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private func formattedBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Voice Notes Storage Section
    
    // MARK: - Voice Notes Settings Section
    
    private var voiceNotesSettingsSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // Section Header
            HStack(spacing: 8) {
                Image(systemName: "mic.fill")
                    .foregroundColor(.accentColor)
                Text("Voice Notes")
                    .font(.title2)
                    .fontWeight(.semibold)
            }
            
            // Voice Notes General Settings
            voiceNotesGeneralSettings
            
            // Storage Settings
            voiceNotesStorageSettings
            
            // Playback Settings
            voiceNotesPlaybackSettings
            
            // Recording Settings
            voiceNotesRecordingSettings
            
            // Transcription Settings
            voiceNotesTranscriptionSettings
            
            // Privacy Settings
            voiceNotesPrivacySettings
            
            // Sync Settings
            voiceNotesSyncSettings
            
            // Permissions
            voiceNotesPermissionsSettings
        }
        .onAppear {
            viewModel.refreshVoiceNotesStats()
        }
    }
    
    // MARK: - Voice Notes General Settings
    
    private var voiceNotesGeneralSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("General")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                // Recording Quality
                VStack(alignment: .leading, spacing: 8) {
                    Text("Recording Quality")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Recording Quality", selection: Binding(
                        get: { viewModel.recordingQuality },
                        set: { viewModel.recordingQuality = $0 }
                    )) {
                        ForEach(SettingsViewModel.RecordingQuality.allCases, id: \.self) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Divider()
                
                // Auto-transcribe
                Toggle("Auto-transcribe", isOn: $viewModel.autoTranscribe)
                
                // Transcription Language
                if viewModel.autoTranscribe {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Transcription Language")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        #if os(iOS)
                        Picker("Language", selection: $viewModel.transcriptionLanguage) {
                            ForEach(VoiceTranscriptionService.shared.getAvailableLanguages(), id: \.identifier) { locale in
                                Text(locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier)
                                    .tag(locale.identifier)
                            }
                        }
                        #else
                        TextField("Language Code", text: $viewModel.transcriptionLanguage)
                            .textFieldStyle(.roundedBorder)
                        #endif
                    }
                }
                
                Divider()
                
                // Keep recordings after transcription
                Toggle("Keep recordings after transcription", isOn: $viewModel.keepRecordingsAfterTranscription)
                
                // Auto-delete after
                VStack(alignment: .leading, spacing: 8) {
                    Text("Auto-delete after")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Auto-delete", selection: $viewModel.autoDeleteAfter) {
                        Text("Never").tag("never")
                        Text("7 days").tag("7")
                        Text("30 days").tag("30")
                        Text("90 days").tag("90")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Voice Notes Storage Settings
    
    private var voiceNotesStorageSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Storage")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                // Storage Usage Display
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Total Storage Used")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: viewModel.voiceNotesTotalStorageUsed, countStyle: .file))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Available Storage")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: viewModel.voiceNotesAvailableStorage, countStyle: .file))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Number of Voice Notes")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text("\(viewModel.voiceNotesCount)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Optimize Storage Button
                Button {
                    Task {
                        await viewModel.optimizeStorage()
                    }
                } label: {
                    HStack {
                        if viewModel.isOptimizingStorage {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text(viewModel.isOptimizingStorage ? "Optimizing..." : "Optimize Storage")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isOptimizingStorage)
                
                Divider()
                
                // Delete All Voice Notes
                Button(role: .destructive) {
                    viewModel.showingDeleteAllVoiceNotesAlert = true
                } label: {
                    Label("Delete All Voice Notes", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
        .alert("Delete All Voice Notes", isPresented: $viewModel.showingDeleteAllVoiceNotesAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteAllVoiceNotes()
                }
            }
        } message: {
            Text("This will permanently delete all voice notes. This action cannot be undone.")
        }
    }
    
    // MARK: - Voice Notes Playback Settings
    
    private var voiceNotesPlaybackSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Playback")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                // Default Playback Speed
                VStack(alignment: .leading, spacing: 8) {
                    Text("Default Playback Speed")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Playback Speed", selection: Binding(
                        get: { viewModel.defaultPlaybackSpeed },
                        set: { viewModel.defaultPlaybackSpeed = $0 }
                    )) {
                        ForEach(SettingsViewModel.PlaybackSpeed.allCases, id: \.self) { speed in
                            Text(speed.displayName).tag(speed)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Divider()
                
                // Skip Interval
                VStack(alignment: .leading, spacing: 8) {
                    Text("Skip Interval")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Skip Interval", selection: $viewModel.skipInterval) {
                        Text("5 seconds").tag(5)
                        Text("10 seconds").tag(10)
                        Text("15 seconds").tag(15)
                        Text("30 seconds").tag(30)
                    }
                    .pickerStyle(.segmented)
                }
                
                Divider()
                
                // Continue playback in background
                Toggle("Continue playback in background", isOn: $viewModel.continuePlaybackInBackground)
                
                // Show in lock screen
                Toggle("Show in lock screen", isOn: $viewModel.showInLockScreen)
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Voice Notes Recording Settings
    
    private var voiceNotesRecordingSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recording")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                // Countdown before recording
                VStack(alignment: .leading, spacing: 8) {
                    Text("Countdown before recording")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Countdown", selection: $viewModel.countdownBeforeRecording) {
                        Text("0 seconds").tag(0)
                        Text("3 seconds").tag(3)
                        Text("5 seconds").tag(5)
                    }
                    .pickerStyle(.segmented)
                }
                
                Divider()
                
                // Max recording duration
                VStack(alignment: .leading, spacing: 8) {
                    Text("Max Recording Duration")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Max Duration", selection: $viewModel.maxRecordingDuration) {
                        Text("No limit").tag("noLimit")
                        Text("5 minutes").tag("5")
                        Text("10 minutes").tag("10")
                        Text("30 minutes").tag("30")
                    }
                    .pickerStyle(.segmented)
                }
                
                Divider()
                
                // Pause recording on interruption
                Toggle("Pause recording on interruption", isOn: $viewModel.pauseRecordingOnInterruption)
                
                // Save automatically on interruption
                Toggle("Save automatically on interruption", isOn: $viewModel.saveAutomaticallyOnInterruption)
                
                Divider()
                
                // Haptic feedback
                Toggle("Haptic feedback on start/stop", isOn: $viewModel.hapticFeedbackOnStartStop)
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Voice Notes Transcription Settings
    
    private var voiceNotesTranscriptionSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Transcription")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                // Transcription Quality
                VStack(alignment: .leading, spacing: 8) {
                    Text("Transcription Quality")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Picker("Quality", selection: Binding(
                        get: { viewModel.transcriptionQuality },
                        set: { viewModel.transcriptionQuality = $0 }
                    )) {
                        ForEach(SettingsViewModel.TranscriptionQuality.allCases, id: \.self) { quality in
                            Text(quality.displayName).tag(quality)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                Divider()
                
                // Auto-detect language
                Toggle("Auto-detect language", isOn: $viewModel.autoDetectLanguage)
                
                // Manual language selection (shown when auto-detect is off)
                if !viewModel.autoDetectLanguage {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Manual Language Selection")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        #if os(iOS)
                        Picker("Language", selection: $viewModel.transcriptionLanguage) {
                            ForEach(VoiceTranscriptionService.shared.getAvailableLanguages(), id: \.identifier) { locale in
                                Text(locale.localizedString(forIdentifier: locale.identifier) ?? locale.identifier)
                                    .tag(locale.identifier)
                            }
                        }
                        #else
                        TextField("Language Code", text: $viewModel.transcriptionLanguage)
                            .textFieldStyle(.roundedBorder)
                        #endif
                    }
                }
                
                Divider()
                
                // Add punctuation automatically
                Toggle("Add punctuation automatically", isOn: $viewModel.addPunctuationAutomatically)
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Voice Notes Privacy Settings
    
    private var voiceNotesPrivacySettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Privacy")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                // On-device transcription only
                Toggle("On-device transcription only", isOn: $viewModel.onDeviceTranscriptionOnly)
                
                // Never upload voice notes
                Toggle("Never upload voice notes", isOn: $viewModel.neverUploadVoiceNotes)
                
                Divider()
                
                // Require Face ID/Touch ID to play
                Toggle("Require Face ID/Touch ID to play", isOn: $viewModel.requireBiometricToPlay)
                
                // Exclude from backups
                Toggle("Exclude voice notes from backups", isOn: $viewModel.excludeFromBackups)
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Voice Notes Sync Settings
    
    private var voiceNotesSyncSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Sync & Cloud Storage")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                // Auto-upload voice notes
                Toggle("Auto-upload voice notes", isOn: $viewModel.autoUploadVoiceNotes)
                    .disabled(viewModel.neverUploadVoiceNotes)
                
                if viewModel.autoUploadVoiceNotes && !viewModel.neverUploadVoiceNotes {
                    // WiFi-only uploads
                    Toggle("WiFi-only uploads", isOn: $viewModel.wifiOnlyUpload)
                    
                    // Compress before upload
                    Toggle("Compress before upload", isOn: $viewModel.compressBeforeUpload)
                    
                    // Delete local after upload
                    Toggle("Delete local file after upload", isOn: $viewModel.deleteLocalAfterUpload)
                }
                
                Divider()
                
                // Auto-download voice notes
                Toggle("Auto-download voice notes", isOn: $viewModel.autoDownloadVoiceNotes)
                
                // Keep local copies
                Toggle("Keep local copies", isOn: $viewModel.keepLocalCopies)
                
                if viewModel.keepLocalCopies {
                    // Cache size limit
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Cache size limit")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Picker("Cache Size", selection: $viewModel.cacheSizeLimit) {
                            Text("100 MB").tag(Int64(100 * 1024 * 1024))
                            Text("500 MB").tag(Int64(500 * 1024 * 1024))
                            Text("1 GB").tag(Int64(1024 * 1024 * 1024))
                            Text("2 GB").tag(Int64(2 * 1024 * 1024 * 1024))
                            Text("Unlimited").tag(Int64.max)
                        }
                        .pickerStyle(.menu)
                    }
                }
                
                Divider()
                
                // Sync transcriptions only
                Toggle("Sync transcriptions only (save bandwidth)", isOn: $viewModel.syncTranscriptionsOnly)
                
                // Max retry attempts
                VStack(alignment: .leading, spacing: 8) {
                    Text("Max retry attempts")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Stepper(value: $viewModel.maxRetryAttempts, in: 1...10) {
                        Text("\(viewModel.maxRetryAttempts)")
                    }
                }
            }
            .padding(20)
            .background(controlBackgroundColor)
            .cornerRadius(12)
        }
    }
    
    // MARK: - Voice Notes Permissions Settings
    
    private var voiceNotesPermissionsSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Permissions")
                .font(.headline)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 16) {
                // Microphone Permission
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Microphone Permission")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text(viewModel.getMicrophonePermissionStatus())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Button {
                        Task {
                            _ = await viewModel.requestMicrophonePermission()
                            viewModel.refreshVoiceNotesStats()
                        }
                    } label: {
                        Label("Re-request Permission", systemImage: "mic.fill")
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider()
                
                // Speech Recognition Permission
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Speech Recognition Permission")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Spacer()
                        Text(viewModel.getSpeechRecognitionPermissionStatus())
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Button {
                        Task {
                            do {
                                try await viewModel.requestSpeechRecognitionPermission()
                            } catch {
                                print("Failed to request speech recognition permission: \(error)")
                            }
                        }
                    } label: {
                        Label("Re-request Permission", systemImage: "waveform")
                    }
                    .buttonStyle(.bordered)
                }
                
                Divider()
                
                // Link to iOS Settings
                #if os(iOS)
                Button {
                    viewModel.openIOSSettings()
                } label: {
                    Label("Open iOS Settings", systemImage: "gear")
                }
                .buttonStyle(.bordered)
                #endif
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
    
    private var backupPreviewSheet: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "eye.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.accentColor)
                        .padding(.top, 20)
                    
                    Text("Backup Preview")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(previewManifestTitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 24)
                
                Divider()
                
                // Content
                ScrollView {
                    VStack(spacing: 20) {
                        if viewModel.isBackupPreviewLoading {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Loading backup…")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                        } else if let summary = viewModel.backupPreviewSummary {
                            // Metadata Card
                            if let metadata = summary.metadata {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack {
                                        Image(systemName: "info.circle.fill")
                                            .foregroundColor(.accentColor)
                                        Text("Backup Information")
                                            .font(.headline)
                                            .fontWeight(.semibold)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 12) {
                                        InfoRow(label: "Created", value: formatBackupDate(metadata.createdAt))
                                        InfoRow(label: "Device", value: metadata.deviceName)
                                        InfoRow(label: "App Version", value: metadata.appVersion.isEmpty ? "Unknown" : metadata.appVersion)
                                    }
                                }
                                .padding(20)
                                .background(controlBackgroundColor)
                                .cornerRadius(16)
                                .padding(.horizontal, 20)
                            }
                            
                            // Statistics Card
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "chart.bar.fill")
                                        .foregroundColor(.accentColor)
                                    Text("Backup Contents")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible()),
                                    GridItem(.flexible())
                                ], spacing: 16) {
                                    StatisticCard(title: "Bookmarks", value: summary.bookmarkCount, icon: "bookmark.fill")
                                    StatisticCard(title: "Collections", value: summary.collectionCount, icon: "folder.fill")
                                    StatisticCard(title: "Tags", value: summary.tagCount, icon: "tag.fill")
                                    StatisticCard(title: "Highlights", value: summary.highlightCount, icon: "highlighter")
                                }
                            }
                            .padding(20)
                            .background(controlBackgroundColor)
                            .cornerRadius(16)
                            .padding(.horizontal, 20)
                            
                            // Sample Bookmarks
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "book.fill")
                                        .foregroundColor(.accentColor)
                                    Text("Sample Bookmarks")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                
                                if summary.sampleBookmarks.isEmpty {
                                    HStack {
                                        Spacer()
                                        VStack(spacing: 8) {
                                            Image(systemName: "bookmark.slash")
                                                .font(.system(size: 32))
                                                .foregroundColor(.secondary)
                                            Text("No bookmarks in backup")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.vertical, 40)
                                } else {
                                    VStack(spacing: 12) {
                                        ForEach(summary.sampleBookmarks.prefix(10), id: \.id) { record in
                                            BookmarkPreviewRow(record: record)
                                        }
                                        
                                        if summary.sampleBookmarks.count > 10 {
                                            Text("... and \(summary.sampleBookmarks.count - 10) more")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .padding(.top, 8)
                                        }
                                    }
                                }
                            }
                            .padding(20)
                            .background(controlBackgroundColor)
                            .cornerRadius(16)
                            .padding(.horizontal, 20)
                            
                        } else if let error = viewModel.backupErrorMessage {
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.orange)
                                Text("Error Loading Backup")
                                    .font(.headline)
                                Text(error)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(40)
                            .frame(maxWidth: .infinity)
                        } else {
                            VStack(spacing: 16) {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 48))
                                    .foregroundColor(.secondary)
                                Text("No preview available")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                            }
                            .padding(40)
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding(.vertical, 24)
                }
                
                Divider()
                
                // Close Button
                Button("Done") {
                    showingPreviewSheet = false
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(20)
            }
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    EmptyView()
                }
            }
        }
        .presentationDetents([.large])
    }
    
    private func InfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    private func StatisticCard(title: String, value: Int, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
            Text("\(value)")
                .font(.title2)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(controlBackgroundColor.opacity(0.5))
        .cornerRadius(12)
    }
    
    private func BookmarkPreviewRow(record: BookmarkRecord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bookmark.fill")
                .foregroundColor(.accentColor)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(record.title ?? record.url ?? "Untitled")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if let url = record.url {
                    Text(url)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
        }
        .padding(12)
        .background(controlBackgroundColor.opacity(0.5))
        .cornerRadius(10)
    }
    
    private func summaryMetric(title: String, value: Int) -> some View {
        VStack {
            Text("\(value)")
                .font(.title3)
                .fontWeight(.bold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func backupContentToggle(title: String, option: BackupContentOptions) -> some View {
        Toggle(isOn: Binding(
            get: { viewModel.backupOptionsState.content.contains(option) },
            set: { viewModel.toggleContentOption(option, enabled: $0) }
        )) {
            Text(title)
                .font(.caption)
        }
    }
    
    private var lastBackupDescription: String {
        if let date = viewModel.backupStatusState.lastBackupDate {
            return formatDate(date)
        }
        return "Never"
    }
    
    private func formattedSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatBackupDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func backupTitle(for manifest: BackupManifest) -> String {
        "\(formatDate(manifest.createdAt)) – \(manifest.trigger == .manual ? "Manual" : "Automatic")"
    }
    
    private var encryptionSheet: some View {
        NavigationView {
            Form {
                Section("Password") {
                    SecureField("Password", text: $encryptionPassword)
                    SecureField("Confirm Password", text: $encryptionConfirmPassword)
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                Section("Hint") {
                    TextField("Optional hint", text: $encryptionHint)
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                if let error = encryptionErrorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            #if os(iOS)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            #else
            .background(Color(NSColor.controlBackgroundColor))
            #endif
            .navigationTitle("Encrypt Backups")
            .onAppear { encryptionErrorMessage = nil }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        showingEncryptionSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard !encryptionPassword.isEmpty else {
                            encryptionErrorMessage = "Password cannot be empty"
                            return
                        }
                        guard encryptionPassword == encryptionConfirmPassword else {
                            encryptionErrorMessage = "Passwords do not match"
                            return
                        }
                        viewModel.configureEncryption(enable: true,
                                                       password: encryptionPassword,
                                                       hint: encryptionHint.isEmpty ? nil : encryptionHint)
                        showingEncryptionSheet = false
                    }
                }
            }
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
    }
    
    private var manualBackupSheet: some View {
        NavigationView {
            Form {
                if viewModel.backupOptionsState.encryptWithPassword && !viewModel.hasStoredBackupPassword {
                    Section("Password") {
                        SecureField("Backup password", text: $manualBackupPassword)
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                } else {
                    Text("A manual backup will be created with the current settings.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            #if os(iOS)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            #else
            .background(Color(NSColor.controlBackgroundColor))
            #endif
            .navigationTitle("Backup Now")
            .onAppear { manualBackupPassword = "" }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingManualBackupSheet = false } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        let password = manualBackupPassword.isEmpty ? nil : manualBackupPassword
                        viewModel.runManualBackup(password: password)
                        showingManualBackupSheet = false
                    }
                }
            }
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
    }
    
    private func backupActionSheet(for action: BackupAction) -> some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with icon
                VStack(spacing: 16) {
                    Image(systemName: iconForAction(action))
                        .font(.system(size: 56))
                        .foregroundColor(.accentColor)
                        .padding(.top, 32)
                    
                    Text(sheetTitle(for: action))
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(descriptionForAction(action))
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .lineLimit(3)
                }
                .padding(.bottom, 32)
                
                Divider()
                
                // Content
                ScrollView {
                    VStack(spacing: 24) {
                        // Backup Info Card
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Image(systemName: "info.circle.fill")
                                    .foregroundColor(.accentColor)
                                Text("Backup Details")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(backupTitle(for: action.manifest))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                        Text("Created: \(formatBackupDate(action.manifest.createdAt))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                
                                Divider()
                                
                                HStack(spacing: 20) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Size")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(formattedSize(action.manifest.size))
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Type")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(action.manifest.type.rawValue.capitalized)
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Location")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(action.manifest.storageLocation == .local ? "Local" : "iCloud")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    
                                    Spacer()
                                }
                            }
                        }
                        .padding(20)
                        .background(controlBackgroundColor)
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        
                        // Password Section
                        if action.manifest.encrypted && !viewModel.hasStoredBackupPassword {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "lock.fill")
                                        .foregroundColor(.orange)
                                    Text("Password Required")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                
                                Text("This backup is encrypted. Please enter the password to continue.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                SecureField("Enter backup password", text: $actionPasswordInput)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                                    .submitLabel(.continue)
                            }
                            .padding(20)
                            .background(controlBackgroundColor)
                            .cornerRadius(16)
                            .padding(.horizontal, 20)
                        }
                        
                        // Restore Mode Picker (only for restore action)
                        if case .restore = action {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "arrow.triangle.merge")
                                        .foregroundColor(.accentColor)
                                    Text("Restore Mode")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                
                                Text("Choose how to handle conflicts with existing data")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Picker("Restore Mode", selection: $selectedRestoreModeSheet) {
                                    ForEach(BackupRestoreMode.allCases, id: \.self) { mode in
                                        Text(modeDescription(mode))
                                            .tag(mode)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(maxWidth: .infinity)
                                
                                HStack {
                                    Image(systemName: iconForRestoreMode(selectedRestoreModeSheet))
                                        .foregroundColor(.accentColor)
                                    Text(modeDescription(selectedRestoreModeSheet))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 4)
                            }
                            .padding(20)
                            .background(controlBackgroundColor)
                            .cornerRadius(16)
                            .padding(.horizontal, 20)
                        }
                    }
                    .padding(.vertical, 24)
                }
                
                Divider()
                
                // Action Buttons
                HStack(spacing: 16) {
                    Button("Cancel") {
                        pendingBackupAction = nil
                        actionPasswordInput = ""
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    
                    Button(actionButtonTitle(action)) {
                        handleBackupAction(action)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(action.manifest.encrypted && !viewModel.hasStoredBackupPassword && actionPasswordInput.isEmpty)
                }
                .padding(20)
            }
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .principal) {
                    EmptyView()
                }
            }
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        .presentationCornerRadius(20)
        .presentationDetents([.large])
        #endif
    }
    
    private func iconForAction(_ action: BackupAction) -> String {
        switch action {
        case .restore: return "arrow.clockwise.circle.fill"
        case .preview: return "eye.circle.fill"
        case .exportJSON: return "doc.text.fill"
        case .exportHTML: return "doc.richtext.fill"
        }
    }
    
    private func descriptionForAction(_ action: BackupAction) -> String {
        switch action {
        case .restore:
            return "Restore your data from this backup. Choose how to handle conflicts with existing data."
        case .preview:
            return "Preview the contents of this backup before restoring."
        case .exportJSON:
            return "Export this backup as a JSON file for external use."
        case .exportHTML:
            return "Export this backup as an HTML file for viewing in a browser."
        }
    }
    
    private func actionButtonTitle(_ action: BackupAction) -> String {
        switch action {
        case .restore: return "Restore"
        case .preview: return "Preview"
        case .exportJSON: return "Export JSON"
        case .exportHTML: return "Export HTML"
        }
    }
    
    private func iconForRestoreMode(_ mode: BackupRestoreMode) -> String {
        switch mode {
        case .merge: return "arrow.triangle.merge"
        case .replaceAll: return "arrow.triangle.swap"
        case .collectionsOnly: return "folder.fill"
        case .bookmarksOnly: return "bookmark.fill"
        }
    }
    
    private func modeDescription(_ mode: BackupRestoreMode) -> String {
        switch mode {
        case .merge:
            return "Merge - Combine backup data with existing data"
        case .replaceAll:
            return "Replace All - Replace all existing data with backup"
        case .collectionsOnly:
            return "Collections Only - Restore only collections"
        case .bookmarksOnly:
            return "Bookmarks Only - Restore only bookmarks"
        }
    }
    
    private func sheetTitle(for action: BackupAction) -> String {
        switch action {
        case .restore: return "Restore Backup"
        case .preview: return "Preview Backup"
        case .exportJSON: return "Export JSON"
        case .exportHTML: return "Export HTML"
        }
    }
    
    private func handleBackupAction(_ action: BackupAction) {
        let password: String? = (action.manifest.encrypted && !viewModel.hasStoredBackupPassword) ? actionPasswordInput : nil
        switch action {
        case .restore(let manifest):
            viewModel.restoreBackup(manifest: manifest, mode: selectedRestoreModeSheet, password: password)
        case .preview(let manifest):
            showingPreviewSheet = true
            viewModel.backupPreviewSummary = nil
            viewModel.isBackupPreviewLoading = true
            Task {
                await viewModel.previewBackup(manifest: manifest, password: password)
            }
        case .exportJSON(let manifest):
            Task {
                if let url = await viewModel.exportBackup(manifest: manifest, format: .json, password: password) {
                    exportedBackupURL = url
                    #if os(iOS)
                    showingExportShareSheet = true
                    #endif
                }
            }
        case .exportHTML(let manifest):
            Task {
                if let url = await viewModel.exportBackup(manifest: manifest, format: .html, password: password) {
                    exportedBackupURL = url
                    #if os(iOS)
                    showingExportShareSheet = true
                    #endif
                }
            }
        }
        pendingBackupAction = nil
        actionPasswordInput = ""
    }
}

extension SettingsView {
    func refreshOfflineStorageSize() {
        offlineStorageSizeMB = Double(OfflineDownloadManager.shared.totalOfflineSize()) / 1_048_576.0
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
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                
                Section {
                    TextField("Brief description of your issue", text: $subject)
                } header: {
                    Text("Subject")
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                
                Section {
                    TextEditor(text: $message)
                        .frame(minHeight: 150)
                } header: {
                    Text("Message")
                }
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
                
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
                .listRowInsets(EdgeInsets(top: 12, leading: 20, bottom: 12, trailing: 20))
            }
            #if os(iOS)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            #else
            .background(Color(NSColor.controlBackgroundColor))
            #endif
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
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
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


