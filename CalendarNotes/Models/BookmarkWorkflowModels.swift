//
//  BookmarkWorkflowModels.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation

struct BookmarkWorkflow: Identifiable, Codable, Hashable {
    enum Status: String, Codable {
        case enabled
        case disabled
    }

    let id: UUID
    var name: String
    var status: Status
    var trigger: WorkflowTrigger
    var conditions: [WorkflowCondition]
    var actions: [WorkflowAction]
    var schedule: WorkflowSchedule?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        status: Status = .enabled,
        trigger: WorkflowTrigger,
        conditions: [WorkflowCondition] = [],
        actions: [WorkflowAction],
        schedule: WorkflowSchedule? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.status = status
        self.trigger = trigger
        self.conditions = conditions
        self.actions = actions
        self.schedule = schedule
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct WorkflowTrigger: Codable, Hashable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case bookmarkSaved
        case bookmarkOpened
        case bookmarkTagged
        case bookmarkInCollectionDays
        case bookmarkNeverOpenedDays
        case bookmarkDomainMatch

        var id: String { rawValue }
    }

    var kind: Kind
    var parameters: [String: String]

    init(kind: Kind, parameters: [String: String] = [:]) {
        self.kind = kind
        self.parameters = parameters
    }
}

struct WorkflowCondition: Codable, Hashable, Identifiable {
    enum Comparator: String, Codable {
        case equals
        case notEquals
        case contains
        case greaterThan
        case lessThan
        case matches
    }

    let id: UUID
    var field: String
    var comparator: Comparator
    var value: String

    init(id: UUID = UUID(), field: String, comparator: Comparator, value: String) {
        self.id = id
        self.field = field
        self.comparator = comparator
        self.value = value
    }
}

struct WorkflowAction: Codable, Hashable, Identifiable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case addTag
        case moveToCollection
        case sendURLScheme
        case createDraftEmail
        case postWebhook
        case addToService
        case generatePDF
        case sendHomeAutomation

        var id: String { rawValue }
    }

    let id: UUID
    var kind: Kind
    var parameters: [String: String]
    var delaySeconds: TimeInterval?

    init(id: UUID = UUID(), kind: Kind, parameters: [String: String] = [:], delaySeconds: TimeInterval? = nil) {
        self.id = id
        self.kind = kind
        self.parameters = parameters
        self.delaySeconds = delaySeconds
    }
}

struct WorkflowSchedule: Codable, Hashable {
    enum Frequency: String, Codable, CaseIterable {
        case once
        case daily
        case weekly
        case monthly
    }

    var frequency: Frequency
    var timeOfDay: DateComponents?
    var weekdays: Set<Int>?

    init(frequency: Frequency, timeOfDay: DateComponents? = nil, weekdays: Set<Int>? = nil) {
        self.frequency = frequency
        self.timeOfDay = timeOfDay
        self.weekdays = weekdays
    }
}

struct WorkflowExecutionLog: Identifiable, Codable, Hashable {
    enum Result: String, Codable {
        case success
        case failure
        case skipped
    }

    let id: UUID
    let workflowID: UUID
    let startedAt: Date
    let finishedAt: Date
    let result: Result
    let detail: String?
    let metrics: [String: Double]

    init(
        id: UUID = UUID(),
        workflowID: UUID,
        startedAt: Date,
        finishedAt: Date,
        result: Result,
        detail: String? = nil,
        metrics: [String: Double] = [:]
    ) {
        self.id = id
        self.workflowID = workflowID
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.result = result
        self.detail = detail
        self.metrics = metrics
    }
}
