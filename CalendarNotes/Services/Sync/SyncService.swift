//
//  SyncService.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import Combine
import CoreData
import Network

#if canImport(BackgroundTasks)
import BackgroundTasks
#endif

/// Main sync coordinator for CalendarNotes.
@MainActor
final class SyncService: ObservableObject {
	static let shared = SyncService()
	
	@Published private(set) var state: SyncState = .idle
	@Published private(set) var activity = SyncStatus()
	@Published private(set) var strategy: SyncStrategy = .automatic
	
	private let userDefaults = UserDefaults.standard
	private let offlineQueue = OfflineQueue.shared
	private let connectivityMonitor = ConnectivityMonitor.shared
	private let policyStore = SyncPolicyStore.shared
	
	private let backgroundQueue = DispatchQueue(label: "SyncService.Queue", qos: .utility)
	private var cancellables = Set<AnyCancellable>()
	
	private let deviceIdKey = "sync.deviceId"
	private let lastSyncKeyPrefix = "sync.last."
	
	// MARK: - Init
	
	private var notificationObserver: NSObjectProtocol?
	
	private init() {
		ensureDeviceId()
		bindConnectivity()
		refreshPendingCount()
		notificationObserver = NotificationCenter.default.addObserver(forName: OfflineOperationQueue.Notifications.queueChanged, object: nil, queue: .main) { [weak self] _ in
			guard let self else { return }
			Task { @MainActor in
				self.activity.pendingChangesCount = OfflineOperationQueue.shared.pendingOperations().count
			}
		}
	}
	
	deinit {
		if let observer = notificationObserver {
			NotificationCenter.default.removeObserver(observer)
		}
		cancellables.removeAll()
	}
	
	// MARK: - Public API
	
	func setStrategy(_ strategy: SyncStrategy) {
		self.strategy = strategy
	}
	
	func syncAll(reason: SyncStrategy = .automatic) {
		guard canSync(for: reason) else { return }
		state = .syncing(progress: 0)
		activity.isInProgress = true
		activity.isPending = pendingChangesCount() > 0
		let operationsCount = pendingChangesCount()
		
		Task.detached(priority: .utility) { [weak self] in
			guard let self = self else { return }
			
			let groups: [() async -> Result<Int, Error>] = [
				{ await self.syncCalendarEvents() },
				{ await self.syncNotes() },
				{ await self.syncTodos() },
				{ await self.syncBookmarks() },
				{ await self.syncVoiceNotes() },
				{ await self.syncCollections() }
			]
			
			Task { @MainActor in
				self.activity.isInProgress = true
			}
			
			var completed = 0
			for group in groups {
				let result = await group()
				completed += 1
				let stepProgress = Double(completed) / Double(groups.count)
				Task { @MainActor in
					self.state = .syncing(progress: stepProgress)
					self.activity.lastSyncDate = Date()
					switch result {
					case .success(let count):
						self.activity.pendingChangesCount = max(0, operationsCount - count)
					case .failure(let error):
						self.activity.lastSyncErrorMessage = error.localizedDescription
					}
				}
			}
			
			Task { @MainActor in
				self.state = .succeeded
				self.activity.isInProgress = false
				self.activity.isPending = self.pendingChangesCount() > 0
				
				// Schedule next background sync after manual sync
				#if os(iOS)
				BackgroundSyncManager.shared.scheduleSyncAfterManualSync()
				#endif
				
				DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
					if self.state == .succeeded {
						self.state = .idle
					}
				}
			}
		}
	}
	
	// MARK: - Entity Sync Stubs
	
	func syncCalendarEvents() async -> Result<Int, Error> {
		await performEntitySync(entityName: "calendar_events") {
			// TODO: Integrate with EventKitManager and CoreData merges
			return 0
		}
	}
	
	func syncNotes() async -> Result<Int, Error> {
		await performEntitySync(entityName: "notes") {
			return 0
		}
	}
	
	func syncTodos() async -> Result<Int, Error> {
		await performEntitySync(entityName: "todos") {
			return 0
		}
	}
	
	func syncBookmarks() async -> Result<Int, Error> {
		await performEntitySync(entityName: "bookmarks") {
			return 0
		}
	}
	
	func syncVoiceNotes() async -> Result<Int, Error> {
		await performEntitySync(entityName: "voice_notes") {
			return 0
		}
	}
	
	func syncCollections() async -> Result<Int, Error> {
		await performEntitySync(entityName: "collections") {
			return 0
		}
	}
	
	// MARK: - Background Sync
	
	#if os(iOS)
	func registerBackgroundTasks() {
		if #available(iOS 13.0, *) {
			BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.calendarNotes.sync.refresh", using: nil) { [weak self] task in
				self?.handleAppRefresh(task: task)
			}
		}
	}
	#endif
	
	#if os(iOS)
	func scheduleBackgroundSync() {
		if #available(iOS 13.0, *) {
			let request = BGAppRefreshTaskRequest(identifier: "com.calendarNotes.sync.refresh")
			request.earliestBeginDate = Date(timeIntervalSinceNow: suggestedBackgroundInterval())
			do {
				try BGTaskScheduler.shared.submit(request)
			} catch {
				print("Failed to schedule background sync: \(error)")
			}
		}
	}
	#endif
	
	#if os(iOS)
	@available(iOS 13.0, *)
	private func handleAppRefresh(task: BGTask) {
		scheduleBackgroundSync()
		let operation = BlockOperation { [weak self] in
			guard let self else { return }
			Task { @MainActor in
				self.syncAll(reason: .automatic)
			}
		}
		task.expirationHandler = {
			operation.cancel()
		}
		operation.completionBlock = {
			task.setTaskCompleted(success: true)
		}
		OperationQueue().addOperation(operation)
	}
	#endif
	
	// MARK: - Conflict Resolution
	
	enum ConflictResolution {
		case lastWriteWins
		case clientWins
		case serverWins
		case manual
		case mergeArrays
	}
	
	func resolveConflict<T>(local: T, remote: T, strategy: ConflictResolution) -> T {
		switch strategy {
		case .lastWriteWins:
			return remote
		case .clientWins:
			return local
		case .serverWins:
			return remote
		case .manual:
			return remote
		case .mergeArrays:
			return remote
		}
	}
	
	// MARK: - Helpers
	
	private func performEntitySync(entityName: String, work: () -> Int) async -> Result<Int, Error> {
		let lastSync = lastSyncDate(for: entityName)
		
		// 1. Fetch local changes since last sync (stub)
		_ = lastSync
		
		// 2. Push local changes to server (stub)
		// 3. Fetch server changes since last sync (stub)
		// 4. Merge server changes to local (stub)
		// 5. Handle conflicts (stub)
		
		let processed = work()
		
		// 7. Update sync timestamp
		setLastSyncDate(Date(), for: entityName)
		
		// 8. Update UI is driven by @Published properties
		return .success(processed)
	}
	
	private func pendingChangesCount() -> Int {
		offlineQueue.load().count
	}
	
	private func bindConnectivity() {
		connectivityMonitor
			.publisher
			.receive(on: DispatchQueue.main)
			.sink { [weak self] path in
				guard let self else { return }
				let isConnected = path.status == .satisfied
				if !isConnected {
					self.state = .offline
					self.activity.isInProgress = false
				} else if self.state == .offline {
					self.state = .idle
				}
			}
			.store(in: &cancellables)
	}
	
	private func ensureDeviceId() {
		if userDefaults.string(forKey: deviceIdKey) == nil {
			userDefaults.set(UUID().uuidString, forKey: deviceIdKey)
		}
	}
	
	func deviceId() -> String {
		userDefaults.string(forKey: deviceIdKey) ?? {
			let id = UUID().uuidString
			userDefaults.set(id, forKey: deviceIdKey)
			return id
		}()
	}
	
	private func lastSyncDate(for entity: String) -> Date? {
		userDefaults.object(forKey: lastSyncKeyPrefix + entity) as? Date
	}
	
	private func setLastSyncDate(_ date: Date, for entity: String) {
		userDefaults.set(date, forKey: lastSyncKeyPrefix + entity)
		activity.lastSyncDate = date
	}
	
	private func canSync(for reason: SyncStrategy) -> Bool {
		let policy = policyStore.policy
		if policy.wifiOnly, connectivityMonitor.currentPath?.connectionQuality != .excellent {
			state = .failed(error: "Wi‑Fi required for sync.")
			return false
		}
		if state == .syncing(progress: 0) {
			return false
		}
		return true
	}
	
	private func refreshPendingCount() {
		activity.pendingChangesCount = OfflineOperationQueue.shared.pendingOperations().count
	}
	
	private func suggestedBackgroundInterval() -> TimeInterval {
		switch policyStore.policy.frequency {
		case .manual: return 6 * 60 * 60
		case .hourly: return 60 * 60
		case .twiceDaily: return 12 * 60 * 60
		case .daily: return 24 * 60 * 60
		}
	}
}


