//
//  SyncEntity.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation

/// Common fields and sync behavior expected for syncable entities.
protocol SyncEntity {
	/// Unique identifier of the entity (stable across devices).
	var id: UUID { get }
	/// User or account identifier owner of the entity.
	var user_id: UUID { get }
	/// Timestamp when this record was last successfully synced.
	var synced_at: Date? { get set }
	/// Timestamp when this record was last updated locally.
	var updated_at: Date { get set }
	/// Timestamp when this record was marked deleted (tombstone).
	var deleted_at: Date? { get set }
	/// Whether this record requires sync with the server.
	func needsSync() -> Bool
}


