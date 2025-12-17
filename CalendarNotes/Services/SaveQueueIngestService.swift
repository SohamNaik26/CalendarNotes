//
//  SaveQueueIngestService.swift
//  CalendarNotes
//

import Foundation
import CoreData

@MainActor
final class SaveQueueIngestService {
    static let shared = SaveQueueIngestService()
    private init() {}

    private let core = CoreDataManager.shared
    private var isRunning = false
    private var timer: Timer?

    func start() {
        guard !isRunning else { return }
        isRunning = true
        ensureQueueDirectory()
        // Poll every 10 seconds in foreground
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { await self?.ingestOnce() }
        }
        Task { await ingestOnce() }
    }

    func stop() {
        timer?.invalidate(); timer = nil; isRunning = false
    }

    private func ensureQueueDirectory() {
        guard let dir = SharedContainer.queueDirectory else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    }

    private func loadQueueFiles() -> [URL] {
        guard let dir = SharedContainer.queueDirectory else { return [] }
        let urls = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return urls.filter { $0.pathExtension.lowercased() == "json" }
    }

    struct Payload: Decodable {
        let id: String?
        let url: String
        let title: String?
        let description: String?
        let collection: String?
        let tags: [String]?
        let selection: String?
        let type: String? // "bookmark" | "note"
    }

    private func decode(_ data: Data) -> Payload? {
        // Try JSON first
        if let obj = try? JSONDecoder().decode(Payload.self, from: data) { return obj }
        // Fallback to JSONSerialization map
        if let map = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            guard let url = map["url"] as? String else { return nil }
            return Payload(
                id: map["id"] as? String,
                url: url,
                title: map["title"] as? String,
                description: map["description"] as? String,
                collection: map["collection"] as? String,
                tags: map["tags"] as? [String],
                selection: map["selection"] as? String,
                type: map["type"] as? String
            )
        }
        return nil
    }

    func ingestOnce() async {
        let files = loadQueueFiles()
        guard !files.isEmpty else { return }
        for url in files {
            do {
                let data = try Data(contentsOf: url)
                guard let p = decode(data) else { continue }
                try await save(payload: p)
                try? FileManager.default.removeItem(at: url)
            } catch {
                // Keep file for retry
            }
        }
    }

    private func save(payload: Payload) async throws {
        if (payload.type ?? "bookmark") == "note" {
            // Create note referencing URL
            let template = payload.selection.map { "\n> \($0)\n\n" } ?? ""
            let _ = try BookmarkNoteLinkService.shared.createNote(from: makeTempBookmark(payload: payload), template: template)
            return
        }
        // Bookmark
        let tags = payload.tags ?? SmartBookmarkService.shared.suggestTags(title: payload.title, description: payload.description, urlString: payload.url)
        let _ = try core.createBookmark(
            url: payload.url,
            title: payload.title ?? URL(string: payload.url)?.host ?? "Bookmark",
            description: payload.description,
            tags: tags,
            collectionName: payload.collection
        )
    }

    private func makeTempBookmark(payload: Payload) -> Bookmark {
        // Create a transient bookmark object in memory to feed into note creation
        let b = Bookmark(context: core.viewContext, url: payload.url, title: payload.title ?? "Bookmark")
        b.bookmarkDescription = payload.description
        return b
    }
}


