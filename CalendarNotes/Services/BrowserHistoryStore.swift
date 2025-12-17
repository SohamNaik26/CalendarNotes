//
//  BrowserHistoryStore.swift
//  CalendarNotes
//
//  Persists lightweight browser history and reading positions.
//

import Foundation

struct BrowserHistoryEntry: Codable, Identifiable {
    var id: UUID
    var url: URL
    var title: String
    var lastVisited: Date
    var visitCount: Int
    var scrollOffset: Double
    var sectionBookmarks: [BrowserSectionBookmark]
}

struct BrowserSectionBookmark: Codable, Identifiable, Equatable {
    var id: UUID
    var title: String
    var offset: Double
    var createdAt: Date
}

final class BrowserHistoryStore {
    static let shared = BrowserHistoryStore()
    private init() { load() }

    private let storeURL: URL = {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folder = directory.appendingPathComponent("BrowserHistory", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("history.json")
    }()

    private let queue = DispatchQueue(label: "BrowserHistoryStoreQueue", attributes: .concurrent)
    private var entries: [BrowserHistoryEntry] = []

    func recordVisit(url: URL, title: String) {
        queue.async(flags: .barrier) {
            if let index = self.entries.firstIndex(where: { $0.url == url }) {
                self.entries[index].title = title
                self.entries[index].lastVisited = Date()
                self.entries[index].visitCount += 1
            } else {
                self.entries.append(BrowserHistoryEntry(
                    id: UUID(),
                    url: url,
                    title: title,
                    lastVisited: Date(),
                    visitCount: 1,
                    scrollOffset: 0,
                    sectionBookmarks: []
                ))
            }
            self.save()
        }
    }

    func updateScrollPosition(for url: URL, offset: Double) {
        queue.async(flags: .barrier) {
            guard let index = self.entries.firstIndex(where: { $0.url == url }) else { return }
            self.entries[index].scrollOffset = offset
            self.save()
        }
    }

    func scrollPosition(for url: URL) -> Double {
        queue.sync { entries.first(where: { $0.url == url })?.scrollOffset ?? 0 }
    }

    func search(query: String, limit: Int = 6) -> [BrowserSuggestion] {
        guard !query.isEmpty else { return [] }
        let currentEntries = queue.sync { entries }
        return currentEntries
            .filter { $0.title.localizedCaseInsensitiveContains(query) || $0.url.absoluteString.localizedCaseInsensitiveContains(query) }
            .sorted { $0.lastVisited > $1.lastVisited }
            .prefix(limit)
            .map { entry in
                BrowserSuggestion(
                    title: entry.title,
                    subtitle: entry.url.absoluteString,
                    url: entry.url,
                    relevance: Double(entry.visitCount),
                    source: .history
                )
            }
    }

    func allEntries() -> [BrowserHistoryEntry] {
        queue.sync { entries.sorted { $0.lastVisited > $1.lastVisited } }
    }

    func sectionBookmarks(for url: URL) -> [BrowserSectionBookmark] {
        queue.sync { entries.first(where: { $0.url == url })?.sectionBookmarks ?? [] }
    }

    func addSectionBookmark(for url: URL, title: String, offset: Double) -> BrowserSectionBookmark? {
        var newBookmark: BrowserSectionBookmark?
        queue.sync(flags: .barrier) {
            guard let index = entries.firstIndex(where: { $0.url == url }) else { return }
            let section = BrowserSectionBookmark(id: UUID(), title: title, offset: offset, createdAt: Date())
            entries[index].sectionBookmarks.append(section)
            newBookmark = section
            save()
        }
        return newBookmark
    }

    func removeSectionBookmark(for url: URL, id: UUID) {
        queue.async(flags: .barrier) {
            guard let entryIndex = self.entries.firstIndex(where: { $0.url == url }) else { return }
            self.entries[entryIndex].sectionBookmarks.removeAll { $0.id == id }
            self.save()
        }
    }

    func clear() {
        queue.async(flags: .barrier) {
            self.entries.removeAll()
            self.save()
        }
    }

    private func load() {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }
        do {
            let data = try Data(contentsOf: storeURL)
            let decoded = try JSONDecoder().decode([BrowserHistoryEntry].self, from: data)
            queue.sync(flags: .barrier) {
                self.entries = decoded
            }
        } catch {
            queue.sync(flags: .barrier) {
                self.entries = []
            }
        }
    }

    private func save() {
        queue.async(flags: .barrier) {
            do {
                let data = try JSONEncoder().encode(self.entries)
                try data.write(to: self.storeURL, options: [.atomic])
            } catch {
                // ignore silently
            }
        }
    }
}


