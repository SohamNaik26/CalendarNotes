//
//  BookmarkIntegrationModels.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation

struct BookmarkIntegration: Identifiable, Codable, Hashable {
    enum Category: String, Codable, CaseIterable, Identifiable {
        case builtIn
        case urlScheme
        case webhook
        case automation

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .builtIn: return "Built-In"
            case .urlScheme: return "URL Schemes"
            case .webhook: return "Webhooks"
            case .automation: return "Automation"
            }
        }
    }

    enum Status: String, Codable {
        case disconnected
        case connected
        case needsAttention
    }

    let id: String
    var name: String
    var description: String
    var category: Category
    var status: Status
    var supportsTriggers: [IntegrationTrigger]
    var supportsActions: [IntegrationAction]
    var configuration: [String: String]

    static func placeholderIntegrations() -> [BookmarkIntegration] {
        [
            BookmarkIntegration(
                id: "calendar",
                name: "Calendar",
                description: "Link bookmarks with events and reminders.",
                category: .builtIn,
                status: .connected,
                supportsTriggers: [.bookmarkSaved, .bookmarkTagged],
                supportsActions: [.createEvent, .attachToEvent],
                configuration: [:]
            ),
            BookmarkIntegration(
                id: "things",
                name: "Things 3",
                description: "Create to-dos from bookmarks via URL scheme.",
                category: .urlScheme,
                status: .disconnected,
                supportsTriggers: [.manual],
                supportsActions: [.createTask],
                configuration: [:]
            ),
            BookmarkIntegration(
                id: "webhook",
                name: "Generic Webhook",
                description: "Send bookmark events to any endpoint.",
                category: .webhook,
                status: .needsAttention,
                supportsTriggers: [.bookmarkSaved, .bookmarkOpened],
                supportsActions: [.postPayload],
                configuration: ["url": "https://api.example.com/webhook"]
            )
        ]
    }
}

enum IntegrationTrigger: String, Codable, CaseIterable, Identifiable {
    case manual
    case bookmarkSaved
    case bookmarkOpened
    case bookmarkTagged

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .manual: return "Manual"
        case .bookmarkSaved: return "Bookmark Saved"
        case .bookmarkOpened: return "Bookmark Opened"
        case .bookmarkTagged: return "Bookmark Tagged"
        }
    }
}

enum IntegrationAction: String, Codable, CaseIterable, Identifiable {
    case createEvent
    case attachToEvent
    case createNote
    case createTask
    case postPayload
    case openURL

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .createEvent: return "Create Event"
        case .attachToEvent: return "Attach to Event"
        case .createNote: return "Create Note"
        case .createTask: return "Create Task"
        case .postPayload: return "Post Payload"
        case .openURL: return "Open URL"
        }
    }
}

struct IntegrationAuthenticationState: Codable, Hashable {
    enum Method: String, Codable {
        case none
        case apiKey
        case oauth
        case webhookSecret
    }

    var method: Method
    var isAuthenticated: Bool
    var lastValidatedAt: Date?
}
