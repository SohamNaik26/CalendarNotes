//
//  BookmarksView.swift
//  CalendarNotes
//

import SwiftUI
import CoreData
#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

struct BookmarksView: View {
    @StateObject private var viewModel = BookmarksViewModel()
    @EnvironmentObject private var syncManager: SyncManager
    @Environment(\.managedObjectContext) private var context
    @State private var selectedBookmark: Bookmark?
    @State private var showingDetail = false
    @State private var showingQuickAdd = false
    @State private var pendingAddURL: URL?
    @State private var pendingCollectionName: String?
    @State private var showingImportExport = false
    @State private var showingDiscovery = false
    @State private var showingAdvancedSearch = false
    @State private var showingStats = false
    @State private var showingBrowser = false
    @State private var showingLayout = false
    @State private var showingCollectionEditor = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var pendingOpenBookmark: Bookmark?
    @State private var showingOpenModeChoice = false
    @State private var showingReadLater = false

    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @StateObject private var backgroundTaskManager = BackgroundTaskManager()
    @Environment(\.scenePhase) private var scenePhase
    @State private var launchDuration: Double?

    var body: some View {
        applyShortcutHandlers(
            applyDeepLinkHandlers(configuredContent)
        )
    }

    private var configuredContent: some View {
        baseLayout
            .toolbar { toolbarItems }
            .refreshable { await viewModel.refreshMetadata() }
            .task { await viewModel.reload(reset: true) }
            .background(Color.cnBackground)
            .sheet(isPresented: $showingDetail) {
                if let bookmark = selectedBookmark {
                    BookmarkDetailView(bookmark: bookmark)
                        .presentationCornerRadius(20)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showingQuickAdd) {
                QuickAddBookmarkSheet(
                    initialURL: pendingAddURL,
                    initialCollectionName: pendingCollectionName
                )
                .presentationCornerRadius(20)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("OpenAddBookmark"))) { note in
                pendingAddURL = note.object as? URL
                showingQuickAdd = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .init("OpenReadLater"))) { _ in
                showingReadLater = true
            }
            .sheet(isPresented: $showingImportExport) {
                ImportExportView()
                    .presentationCornerRadius(20)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showingDiscovery) {
                DiscoveryView()
                    .presentationCornerRadius(20)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $showingBrowser) {
                BookmarkBrowserView()
                    .ignoresSafeArea()
            }
            #else
            .sheet(isPresented: $showingBrowser) {
                BookmarkBrowserView()
                    .frame(minWidth: 1200, maxWidth: .infinity, minHeight: 800, maxHeight: .infinity)
                    .background(Color.cnBackground)
                    .ignoresSafeArea()
            }
            #endif
            .sheet(isPresented: $showingReadLater) {
                ReadLaterView()
                    .presentationCornerRadius(20)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            #if os(iOS)
            .fullScreenCover(isPresented: $showingAdvancedSearch) { AdvancedBookmarkSearchView() }
            .fullScreenCover(isPresented: $showingStats) { StatsDashboardView() }
            #else
            .sheet(isPresented: $showingAdvancedSearch) {
                AdvancedBookmarkSearchView()
                    .frame(minWidth: 900, minHeight: 600)
            }
            .sheet(isPresented: $showingStats) {
                StatsDashboardView()
                    .frame(minWidth: 900, minHeight: 600)
            }
            #endif
            .onChange(of: showingQuickAdd, initial: false) { _, isPresented in
                guard !isPresented else { return }
                pendingCollectionName = nil
                pendingAddURL = nil
            }
            .sheet(isPresented: $showingCollectionEditor) {
                CollectionEditorView(context: context)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .confirmationDialog("Open Bookmark", isPresented: $showingOpenModeChoice, presenting: pendingOpenBookmark) { bookmark in
                Button("Open in CalendarNotes") {
                    openInDetail(bookmark)
                }
                Button("Open in Safari") {
                    openExternally(bookmark)
                }
                Button("Edit Bookmark") {
                    selectedBookmark = bookmark
                    showingDetail = true
                }
                Button("Cancel", role: .cancel) {
                    pendingOpenBookmark = nil
                    showingOpenModeChoice = false
                }
            } message: { _ in
                Text("Choose how you'd like to open this bookmark.")
            }
            .alert(item: $viewModel.contextActionMessage) { message in
                Alert(
                    title: Text(message.title),
                    message: Text(message.message),
                    dismissButton: .default(Text("OK")) {
                        viewModel.contextActionMessage = nil
                    }
                )
            }
            .onChange(of: scenePhase, initial: false) { _, newPhase in
                switch newPhase {
                case .background:
                    backgroundTaskManager.startBackgroundTask()
                case .active:
                    backgroundTaskManager.endBackgroundTask()
                    Task { @MainActor in launchDuration = AppLaunchMetrics.shared.latestDuration() }
                default:
                    break
                }
            }
            .task {
                launchDuration = await MainActor.run { AppLaunchMetrics.shared.latestDuration() }
            }
            .instrumentBody("BookmarksView")
    }

    private var baseLayout: some View {
        NavigationView {
            ZStack {
                // Background
                #if os(macOS)
                Color(NSColor.windowBackgroundColor)
                    .ignoresSafeArea()
                #else
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                #endif
                
                VStack(spacing: 0) {
                    SyncStatusBanner()
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                    header
                    content
                }
            }
            .navigationTitle("Bookmarks")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            .safeAreaInset(edge: .top) {
                Color.clear.frame(height: ScreenSize.statusBarHeight)
            }
            #endif
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }

    @ViewBuilder
    private func applyDeepLinkHandlers<Content: View>(_ content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .deepLinkOpenBookmark)) { note in
                guard let objectID = note.userInfo?[DeepLinkUserInfoKey.bookmarkObjectID] as? NSManagedObjectID else { return }
                if let bookmark = try? context.existingObject(with: objectID) as? Bookmark {
                    selectedBookmark = bookmark
                    showingDetail = true
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .deepLinkShowCollection)) { note in
                if let name = note.userInfo?[DeepLinkUserInfoKey.collectionName] as? String {
                    viewModel.applyCollectionFilter(named: name)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .deepLinkShowTag)) { note in
                if let tag = note.userInfo?[DeepLinkUserInfoKey.tagName] as? String {
                    viewModel.applyTagFilter(named: tag)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .deepLinkPrefillCollectionForNewBookmark)) { note in
                if let name = note.userInfo?[DeepLinkUserInfoKey.collectionName] as? String {
                    pendingCollectionName = name
                }
            }
    }

    @ViewBuilder
    private func applyShortcutHandlers<Content: View>(_ content: Content) -> some View {
        content
            .onReceive(NotificationCenter.default.publisher(for: .keyboardShortcutFocusSearch)) { _ in
                isSearchFieldFocused = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .keyboardShortcutReload)) { _ in
                Task { await viewModel.reload() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .keyboardShortcutCloseModal)) { _ in
                showingDetail = false
                showingQuickAdd = false
                showingImportExport = false
                showingDiscovery = false
                showingAdvancedSearch = false
                showingStats = false
                showingLayout = false
                showingCollectionEditor = false
            }
            .onReceive(NotificationCenter.default.publisher(for: .keyboardShortcutOpenBookmark)) { _ in
                if let target = currentKeyboardTargetBookmark {
                    open(target)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickActionAddBookmark)) { _ in
                pendingAddURL = nil
                pendingCollectionName = nil
                showingQuickAdd = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickActionPasteAndSave)) { _ in
                pendingAddURL = clipboardURL()
                pendingCollectionName = nil
                showingQuickAdd = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickActionSearchBookmarks)) { notification in
                if let query = notification.userInfo?["presetQuery"] as? String {
                    viewModel.searchText = query
                }
                isSearchFieldFocused = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickActionOpenLastBookmark)) { notification in
                if let uriString = notification.userInfo?["bookmarkURI"] as? String {
                    openBookmark(withURI: uriString)
                } else {
                    openLastBookmark()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .quickActionOpenBookmark)) { notification in
                if let uriString = notification.userInfo?["bookmarkURI"] as? String {
                    openBookmark(withURI: uriString)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .keyboardShortcutEditBookmark)) { _ in
                if let target = currentKeyboardTargetBookmark {
                    open(target)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .keyboardShortcutDeleteBookmark)) { _ in
                performOnSelectedBookmark { bookmark in
                    viewModel.delete(bookmark)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .keyboardShortcutToggleFavorite)) { _ in
                performOnSelectedBookmark { bookmark in
                    viewModel.toggleFavorite(bookmark)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .keyboardShortcutCopyURL)) { _ in
                guard let bookmark = currentKeyboardTargetBookmark,
                      let url = bookmark.url else { return }
                copyToPasteboard(url)
            }
            .onReceive(NotificationCenter.default.publisher(for: .keyboardShortcutSelectAll)) { _ in
                viewModel.selectAllVisible()
            }
            .onReceive(NotificationCenter.default.publisher(for: .keyboardShortcutNewCollection)) { _ in
                showingCollectionEditor = true
            }
    }

    private var header: some View {
        VStack(spacing: 8) {
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.cnSecondaryText)
                    .font(.system(size: 16))
                TextField("Search bookmarks", text: $viewModel.searchText)
                    .focused($isSearchFieldFocused)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cnTertiaryBackground)
                    .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            )
            .padding(.horizontal)

            // Filters & layout toggle + Collections button
            HStack {
                filterChips
                readLaterShortcut
                Spacer()
                Button {
                    showingCollectionEditor = true
                } label: {
                    Label("Collections", systemImage: "folder")
                }
                Button {
                    showingBrowser = true
                } label: {
                    Label("Browser", systemImage: "globe")
                }
                layoutToggle
            }
            .padding(.horizontal)
            if !viewModel.availableContentTypes.isEmpty {
                contentTypeFilters
                    .padding(.horizontal)
            }
        }
        .padding(.vertical, 8)
        .background(Color.cnSecondaryBackground)
    }

    private var filterChips: some View {
        HStack(spacing: 8) {
            chip(title: "All", .all)
            chip(title: "Favorites", .favorites)
            chip(title: "Recent", .recent)
            chip(title: "Collections", .collections)
            chip(title: "Tags", .tags)
        }
    }

    private func chip(title: String, _ f: BookmarksViewModel.Filter) -> some View {
        Button(action: {
            withAnimation(.defaultSpring) {
                viewModel.activeFilter = f
                switch f {
                case .all:
                    viewModel.clearDeepLinkFilters()
                case .collections:
                    viewModel.appliedTagFilter = nil
                case .tags:
                    viewModel.appliedCollectionFilter = nil
                default:
                    viewModel.appliedCollectionFilter = nil
                    viewModel.appliedTagFilter = nil
                }
            }
        }) {
            Text(title)
                .font(.caption)
                .fontWeight(viewModel.activeFilter == f ? .semibold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Group {
                        if viewModel.activeFilter == f {
                            Capsule()
                                .fill(Color.cnAccent.opacity(0.2))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.cnAccent.opacity(0.4), lineWidth: 1.5)
                                )
                        } else {
                            Capsule()
                                .fill(Color.cnTertiaryBackground)
                        }
                    }
                )
                .foregroundColor(viewModel.activeFilter == f ? .cnAccent : .cnPrimaryText)
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(viewModel.activeFilter == f ? 1.05 : 1.0)
        .animation(.defaultSpring, value: viewModel.activeFilter == f)
    }

    private var readLaterShortcut: some View {
        Button {
            showingReadLater = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "bookmark.fill")
                Text("Read Later")
                if viewModel.readLaterCount > 0 {
                    Text("\(viewModel.readLaterCount)")
                        .font(.caption2.bold())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                        .background(Color.cnAccent.opacity(0.2))
                        .clipShape(Capsule())
                }
            }
            .font(.caption)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.cnTertiaryBackground)
            .clipShape(Capsule())
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("Open Read Later list")
        .padding(.leading, 4)
    }

    private var layoutToggle: some View {
        HStack(spacing: 12) {
            Menu {
                Picker("Sort", selection: $viewModel.sort) {
                    Text("Recent").tag(BookmarksViewModel.Sort.recent)
                    Text("Oldest").tag(BookmarksViewModel.Sort.oldest)
                    Text("Most Visited").tag(BookmarksViewModel.Sort.mostVisited)
                    Text("A-Z").tag(BookmarksViewModel.Sort.alphabetical)
                    Text("Custom").tag(BookmarksViewModel.Sort.custom)
                }
            } label: {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }

            Button {
                showingLayout.toggle()
            } label: {
                HStack(spacing: 6) {
                    Text("Layout")
                    Image(systemName: "chevron.down")
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.cnTertiaryBackground)
                .clipShape(Capsule())
            }
            .popover(isPresented: $showingLayout, arrowEdge: .top) {
                LayoutSettingsView(layoutMode: $viewModel.layoutMode)
                    .frame(width: 260)
                    .padding(12)
            }
        }
    }

    private var contentTypeFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.availableContentTypes, id: \.self) { type in
                    contentTypeChip(for: type)
                }
                if viewModel.activeContentType != nil {
                    Button("Clear") {
                        viewModel.clearContentTypeFilter()
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.cnSecondaryBackground)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    private func contentTypeChip(for type: BookmarkContentType) -> some View {
        let isActive = viewModel.activeContentType == type
        return Button {
            viewModel.setContentTypeFilter(type)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: iconName(for: type))
                Text(title(for: type))
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? Color.cnAccent.opacity(0.2) : Color.cnTertiaryBackground)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isActive ? Color.cnAccent : Color.clear, lineWidth: 1.5)
            )
            .cornerRadius(12)
            .foregroundColor(isActive ? .cnAccent : .cnPrimaryText)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func iconName(for type: BookmarkContentType) -> String {
        switch type {
        case .article: return "doc.text"
        case .video: return "play.rectangle"
        case .pdf: return "doc.richtext"
        case .image: return "photo"
        case .social: return "bubble.left"
        case .product: return "bag"
        case .repository: return "chevron.left.slash.chevron.right"
        case .recipe: return "fork.knife"
        case .unknown: return "questionmark.circle"
        }
    }
    
    private func title(for type: BookmarkContentType) -> String {
        switch type {
        case .article: return "Articles"
        case .video: return "Videos"
        case .pdf: return "PDFs"
        case .image: return "Images"
        case .social: return "Social"
        case .product: return "Products"
        case .repository: return "GitHub"
        case .recipe: return "Recipes"
        case .unknown: return "Other"
        }
    }

    private var content: some View {
        Group {
            if viewModel.sections.flatMap({ $0.items }).isEmpty {
                emptyState
                    .transition(.scaleAndFade)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16, pinnedViews: [.sectionHeaders]) {
                        ForEach(Array(viewModel.sections.enumerated()), id: \.offset) { index, section in
                            Section(header: sectionHeader(section.title)) {
                                if viewModel.layoutMode == .grid {
                                    gridSection(section.items)
                                        .transition(.scaleAndFade)
                                } else {
                                    listSection(section.items)
                                        .transition(.slideFromTrailing)
                                }
                            }
                        }
                        if viewModel.isLoadingMore {
                            HStack {
                                Spacer()
                                ProgressView().padding(.vertical, 16)
                                Spacer()
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 1) // Prevents content from hiding under nav bar
                    .padding(.bottom, 80)
                }
                .transition(.scaleAndFade)
            }
        }
        .animation(.smooth, value: viewModel.layoutMode)
        .animation(.smooth, value: viewModel.sections.count)
        .overlay(alignment: .bottomTrailing) { addButton }
        .overlay(alignment: .bottomLeading) { performanceHUD }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.cnPrimaryText)
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.cnSecondaryBackground.opacity(0.5))
        )
    }

    private func gridSection(_ items: [Bookmark]) -> some View {
        let columns: [GridItem] = {
            #if os(iOS)
            #if targetEnvironment(macCatalyst)
            return Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
            #else
            return UIDevice.current.userInterfaceIdiom == .pad ? Array(repeating: GridItem(.flexible(), spacing: 12), count: 3) : [GridItem(.flexible()), GridItem(.flexible())]
            #endif
            #else
            return Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
            #endif
        }()
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(Array(items.enumerated()), id: \.element.objectID) { index, bookmark in
                let offline = OfflineDownloadManager.shared.isOfflineAvailable(bookmarkID: bookmark.objectID.uriRepresentation().absoluteString)
                BookmarkGridItem(
                    bookmark: bookmark,
                    isSelected: viewModel.selectionState.contains(bookmark.objectID),
                    isSelectionMode: viewModel.selectionState.isActive,
                    onTap: { handleBookmarkTap(bookmark) },
                    onLongPress: { handleLongPress(bookmark) },
                    isOfflineAvailable: offline
                )
                .equatable()
                .task {
                    viewModel.loadMoreIfNeeded(for: bookmark)
                }
                .contextMenu {
                    if !viewModel.selectionState.isActive {
                        contextMenu(for: bookmark)
                    }
                }
                .swipeActions(for: bookmark, using: viewModel, isEnabled: !viewModel.selectionState.isActive)
                .transition(
                    .asymmetric(
                        insertion: .scale(scale: 0.8).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    )
                )
                .animation(
                    .defaultSpring.delay(Double(index % 6) * 0.05),
                    value: items.count
                )
            }
        }
    }

    private func listSection(_ items: [Bookmark]) -> some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.objectID) { index, bookmark in
                let offline = OfflineDownloadManager.shared.isOfflineAvailable(bookmarkID: bookmark.objectID.uriRepresentation().absoluteString)
                BookmarkListRow(
                    bookmark: bookmark,
                    isSelected: viewModel.selectionState.contains(bookmark.objectID),
                    isSelectionMode: viewModel.selectionState.isActive,
                    onTap: { handleBookmarkTap(bookmark) },
                    onLongPress: { handleLongPress(bookmark) },
                    isOfflineAvailable: offline
                )
                .equatable()
                .task {
                    viewModel.loadMoreIfNeeded(for: bookmark)
                }
                .contextMenu {
                    if !viewModel.selectionState.isActive {
                        contextMenu(for: bookmark)
                    }
                }
                .swipeActions(for: bookmark, using: viewModel, isEnabled: !viewModel.selectionState.isActive)
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    )
                )
                .animation(
                    .smooth.delay(Double(index % 10) * 0.03),
                    value: items.count
                )
                if index < items.count - 1 {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
    }

    private var emptyState: some View {
        BookmarksEmptyState(
            onReadLater: {
                showingReadLater = true
            },
            onCollections: {
                showingCollectionEditor = true
            },
            onBrowser: {
                showingBrowser = true
            }
        )
    }

    private var addButton: some View {
        Button(action: {
            withAnimation(.bouncy) {
                NotificationCenter.default.post(name: .init("OpenAddBookmark"), object: nil)
            }
        }) {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color.cnAccent, Color.cnAccent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: Color.cnAccent.opacity(0.4), radius: 12, x: 0, y: 4)
                )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(showingQuickAdd ? 0.9 : 1.0)
        .animation(.defaultSpring, value: showingQuickAdd)
        .padding(20)
        .accessibilityLabel("Add new bookmark")
        .accessibilityHint(AccessibilityHelpers.addButtonHint(type: "bookmark"))
        .accessibilityIdentifier("addBookmarkButton")
    }

    private var performanceHUD: some View {
        HStack(spacing: 6) {
            Image(systemName: "memorychip")
                .foregroundColor(.cnAccent)
            Text(String(format: "%.1f MB", Double(performanceMonitor.memoryUsage) / (1024 * 1024)))
                .font(.caption2)
                .foregroundStyle(.secondary)
            if let launchDuration {
                Divider().frame(height: 10)
                Image(systemName: "stopwatch")
                    .foregroundColor(.cnAccent)
                Text(String(format: "%.0f ms", launchDuration * 1000))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
        .padding([.leading, .bottom], 16)
        .accessibilityLabel("Memory usage \(performanceMonitor.memoryUsage) bytes")
    }

    private func contextMenu(for b: Bookmark) -> some View {
        let bookmarkID = b.objectID.uriRepresentation().absoluteString
        let downloadManager = OfflineDownloadManager.shared
        let isOffline = downloadManager.isOfflineAvailable(bookmarkID: bookmarkID)
        
        return Group {
            Button("Open") { open(b) }
            Button(b.isFavorite ? "Unfavorite" : "Favorite") { viewModel.toggleFavorite(b) }
            Button(b.isArchived ? "Unarchive" : "Archive") { viewModel.toggleArchive(b) }
            Button(b.isInReadLater ? "Remove from Read Later" : "Add to Read Later") {
                viewModel.toggleReadLater(for: b)
            }
            if b.isInReadLater {
                Button(b.isReadValue ? "Mark Unread" : "Mark Read") {
                    if b.isReadValue {
                        viewModel.markBookmarkAsUnread(b)
                    } else {
                        viewModel.markBookmarkAsRead(b)
                    }
                }
            }
            Divider()
            if isOffline {
                Button("Remove Offline Copy") {
                    downloadManager.toggleOffline(for: b, enable: false)
                    Task { await viewModel.reload() }
                }
            } else {
                Button("Download for Offline Use") {
                    downloadManager.toggleOffline(for: b, enable: true)
                    Task { await viewModel.reload() }
                }
            }
            if b.contentTypeValue == .video {
                Divider()
                Button(b.isWatched ? "Mark as Unwatched" : "Mark as Watched") {
                    viewModel.toggleWatched(b)
                }
                if let duration = b.formattedVideoDuration {
                    Text("Duration: \(duration)")
                }
            }
            Divider()
            Button("Create event from bookmark") {
                Task { await viewModel.createCalendarEvent(from: b) }
            }
            Button("Add to reading list task") {
                Task { await viewModel.createReadingTask(from: b) }
            }
            Button("Share with note") {
                Task { await viewModel.createNoteShare(from: b) }
            }
            Divider()
            Button("Share") { share(b) }
            Button("Delete", role: .destructive) { viewModel.delete(b) }
        }
    }

    private func open(_ b: Bookmark) {
        switch BookmarkPreferenceStore.openMode {
        case .safari:
            openExternally(b)
        case .inApp:
            openInDetail(b)
        case .ask:
            pendingOpenBookmark = b
            showingOpenModeChoice = true
        }
    }

    private func openInDetail(_ b: Bookmark) {
        pendingOpenBookmark = nil
        showingOpenModeChoice = false
        recordBookmarkOpened(b)
        selectedBookmark = b
        showingDetail = true
    }

    private func openExternally(_ b: Bookmark) {
        pendingOpenBookmark = nil
        showingOpenModeChoice = false
        if let urlString = b.url, let url = URL(string: urlString) {
            recordBookmarkOpened(b)
#if os(macOS)
            NSWorkspace.shared.open(url)
#else
            UIApplication.shared.open(url)
#endif
        } else {
            openInDetail(b)
        }
    }

    private func share(_ b: Bookmark) {
        // Placeholder: the app already has sharing helpers in places; integrate here later.
    }
    
    private func handleBookmarkTap(_ bookmark: Bookmark) {
        if viewModel.selectionState.isActive {
            withAnimation(.defaultSpring) {
                viewModel.toggleSelection(for: bookmark)
            }
        } else {
            withAnimation(.defaultSpring) {
                open(bookmark)
            }
        }
        OfflineDownloadManager.shared.markAccess(for: bookmark.objectID.uriRepresentation().absoluteString)
    }
    
    private func handleLongPress(_ bookmark: Bookmark) {
        withAnimation(.defaultSpring) {
            viewModel.enterSelectionMode(with: bookmark)
        }
    }

    private var toolbarItems: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            if viewModel.selectionState.isActive {
                if viewModel.bulkProgress.status == .running {
                    HStack(spacing: 8) {
                        ProgressView(value: viewModel.bulkProgress.fractionCompleted)
                            .progressViewStyle(.linear)
                            .frame(width: 100)
                        Button("Cancel") { viewModel.cancelBulkAction() }
                    }
                } else {
                    Text(viewModel.selectionSummary.description)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if viewModel.canUndoBulkAction {
                    Button {
                        Task { await viewModel.undoLastBulkAction() }
                    } label: {
                        Label("Undo", systemImage: "arrow.uturn.backward")
                    }
                }
                if viewModel.canRedoBulkAction {
                    Button {
                        Task { await viewModel.redoLastBulkAction() }
                    } label: {
                        Label("Redo", systemImage: "arrow.uturn.forward")
                    }
                }
                Button("Clear Selection") {
                    viewModel.clearSelection()
                }
            } else {
                Button(action: { showingQuickAdd = true }) { Label("Add", systemImage: "plus") }
                Button(action: { showingImportExport = true }) { Label("Import/Export", systemImage: "arrow.up.arrow.down.circle") }
                Button(action: { showingDiscovery = true }) { Label("Discover", systemImage: "sparkles") }
                Button(action: { showingAdvancedSearch = true }) { Label("Search", systemImage: "magnifyingglass") }
                Button(action: { showingStats = true }) { Label("Stats", systemImage: "chart.bar") }
                syncToolbarContent
            }
        }
    }
    
    private var syncToolbarContent: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: syncManager.connectionQuality.symbolName)
                    .foregroundColor(syncManager.connectionQuality.tintColor)
                if syncManager.pendingChanges > 0 {
                    Text("\(syncManager.pendingChanges)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.cnSecondaryBackground)
            .clipShape(Capsule())
            
            Button {
                syncManager.triggerManualSync()
            } label: {
                if let progress = currentSyncProgress {
                    ProgressView(value: progress, total: 1)
                        .frame(width: 28)
                } else {
                    Label("Sync", systemImage: "arrow.clockwise")
                        .labelStyle(.iconOnly)
                }
            }
            .buttonStyle(.bordered)
            .disabled(currentSyncProgress != nil)
        }
    }
    
    private var currentSyncProgress: Double? {
        if case .syncing(let progress) = syncManager.state {
            return progress
        }
        return nil
    }
}

// MARK: - Cells

private struct BookmarkGridItem: View, Equatable {
    @ObservedObject var bookmark: Bookmark
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let isOfflineAvailable: Bool
    
    // Pre-computed properties to avoid recalculation
    let bookmarkID: NSManagedObjectID
    let title: String
    let url: String?
    let contentTypeDisplayName: String
    let formattedVideoDuration: String?
    let isInReadLater: Bool
    let isWatched: Bool
    
    @State private var previewData: Data?
    @State private var faviconData: Data?
    @State private var isLoadingPreview = false
    
    init(
        bookmark: Bookmark,
        isSelected: Bool,
        isSelectionMode: Bool,
        onTap: @escaping () -> Void,
        onLongPress: @escaping () -> Void,
        isOfflineAvailable: Bool
    ) {
        self.bookmark = bookmark
        self.isSelected = isSelected
        self.isSelectionMode = isSelectionMode
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.isOfflineAvailable = isOfflineAvailable
        
        // Pre-compute properties
        self.bookmarkID = bookmark.objectID
        self.title = bookmark.title ?? bookmark.url ?? "Untitled"
        self.url = bookmark.url
        self.contentTypeDisplayName = bookmark.contentTypeDisplayName
        self.formattedVideoDuration = bookmark.formattedVideoDuration
        self.isInReadLater = bookmark.isInReadLater
        self.isWatched = bookmark.isWatched
    }
    
    static func == (lhs: BookmarkGridItem, rhs: BookmarkGridItem) -> Bool {
        lhs.bookmarkID == rhs.bookmarkID &&
        lhs.isSelected == rhs.isSelected &&
        lhs.isSelectionMode == rhs.isSelectionMode &&
        lhs.isOfflineAvailable == rhs.isOfflineAvailable &&
        lhs.title == rhs.title &&
        lhs.url == rhs.url &&
        lhs.contentTypeDisplayName == rhs.contentTypeDisplayName &&
        lhs.formattedVideoDuration == rhs.formattedVideoDuration &&
        lhs.isInReadLater == rhs.isInReadLater &&
        lhs.isWatched == rhs.isWatched
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.cnSecondaryBackground)
                    .overlay(previewOverlay)
                    .frame(height: 140)
                    .clipped()
                if let favicon = faviconImage {
                    favicon
                        .resizable()
                        .scaledToFit()
                        .frame(width: 24, height: 24)
                        .padding(6)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        .padding(10)
                }
            }
            .overlay(durationBadge, alignment: .bottomTrailing)
            .overlay(watchedBadge, alignment: .topTrailing)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                    .foregroundColor(.cnPrimaryText)
                    .accessibilityIdentifier("bookmark-title-\(bookmarkID)")
                if let host = URL(string: url ?? "")?.host {
                    Text(host)
                        .font(.caption)
                        .foregroundColor(.cnSecondaryText)
                }
                metadataFootnote
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color.cnTertiaryBackground)
                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
        )
        .overlay(selectionOverlay)
        .overlay(offlineOverlay, alignment: .bottomLeading)
        .scaleEffect(isSelectionMode && isSelected ? 0.97 : 1.0)
        .animation(.quick, value: isSelected)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onLongPressGesture(minimumDuration: 0.6, maximumDistance: 20, perform: onLongPress)
        .task(id: bookmarkID) {
            await loadPreview()
        }
    }
    
    @ViewBuilder
    private var previewOverlay: some View {
        if let preview = previewImage {
            preview
                .resizable()
                .scaledToFill()
                .transition(.opacity)
        } else if isLoadingPreview {
            ProgressView()
        } else {
            Image(systemName: "photo")
                .resizable()
                .scaledToFit()
                .foregroundColor(.cnSecondaryText.opacity(0.5))
                .padding(32)
        }
    }
    
    private var selectionOverlay: some View {
        Group {
            if isSelectionMode {
                Circle()
                    .fill(isSelected ? Color.cnAccent : Color.cnSecondaryBackground.opacity(0.9))
                    .frame(width: 28, height: 28)
                    .overlay(
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(isSelected ? .white : .secondary)
                    )
                    .padding(8)
                    .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
            }
        }
    }
    
    private var offlineOverlay: some View {
        Group {
            if isOfflineAvailable {
                Label("Offline", systemImage: "arrow.down.circle.fill")
                    .labelStyle(.iconOnly)
                    .foregroundColor(.cnAccent)
                    .padding(6)
            }
        }
    }
    
    private var previewImage: Image? {
        guard let data = previewData else { return nil }
        #if os(macOS)
        if let image = NSImage(data: data) {
            return Image(nsImage: image)
        }
        #else
        if let image = UIImage(data: data) {
            return Image(uiImage: image)
        }
        #endif
        return nil
    }
    
    private var faviconImage: Image? {
        guard let data = faviconData else { return nil }
        #if os(macOS)
        if let image = NSImage(data: data) {
            return Image(nsImage: image)
        }
        #else
        if let image = UIImage(data: data) {
            return Image(uiImage: image)
        }
        #endif
        return nil
    }
    
    private func loadPreview() async {
        if previewData == nil, let existing = bookmark.previewImage {
            previewData = existing
        }
        if faviconData == nil, let existing = bookmark.favicon {
            faviconData = existing
        }
        guard !isLoadingPreview, previewData == nil || faviconData == nil else { return }
        isLoadingPreview = true
        let request = BookmarkPreviewRequest(
            objectID: bookmark.objectID,
            url: bookmark.url,
            existingPreview: previewData ?? bookmark.previewImage,
            existingFavicon: faviconData ?? bookmark.favicon
        )
        let result = await BookmarkPreviewLoader.shared.assets(for: request)
        await MainActor.run {
            previewData = result.thumbnailData
            faviconData = result.faviconData
            isLoadingPreview = false
        }
    }
    
    private var metadataFootnote: some View {
        HStack(spacing: 8) {
            Text(contentTypeDisplayName)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.cnSecondaryBackground)
                .cornerRadius(6)
            switch bookmark.contentTypeValue {
            case .video:
                if let duration = formattedVideoDuration {
                    Label(duration, systemImage: "clock.fill")
                        .font(.caption2)
                        .foregroundColor(.cnSecondaryText)
                }
            case .pdf:
                if let pages = bookmark.pdfPageCountValue {
                    Label("\(pages)p", systemImage: "doc.on.doc")
                        .font(.caption2)
                        .foregroundColor(.cnSecondaryText)
                }
            case .image:
                if let dims = bookmark.imageDimensionsDescription {
                    Label(dims, systemImage: "photo")
                        .font(.caption2)
                        .foregroundColor(.cnSecondaryText)
                }
            case .recipe:
                if let cook = bookmark.recipeCookTimeDescription {
                    Label(cook, systemImage: "timer")
                        .font(.caption2)
                        .foregroundColor(.cnSecondaryText)
                }
            case .repository:
                let stats = bookmark.gitHubStatistics
                if let stars = stats.stars {
                    Label("\(stars)", systemImage: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
                if let forks = stats.forks {
                    Label("\(forks)", systemImage: "tuningfork")
                        .font(.caption2)
                        .foregroundColor(.cnSecondaryText)
                }
                if let language = stats.language {
                    Text(language)
                        .font(.caption2)
                        .foregroundColor(.cnSecondaryText)
                }
            case .product:
                if let price = bookmark.productPriceDisplay {
                    Label(price, systemImage: "tag")
                        .font(.caption2)
                        .foregroundColor(.cnSecondaryText)
                }
            case .social:
                if let author = bookmark.socialAuthorHandle {
                    Label(author, systemImage: "at")
                        .font(.caption2)
                        .foregroundColor(.cnSecondaryText)
                }
            case .article:
                if let readTime = bookmark.articleReadTimeDescription {
                    Label(readTime, systemImage: "book")
                        .font(.caption2)
                        .foregroundColor(.cnSecondaryText)
                }
            case .unknown:
                EmptyView()
            }
            if bookmark.isInReadLater {
                Label(bookmark.estimatedReadingDescription ?? "Read Later", systemImage: bookmark.readLaterStatusIcon)
                    .font(.caption2)
                    .foregroundColor(bookmark.readLaterStatusColor)
            }
            if let progress = bookmark.readingProgressDisplay {
                Label(progress, systemImage: "chart.bar.xaxis")
                    .font(.caption2)
                    .foregroundColor(.cnSecondaryText)
            }
        }
    }
    
    private var durationBadge: some View {
        Group {
            if bookmark.contentTypeValue == .video, let duration = formattedVideoDuration {
                Text(duration)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.7))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding(8)
            }
        }
    }
    
    private var watchedBadge: some View {
        Group {
            if bookmark.contentTypeValue == .video, isWatched {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.green)
                    .padding(6)
                    .background(Color.white.opacity(0.9), in: Circle())
                    .padding(8)
            }
        }
    }
}

private struct BookmarkListRow: View, Equatable {
    @ObservedObject var bookmark: Bookmark
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    let onLongPress: () -> Void
    let isOfflineAvailable: Bool
    
    // Pre-computed properties
    let bookmarkID: NSManagedObjectID
    let title: String
    let url: String?
    let contentTypeDisplayName: String
    let isFavorite: Bool
    let isInReadLater: Bool
    let isWatched: Bool
    let formattedVideoDuration: String?
    
    @State private var isHovered = false
    @State private var faviconData: Data?
    @State private var isLoadingPreview = false
    
    init(
        bookmark: Bookmark,
        isSelected: Bool,
        isSelectionMode: Bool,
        onTap: @escaping () -> Void,
        onLongPress: @escaping () -> Void,
        isOfflineAvailable: Bool
    ) {
        self.bookmark = bookmark
        self.isSelected = isSelected
        self.isSelectionMode = isSelectionMode
        self.onTap = onTap
        self.onLongPress = onLongPress
        self.isOfflineAvailable = isOfflineAvailable
        
        // Pre-compute properties
        self.bookmarkID = bookmark.objectID
        self.title = bookmark.title ?? bookmark.url ?? "Untitled"
        self.url = bookmark.url
        self.contentTypeDisplayName = bookmark.contentTypeDisplayName
        self.isFavorite = bookmark.isFavorite
        self.isInReadLater = bookmark.isInReadLater
        self.isWatched = bookmark.isWatched
        self.formattedVideoDuration = bookmark.formattedVideoDuration
    }
    
    static func == (lhs: BookmarkListRow, rhs: BookmarkListRow) -> Bool {
        lhs.bookmarkID == rhs.bookmarkID &&
        lhs.isSelected == rhs.isSelected &&
        lhs.isSelectionMode == rhs.isSelectionMode &&
        lhs.isOfflineAvailable == rhs.isOfflineAvailable &&
        lhs.title == rhs.title &&
        lhs.url == rhs.url &&
        lhs.contentTypeDisplayName == rhs.contentTypeDisplayName &&
        lhs.isFavorite == rhs.isFavorite &&
        lhs.isInReadLater == rhs.isInReadLater &&
        lhs.isWatched == rhs.isWatched &&
        lhs.formattedVideoDuration == rhs.formattedVideoDuration
    }
    
    var body: some View {
        HStack(spacing: 14) {
            faviconStack
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(.cnPrimaryText)
                if let host = URL(string: url ?? "")?.host {
                    Text(host)
                        .font(.caption)
                        .foregroundColor(.cnSecondaryText)
                }
                listMetadataFootnote
            }
            
            Spacer()
            
            if bookmark.contentTypeValue == .video {
                if isWatched {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 14, weight: .bold))
                }
                if let duration = formattedVideoDuration {
                    Text(duration)
                        .font(.caption2)
                        .foregroundColor(.cnSecondaryText)
                }
            }
            
            if isFavorite {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                    .font(.system(size: 16))
            }
            
            if isOfflineAvailable {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.cnAccent)
                    .font(.system(size: 16))
            }
            
            if isInReadLater {
                Image(systemName: bookmark.readLaterStatusIcon)
                    .foregroundColor(bookmark.readLaterStatusColor)
                    .font(.system(size: 16))
            }
            
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .cnAccent : .secondary)
                    .font(.system(size: 20, weight: .semibold))
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isHovered ? Color.cnSecondaryBackground.opacity(0.5) : Color.clear)
        )
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.defaultSpring, value: isHovered)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onLongPressGesture(minimumDuration: 0.6, maximumDistance: 16, pressing: { pressing in
            #if os(macOS)
            isHovered = pressing
            #endif
        }, perform: onLongPress)
        .task(id: bookmarkID) {
            await loadAssets()
        }
        #if os(macOS)
        .onHover { hovering in
            isHovered = hovering
        }
        #endif
    }
    
    @ViewBuilder
    private var faviconStack: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.cnAccent.opacity(0.12))
                .frame(width: 40, height: 40)
            if let favicon = faviconImage {
                favicon
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else if isLoadingPreview {
                ProgressView()
                    .frame(width: 24, height: 24)
        } else {
            Image(systemName: isFavorite ? "star.fill" : "bookmark.fill")
                .font(.system(size: 16))
                .foregroundColor(isFavorite ? .yellow : .cnAccent)
        }
        }
    }
    
    private var faviconImage: Image? {
        guard let data = faviconData else { return nil }
        #if os(macOS)
        if let image = NSImage(data: data) {
            return Image(nsImage: image)
        }
        #else
        if let image = UIImage(data: data) {
            return Image(uiImage: image)
        }
        #endif
        return nil
    }
    
    private func loadAssets() async {
        if faviconData == nil, let existing = bookmark.favicon {
            faviconData = existing
        }
        guard !isLoadingPreview, faviconData == nil else { return }
        isLoadingPreview = true
        let request = BookmarkPreviewRequest(
            objectID: bookmark.objectID,
            url: bookmark.url,
            existingPreview: bookmark.previewImage,
            existingFavicon: faviconData ?? bookmark.favicon
        )
        let result = await BookmarkPreviewLoader.shared.assets(for: request)
        await MainActor.run {
            faviconData = result.faviconData
            isLoadingPreview = false
        }
    }
    
    private var listMetadataFootnote: some View {
        HStack(spacing: 8) {
            Text(contentTypeDisplayName)
                .font(.caption2)
                .foregroundColor(.cnSecondaryText)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.cnSecondaryBackground)
                .cornerRadius(4)
            switch bookmark.contentTypeValue {
            case .pdf:
                if let pages = bookmark.pdfPageCountValue {
                    Label("\(pages)p", systemImage: "doc.on.doc")
                        .font(.caption2)
                        .foregroundColor(.cnSecondaryText)
                }
            case .recipe:
                if let cook = bookmark.recipeCookTimeDescription {
                    Label(cook, systemImage: "timer")
                        .font(.caption2)
                        .foregroundColor(.cnSecondaryText)
                }
            case .repository:
                let stats = bookmark.gitHubStatistics
                if let stars = stats.stars {
                    Label("\(stars)", systemImage: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.yellow)
                }
                if let forks = stats.forks {
                    Label("\(forks)", systemImage: "tuningfork")
                        .font(.caption2)
                        .foregroundColor(.cnSecondaryText)
                }
                if let language = stats.language {
                    Text(language)
                        .font(.caption2)
                        .foregroundColor(.cnSecondaryText)
                }
            case .product:
                if let price = bookmark.productPriceDisplay {
                    Label(price, systemImage: "tag")
                        .font(.caption2)
                        .foregroundColor(.cnSecondaryText)
                }
            case .article:
                if let readTime = bookmark.articleReadTimeDescription {
                    Label(readTime, systemImage: "book")
                        .font(.caption2)
                        .foregroundColor(.cnSecondaryText)
                }
            case .image:
                if let dims = bookmark.imageDimensionsDescription {
                    Label(dims, systemImage: "photo")
                        .font(.caption2)
                        .foregroundColor(.cnSecondaryText)
                }
            case .social:
                if let author = bookmark.socialAuthorHandle {
                    Label(author, systemImage: "at")
                        .font(.caption2)
                        .foregroundColor(.cnSecondaryText)
                }
            case .video:
                if let duration = formattedVideoDuration {
                    Label(duration, systemImage: "clock.fill")
                        .font(.caption2)
                        .foregroundColor(.cnSecondaryText)
                }
            case .unknown:
                EmptyView()
            }
            if bookmark.isInReadLater {
                Label(bookmark.estimatedReadingDescription ?? "Read Later", systemImage: bookmark.readLaterStatusIcon)
                    .font(.caption2)
                    .foregroundColor(bookmark.readLaterStatusColor)
            }
            if let progress = bookmark.readingProgressDisplay {
                Label(progress, systemImage: "chart.bar.xaxis")
                    .font(.caption2)
                    .foregroundColor(.cnSecondaryText)
            }
        }
    }
}

// MARK: - Swipe Actions helper

private extension View {
    @ViewBuilder
    func swipeActions(for bookmark: Bookmark, using viewModel: BookmarksViewModel, isEnabled: Bool) -> some View {
        if isEnabled {
            let enabledActions = BookmarkPreferenceStore.enabledSwipeActions
            self
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if enabledActions.contains(.delete) {
                        Button(role: .destructive) { viewModel.delete(bookmark) } label: { Label("Delete", systemImage: "trash") }
                    }
                    if enabledActions.contains(.archive) {
                        Button { viewModel.toggleArchive(bookmark) } label: { Label(bookmark.isArchived ? "Unarchive" : "Archive", systemImage: "archivebox") }
                    }
                    if enabledActions.contains(.favorite) {
                        Button { viewModel.toggleFavorite(bookmark) } label: { Label(bookmark.isFavorite ? "Unfavorite" : "Favorite", systemImage: "star") }
                    }
                    if enabledActions.contains(.readLater) {
                        Button {
                            viewModel.toggleReadLater(for: bookmark)
                        } label: {
                            Label(bookmark.isInReadLater ? "Remove" : "Read Later", systemImage: bookmark.isInReadLater ? "bookmark.slash" : "bookmark")
                        }
                        .tint(.indigo)
                    }
                }
        } else {
            self
        }
    }
}

// MARK: - Keyboard Helpers

private extension BookmarksView {
    var allBookmarks: [Bookmark] {
        viewModel.sections.flatMap { $0.items }
    }
    
    var currentKeyboardTargetBookmark: Bookmark? {
        let selectionIDs = viewModel.selectionState.selectedObjectIDs
        if !selectionIDs.isEmpty {
            for bookmark in allBookmarks where selectionIDs.contains(bookmark.objectID) {
                return bookmark
            }
        }
        return allBookmarks.first
    }
    
    func performOnSelectedBookmark(_ action: (Bookmark) -> Void) {
        guard let bookmark = currentKeyboardTargetBookmark else { return }
        action(bookmark)
    }
    
    func copyToPasteboard(_ string: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = string
        #elseif os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        #endif
    }

    func recordBookmarkOpened(_ bookmark: Bookmark) {
        BookmarkPreferenceStore.lastOpenedBookmarkURI = bookmark.objectID.uriRepresentation().absoluteString
        BookmarkPreferenceStore.lastOpenedBookmarkTitle = bookmark.title ?? bookmark.url
        try? CoreDataManager.shared.markBookmarkOpened(bookmark)
        #if os(iOS)
        AppQuickActionService.shared.updateDynamicQuickActions()
        #endif
    }

    func openBookmark(withURI uriString: String) {
        guard let uri = URL(string: uriString),
              let objectID = context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: uri) else {
            viewModel.lastBulkActionError = "Bookmark is unavailable."
            return
        }
        openBookmark(with: objectID)
    }

    func openLastBookmark() {
        guard let uri = BookmarkPreferenceStore.lastOpenedBookmarkURI else {
            viewModel.lastBulkActionError = "No recent bookmark to open."
            return
        }
        openBookmark(withURI: uri)
    }

    func openBookmark(with objectID: NSManagedObjectID) {
        guard let bookmark = try? context.existingObject(with: objectID) as? Bookmark else {
            viewModel.lastBulkActionError = "Bookmark could not be found."
            return
        }
        open(bookmark)
    }

    func clipboardURL() -> URL? {
#if canImport(UIKit)
        if let string = UIPasteboard.general.string,
           let url = URL(string: string),
           let scheme = url.scheme,
           scheme.lowercased().hasPrefix("http") {
            return url
        }
#elseif os(macOS)
        if let string = NSPasteboard.general.string(forType: .string),
           let url = URL(string: string),
           let scheme = url.scheme,
           scheme.lowercased().hasPrefix("http") {
            return url
        }
#endif
        return nil
    }
}


