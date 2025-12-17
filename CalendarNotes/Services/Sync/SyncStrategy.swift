//
//  SyncStrategy.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation

/// Strategy determining when and how sync is executed.
enum SyncStrategy: Equatable {
	/// User explicitly triggers sync via UI.
	case manual
	/// Automatic background sync based on policy and heuristics.
	case automatic
	/// Real-time sync via WebSocket/events.
	case realtime
	/// Sync attempted during app launch/startup.
	case onLaunch
	/// Sync only when on Wi‑Fi (policy enforced).
	case onWiFi
}


