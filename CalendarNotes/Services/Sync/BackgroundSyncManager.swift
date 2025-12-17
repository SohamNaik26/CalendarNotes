//
//  BackgroundSyncManager.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import Network
import UserNotifications

#if os(iOS)
import UIKit
import BackgroundTasks
@MainActor
final class BackgroundSyncManager {
	static let shared = BackgroundSyncManager()
	
	// Task identifiers
	private let syncTaskIdentifier = "com.calendarnotes.sync"
	private let processingTaskIdentifier = "com.calendarnotes.process"
	
	// Settings keys
	private let backgroundSyncEnabledKey = "backgroundSync.enabled"
	private let backgroundSyncFrequencyKey = "backgroundSync.frequency"
	private let wifiOnlyBackgroundSyncKey = "backgroundSync.wifiOnly"
	private let batteryAwareSyncKey = "backgroundSync.batteryAware"
	
	private let syncService = SyncService.shared
	private let offlineQueue = OfflineRequestQueue.shared
	private let networkMonitor = NWPathMonitor()
	private let monitorQueue = DispatchQueue(label: "com.calendarnotes.network.monitor")
	
	private var isOnline = true
	private var lastSyncDate: Date?
	
	private init() {
		setupNetworkMonitoring()
		loadSettings()
	}
	
	// MARK: - Registration
	
	func registerBackgroundTasks() {
		guard #available(iOS 13.0, *) else { return }
		
		// Register sync task (BGAppRefreshTask)
		BGTaskScheduler.shared.register(
			forTaskWithIdentifier: syncTaskIdentifier,
			using: nil
		) { [weak self] task in
			guard let self = self else { return }
			self.handleBackgroundSync(task: task as! BGAppRefreshTask)
		}
		
		// Register processing task (BGProcessingTask)
		BGTaskScheduler.shared.register(
			forTaskWithIdentifier: processingTaskIdentifier,
			using: nil
		) { [weak self] task in
			guard let self = self else { return }
			self.handleBackgroundProcessing(task: task as! BGProcessingTask)
		}
		
		print("✅ Background tasks registered")
	}
	
	// MARK: - Scheduling
	
	func scheduleBackgroundSync() {
		guard #available(iOS 13.0, *) else { return }
		guard isBackgroundSyncEnabled() else { return }
		
		let request = BGAppRefreshTaskRequest(identifier: syncTaskIdentifier)
		let interval = getBackgroundSyncInterval()
		request.earliestBeginDate = Date(timeIntervalSinceNow: interval)
		
		do {
			try BGTaskScheduler.shared.submit(request)
			print("✅ Background sync scheduled for \(request.earliestBeginDate?.description ?? "unknown")")
		} catch {
			print("❌ Failed to schedule background sync: \(error.localizedDescription)")
		}
	}
	
	func scheduleBackgroundProcessing() {
		guard #available(iOS 13.0, *) else { return }
		guard isBackgroundSyncEnabled() else { return }
		
		let request = BGProcessingTaskRequest(identifier: processingTaskIdentifier)
		// Processing tasks can run less frequently
		request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 60 * 60) // 4 hours
		request.requiresNetworkConnectivity = true
		request.requiresExternalPower = false
		
		do {
			try BGTaskScheduler.shared.submit(request)
			print("✅ Background processing scheduled")
		} catch {
			print("❌ Failed to schedule background processing: \(error.localizedDescription)")
		}
	}
	
	// MARK: - Background Sync Handler
	
	@available(iOS 13.0, *)
	private func handleBackgroundSync(task: BGAppRefreshTask) {
		print("🔄 Background sync task started")
		
		// Schedule next sync
		scheduleBackgroundSync()
		
		// Set expiration handler
		task.expirationHandler = {
			print("⏰ Background sync task expired")
			task.setTaskCompleted(success: false)
		}
		
		// Perform sync
		Task {
			// Check prerequisites
			guard await checkSyncPrerequisites() else {
				task.setTaskCompleted(success: false)
				return
			}
			
			// Process offline queue first
			await offlineQueue.processQueue()
			
			// Perform sync
			await performBackgroundSync()
			
			// Update last sync date
			lastSyncDate = Date()
			
			// Update UI if app is in foreground
			await updateUIAfterSync()
			
			task.setTaskCompleted(success: true)
			print("✅ Background sync completed successfully")
		}
	}
	
	// MARK: - Background Processing Handler
	
	@available(iOS 13.0, *)
	private func handleBackgroundProcessing(task: BGProcessingTask) {
		print("🔄 Background processing task started")
		
		// Schedule next processing
		scheduleBackgroundProcessing()
		
		// Set expiration handler
		task.expirationHandler = {
			print("⏰ Background processing task expired")
			task.setTaskCompleted(success: false)
		}
		
		// Perform processing
		Task {
			// Check prerequisites
			guard await checkProcessingPrerequisites() else {
				task.setTaskCompleted(success: false)
				return
			}
			
			// Upload queued voice notes
			await uploadQueuedVoiceNotes()
			
			// Process large syncs
			await processLargeSyncs()
			
			// Optimize database
			await optimizeDatabase()
			
			// Clean up old data
			await cleanupOldData()
			
			task.setTaskCompleted(success: true)
			print("✅ Background processing completed successfully")
		}
	}
	
	// MARK: - Sync Operations
	
	private func performBackgroundSync() async {
		// Check network connectivity
		guard isOnline else {
			print("⚠️ No network connection, skipping sync")
			return
		}
		
		// Sync pending changes
		await syncPendingChanges()
		
		// Fetch new data from server
		await fetchNewDataFromServer()
		
		// Update local database
		await updateLocalDatabase()
	}
	
	private func syncPendingChanges() async {
		print("📤 Syncing pending changes...")
		
		// Process offline queue
		await offlineQueue.processQueue()
		
		// Use SyncService to sync all entities
		await MainActor.run {
			syncService.syncAll(reason: .automatic)
		}
	}
	
	private func fetchNewDataFromServer() async {
		print("📥 Fetching new data from server...")
		
		// TODO: Integrate with API repositories to fetch new data
		// This would use the API client to pull changes since last sync
		
		// Example:
		// let eventRepo = EventAPIRepository()
		// let events = try? await eventRepo.fetchEvents(...)
	}
	
	private func updateLocalDatabase() async {
		print("💾 Updating local database...")
		
		// TODO: Integrate with CoreData or local storage
		// Update local database with fetched data
	}
	
	// MARK: - Processing Operations
	
	private func uploadQueuedVoiceNotes() async {
		print("🎤 Uploading queued voice notes...")
		
		// TODO: Implement voice note upload queue processing
		// Check for pending voice note uploads and process them
	}
	
	private func processLargeSyncs() async {
		print("🔄 Processing large syncs...")
		
		// TODO: Handle large sync operations that need more time
		// This could include batch operations, large file transfers, etc.
	}
	
	private func optimizeDatabase() async {
		print("⚡ Optimizing database...")
		
		// TODO: Perform database optimization tasks
		// This could include vacuuming, reindexing, etc.
	}
	
	private func cleanupOldData() async {
		print("🧹 Cleaning up old data...")
		
		// TODO: Clean up old cached data, expired items, etc.
	}
	
	// MARK: - Prerequisites Checking
	
	private func checkSyncPrerequisites() async -> Bool {
		// Check network connectivity
		guard isOnline else {
			print("⚠️ No network connection")
			return false
		}
		
		// Check WiFi-only setting
		if isWifiOnlyBackgroundSync() {
			guard await isConnectedViaWiFi() else {
				print("⚠️ WiFi required but not connected")
				return false
			}
		}
		
		// Check battery level if battery-aware
		if isBatteryAwareSync() {
			guard await checkBatteryLevel() else {
				print("⚠️ Battery level too low or low power mode enabled")
				return false
			}
		}
		
		return true
	}
	
	private func checkProcessingPrerequisites() async -> Bool {
		// Processing tasks need network
		guard isOnline else {
			return false
		}
		
		// Check battery if battery-aware
		if isBatteryAwareSync() {
			guard await checkBatteryLevel() else {
				return false
			}
		}
		
		return true
	}
	
	private func checkBatteryLevel() async -> Bool {
		// Check if low power mode is enabled
		#if os(iOS)
		if ProcessInfo.processInfo.isLowPowerModeEnabled {
			return false
		}
		#endif
		
		// TODO: Check actual battery level if needed
		// UIDevice.current.batteryLevel (requires battery monitoring to be enabled)
		
		return true
	}
	
	private func isConnectedViaWiFi() async -> Bool {
		// Check if connected via WiFi
		// This is a simplified check - in production, you'd want more robust network type detection
		return isOnline
	}
	
	// MARK: - UI Updates
	
	private func updateUIAfterSync() async {
		// Check if app is in foreground
		#if os(iOS)
		let appState = UIApplication.shared.applicationState
		if appState == .active {
			// Update UI on main thread
			await MainActor.run {
				// Post notification for UI updates
				NotificationCenter.default.post(name: .backgroundSyncCompleted, object: nil)
			}
		} else {
			// Show notification if important updates
			await showSyncNotificationIfNeeded()
		}
		#endif
		
		// Update app badge
		await updateAppBadge()
	}
	
	private func showSyncNotificationIfNeeded() async {
		// TODO: Check if there are important updates that warrant a notification
		// For now, we'll show a notification if sync was successful
		
		let content = UNMutableNotificationContent()
		content.title = "Sync Complete"
		content.body = "Your data has been synced successfully"
		content.sound = .default
		content.badge = await getPendingCount() as NSNumber
		
		let request = UNNotificationRequest(
			identifier: UUID().uuidString,
			content: content,
			trigger: nil
		)
		
		do {
			try await UNUserNotificationCenter.current().add(request)
		} catch {
			print("Failed to show sync notification: \(error)")
		}
	}
	
	private func updateAppBadge() async {
		let count = await getPendingCount()
		#if os(iOS)
		if #available(iOS 16.0, *) {
			try? await UNUserNotificationCenter.current().setBadgeCount(count)
		} else {
			await MainActor.run {
				UIApplication.shared.applicationIconBadgeNumber = count
			}
		}
		#endif
	}
	
	private func getPendingCount() async -> Int {
		return offlineQueue.pendingCount
	}
	
	// MARK: - Network Monitoring
	
	private func setupNetworkMonitoring() {
		networkMonitor.pathUpdateHandler = { [weak self] path in
			guard let self = self else { return }
			Task { @MainActor in
				self.isOnline = path.status == .satisfied
			}
		}
		networkMonitor.start(queue: monitorQueue)
	}
	
	// MARK: - Settings Management
	
	func setBackgroundSyncEnabled(_ enabled: Bool) {
		UserDefaults.standard.set(enabled, forKey: backgroundSyncEnabledKey)
		if enabled {
			scheduleBackgroundSync()
			scheduleBackgroundProcessing()
		}
	}
	
	func isBackgroundSyncEnabled() -> Bool {
		UserDefaults.standard.bool(forKey: backgroundSyncEnabledKey)
	}
	
	func setBackgroundSyncFrequency(_ frequency: BackgroundSyncFrequency) {
		UserDefaults.standard.set(frequency.rawValue, forKey: backgroundSyncFrequencyKey)
		scheduleBackgroundSync()
	}
	
	func getBackgroundSyncFrequency() -> BackgroundSyncFrequency {
		let rawValue = UserDefaults.standard.string(forKey: backgroundSyncFrequencyKey) ?? BackgroundSyncFrequency.every15Minutes.rawValue
		return BackgroundSyncFrequency(rawValue: rawValue) ?? .every15Minutes
	}
	
	func setWifiOnlyBackgroundSync(_ wifiOnly: Bool) {
		UserDefaults.standard.set(wifiOnly, forKey: wifiOnlyBackgroundSyncKey)
	}
	
	func isWifiOnlyBackgroundSync() -> Bool {
		UserDefaults.standard.bool(forKey: wifiOnlyBackgroundSyncKey)
	}
	
	func setBatteryAwareSync(_ batteryAware: Bool) {
		UserDefaults.standard.set(batteryAware, forKey: batteryAwareSyncKey)
	}
	
	func isBatteryAwareSync() -> Bool {
		UserDefaults.standard.bool(forKey: batteryAwareSyncKey)
	}
	
	private func loadSettings() {
		// Load default settings if not set
		if UserDefaults.standard.object(forKey: backgroundSyncEnabledKey) == nil {
			setBackgroundSyncEnabled(true)
		}
		if UserDefaults.standard.object(forKey: backgroundSyncFrequencyKey) == nil {
			setBackgroundSyncFrequency(.every15Minutes)
		}
		if UserDefaults.standard.object(forKey: wifiOnlyBackgroundSyncKey) == nil {
			setWifiOnlyBackgroundSync(false)
		}
		if UserDefaults.standard.object(forKey: batteryAwareSyncKey) == nil {
			setBatteryAwareSync(true)
		}
	}
	
	private func getBackgroundSyncInterval() -> TimeInterval {
		switch getBackgroundSyncFrequency() {
		case .every15Minutes:
			return 15 * 60
		case .every30Minutes:
			return 30 * 60
		case .hourly:
			return 60 * 60
		case .every2Hours:
			return 2 * 60 * 60
		case .every4Hours:
			return 4 * 60 * 60
		case .daily:
			return 24 * 60 * 60
		}
	}
	
	// MARK: - Manual Scheduling
	
	func scheduleSyncAfterAppEntersBackground() {
		scheduleBackgroundSync()
		scheduleBackgroundProcessing()
	}
	
	func scheduleSyncAfterManualSync() {
		// Schedule next sync after manual sync completes
		let interval = getBackgroundSyncInterval()
		DispatchQueue.main.asyncAfter(deadline: .now() + interval) { [weak self] in
			self?.scheduleBackgroundSync()
		}
	}
}

// MARK: - Background Sync Frequency

enum BackgroundSyncFrequency: String, CaseIterable {
	case every15Minutes = "15min"
	case every30Minutes = "30min"
	case hourly = "hourly"
	case every2Hours = "2hours"
	case every4Hours = "4hours"
	case daily = "daily"
	
	var displayName: String {
		switch self {
		case .every15Minutes: return "Every 15 Minutes"
		case .every30Minutes: return "Every 30 Minutes"
		case .hourly: return "Hourly"
		case .every2Hours: return "Every 2 Hours"
		case .every4Hours: return "Every 4 Hours"
		case .daily: return "Daily"
		}
	}
}

// MARK: - Notifications

extension Notification.Name {
	static let backgroundSyncCompleted = Notification.Name("backgroundSyncCompleted")
}

#endif

