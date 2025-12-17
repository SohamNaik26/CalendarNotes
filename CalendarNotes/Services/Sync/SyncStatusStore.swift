//
//  SyncStatusStore.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import Combine

public enum SyncIndicatorState: Equatable {
	case syncing(progress: Double)
	case synced(last: Date?)
	case error(message: String)
	case offline
	case pending(count: Int)
}

public struct PerEntitySyncStatus: Identifiable, Equatable {
	public enum State: Equatable {
		case synced(total: Int)
		case syncing(done: Int, total: Int)
		case error(failed: Int)
		case pending(changes: Int)
	}
	
	public let id: String
	public let name: String
	public let iconSystemName: String
	public let state: State
}

public struct SyncEventLog: Identifiable, Codable, Equatable {
	public enum Level: String, Codable { case info, warning, error }
	public let id: String
	public let timestamp: Date
	public let message: String
	public let level: Level
	public let items: Int
}

final class SyncStatusStore: ObservableObject {
	static let shared = SyncStatusStore()
	private init() {}
	
	@Published var indicator: SyncIndicatorState = .synced(last: nil)
	@Published var overallProgress: Double = 0
	@Published var perEntity: [PerEntitySyncStatus] = []
	@Published var lastSuccessfulSync: Date?
	@Published var nextScheduledSync: Date?
	@Published var networkStatusDescription: String = "Unknown"
	@Published var pendingOperations: Int = 0
	@Published var recentEvents: [SyncEventLog] = []
	
	// Settings bindings (UserDefaults-backed)
	private let autoSyncKey = "realtimeSyncEnabled"
	private let wifiOnlyKey = "realtimeSyncWifiOnly"
	private let batterySaverKey = "realtimeSyncBatterySaver"
	private let showIndicatorKey = "showSyncIndicator"
	private let backgroundSyncKey = "backgroundSyncEnabled"
	private let frequencyKey = "syncFrequencyMinutes"
	
	var autoSyncEnabled: Bool {
		get { UserDefaults.standard.bool(forKey: autoSyncKey) }
		set { UserDefaults.standard.set(newValue, forKey: autoSyncKey) }
	}
	
	var wifiOnly: Bool {
		get { UserDefaults.standard.bool(forKey: wifiOnlyKey) }
		set { UserDefaults.standard.set(newValue, forKey: wifiOnlyKey) }
	}
	
	var batterySaver: Bool {
		get { UserDefaults.standard.bool(forKey: batterySaverKey) }
		set { UserDefaults.standard.set(newValue, forKey: batterySaverKey) }
	}
	
	var showIndicator: Bool {
		get { UserDefaults.standard.object(forKey: showIndicatorKey) as? Bool ?? true }
		set { UserDefaults.standard.set(newValue, forKey: showIndicatorKey) }
	}
	
	var backgroundSyncEnabled: Bool {
		get { UserDefaults.standard.object(forKey: backgroundSyncKey) as? Bool ?? true }
		set { UserDefaults.standard.set(newValue, forKey: backgroundSyncKey) }
	}
	
	var frequencyMinutes: Int {
		get { let v = UserDefaults.standard.integer(forKey: frequencyKey); return v == 0 ? 15 : v }
		set { UserDefaults.standard.set(newValue, forKey: frequencyKey) }
	}
	
	func appendEvent(_ log: SyncEventLog) {
		recentEvents.insert(log, at: 0)
		if recentEvents.count > 200 {
			recentEvents.removeLast(recentEvents.count - 200)
		}
	}
}


