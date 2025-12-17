//
//  BookmarkBrowserView.swift
//  CalendarNotes
//
//  Main entry point for the in-app bookmark browser with advanced controls.
//

import SwiftUI
import CoreData
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif

struct BookmarkBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: BookmarkBrowserViewModel
    @State private var isShowingShareSheet = false
    @State private var shareURL: URL?
    @State private var inspectedLink: URL?

    init(initialURL: URL? = nil, privateMode: Bool = false) {
        _viewModel = StateObject(wrappedValue: BookmarkBrowserViewModel(initialURL: initialURL, privateMode: privateMode))
    }

    var body: some View {
        NavigationView {
            content
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            dismiss()
                        } label: {
                            Label("Close", systemImage: "xmark.circle.fill")
                        }
                    }
                }
                .toolbar {
                    toolbarItems
                }
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cnBackground)
        .ignoresSafeArea()
        #if canImport(UIKit)
        .sheet(isPresented: $isShowingShareSheet) {
            if let shareURL {
                ActivityView(activityItems: [shareURL])
            }
        }
        #endif
        .sheet(isPresented: $viewModel.isShowingHistory) {
            BrowserHistoryView(
                loadEntries: { viewModel.historyEntries() },
                onClear: { viewModel.clearHistory() },
                onSelect: { entry in
                    viewModel.load(url: entry.url)
                    viewModel.isShowingHistory = false
                }
            )
            .presentationDetents([.medium, .large])
        }
        .overlay(alignment: .bottom) {
            if let inspectedLink {
                LinkInspectorView(url: inspectedLink, viewModel: viewModel)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding()
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            addressBar
            tabStrip
            Divider()
            if let selectedTab = viewModel.tabs.first(where: { $0.id == viewModel.selectedTabID }) {
                BrowserSplitView(
                    tab: selectedTab,
                    viewModel: viewModel,
                    shareHandler: { url in
                        shareURL = url
                        isShowingShareSheet = true
                    },
                    linkHoverHandler: { url in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            inspectedLink = url
                        }
                    }
                )
            } else {
                Text("No open tabs")
                    .foregroundColor(.secondary)
                    .padding()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var addressBar: some View {
        HStack(spacing: 8) {
            Menu {
                Button(action: { viewModel.addNewTab(privateMode: false) }) {
                    Label("New Tab", systemImage: "plus")
                }
                Button(action: { viewModel.addNewTab(privateMode: true) }) {
                    Label("New Private Tab", systemImage: "lock")
                }
                Button(action: { viewModel.isPrivateBrowsingEnabled.toggle() }) {
                    Label(viewModel.isPrivateBrowsingEnabled ? "Disable Private Browsing" : "Enable Private Browsing", systemImage: "hand.raised")
                }
                Button(action: { viewModel.isShowingHistory = true }) {
                    Label("History", systemImage: "clock")
                }
            } label: {
                Image(systemName: "square.on.square.dashed")
                    .font(.title3)
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.plain)

            TextField("Search or enter website name", text: $viewModel.addressText, onCommit: {
                viewModel.load(address: viewModel.addressText)
            })
            .textFieldStyle(.roundedBorder)
            .disableAutocorrection(true)
            #if os(iOS)
            .textInputAutocapitalization(.never)
            #endif
            .overlay(alignment: .trailing) {
                if !viewModel.addressText.isEmpty {
                    Button {
                        viewModel.addressText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .padding(.trailing, 8)
                }
            }

            Button {
                if let selected = viewModel.selectedTabID, let tab = viewModel.tabs.first(where: { $0.id == selected }), let url = tab.url {
                    shareURL = url
                    isShowingShareSheet = true
                }
            } label: {
                Image(systemName: "square.and.arrow.up")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.cnSecondaryBackground)
        .overlay(alignment: .bottom) {
            if viewModel.isShowingSuggestions {
                suggestionList
                    .background(Color.cnBackground)
                    .transition(.opacity)
                    .padding(.horizontal)
            }
        }
    }

    private var suggestionList: some View {
        VStack(spacing: 0) {
            Divider()
            ForEach(viewModel.suggestions) { suggestion in
                Button {
                    viewModel.selectSuggestion(suggestion)
                } label: {
                    HStack {
                        Image(systemName: suggestion.source == .bookmark ? "bookmark.fill" : "clock")
                            .foregroundColor(.cnAccent)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(suggestion.title)
                                .font(.subheadline)
                                .foregroundColor(.primary)
                            Text(suggestion.subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                Divider()
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(radius: 4)
    }

    private var tabStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.tabs) { tab in
                    HStack(spacing: 6) {
                        Image(systemName: tab.isPrivate ? "hand.raised" : "globe")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(tab.title)
                            .font(.caption)
                            .foregroundColor(viewModel.selectedTabID == tab.id ? .white : .primary)
                            .lineLimit(1)
                        if tab.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.6)
                        } else {
                            Button {
                                viewModel.closeTab(tab)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(viewModel.selectedTabID == tab.id ? .white.opacity(0.8) : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(viewModel.selectedTabID == tab.id ? Color.cnAccent : Color.cnTertiaryBackground)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 10))
                    .onTapGesture {
                        viewModel.selectTab(tab)
                    }
                }
                Button {
                    viewModel.addNewTab(privateMode: viewModel.isPrivateBrowsingEnabled)
                } label: {
                    Image(systemName: "plus")
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.cnTertiaryBackground))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
        .background(Color.cnSecondaryBackground)
    }

    private func toolbarButton(_ systemName: String, action: @escaping () -> Void, disabled: Bool = false) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
        }
        .disabled(disabled)
    }

    private var toolbarItems: some ToolbarContent {
        #if os(iOS)
        ToolbarItemGroup(placement: .bottomBar) {
            if let selected = viewModel.selectedTabID,
               let tab = viewModel.tabs.first(where: { $0.id == selected }) {
                toolbarButton("chevron.backward", action: { NotificationCenter.default.post(name: .browserGoBack, object: tab.id) }, disabled: !tab.canGoBack)
                toolbarButton("chevron.forward", action: { NotificationCenter.default.post(name: .browserGoForward, object: tab.id) }, disabled: !tab.canGoForward)
                toolbarButton("arrow.clockwise", action: { NotificationCenter.default.post(name: .browserReload, object: tab.id) })
                toolbarButton("line.3.horizontal.decrease", action: { viewModel.isShowingFindPanel.toggle() })
                toolbarButton("person.crop.square", action: { viewModel.toggleUserAgent(for: tab) })
                toolbarButton(tab.javaScriptEnabled ? "bolt.fill" : "bolt.slash.fill", action: { viewModel.toggleJavaScript(for: tab) })
                toolbarButton(tab.contentBlockingEnabled ? "shield.lefthalf.fill" : "shield.slash", action: { viewModel.toggleContentBlocking(for: tab) })
                toolbarButton("camera", action: { NotificationCenter.default.post(name: .browserCaptureSnapshot, object: tab.id) })
                toolbarButton("doc.richtext", action: { NotificationCenter.default.post(name: .browserGeneratePDF, object: tab.id) })
            }
        }
        #else
        ToolbarItemGroup {
            if let selected = viewModel.selectedTabID,
               let tab = viewModel.tabs.first(where: { $0.id == selected }) {
                toolbarButton("chevron.backward", action: { NotificationCenter.default.post(name: .browserGoBack, object: tab.id) }, disabled: !tab.canGoBack)
                toolbarButton("chevron.forward", action: { NotificationCenter.default.post(name: .browserGoForward, object: tab.id) }, disabled: !tab.canGoForward)
                toolbarButton("arrow.clockwise", action: { NotificationCenter.default.post(name: .browserReload, object: tab.id) })
            }
        }
        #endif
    }
}

// MARK: - Split View (List + Preview)

struct BrowserSplitView: View {
    let tab: BrowserTab
    @ObservedObject var viewModel: BookmarkBrowserViewModel
    let shareHandler: (URL) -> Void
    let linkHoverHandler: (URL?) -> Void

    var body: some View {
        #if os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView {
                BookmarkSidebarView(select: { url in
                    viewModel.load(url: url)
                })
            } detail: {
                BrowserDetailView(tab: tab, viewModel: viewModel, shareHandler: shareHandler, linkHoverHandler: linkHoverHandler)
            }
        } else {
            BrowserDetailView(tab: tab, viewModel: viewModel, shareHandler: shareHandler, linkHoverHandler: linkHoverHandler)
        }
        #else
        BrowserDetailView(tab: tab, viewModel: viewModel, shareHandler: shareHandler, linkHoverHandler: linkHoverHandler)
        #endif
    }
}

struct BrowserDetailView: View {
    let tab: BrowserTab
    @ObservedObject var viewModel: BookmarkBrowserViewModel
    let shareHandler: (URL) -> Void
    let linkHoverHandler: (URL?) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isShowingFindPanel {
                FindInPageBar(query: $viewModel.findQuery) {
                    NotificationCenter.default.post(name: .browserFindInPage, object: tab.id, userInfo: ["query": viewModel.findQuery])
                } onCancel: {
                    viewModel.isShowingFindPanel = false
                    NotificationCenter.default.post(name: .browserClearFind, object: tab.id)
                }
            }
            #if canImport(UIKit)
            WebViewContainer(
                viewModel: viewModel,
                tab: tab,
                linkHoverHandler: linkHoverHandler
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #else
            Text("In-app browser is currently available on iOS devices.")
                .foregroundColor(.secondary)
                .padding()
            #endif
            if tab.url != nil {
                Divider()
                BookmarkMetadataEditor(tab: tab, viewModel: viewModel)
            }
        }
    }
}

// MARK: - Subviews

struct FindInPageBar: View {
    @Binding var query: String
    let onSearch: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            TextField("Find in page", text: $query)
                .textFieldStyle(.roundedBorder)
                .onSubmit { onSearch() }
            Button("Find") { onSearch() }
            Button("Cancel", role: .cancel) { onCancel() }
        }
        .padding(8)
        .background(Color.cnSecondaryBackground)
    }
}

struct LinkInspectorView: View {
    let url: URL
    let viewModel: BookmarkBrowserViewModel

    private enum LinkSafetyStatus {
        case secure
        case caution
        case warning

        var color: Color {
            switch self {
            case .secure: return .green
            case .caution: return .orange
            case .warning: return .red
            }
        }

        var label: String {
            switch self {
            case .secure: return "Secure connection"
            case .caution: return "Mixed content"
            case .warning: return "Unverified link"
            }
        }
    }

    private var safetyStatus: LinkSafetyStatus {
        if let scheme = url.scheme?.lowercased(), scheme == "https" {
            return .secure
        } else if let scheme = url.scheme, scheme == "http" {
            return .caution
        }
        let suspiciousHosts = ["clickme", "malware", "phishing", "tracking"]
        if let host = url.host?.lowercased(),
           suspiciousHosts.contains(where: { host.contains($0) }) {
            return .warning
        }
        return .caution
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "link")
                    .font(.title3)
                    .foregroundColor(.cnAccent)
                VStack(alignment: .leading, spacing: 4) {
                    Text(url.host ?? url.absoluteString)
                        .font(.headline)
                    Text(url.absoluteString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(safetyStatus.color)
                            .frame(width: 8, height: 8)
                        Text(safetyStatus.label)
                            .font(.caption2)
                            .foregroundColor(safetyStatus.color)
                    }
                }
                Spacer()
            }
            HStack(spacing: 12) {
                Button {
                    openInCurrentTab()
                } label: {
                    Label("Open", systemImage: "safari")
                }
                .buttonStyle(.bordered)

                Button {
                    openInNewTab()
                } label: {
                    Label("New Tab", systemImage: "plus.square.on.square")
                }
                .buttonStyle(.bordered)

                Button {
                    copyLink()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.cnSecondaryBackground))
        .shadow(radius: 6)
    }

    private func openInCurrentTab() {
        viewModel.load(url: url)
    }

    private func openInNewTab() {
        viewModel.addNewTab(privateMode: viewModel.isPrivateBrowsingEnabled)
        viewModel.load(url: url)
    }

    private func copyLink() {
        #if canImport(UIKit)
        UIPasteboard.general.url = url
        #elseif canImport(AppKit)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(url.absoluteString, forType: .string)
        #endif
    }
}

struct BookmarkSidebarView: View {
    let select: (URL) -> Void
    @State private var bookmarks: [Bookmark] = []

    var body: some View {
        List(bookmarks, id: \.objectID) { bookmark in
            Button {
                if let urlString = bookmark.url, let url = URL(string: urlString) {
                    select(url)
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(bookmark.title ?? "Untitled")
                        .font(.body)
                    if let url = bookmark.url {
                        Text(url)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .onAppear {
            loadBookmarks()
        }
        .onReceive(NotificationCenter.default.publisher(for: .bookmarksDidChange)) { _ in
            loadBookmarks()
        }
        .navigationTitle("Bookmarks")
    }

    private func loadBookmarks() {
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        request.fetchLimit = 100
        request.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        bookmarks = (try? CoreDataManager.shared.viewContext.fetch(request)) ?? []
    }
}

struct BookmarkMetadataEditor: View {
    let tab: BrowserTab
    @ObservedObject var viewModel: BookmarkBrowserViewModel
    @State private var bookmark: Bookmark?
    @State private var title: String = ""
    @State private var notes: String = ""
    @State private var tagsText: String = ""
    @State private var saveState: SaveState = .idle
    @State private var sectionTitle: String = ""
    @State private var sections: [BrowserSectionBookmark] = []

    private enum SaveState {
        case idle
        case saving
        case saved
        case failed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Metadata")
                        .font(.headline)
                    Text(tab.url?.absoluteString ?? "No URL")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                if let urlString = tab.url?.absoluteString {
                    Label("Drag to Notes", systemImage: "note.text")
                        .font(.caption)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Color.cnTertiaryBackground))
                        .draggable(urlString)
                }
            }

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            TextField("Notes", text: $notes, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(3, reservesSpace: true)

            TextField("Tags (comma separated)", text: $tagsText)
                .textFieldStyle(.roundedBorder)

            sectionBookmarkEditor

            HStack(spacing: 12) {
                Button(action: saveChanges) {
                    if saveState == .saving {
                        ProgressView()
                    } else {
                        Label(bookmark == nil ? "Add to Bookmarks" : "Save Changes", systemImage: "checkmark.circle")
                    }
                }
                .buttonStyle(.borderedProminent)

                if bookmark != nil {
                    Button(role: .destructive, action: removeBookmark) {
                        Label("Remove Bookmark", systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                }

                if saveState == .saved {
                    Text("Saved")
                        .font(.caption)
                        .foregroundColor(.green)
                } else if saveState == .failed {
                    Text("Failed to save")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color.cnSecondaryBackground)
        .onAppear(perform: loadBookmark)
        .onChange(of: tab.url) { _, _ in loadBookmark() }
        .onChange(of: tab.lastScrollOffset) { _, _ in refreshSections() }
    }

    private func loadBookmark() {
        let context = CoreDataManager.shared.viewContext
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        if let urlString = tab.url?.absoluteString {
            request.predicate = NSPredicate(format: "url == %@", urlString)
        } else {
            request.predicate = NSPredicate(value: false)
        }
        request.fetchLimit = 1
        do {
            let result = try context.fetch(request).first
            bookmark = result
            title = result?.title ?? tab.url?.absoluteString ?? "Untitled"
            notes = result?.notes ?? ""
            tagsText = result?.decodedTags.joined(separator: ", ") ?? ""
        } catch {
            bookmark = nil
            title = tab.url?.absoluteString ?? ""
            notes = ""
            tagsText = ""
        }
        refreshSections()
    }

    private func saveChanges() {
        guard saveState != .saving else { return }
        guard let resolvedURL = tab.url else {
            saveState = .failed
            return
        }
        saveState = .saving
        let context = CoreDataManager.shared.viewContext
        do {
            let current: Bookmark
            if let bookmark {
                current = bookmark
            } else {
                current = Bookmark(
                    context: context,
                    url: resolvedURL.absoluteString,
                    title: resolvedTitle()
                )
                bookmark = current
            }
            current.title = resolvedTitle()
            current.notes = notes
            current.decodedTags = tagsText
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            current.lastModifiedDate = Date()
            try CoreDataManager.shared.save()
            saveState = .saved
            NotificationCenter.default.post(name: .bookmarksDidChange, object: nil)
        } catch {
            saveState = .failed
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            saveState = .idle
        }
    }

    private func removeBookmark() {
        guard let existingBookmark = bookmark else { return }
        let context = CoreDataManager.shared.viewContext
        context.delete(existingBookmark)
        do {
            try CoreDataManager.shared.save()
            NotificationCenter.default.post(name: .bookmarksDidChange, object: nil)
            bookmark = nil
            title = tab.url?.absoluteString ?? ""
            notes = ""
            tagsText = ""
            saveState = .saved
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                saveState = .idle
            }
        } catch {
            saveState = .failed
        }
    }

    private var sectionBookmarkEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Section Bookmarks")
                .font(.subheadline)
            HStack {
                TextField("Section title", text: $sectionTitle)
                    .textFieldStyle(.roundedBorder)
                Text("Current: \(Int(tab.lastScrollOffset))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Button {
                    createSectionBookmark()
                } label: {
                    Label("Save Position", systemImage: "bookmark.fill")
                }
                .buttonStyle(.bordered)
                .disabled(sectionTitle.trimmingCharacters(in: .whitespaces).isEmpty || tab.url == nil)
            }
            if sections.isEmpty {
                Text("No saved sections yet. Scroll and tap save to create one.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(sections) { section in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(section.title)
                                .font(.footnote)
                            Text("Scroll offset: \(Int(section.offset))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button {
                            navigateToSection(section)
                        } label: {
                            Image(systemName: "arrowshape.turn.up.forward")
                        }
                        .buttonStyle(.borderless)
                        Button(role: .destructive) {
                            deleteSection(section)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.cnTertiaryBackground))
                }
            }
        }
    }

    private func resolvedTitle() -> String {
        guard let url = tab.url else { return title }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? (url.host ?? url.absoluteString) : trimmed
    }

    private func createSectionBookmark() {
        guard let url = tab.url else { return }
        let title = sectionTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        let offset = tab.lastScrollOffset
        if let new = viewModel.addSectionBookmark(for: url, title: title, offset: offset) {
            sections = (sections + [new]).sorted { $0.createdAt < $1.createdAt }
            sectionTitle = ""
        }
    }

    private func deleteSection(_ section: BrowserSectionBookmark) {
        guard let url = tab.url else { return }
        viewModel.removeSectionBookmark(for: url, id: section.id)
        sections.removeAll { $0.id == section.id }
    }

    private func refreshSections() {
        if let url = tab.url {
            sections = viewModel.sectionBookmarks(for: url).sorted { $0.createdAt < $1.createdAt }
        } else {
            sections = []
        }
    }

    private func navigateToSection(_ section: BrowserSectionBookmark) {
        NotificationCenter.default.post(name: .browserScrollToOffset, object: tab.id, userInfo: ["offset": section.offset])
    }
}

struct BrowserHistoryView: View {
    @State private var entries: [BrowserHistoryEntry] = []
    @State private var searchText: String = ""
    let loadEntries: () -> [BrowserHistoryEntry]
    let onClear: () -> Void
    let onSelect: (BrowserHistoryEntry) -> Void

    private var filteredEntries: [BrowserHistoryEntry] {
        guard !searchText.isEmpty else { return entries }
        return entries.filter { entry in
            entry.title.localizedCaseInsensitiveContains(searchText) ||
            entry.url.absoluteString.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationView {
            List {
                ForEach(filteredEntries) { entry in
                    Button {
                        onSelect(entry)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(entry.title)
                                .font(.headline)
                            Text(entry.url.absoluteString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                            Text(entry.lastVisited, style: .date)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search history")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Clear") {
                        onClear()
                        entries = loadEntries()
                    }
                }
                #else
                ToolbarItem {
                    Button("Clear") {
                        onClear()
                        entries = loadEntries()
                    }
                }
                #endif
            }
        }
        .onAppear {
            entries = loadEntries()
        }
    }
}

// MARK: - Utilities

#if canImport(UIKit)
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

extension Notification.Name {
    static let browserGoBack = Notification.Name("BrowserGoBack")
    static let browserGoForward = Notification.Name("BrowserGoForward")
    static let browserReload = Notification.Name("BrowserReload")
    static let browserFindInPage = Notification.Name("BrowserFindInPage")
    static let browserClearFind = Notification.Name("BrowserClearFind")
    static let browserCaptureSnapshot = Notification.Name("BrowserCaptureSnapshot")
    static let browserGeneratePDF = Notification.Name("BrowserGeneratePDF")
    static let browserScrollToOffset = Notification.Name("BrowserScrollToOffset")
}


