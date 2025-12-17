//
//  WatchSyncManager.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation

/// Coordinator responsible for periodically pushing bookmark summaries to the watch.
@MainActor
final class WatchSyncManager {
    static let shared = WatchSyncManager()

    private let snapshotProvider = WatchBookmarkSnapshotProvider()
    private let connectivity = WatchConnectivityService.shared
    private var timer: Timer?

    private init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleBookmarksChange),
            name: .bookmarksDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleReadLaterChange),
            name: .readLaterUpdated,
            object: nil
        )
        scheduleRecurringSync()
    }

    func requestSync() {
        guard connectivity.syncEnabled else { return }
        let snapshot = snapshotProvider.buildSnapshot()
        Task { await connectivity.sendSnapshot(snapshot) }
    }

    @objc private func handleBookmarksChange() {
        requestSync()
    }

    @objc private func handleReadLaterChange() {
        requestSync()
    }

    private func scheduleRecurringSync() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60 * 15, repeats: true) { [weak self] _ in
			guard let self = self else { return }
			Task { @MainActor in
				self.requestSync()
			}
        }
    }
    
    deinit {
        timer?.invalidate()
        NotificationCenter.default.removeObserver(self)
    }
}

