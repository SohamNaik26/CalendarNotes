//
//  BookmarkIntegrationService.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation
import Combine

@MainActor
final class BookmarkIntegrationService: ObservableObject {
    static let shared = BookmarkIntegrationService()

    @Published private(set) var integrations: [BookmarkIntegration]
    let objectWillChange = PassthroughSubject<Void, Never>()

    private let storage = BookmarkIntegrationStorage()

    private init() {
        integrations = storage.loadIntegrations()
        if integrations.isEmpty {
            integrations = BookmarkIntegration.placeholderIntegrations()
        }
    }

    func refresh() {
        integrations = storage.loadIntegrations()
        if integrations.isEmpty {
            integrations = BookmarkIntegration.placeholderIntegrations()
        }
    }

    func updateIntegration(_ integration: BookmarkIntegration) {
        if let index = integrations.firstIndex(where: { $0.id == integration.id }) {
            integrations[index] = integration
        } else {
            integrations.append(integration)
        }
        storage.saveIntegrations(integrations)
    }
}

private final class BookmarkIntegrationStorage {
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let storageURL: URL

    init() {
        let directory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory
        storageURL = directory.appendingPathComponent("bookmark-integrations.json")
        encoder.outputFormatting = [.prettyPrinted]
    }

    func loadIntegrations() -> [BookmarkIntegration] {
        guard let data = try? Data(contentsOf: storageURL) else { return [] }
        return (try? decoder.decode([BookmarkIntegration].self, from: data)) ?? []
    }

    func saveIntegrations(_ integrations: [BookmarkIntegration]) {
        guard let data = try? encoder.encode(integrations) else { return }
        try? fileManager.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: storageURL)
    }
}
