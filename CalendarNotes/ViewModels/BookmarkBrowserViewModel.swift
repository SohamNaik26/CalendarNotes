//
//  BookmarkBrowserViewModel.swift
//  CalendarNotes
//
//  Manages state for the in-app bookmark browser including tabs, history,
//  private mode, content settings, and reading position memory.
//

import Foundation
import Combine
import CoreData

@MainActor
final class BookmarkBrowserViewModel: ObservableObject {
    @Published private(set) var tabs: [BrowserTab] = []
    @Published var selectedTabID: UUID?
    @Published var addressText: String = ""
    @Published var isShowingSuggestions: Bool = false
    @Published var suggestions: [BrowserSuggestion] = []
    @Published var isShowingFindPanel: Bool = false
    @Published var findQuery: String = ""
    @Published var isPrivateBrowsingEnabled: Bool = false
    @Published var isShowingHistory: Bool = false
    @Published var isShowingShareSheet: Bool = false
    @Published var isShowingSettings: Bool = false
    @Published var showLinkInspectorURL: URL?

    private let historyStore = BrowserHistoryStore.shared
    private let suggestionService = BookmarkSuggestionService.shared
    private let coreData = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()

    init(initialURL: URL? = nil, privateMode: Bool = false) {
        self.isPrivateBrowsingEnabled = privateMode
        let initialTab = BrowserTab(
            url: initialURL,
            title: initialURL?.absoluteString ?? "New Tab",
            isPrivate: privateMode
        )
        tabs = [initialTab]
        selectedTabID = initialTab.id
        addressText = initialURL?.absoluteString ?? ""

        setupSuggestionPipeline()
    }

    private func setupSuggestionPipeline() {
        $addressText
            .debounce(for: .milliseconds(200), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] text in
                guard let self else { return }
                if text.isEmpty {
                    self.suggestions = []
                    self.isShowingSuggestions = false
                } else {
                    Task {
                        await self.updateSuggestions(for: text)
                    }
                }
            }
            .store(in: &cancellables)
    }

    func updateSuggestions(for query: String) async {
        let bookmarkMatches = suggestionService.bookmarkSuggestions(for: query)
        let historyMatches = historyStore.search(query: query)
        let combined = (bookmarkMatches + historyMatches)
            .sorted { $0.relevance > $1.relevance }
        await MainActor.run {
            self.suggestions = combined
            self.isShowingSuggestions = !combined.isEmpty
        }
    }

    func selectSuggestion(_ suggestion: BrowserSuggestion) {
        addressText = suggestion.url.absoluteString
        load(url: suggestion.url)
        isShowingSuggestions = false
    }

    func addNewTab(privateMode: Bool? = nil) {
        let tab = BrowserTab(isPrivate: privateMode ?? isPrivateBrowsingEnabled)
        tabs.append(tab)
        selectedTabID = tab.id
        addressText = ""
    }

    func closeTab(_ tab: BrowserTab) {
        guard let index = tabs.firstIndex(of: tab) else { return }
        tabs.remove(at: index)
        if tabs.isEmpty {
            addNewTab(privateMode: isPrivateBrowsingEnabled)
        } else if tab.id == selectedTabID {
            let newIndex = max(0, index - 1)
            selectedTabID = tabs[newIndex].id
            addressText = tabs[newIndex].url?.absoluteString ?? ""
        }
    }

    func selectTab(_ tab: BrowserTab) {
        selectedTabID = tab.id
        addressText = tab.url?.absoluteString ?? ""
    }

    func togglePrivateBrowsing() {
        isPrivateBrowsingEnabled.toggle()
        if let selectedID = selectedTabID,
           let index = tabs.firstIndex(where: { $0.id == selectedID }) {
            tabs[index].isPrivate = isPrivateBrowsingEnabled
        }
    }

    func load(address: String) {
        guard let url = normalizedURL(from: address) else { return }
        load(url: url)
    }

    func load(url: URL) {
        guard let selectedID = selectedTabID,
              let index = tabs.firstIndex(where: { $0.id == selectedID }) else { return }
        tabs[index].url = url
        tabs[index].title = url.absoluteString
        tabs[index].isLoading = true
        addressText = url.absoluteString

        if !tabs[index].isPrivate {
            historyStore.recordVisit(url: url, title: tabs[index].title)
        }
    }

    func recordVisit(url: URL, title: String) {
        guard let selectedID = selectedTabID,
              let index = tabs.firstIndex(where: { $0.id == selectedID }) else { return }
        tabs[index].title = title
        if !tabs[index].isPrivate {
            historyStore.recordVisit(url: url, title: title)
        }
    }

    func updateLoadingState(tabID: UUID, isLoading: Bool, title: String?, canGoBack: Bool, canGoForward: Bool) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs[index].isLoading = isLoading
        if let title = title, !title.isEmpty {
            tabs[index].title = title
        }
        tabs[index].canGoBack = canGoBack
        tabs[index].canGoForward = canGoForward
    }

    func updateScrollPosition(tabID: UUID, offset: Double) {
        guard let index = tabs.firstIndex(where: { $0.id == tabID }) else { return }
        tabs[index].lastScrollOffset = offset
        if let url = tabs[index].url {
            historyStore.updateScrollPosition(for: url, offset: offset)
        }
    }

    func restoreScrollPosition(for url: URL) -> Double {
        historyStore.scrollPosition(for: url)
    }

    func clearHistory() {
        historyStore.clear()
    }

    func historyEntries() -> [BrowserHistoryEntry] {
        historyStore.allEntries()
    }

    func sectionBookmarks(for url: URL) -> [BrowserSectionBookmark] {
        historyStore.sectionBookmarks(for: url)
    }

    func addSectionBookmark(for url: URL, title: String, offset: Double) -> BrowserSectionBookmark? {
        historyStore.addSectionBookmark(for: url, title: title, offset: offset)
    }

    func removeSectionBookmark(for url: URL, id: UUID) {
        historyStore.removeSectionBookmark(for: url, id: id)
    }

    func toggleJavaScript(for tab: BrowserTab) {
        updateTab(tab.id) { $0.javaScriptEnabled.toggle() }
    }

    func toggleContentBlocking(for tab: BrowserTab) {
        updateTab(tab.id) { $0.contentBlockingEnabled.toggle() }
    }

    func toggleUserAgent(for tab: BrowserTab) {
        updateTab(tab.id) {
            switch $0.userAgent {
            case .automatic: $0.userAgent = .desktop
            case .desktop: $0.userAgent = .mobile
            case .mobile: $0.userAgent = .automatic
            }
        }
    }

    func updateZoom(for tab: BrowserTab, delta: Double) {
        updateTab(tab.id) {
            let newValue = max(0.5, min(2.0, $0.zoomScale + delta))
            $0.zoomScale = newValue
        }
    }

    private func updateTab(_ id: UUID, update: (inout BrowserTab) -> Void) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        update(&tabs[index])
    }

    private func normalizedURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), url.scheme != nil {
            return url
        }
        if let url = URL(string: "https://\(trimmed)") {
            return url
        }
        return URL(string: "https://www.google.com/search?q=\(trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed)")
    }
}

struct BrowserSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let url: URL
    let relevance: Double
    let source: Source

    enum Source {
        case bookmark
        case history
    }
}

// MARK: - BookmarkSuggestionService

final class BookmarkSuggestionService {
    static let shared = BookmarkSuggestionService()
    private init() {}

    private let coreData = CoreDataManager.shared

    func bookmarkSuggestions(for query: String, limit: Int = 6) -> [BrowserSuggestion] {
        guard !query.isEmpty else { return [] }
        var matches: [Bookmark] = []
        coreData.viewContext.performAndWait {
            let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
            request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "title CONTAINS[cd] %@", query),
                NSPredicate(format: "bookmarkDescription CONTAINS[cd] %@", query),
                NSPredicate(format: "url CONTAINS[cd] %@", query)
            ])
            request.fetchLimit = limit * 2
            matches = (try? coreData.viewContext.fetch(request)) ?? []
        }
        return matches.prefix(limit).compactMap { bookmark in
            guard let urlString = bookmark.url, let url = URL(string: urlString) else { return nil }
            return BrowserSuggestion(
                title: bookmark.title ?? urlString,
                subtitle: bookmark.bookmarkDescription ?? urlString,
                url: url,
                relevance: 1.0,
                source: .bookmark
            )
        }
    }
}


