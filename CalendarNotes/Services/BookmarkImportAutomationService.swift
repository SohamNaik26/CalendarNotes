//
//  BookmarkImportAutomationService.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation
import Combine
import UniformTypeIdentifiers

/// Central coordinator for advanced bookmark import pipelines and automation features.
@MainActor
final class BookmarkImportAutomationService: ObservableObject {
    static let shared = BookmarkImportAutomationService()

    enum AutomationError: LocalizedError {
        case integrationUnavailable(String)
        case invalidConfiguration(String)
        case notImplemented
        case sourceNotRegistered
        case historyUnavailable

        var errorDescription: String? {
            switch self {
            case .integrationUnavailable(let message): return message
            case .invalidConfiguration(let message): return message
            case .notImplemented: return "This integration has not been implemented yet."
            case .sourceNotRegistered: return "The requested import source is not registered."
            case .historyUnavailable: return "Import history could not be retrieved."
            }
        }
    }

    // MARK: - Published automation toggles

    @Published private(set) var clipboardWatchingEnabled: Bool
    @Published private(set) var emailSources: [String]
    @Published private(set) var rssFeeds: [URL]
    @Published private(set) var pocketIntegrationActive: Bool
    @Published private(set) var instapaperIntegrationActive: Bool
    @Published private(set) var readLaterIntegrations: Set<String>
    @Published private(set) var lastJobs: [BookmarkImportJob]

    private let historyStore = BookmarkImportHistoryStore()
    private let defaults = UserDefaults.standard
    private var cancellables = Set<AnyCancellable>()

    private init() {
        clipboardWatchingEnabled = defaults.bool(forKey: Keys.clipboardWatchingEnabled)
        emailSources = defaults.stringArray(forKey: Keys.emailSources) ?? []
        rssFeeds = (defaults.array(forKey: Keys.rssFeeds) as? [String])?
            .compactMap { URL(string: $0) } ?? []
        pocketIntegrationActive = defaults.bool(forKey: Keys.pocketIntegrationActive)
        instapaperIntegrationActive = defaults.bool(forKey: Keys.instapaperIntegrationActive)
        readLaterIntegrations = Set(defaults.stringArray(forKey: Keys.readLaterIntegrations) ?? [])
        lastJobs = historyStore.loadRecentJobs()
    }

    // MARK: - Browser extension capture

    func captureCurrentTab(metadata: [String: Any]) async throws -> BookmarkImportJob {
        let job = BookmarkImportJob(
            source: .browserExtension,
            itemCount: 1,
            status: .queued,
            summary: "Captured \(metadata["title"] as? String ?? "page") from browser extension",
            optionsSummary: ["mode": "single"]
        )
        historyStore.append(job)
        cache(job: job)
        return job
    }

    func importOpenTabs(tabs: [[String: Any]]) async throws -> BookmarkImportJob {
        let job = BookmarkImportJob(
            source: .browserTabs,
            itemCount: tabs.count,
            status: .queued,
            summary: "Queued \(tabs.count) open tabs for import",
            optionsSummary: ["mode": "batch"]
        )
        historyStore.append(job)
        cache(job: job)
        return job
    }

    func importBrowserFolder(named name: String, bookmarks: [[String: Any]]) async throws -> BookmarkImportJob {
        let job = BookmarkImportJob(
            source: .browserFolder,
            itemCount: bookmarks.count,
            status: .queued,
            summary: "Imported folder \(name)",
            optionsSummary: ["preserveStructure": "true"]
        )
        historyStore.append(job)
        cache(job: job)
        return job
    }

    // MARK: - Clipboard & automatic sources

    func setClipboardWatchingEnabled(_ enabled: Bool) {
        clipboardWatchingEnabled = enabled
        defaults.set(enabled, forKey: Keys.clipboardWatchingEnabled)
        if enabled {
            scheduleClipboardPolling()
        }
    }

    private func scheduleClipboardPolling() {
        // Placeholder scheduling - actual implementation will hook into platform-specific APIs.
        Task.detached {
            // Intentionally left blank for now.
        }
    }

    func registerEmailSource(address: String) throws {
        guard address.contains("@") else {
            throw AutomationError.invalidConfiguration("Email address appears invalid.")
        }
        if !emailSources.contains(address) {
            emailSources.append(address)
            defaults.set(emailSources, forKey: Keys.emailSources)
        }
    }

    func unregisterEmailSource(address: String) {
        emailSources.removeAll { $0.caseInsensitiveCompare(address) == .orderedSame }
        defaults.set(emailSources, forKey: Keys.emailSources)
    }

    func addRSSFeed(_ url: URL) {
        guard !rssFeeds.contains(url) else { return }
        rssFeeds.append(url)
        defaults.set(rssFeeds.map(\.absoluteString), forKey: Keys.rssFeeds)
    }

    func removeRSSFeed(_ url: URL) {
        rssFeeds.removeAll { $0 == url }
        defaults.set(rssFeeds.map(\.absoluteString), forKey: Keys.rssFeeds)
    }

    func enablePocketIntegration(token: String) {
        defaults.set(token, forKey: Keys.pocketToken)
        pocketIntegrationActive = true
        defaults.set(true, forKey: Keys.pocketIntegrationActive)
    }

    func disablePocketIntegration() {
        defaults.removeObject(forKey: Keys.pocketToken)
        pocketIntegrationActive = false
        defaults.set(false, forKey: Keys.pocketIntegrationActive)
    }

    func enableInstapaperIntegration(username: String, password: String) {
        defaults.set(username, forKey: Keys.instapaperUsername)
        defaults.set(password, forKey: Keys.instapaperPassword)
        instapaperIntegrationActive = true
        defaults.set(true, forKey: Keys.instapaperIntegrationActive)
    }

    func disableInstapaperIntegration() {
        defaults.removeObject(forKey: Keys.instapaperUsername)
        defaults.removeObject(forKey: Keys.instapaperPassword)
        instapaperIntegrationActive = false
        defaults.set(false, forKey: Keys.instapaperIntegrationActive)
    }

    func registerReadLaterIntegration(identifier: String) {
        readLaterIntegrations.insert(identifier)
        defaults.set(Array(readLaterIntegrations), forKey: Keys.readLaterIntegrations)
    }

    func unregisterReadLaterIntegration(identifier: String) {
        readLaterIntegrations.remove(identifier)
        defaults.set(Array(readLaterIntegrations), forKey: Keys.readLaterIntegrations)
    }

    func performAutomaticSync(for source: BookmarkImportSourceType) async throws -> BookmarkImportJob {
        let job = BookmarkImportJob(
            source: source,
            status: .queued,
            summary: "Triggered automatic sync for \(source.displayName)"
        )
        historyStore.append(job)
        cache(job: job)
        return job
    }

    // MARK: - URL extraction helpers

    func extractURLs(fromText text: String) -> [URL] {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, options: [], range: NSRange(location: 0, length: (text as NSString).length)) ?? []
        return matches.compactMap { $0.url }
    }

    func extractURLs(fromPDFData data: Data) throws -> [URL] {
        // Placeholder: In future this will parse PDF annotations.
        // For now perform a naive scan for http(s) strings.
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return extractURLs(fromText: text)
    }

    func extractURLs(fromEMLData data: Data) -> [URL] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return extractURLs(fromText: text)
    }

    func extractURLs(fromNotesData data: Data) -> [URL] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        return extractURLs(fromText: text)
    }

    // MARK: - History & rollback

    func record(job: BookmarkImportJob) {
        historyStore.append(job)
        cache(job: job)
    }

    func loadHistory() -> [BookmarkImportJob] {
        let jobs = historyStore.loadRecentJobs()
        lastJobs = jobs
        return jobs
    }

    func job(withID id: UUID) -> BookmarkImportJob? {
        historyStore.job(withID: id)
    }

    func rollback(jobID: UUID) throws {
        guard var job = historyStore.job(withID: jobID) else {
            throw AutomationError.historyUnavailable
        }
        job.status = .rolledBack
        historyStore.update(job)
        refreshHistoryCache()
    }

    func clearHistory() {
        historyStore.clear()
        lastJobs = []
    }

    // MARK: - Persistence

    private enum Keys {
        static let clipboardWatchingEnabled = "bookmark.automation.clipboardEnabled"
        static let emailSources = "bookmark.automation.emailSources"
        static let rssFeeds = "bookmark.automation.rssFeeds"
        static let pocketIntegrationActive = "bookmark.automation.pocketActive"
        static let pocketToken = "bookmark.automation.pocketToken"
        static let instapaperIntegrationActive = "bookmark.automation.instapaperActive"
        static let instapaperUsername = "bookmark.automation.instapaperUsername"
        static let instapaperPassword = "bookmark.automation.instapaperPassword"
        static let readLaterIntegrations = "bookmark.automation.readLaterIntegrations"
    }

    private func refreshHistoryCache() {
        lastJobs = historyStore.loadRecentJobs()
    }

    private func cache(job: BookmarkImportJob) {
        lastJobs.insert(job, at: 0)
        if lastJobs.count > 50 {
            lastJobs = Array(lastJobs.prefix(50))
        }
    }
}

// MARK: - Lightweight persistence for import history

final class BookmarkImportHistoryStore {
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let historyURL: URL
    private let queue = DispatchQueue(label: "BookmarkImportHistoryStore")

    init() {
        let dir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ??
            fileManager.temporaryDirectory
        historyURL = dir.appendingPathComponent("bookmark-import-history.json")
        encoder.outputFormatting = [.prettyPrinted]
    }

    func append(_ job: BookmarkImportJob) {
        queue.async {
            var jobs = self.readJobs(limit: Int.max)
            jobs.insert(job, at: 0)
            self.persist(jobs: jobs)
        }
    }

    func update(_ job: BookmarkImportJob) {
        queue.async {
            var jobs = self.readJobs(limit: Int.max)
            if let idx = jobs.firstIndex(where: { $0.id == job.id }) {
                jobs[idx] = job
                self.persist(jobs: jobs)
            }
        }
    }

    func loadRecentJobs(limit: Int = 50) -> [BookmarkImportJob] {
        queue.sync {
            readJobs(limit: limit)
        }
    }

    func job(withID id: UUID) -> BookmarkImportJob? {
        queue.sync {
            readJobs(limit: Int.max).first(where: { $0.id == id })
        }
    }

    func clear() {
        queue.async {
            try? self.fileManager.removeItem(at: self.historyURL)
        }
    }

    private func persist(jobs: [BookmarkImportJob]) {
        guard let data = try? encoder.encode(jobs) else { return }
        try? fileManager.createDirectory(at: historyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: historyURL)
    }

    private func readJobs(limit: Int) -> [BookmarkImportJob] {
        guard let data = try? Data(contentsOf: historyURL) else { return [] }
        guard let jobs = try? decoder.decode([BookmarkImportJob].self, from: data) else { return [] }
        return Array(jobs.prefix(limit))
    }
}

