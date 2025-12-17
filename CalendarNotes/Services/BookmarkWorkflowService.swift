//
//  BookmarkWorkflowService.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation
import Combine

@MainActor
final class BookmarkWorkflowService: ObservableObject {
    static let shared = BookmarkWorkflowService()

    @Published private(set) var workflows: [BookmarkWorkflow]
    @Published private(set) var logs: [WorkflowExecutionLog]

    private let storage = BookmarkWorkflowStorage()
    private var cancellables = Set<AnyCancellable>()

    private init() {
        workflows = storage.loadWorkflows()
        logs = storage.loadLogs()
    }

    // MARK: - Workflow management

    func addWorkflow(_ workflow: BookmarkWorkflow) {
        workflows.append(workflow)
        persistWorkflows()
    }

    func updateWorkflow(_ workflow: BookmarkWorkflow) {
        guard let idx = workflows.firstIndex(where: { $0.id == workflow.id }) else { return }
        workflows[idx] = workflow
        persistWorkflows()
    }

    func removeWorkflow(id: UUID) {
        workflows.removeAll { $0.id == id }
        persistWorkflows()
    }

    func setWorkflowEnabled(_ id: UUID, enabled: Bool) {
        guard let idx = workflows.firstIndex(where: { $0.id == id }) else { return }
        workflows[idx].status = enabled ? .enabled : .disabled
        workflows[idx].updatedAt = Date()
        persistWorkflows()
    }

    // MARK: - Execution stubs

    func handleTrigger(kind: WorkflowTrigger.Kind, bookmark: Bookmark) async {
        let candidates = workflows.filter { $0.status == .enabled && $0.trigger.kind == kind }
        guard !candidates.isEmpty else { return }
        for workflow in candidates {
            await execute(workflow: workflow, bookmark: bookmark)
        }
    }

    private func execute(workflow: BookmarkWorkflow, bookmark: Bookmark) async {
        let start = Date()
        do {
            // Placeholder execution pipeline – actual logic to be implemented later.
            for action in workflow.actions {
                try await perform(action: action, on: bookmark)
            }
            appendLog(workflowID: workflow.id, startedAt: start, result: .success, message: nil)
        } catch {
            appendLog(workflowID: workflow.id, startedAt: start, result: .failure, message: error.localizedDescription)
        }
    }

    private func perform(action: WorkflowAction, on bookmark: Bookmark) async throws {
        // Placeholder for future action handlers. For now, simulate delay if requested.
        if let delay = action.delaySeconds, delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        }
    }

    // MARK: - Logging

    private func appendLog(workflowID: UUID, startedAt: Date, result: WorkflowExecutionLog.Result, message: String?) {
        let finished = Date()
        let log = WorkflowExecutionLog(
            workflowID: workflowID,
            startedAt: startedAt,
            finishedAt: finished,
            result: result,
            detail: message,
            metrics: ["duration": finished.timeIntervalSince(startedAt)]
        )
        logs.insert(log, at: 0)
        persistLogs()
    }

    // MARK: - Persistence

    private func persistWorkflows() {
        storage.saveWorkflows(workflows)
    }

    private func persistLogs() {
        storage.saveLogs(logs)
    }
}

private final class BookmarkWorkflowStorage {
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private let workflowsURL: URL
    private let logsURL: URL

    init() {
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        workflowsURL = directory.appendingPathComponent("bookmark-workflows.json")
        logsURL = directory.appendingPathComponent("bookmark-workflow-logs.json")
        encoder.outputFormatting = [.prettyPrinted]
    }

    func loadWorkflows() -> [BookmarkWorkflow] {
        guard let data = try? Data(contentsOf: workflowsURL) else { return [] }
        return (try? decoder.decode([BookmarkWorkflow].self, from: data)) ?? []
    }

    func loadLogs() -> [WorkflowExecutionLog] {
        guard let data = try? Data(contentsOf: logsURL) else { return [] }
        return (try? decoder.decode([WorkflowExecutionLog].self, from: data)) ?? []
    }

    func saveWorkflows(_ workflows: [BookmarkWorkflow]) {
        guard let data = try? encoder.encode(workflows) else { return }
        try? fileManager.createDirectory(at: workflowsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: workflowsURL)
    }

    func saveLogs(_ logs: [WorkflowExecutionLog]) {
        guard let data = try? encoder.encode(logs) else { return }
        try? fileManager.createDirectory(at: logsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: logsURL)
    }
}
