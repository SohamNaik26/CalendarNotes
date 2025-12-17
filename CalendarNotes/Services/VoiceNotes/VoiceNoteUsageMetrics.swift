//
//  VoiceNoteUsageMetrics.swift
//  CalendarNotes
//
//  Created by GPT-5.1 Codex on 17/11/25.
//

import Foundation

final class VoiceNoteUsageMetrics {
	static let shared = VoiceNoteUsageMetrics()
	
	private let defaults = UserDefaults.standard
	private let creationCountKey = "voiceNotes.metrics.creationCount"
	private let lastCreatedAtKey = "voiceNotes.metrics.lastCreatedAt"
	
	private init() {}
	
	func trackCreation() {
		let current = defaults.integer(forKey: creationCountKey)
		defaults.set(current + 1, forKey: creationCountKey)
		defaults.set(Date(), forKey: lastCreatedAtKey)
	}
	
	var totalVoiceNotesCreated: Int {
		defaults.integer(forKey: creationCountKey)
	}
	
	var lastCreatedAt: Date? {
		defaults.object(forKey: lastCreatedAtKey) as? Date
	}
}

