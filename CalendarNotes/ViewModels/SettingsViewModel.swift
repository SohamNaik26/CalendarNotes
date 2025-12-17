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
#if os(iOS)
import AVFoundation
#if canImport(AVFAudio)
import AVFAudio
#endif
import Speech
import UIKit
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

#if os(iOS)
enum OrientationPreference: String, CaseIterable {
    case auto = "Auto-rotate"
    case portrait = "Portrait only"
    case landscape = "Landscape only"
    
    var displayName: String {
        switch self {
        case .auto: return "Auto-rotate"
        case .portrait: return "Portrait only"
        case .landscape: return "Landscape only"
        }
    }
}
#endif

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
#if os(iOS)
    @AppStorage("orientationPreference") var orientationPreferenceRaw: String = OrientationPreference.auto.rawValue
    
    var orientationPreference: OrientationPreference {
        get { OrientationPreference(rawValue: orientationPreferenceRaw) ?? .auto }
        set { orientationPreferenceRaw = newValue.rawValue }
    }
#endif

    
    // Bookmark settings
    @AppStorage("bookmark.defaultCollection") var bookmarkDefaultCollection: String = ""
    @AppStorage("bookmark.autoFetchMetadata") var bookmarkAutoFetchMetadata: Bool = true
    @AppStorage("bookmark.previewDownloadMode") private var bookmarkPreviewDownloadModeRaw: String = BookmarkPreviewDownloadMode.wifiOnly.rawValue
    @AppStorage("bookmark.previewRetentionDays") private var bookmarkPreviewRetentionRaw: Int = BookmarkPreviewRetentionPolicy.days(30).rawValue
    @AppStorage("bookmark.defaultView") var bookmarkDefaultViewRaw: String = BookmarksViewModel.LayoutMode.grid.rawValue
    @AppStorage("bookmark.gridColumns") var bookmarkGridColumns: Int = 3
    @AppStorage("bookmark.sortOrder") var bookmarkSortOrderRaw: String = BookmarksViewModel.Sort.recent.rawValue
    @AppStorage("bookmark.openMode") var bookmarkOpenModeRaw: String = BookmarkOpenMode.ask.rawValue
    @AppStorage("bookmark.swipeActions") private var bookmarkSwipeActionsRaw: String = BookmarkSwipeAction.encodedString(from: BookmarkSwipeAction.defaultSet)
    @AppStorage("bookmark.duplicateDetection") var bookmarkDuplicateDetection: Bool = true
    @AppStorage("bookmark.quickImportShortcut") var bookmarkQuickImportShortcut: Bool = true
    @AppStorage("bookmark.quickExportShortcut") var bookmarkQuickExportShortcut: Bool = true
    @AppStorage("bookmark.defaultImportFormat") var bookmarkDefaultImportFormatRaw: String = BookmarkDataFormat.html.rawValue
    @AppStorage("bookmark.defaultExportFormat") var bookmarkDefaultExportFormatRaw: String = BookmarkDataFormat.html.rawValue
    @AppStorage("bookmark.requireBiometricCollections") var bookmarkRequireBiometric: Bool = false
    @AppStorage("bookmark.experimentalFeatures") var bookmarkExperimentalFeatures: Bool = false
    @AppStorage("bookmark.debugMode") var bookmarkDebugMode: Bool = false
    
    var bookmarkPreviewDownloadMode: BookmarkPreviewDownloadMode {
        get { BookmarkPreviewDownloadMode(rawValue: bookmarkPreviewDownloadModeRaw) ?? .wifiOnly }
        set { bookmarkPreviewDownloadModeRaw = newValue.rawValue }
    }
    
    var bookmarkPreviewRetention: BookmarkPreviewRetentionPolicy {
        get { BookmarkPreviewRetentionPolicy(rawValue: bookmarkPreviewRetentionRaw) ?? .days(30) }
        set { bookmarkPreviewRetentionRaw = newValue.rawValue }
    }
    
    var bookmarkDefaultView: BookmarksViewModel.LayoutMode {
        get { BookmarksViewModel.LayoutMode(rawValue: bookmarkDefaultViewRaw) ?? .grid }
        set { bookmarkDefaultViewRaw = newValue.rawValue }
    }
    
    var bookmarkSortOrder: BookmarksViewModel.Sort {
        get { BookmarksViewModel.Sort(rawValue: bookmarkSortOrderRaw) ?? .recent }
        set { bookmarkSortOrderRaw = newValue.rawValue }
    }
    
    var bookmarkOpenMode: BookmarkOpenMode {
        get { BookmarkOpenMode(rawValue: bookmarkOpenModeRaw) ?? .ask }
        set { bookmarkOpenModeRaw = newValue.rawValue }
    }
    
    var bookmarkSwipeActions: Set<BookmarkSwipeAction> {
        get { BookmarkSwipeAction.decode(from: bookmarkSwipeActionsRaw) }
        set { bookmarkSwipeActionsRaw = BookmarkSwipeAction.encodedString(from: newValue.isEmpty ? BookmarkSwipeAction.defaultSet : newValue) }
    }
    
    var bookmarkDefaultImportFormat: BookmarkDataFormat {
        get { BookmarkDataFormat(rawValue: bookmarkDefaultImportFormatRaw) ?? .html }
        set { bookmarkDefaultImportFormatRaw = newValue.rawValue }
    }
    
    var bookmarkDefaultExportFormat: BookmarkDataFormat {
        get { BookmarkDataFormat(rawValue: bookmarkDefaultExportFormatRaw) ?? .html }
        set { bookmarkDefaultExportFormatRaw = newValue.rawValue }
    }
    
    // MARK: - Voice Notes Settings
    
    // Recording Quality
    enum RecordingQuality: String, CaseIterable {
        case high = "high"      // 256 kbps
        case medium = "medium"  // 128 kbps
        case low = "low"        // 64 kbps
        
        var displayName: String {
            switch self {
            case .high: return "High (256 kbps)"
            case .medium: return "Medium (128 kbps)"
            case .low: return "Low (64 kbps)"
            }
        }
        
        var bitrate: Int {
            switch self {
            case .high: return 256000
            case .medium: return 128000
            case .low: return 64000
            }
        }
    }
    
    @AppStorage("voiceNotes.recordingQuality") var recordingQualityRaw: String = RecordingQuality.medium.rawValue
    @AppStorage("voiceNotes.autoTranscribe") var autoTranscribe: Bool = true
    @AppStorage("voiceNotes.transcriptionLanguage") var transcriptionLanguage: String = Locale.current.identifier
    @AppStorage("voiceNotes.keepRecordingsAfterTranscription") var keepRecordingsAfterTranscription: Bool = true
    @AppStorage("voiceNotes.autoDeleteAfter") var autoDeleteAfterRaw: String = "never" // 7, 30, 90, never
    
    // Playback Settings
    enum PlaybackSpeed: Double, CaseIterable {
        case oneX = 1.0
        case onePointFiveX = 1.5
        case twoX = 2.0
        
        var displayName: String {
            switch self {
            case .oneX: return "1x"
            case .onePointFiveX: return "1.5x"
            case .twoX: return "2x"
            }
        }
    }
    
    @AppStorage("voiceNotes.defaultPlaybackSpeed") var defaultPlaybackSpeedRaw: Double = PlaybackSpeed.oneX.rawValue
    @AppStorage("voiceNotes.skipInterval") var skipInterval: Int = 10 // seconds: 5, 10, 15, 30
    @AppStorage("voiceNotes.continuePlaybackInBackground") var continuePlaybackInBackground: Bool = true
    @AppStorage("voiceNotes.showInLockScreen") var showInLockScreen: Bool = true
    
    // Recording Settings
    @AppStorage("voiceNotes.countdownBeforeRecording") var countdownBeforeRecording: Int = 0 // 0, 3, 5 seconds
    @AppStorage("voiceNotes.maxRecordingDuration") var maxRecordingDurationRaw: String = "noLimit" // noLimit, 5, 10, 30 (minutes)
    @AppStorage("voiceNotes.pauseRecordingOnInterruption") var pauseRecordingOnInterruption: Bool = true
    @AppStorage("voiceNotes.saveAutomaticallyOnInterruption") var saveAutomaticallyOnInterruption: Bool = true
    @AppStorage("voiceNotes.hapticFeedbackOnStartStop") var hapticFeedbackOnStartStop: Bool = true
    
    // Transcription Settings
    enum TranscriptionQuality: String, CaseIterable {
        case fast = "fast"
        case accurate = "accurate"
        
        var displayName: String {
            switch self {
            case .fast: return "Fast"
            case .accurate: return "Accurate"
            }
        }
    }
    
    @AppStorage("voiceNotes.transcriptionQuality") var transcriptionQualityRaw: String = TranscriptionQuality.accurate.rawValue
    @AppStorage("voiceNotes.autoDetectLanguage") var autoDetectLanguage: Bool = true
    @AppStorage("voiceNotes.addPunctuationAutomatically") var addPunctuationAutomatically: Bool = true
    
    // Privacy Settings
    @AppStorage("voiceNotes.onDeviceTranscriptionOnly") var onDeviceTranscriptionOnly: Bool = true
    @AppStorage("voiceNotes.neverUploadVoiceNotes") var neverUploadVoiceNotes: Bool = true
    @AppStorage("voiceNotes.requireBiometricToPlay") var requireBiometricToPlay: Bool = false
    @AppStorage("voiceNotes.excludeFromBackups") var excludeFromBackups: Bool = false
    
    // Sync Settings
    @AppStorage("voiceNotes.autoUpload") var autoUploadVoiceNotes: Bool = true
    @AppStorage("voiceNotes.wifiOnlyUpload") var wifiOnlyUpload: Bool = true
    @AppStorage("voiceNotes.autoDownload") var autoDownloadVoiceNotes: Bool = false
    @AppStorage("voiceNotes.compressBeforeUpload") var compressBeforeUpload: Bool = true
    @AppStorage("voiceNotes.deleteLocalAfterUpload") var deleteLocalAfterUpload: Bool = false
    @AppStorage("voiceNotes.keepLocalCopies") var keepLocalCopies: Bool = true
    @AppStorage("voiceNotes.cacheSizeLimit") private var cacheSizeLimitRaw: String = "\(500 * 1024 * 1024)"
    
    var cacheSizeLimit: Int64 {
        get { Int64(cacheSizeLimitRaw) ?? 500 * 1024 * 1024 }
        set { cacheSizeLimitRaw = "\(newValue)" }
    }
    @AppStorage("voiceNotes.syncTranscriptionsOnly") var syncTranscriptionsOnly: Bool = false
    @AppStorage("voiceNotes.maxRetryAttempts") var maxRetryAttempts: Int = 3
    
    // Computed Properties
    var recordingQuality: RecordingQuality {
        get { RecordingQuality(rawValue: recordingQualityRaw) ?? .medium }
        set { recordingQualityRaw = newValue.rawValue }
    }
    
    var defaultPlaybackSpeed: PlaybackSpeed {
        get { PlaybackSpeed(rawValue: defaultPlaybackSpeedRaw) ?? .oneX }
        set { defaultPlaybackSpeedRaw = newValue.rawValue }
    }
    
    var transcriptionQuality: TranscriptionQuality {
        get { TranscriptionQuality(rawValue: transcriptionQualityRaw) ?? .accurate }
        set { transcriptionQualityRaw = newValue.rawValue }
    }
    
    var autoDeleteAfter: String {
        get { autoDeleteAfterRaw }
        set { autoDeleteAfterRaw = newValue }
    }
    
    var maxRecordingDuration: String {
        get { maxRecordingDurationRaw }
        set { maxRecordingDurationRaw = newValue }
    }
    
    // Voice Notes Storage & Stats
    @Published var voiceNotesTotalStorageUsed: Int64 = 0
    @Published var voiceNotesAvailableStorage: Int64 = 0
    @Published var voiceNotesCount: Int = 0
    @Published var isOptimizingStorage: Bool = false
    @Published var showingDeleteAllVoiceNotesAlert: Bool = false
    
    
    @Published var showingDataExport = false
    @Published var showingDataImport = false
    @Published var showingClearCacheAlert = false
    @Published var showingDeleteAllDataAlert = false
    @Published var showingBackupSheet = false
    @Published var showingRestoreSheet = false
    @Published var showingContactSupport = false
    
    // Backup
    private let backupService = BookmarkBackupService.shared
    private var backupCancellables = Set<AnyCancellable>()
    @Published var backupOptionsState: BackupOptions
    @Published var backupStatusState: BackupStatus
    @Published var backupHistory: [BackupManifest]
    @Published var isBackupRunningState: Bool = false
    @Published var isCalculatingBackupSize = false
    @Published var calculatedBackupSize: Int64 = 0
    @Published var backupErrorMessage: String?
    @Published var selectedBackupManifest: BackupManifest?
    @Published var selectedRestoreMode: BackupRestoreMode = .merge
    @Published var restorePassword: String = ""
    @Published var backupPasswordInput: String = ""
    @Published var backupPasswordHintInput: String = ""
    @Published var backupPreviewSummary: BackupPreviewSummary?
    @Published var isBackupPreviewLoading = false
    
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

    
    // Bookmark metrics & state
    @Published var bookmarkCollections: [String] = []
    @Published var bookmarkCount: Int = 0
    @Published var bookmarkStorageBytes: Int64 = 0
    @Published var bookmarkImageCacheBytes: Int64 = 0
    @Published var bookmarkMetadataCacheBytes: Int64 = 0
    @Published var bookmarkActionMessage: String = ""
    @Published var isBookmarkMaintenanceRunning: Bool = false
    
    init() {
        let options = backupService.options
        self.backupOptionsState = options
        self.backupStatusState = backupService.status
        self.backupHistory = backupService.availableManifests()
        backupService.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.backupStatusState = status
            }
            .store(in: &backupCancellables)
        backupService.$manifests
            .receive(on: RunLoop.main)
            .sink { [weak self] manifests in
                self?.backupHistory = manifests.sorted { $0.createdAt > $1.createdAt }
            }
            .store(in: &backupCancellables)
        backupService.$isRunningBackup
            .receive(on: RunLoop.main)
            .sink { [weak self] running in
                self?.isBackupRunningState = running
            }
            .store(in: &backupCancellables)
    }
    
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
        if let date = backupStatusState.lastBackupDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
        return "Never"
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
        BookmarkService.shared.clearCaches()
        ImageCacheService.shared.clearAllCache()
        Task { await BookmarkPreviewIndex.shared.clear() }
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
            let password = backupOptionsState.encryptWithPassword && !backupService.hasStoredEncryptionPassword() ? backupPasswordInput : nil
            _ = try await backupService.performManualBackup(password: password)
            backupErrorMessage = nil
        } catch {
            backupErrorMessage = error.localizedDescription
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
    
    // MARK: - Backup Management
    
    func setAutoBackupEnabled(_ enabled: Bool) {
        backupService.autoBackupEnabled = enabled
        refreshBackupBindings()
    }
    
    func toggleContentOption(_ option: BackupContentOptions, enabled: Bool) {
        var updated = backupOptionsState
        if enabled {
            updated.content.insert(option)
        } else {
            updated.content.remove(option)
        }
        backupOptionsState = updated
        backupService.updateOptions(updated)
        refreshBackupBindings()
    }
    
    func setStoragePreference(_ preference: BackupStoragePreference) {
        var updated = backupOptionsState
        updated.storagePreference = preference
        backupOptionsState = updated
        backupService.updateOptions(updated)
        refreshBackupBindings()
    }
    
    func setIncrementalBackup(_ enabled: Bool) {
        var updated = backupOptionsState
        updated.incremental = enabled
        backupOptionsState = updated
        backupService.updateOptions(updated)
        refreshBackupBindings()
    }
    
    func configureEncryption(enable: Bool, password: String?, hint: String?) {
        backupService.configureEncryption(enabled: enable, password: password, hint: hint)
        backupOptionsState = backupService.options
        refreshBackupBindings()
    }
    
    func calculateBackupSizeEstimate() {
        guard !isCalculatingBackupSize else { return }
        isCalculatingBackupSize = true
        backupErrorMessage = nil
        Task {
            do {
                let size = try await backupService.calculateBackupSize(options: backupOptionsState)
                calculatedBackupSize = size
            } catch {
                backupErrorMessage = error.localizedDescription
            }
            isCalculatingBackupSize = false
        }
    }
    
    func runManualBackup(password: String?) {
        Task {
            do {
                _ = try await backupService.performManualBackup(password: password)
                backupHistory = backupService.availableManifests()
                backupErrorMessage = nil
            } catch {
                backupErrorMessage = error.localizedDescription
            }
        }
    }
    
    func restoreBackup(manifest: BackupManifest, mode: BackupRestoreMode, password: String?) {
        Task {
            do {
                try await backupService.restore(from: manifest, mode: mode, password: password)
                backupErrorMessage = nil
            } catch {
                backupErrorMessage = error.localizedDescription
            }
        }
    }
    
    func previewBackup(manifest: BackupManifest, password: String?) async {
        isBackupPreviewLoading = true
        backupErrorMessage = nil
        backupPreviewSummary = nil
        do {
            let summary = try await backupService.previewSummary(for: manifest, password: password)
            backupPreviewSummary = summary
        } catch {
            backupErrorMessage = error.localizedDescription
        }
        isBackupPreviewLoading = false
    }
    
    func deleteBackup(manifest: BackupManifest) {
        backupService.deleteBackup(manifest: manifest)
        backupHistory = backupService.availableManifests()
        refreshBackupBindings()
    }
    
    func exportBackup(manifest: BackupManifest, format: BackupFileFormat, password: String?) async -> URL? {
        do {
            return try await backupService.exportBackup(manifest: manifest, format: format, password: password)
        } catch {
            backupErrorMessage = error.localizedDescription
            return nil
        }
    }
    
    func refreshBackupBindings() {
        backupOptionsState = backupService.options
        backupStatusState = backupService.status
        backupHistory = backupService.availableManifests()
    }
    
    var hasStoredBackupPassword: Bool {
        backupService.hasStoredEncryptionPassword()
    }
    
    var backupPasswordHint: String? {
        backupStatusState.passwordHint
    }

    func refreshBookmarkCollections() {
        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        let names = (try? CoreDataManager.shared.viewContext.fetch(request).compactMap { $0.name?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }) ?? []
        bookmarkCollections = names
    }
    
    func refreshBookmarkStats() {
        Task { @MainActor in
            let context = CoreDataManager.shared.viewContext
            let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
            request.includesPropertyValues = false
            request.includesSubentities = false
            bookmarkCount = (try? context.count(for: request)) ?? 0
            bookmarkStorageBytes = Self.bookmarkDatabaseSize()
            let cacheUsage = await BookmarkService.shared.cacheUsage()
            bookmarkImageCacheBytes = cacheUsage.previewBytes + cacheUsage.faviconBytes
            bookmarkMetadataCacheBytes = cacheUsage.metadataBytes
        }
    }
    
    func setSwipeAction(_ action: BookmarkSwipeAction, enabled: Bool) {
        var updated = bookmarkSwipeActions
        if enabled {
            updated.insert(action)
        } else {
            updated.remove(action)
        }
        bookmarkSwipeActions = updated.isEmpty ? BookmarkSwipeAction.defaultSet : updated
    }
    
    func clearBookmarkBrowsingHistory() {
        guard !isBookmarkMaintenanceRunning else { return }
        isBookmarkMaintenanceRunning = true
        Task { @MainActor in
            do {
                try CoreDataManager.shared.batchUpdate(
                    entityName: "Bookmark",
                    propertiesToUpdate: ["lastOpenedDate": NSNull(), "openCount": 0]
                )
                bookmarkActionMessage = "Browsing history cleared."
                refreshBookmarkStats()
            } catch {
                bookmarkActionMessage = "Failed to clear browsing history: \(error.localizedDescription)"
            }
            isBookmarkMaintenanceRunning = false
        }
    }
    
    func clearCachedBookmarkImages() {
        guard !isBookmarkMaintenanceRunning else { return }
        isBookmarkMaintenanceRunning = true
        Task { @MainActor in
            BookmarkService.shared.clearImageCaches()
            await BookmarkPreviewIndex.shared.clear()
            bookmarkActionMessage = "Cached bookmark images cleared."
            refreshBookmarkStats()
            isBookmarkMaintenanceRunning = false
        }
    }
    
    func clearBookmarkSearchHistory() {
        AdvancedBookmarkSearchService.shared.clearHistory()
        bookmarkActionMessage = "Search history cleared."
    }
    
    func applyPreviewRetentionPolicy() {
        BookmarkService.shared.applyPreviewRetention(policy: bookmarkPreviewRetention)
        bookmarkActionMessage = "Preview retention policy applied."
        refreshBookmarkStats()
    }
    
    func deleteArchivedBookmarks() {
        guard !isBookmarkMaintenanceRunning else { return }
        isBookmarkMaintenanceRunning = true
        Task { @MainActor in
            let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
            request.predicate = NSPredicate(format: "isArchived == YES")
            let context = CoreDataManager.shared.viewContext
            do {
                if let archived = try? context.fetch(request) {
                    archived.forEach { context.delete($0) }
                    try context.save()
                }
                bookmarkActionMessage = "Archived bookmarks deleted."
                refreshBookmarkStats()
                refreshBookmarkCollections()
            } catch {
                bookmarkActionMessage = "Failed to delete archived bookmarks: \(error.localizedDescription)"
            }
            isBookmarkMaintenanceRunning = false
        }
    }
    
    func deleteAllBookmarks() {
        guard !isBookmarkMaintenanceRunning else { return }
        isBookmarkMaintenanceRunning = true
        Task { @MainActor in
            do {
                let fetchRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
                try CoreDataManager.shared.batchDelete(fetchRequest)
                await BookmarkPreviewIndex.shared.clear()
                BookmarkService.shared.clearImageCaches()
                bookmarkActionMessage = "All bookmarks deleted."
                refreshBookmarkStats()
                refreshBookmarkCollections()
            } catch {
                bookmarkActionMessage = "Failed to delete bookmarks: \(error.localizedDescription)"
            }
            isBookmarkMaintenanceRunning = false
        }
    }
    
    func resetBookmarkSettings() {
        BookmarkPreferenceStore.reset()
        bookmarkDefaultCollection = ""
        bookmarkAutoFetchMetadata = true
        bookmarkPreviewDownloadMode = .wifiOnly
        bookmarkPreviewRetention = .days(30)
        bookmarkDefaultView = .grid
        bookmarkGridColumns = 3
        bookmarkSortOrder = .recent
        bookmarkOpenMode = .ask
        bookmarkSwipeActions = BookmarkSwipeAction.defaultSet
        bookmarkDuplicateDetection = true
        bookmarkQuickImportShortcut = true
        bookmarkQuickExportShortcut = true
        bookmarkDefaultImportFormat = .html
        bookmarkDefaultExportFormat = .html
        bookmarkRequireBiometric = false
        bookmarkExperimentalFeatures = false
        bookmarkDebugMode = false
        bookmarkActionMessage = "Bookmark settings reset."
        refreshBookmarkStats()
        refreshBookmarkCollections()
    }
    
    private static func bookmarkDatabaseSize() -> Int64 {
        guard let url = CoreDataManager.shared.persistentContainer.persistentStoreDescriptions.first?.url else {
            return 0
        }
        var total: Int64 = fileSize(at: url)
        let shm = url.deletingPathExtension().appendingPathExtension("sqlite-shm")
        let wal = url.deletingPathExtension().appendingPathExtension("sqlite-wal")
        total += fileSize(at: shm)
        total += fileSize(at: wal)
        return total
    }
    
    private static func fileSize(at url: URL) -> Int64 {
        guard FileManager.default.fileExists(atPath: url.path) else { return 0 }
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return (attributes?[.size] as? NSNumber)?.int64Value ?? 0
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
    
    // MARK: - Voice Notes Management
    
    func refreshVoiceNotesStats() {
        Task { @MainActor in
            let storageService = VoiceNoteStorageService.shared
            await storageService.refreshStorageUsage()
            
            voiceNotesTotalStorageUsed = storageService.totalStorageUsed
            voiceNotesAvailableStorage = max(0, storageService.storageQuota - storageService.totalStorageUsed)
            
            // Count voice notes
            let context = CoreDataManager.shared.viewContext
            let request: NSFetchRequest<VoiceNoteEntity> = VoiceNoteEntity.fetchRequest()
            request.includesPropertyValues = false
            voiceNotesCount = (try? context.count(for: request)) ?? 0
        }
    }
    
    func optimizeStorage() async {
        guard !isOptimizingStorage else { return }
        isOptimizingStorage = true
        
        // Compress old recordings, delete transcribed notes if setting enabled, etc.
        _ = VoiceNoteCleanupService.shared
        // This would need to be implemented in the cleanup service
        // For now, just refresh stats
        refreshVoiceNotesStats()
        
        isOptimizingStorage = false
    }
    
    func deleteAllVoiceNotes() async {
        do {
            let context = CoreDataManager.shared.viewContext
            let request: NSFetchRequest<VoiceNoteEntity> = VoiceNoteEntity.fetchRequest()
            let voiceNotes = try context.fetch(request)
            
            for voiceNote in voiceNotes {
                // Delete audio file if it exists
                if let audioPath = voiceNote.audioFilePath {
                    let url = URL(fileURLWithPath: audioPath)
                    try? FileManager.default.removeItem(at: url)
                }
                context.delete(voiceNote)
            }
            
            try context.save()
            refreshVoiceNotesStats()
        } catch {
            print("Error deleting all voice notes: \(error)")
        }
    }
    
    #if os(iOS)
    func getMicrophonePermissionStatus() -> String {
        if #available(iOS 17.0, *) {
            // Use AVAudioApplication.recordPermission for iOS 17+
            let status = AVAudioApplication.shared.recordPermission
            switch status {
            case .undetermined: return "Not Determined"
            case .denied: return "Denied"
            case .granted: return "Granted"
            @unknown default: return "Unknown"
            }
        } else {
            // Fallback to AVAudioSession for older iOS versions
            let status = AVAudioSession.sharedInstance().recordPermission
            switch status {
            case .undetermined: return "Not Determined"
            case .denied: return "Denied"
            case .granted: return "Granted"
            @unknown default: return "Unknown"
            }
        }
    }
    
    func getSpeechRecognitionPermissionStatus() -> String {
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .notDetermined: return "Not Determined"
        case .denied: return "Denied"
        case .restricted: return "Restricted"
        case .authorized: return "Granted"
        @unknown default: return "Unknown"
        }
    }
    
    func requestMicrophonePermission() async -> Bool {
        if #available(iOS 17.0, *) {
            return await AVAudioApplication.requestRecordPermission()
        } else {
            let status = AVAudioSession.sharedInstance().recordPermission
            if status == .undetermined {
                return await withCheckedContinuation { continuation in
                    AVAudioSession.sharedInstance().requestRecordPermission { granted in
                        continuation.resume(returning: granted)
                    }
                }
            }
            return status == .granted
        }
    }
    
    func requestSpeechRecognitionPermission() async throws {
        try await VoiceTranscriptionService.shared.requestPermission()
    }
    
    func openIOSSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
    #else
    func getMicrophonePermissionStatus() -> String { "N/A" }
    func getSpeechRecognitionPermissionStatus() -> String { "N/A" }
    func requestMicrophonePermission() async -> Bool { false }
    func requestSpeechRecognitionPermission() async throws {}
    func openIOSSettings() {}
    #endif
    
    deinit {
        backupCancellables.removeAll()
    }
}

