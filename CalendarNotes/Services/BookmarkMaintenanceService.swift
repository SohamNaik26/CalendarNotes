//
//  BookmarkMaintenanceService.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation
import Combine

@MainActor
final class BookmarkMaintenanceService: ObservableObject {
    static let shared = BookmarkMaintenanceService()

    @Published private(set) var healthSnapshot: BookmarkHealthSnapshot
    @Published private(set) var tasks: [MaintenanceTaskSummary]
    let objectWillChange = PassthroughSubject<Void, Never>()

    private let coreData = CoreDataManager.shared
    private var runningTask: Task<Void, Never>?

    private init() {
        self.healthSnapshot = BookmarkHealthSnapshot.placeholder()
        self.tasks = [
            MaintenanceTaskSummary(type: .linkCheck, lastRun: Date().addingTimeInterval(-86400 * 4), nextRun: Date().addingTimeInterval(86400 * 3), status: .scheduled),
            MaintenanceTaskSummary(type: .duplicateScan, lastRun: Date().addingTimeInterval(-86400 * 12), nextRun: Date().addingTimeInterval(86400 * 18), status: .scheduled),
            MaintenanceTaskSummary(type: .cleanup, lastRun: Date().addingTimeInterval(-86400 * 30), nextRun: Date().addingTimeInterval(86400 * 7), status: .scheduled)
        ]
    }

    func refreshHealth() {
        runningTask?.cancel()
        runningTask = Task { [weak self] in
            guard let self else { return }
            do {
                let snapshot = try await self.computeHealthSnapshot()
                if Task.isCancelled { return }
                await MainActor.run {
                    self.healthSnapshot = snapshot
                }
            } catch {
                // For now we swallow errors; future work can surface them.
            }
        }
    }

    func cancelRefresh() {
        runningTask?.cancel()
        runningTask = nil
    }

    private func computeHealthSnapshot() async throws -> BookmarkHealthSnapshot {
        try await Task.sleep(nanoseconds: 120_000_000)
        return BookmarkHealthSnapshot.placeholder()
    }
}
