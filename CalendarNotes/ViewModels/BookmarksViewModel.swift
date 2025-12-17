//
//  BookmarksViewModel.swift
//  CalendarNotes
//

import Foundation
import Combine
import CoreData

extension Notification.Name {
    static let bookmarksDidChange = Notification.Name("BookmarksDidChange")
}

@MainActor
final class BookmarksViewModel: ObservableObject {
    enum LayoutMode: String { case grid, list }
    enum Filter: String, CaseIterable { case all, favorites, recent, collections, tags }
    enum Sort: String, CaseIterable { case recent, oldest, mostVisited, alphabetical, custom }

    @Published var layoutMode: LayoutMode = .grid
    @Published var searchText: String = ""
    @Published var activeFilter: Filter = .all
    @Published var sort: Sort = .recent
    @Published var isRefreshing: Bool = false
    @Published var selectionState: BulkSelectionState = BulkSelectionState()
    @Published var selectionSummary: BulkSelectionSummary = BulkSelectionSummary(count: 0, contextTitle: BulkSelectionContext.library.title)
    @Published var bulkProgress: BulkOperationProgress = .idle()
    @Published var canUndoBulkAction: Bool = false
    @Published var canRedoBulkAction: Bool = false
    @Published var lastBulkActionError: String?
    @Published var contextActionMessage: BookmarkContextActionMessage?
    @Published var appliedCollectionFilter: String?
    @Published var appliedTagFilter: String?
    @Published var activeContentType: BookmarkContentType? = nil
    @Published private(set) var availableContentTypes: [BookmarkContentType] = []
    @Published var bookmarksState: LoadingState<[Bookmark]> = .idle
    @Published private(set) var sections: [(title: String, items: [Bookmark])] = []
    @Published private(set) var isLoadingMore: Bool = false
    @Published private(set) var readLaterCount: Int = 0
    @Published var readLaterSort: ReadLaterService.SortOption
    
    private let coreData = CoreDataManager.shared
    private let bulkService = BulkOperationService.shared
    private let syncManager = SyncManager.shared
    private let readLaterService = ReadLaterService.shared
    private var cancellables = Set<AnyCancellable>()
    #if os(iOS)
    private let watchConnectivityService = WatchConnectivityService.shared
    private let watchSnapshotProvider = WatchBookmarkSnapshotProvider()
    #endif

    private let pageSize = 60
    private var currentOffset: Int = 0
    private var allBookmarks: [Bookmark] = []
    private var isLoadingPage = false
    private var hasMorePages = true
    private let searchCache = TemporaryCache<String, [NSManagedObjectID]>(ttl: 60)
    private let contentTypeDisplayOrder: [BookmarkContentType] = [.article, .video, .pdf, .image, .social, .product, .repository, .recipe, .unknown]
    
    deinit {
        cancellables.removeAll()
    }

    init() {

        layoutMode = LayoutMode(rawValue: BookmarkPreferenceStore.defaultViewMode) ?? .grid
        sort = Sort(rawValue: BookmarkPreferenceStore.sortOrder) ?? .recent
        readLaterSort = BookmarkPreferenceStore.readLaterSortOption

        _ = readLaterService.ensureSystemCollection()

        Publishers.CombineLatest3($searchText.removeDuplicates(), $activeFilter, $sort)
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in await self?.reload(reset: true) }
            }
            .store(in: &cancellables)

        $appliedCollectionFilter
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in await self?.reload(reset: true) }
            }
            .store(in: &cancellables)


        $layoutMode
            .dropFirst()
            .sink { mode in
                BookmarkPreferenceStore.defaultViewMode = mode.rawValue
            }
            .store(in: &cancellables)
        
        $sort
            .dropFirst()
            .sink { value in
                BookmarkPreferenceStore.sortOrder = value.rawValue
            }
            .store(in: &cancellables)
        
        $readLaterSort
            .dropFirst()
            .sink { value in
                BookmarkPreferenceStore.readLaterSortOption = value
                Task { @MainActor [weak self] in self?.updateReadLaterSnapshot() }
            }
            .store(in: &cancellables)

        $appliedTagFilter
            .removeDuplicates()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in await self?.reload(reset: true) }
            }
            .store(in: &cancellables)
        
        $activeContentType
            .removeDuplicates(by: { $0 == $1 })
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in await self?.reload(reset: true) }
            }
            .store(in: &cancellables)
        
        bulkService.$progress
            .receive(on: RunLoop.main)
            .sink { [weak self] progress in
                guard let self else { return }
                self.bulkProgress = progress
                if progress.status == .failed {
                    self.lastBulkActionError = progress.errorMessage
                }
                switch progress.status {
                case .running:
                    self.syncManager.markBulkProgress(progress.fractionCompleted)
                case .completed:
                    self.syncManager.triggerManualSync()
                default:
                    break
                }
            }
            .store(in: &cancellables)
        
        bulkService.$canUndo
            .receive(on: RunLoop.main)
            .assign(to: &$canUndoBulkAction)
        
        bulkService.$canRedo
            .receive(on: RunLoop.main)
            .assign(to: &$canRedoBulkAction)
        
        NotificationCenter.default.publisher(for: .readLaterUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateReadLaterSnapshot()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .bookmarksDidChange)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.clearSearchCache()
                Task { @MainActor in
                    await self.reload(reset: true)
                    self.syncWatchSnapshotIfNeeded()
                }
            }
            .store(in: &cancellables)

        updateReadLaterSnapshot()
    }

    func reload(reset: Bool = false) async {
        await loadPage(reset: reset)
        syncWatchSnapshotIfNeeded()
    }
    
    func loadMoreIfNeeded(for bookmark: Bookmark) {
        guard hasMorePages, !isLoadingPage else { return }
        guard let index = allBookmarks.firstIndex(where: { $0.objectID == bookmark.objectID }) else { return }
        let threshold = max(allBookmarks.count - (pageSize / 3), 0)
        if index >= threshold {
            Task { @MainActor in await self.loadPage(reset: false) }
        }
    }
    
    private func loadPage(reset: Bool) async {
        guard !isLoadingPage else { return }
        if reset {
            hasMorePages = true
            currentOffset = 0
            allBookmarks.removeAll()
            await MainActor.run { bookmarksState = .loading }
        }
        guard hasMorePages else {
            await MainActor.run { isLoadingMore = false }
            return
        }
        isLoadingPage = true
        await MainActor.run { isLoadingMore = true }
        let cacheKey = pageCacheKey(forOffset: currentOffset)
        let sortDescriptors = makeSortDescriptors()
        let collectionFilter = (appliedCollectionFilter?.isEmpty == false) ? appliedCollectionFilter : nil
        let tagFilter: String? = {
            if let explicit = appliedTagFilter, !explicit.isEmpty {
                return explicit
            }
            if activeFilter == .tags, !searchText.isEmpty {
                return searchText
            }
            return nil
        }()
        do {
            let bookmarks: [Bookmark]
            if let cachedIDs = searchCache.value(for: cacheKey) {
                bookmarks = cachedIDs.compactMap { id in
                    try? coreData.viewContext.existingObject(with: id) as? Bookmark
                }
            } else {
                let fetched = try coreData.fetchBookmarks(
                    inCollection: collectionFilter,
                    withTag: tagFilter,
                    isFavorite: activeFilter == .favorites ? true : nil,
                    isArchived: nil,
                    searchText: searchText.isEmpty ? nil : searchText,
                    contentType: activeContentType,
                    limit: pageSize,
                    offset: currentOffset,
                    sortDescriptors: sortDescriptors,
                    batchSize: pageSize
                )
                bookmarks = fetched
                searchCache.insert(fetched.map { $0.objectID }, for: cacheKey)
            }
            await MainActor.run {
                integrateLoadedPage(bookmarks, reset: reset)
                if reset {
                    bookmarksState = .loaded(bookmarks)
                }
            }
        } catch {
            await MainActor.run {
                if reset {
                    sections = []
                    let cachedBookmarks = bookmarksState.value ?? []
                    bookmarksState = .error(error)
                    if !cachedBookmarks.isEmpty {
                        allBookmarks = cachedBookmarks
                        integrateLoadedPage(cachedBookmarks, reset: true)
                    }
                }
                lastBulkActionError = error.localizedDescription
            }
        }
        isLoadingPage = false
        await MainActor.run { isLoadingMore = false }
        syncWatchSnapshotIfNeeded()
    }

    private func syncWatchSnapshotIfNeeded() {
        #if os(iOS)
        guard watchConnectivityService.syncEnabled else { return }
        Task { @MainActor in
            let snapshot = watchSnapshotProvider.buildSnapshot()
            await watchConnectivityService.sendSnapshot(snapshot)
        }
        #endif
    }
    
    private func integrateLoadedPage(_ bookmarks: [Bookmark], reset: Bool) {
        if reset {
            allBookmarks = bookmarks
        } else {
            let newOnes = bookmarks.filter { bookmark in
                !allBookmarks.contains(where: { $0.objectID == bookmark.objectID })
            }
            allBookmarks.append(contentsOf: newOnes)
        }
        hasMorePages = bookmarks.count == pageSize
        currentOffset = allBookmarks.count
        availableContentTypes = orderedContentTypes(from: allBookmarks)
        let filtered = applyContentTypeFilter(to: allBookmarks)
        let sorted = sortBookmarks(filtered)
        sections = groupByContentType(sorted)
        pruneSelection(with: sorted)
        selectionState.updateContext(currentSelectionContext())
        refreshSelectionSummary()
        #if canImport(CoreSpotlight)
        if reset {
            BookmarkSpotlightIndexer.shared.reindexRecentBookmarks()
        }
        #endif
    }
    
    private func pageCacheKey(forOffset offset: Int) -> String {
        let components: [String] = [
            searchText.lowercased(),
            activeFilter.rawValue,
            sort.rawValue,
            appliedCollectionFilter ?? "",
            appliedTagFilter ?? "",
            activeContentType?.rawValue ?? "",
            String(offset)
        ]
        return components.joined(separator: "|")
    }
    
    private func makeSortDescriptors() -> [NSSortDescriptor] {
        switch sort {
        case .recent:
            return [
                NSSortDescriptor(keyPath: \Bookmark.lastOpenedDate, ascending: false),
                NSSortDescriptor(keyPath: \Bookmark.createdDate, ascending: false)
            ]
        case .oldest:
            return [
                NSSortDescriptor(keyPath: \Bookmark.createdDate, ascending: true)
            ]
        case .mostVisited:
            return [
                NSSortDescriptor(keyPath: \Bookmark.openCount, ascending: false)
            ]
        case .alphabetical:
            return [
                NSSortDescriptor(key: "title", ascending: true, selector: #selector(NSString.localizedCaseInsensitiveCompare(_:)))
            ]
        case .custom:
            return []
        }
    }
    
    // MARK: - Selection
    
    var hasSelection: Bool {
        selectionState.isActive && !selectionState.isEmpty
    }
    
    func enterSelectionMode(with bookmark: Bookmark? = nil) {
        selectionState.updateContext(currentSelectionContext())
        selectionState.activate(initialSelection: bookmark?.objectID)
        refreshSelectionSummary()
    }
    
    func toggleSelection(for bookmark: Bookmark) {
        if !selectionState.isActive {
            enterSelectionMode(with: bookmark)
            return
        }
        selectionState.toggle(bookmark.objectID)
        if selectionState.isEmpty {
            selectionState.deactivate()
        }
        refreshSelectionSummary()
    }
    
    func selectAllVisible() {
        let ids = sections.flatMap { $0.items.map(\.objectID) }
        selectionState.updateContext(currentSelectionContext())
        selectionState.activate()
        selectionState.selectMany(ids)
        refreshSelectionSummary()
    }
    
    func clearSelection() {
        selectionState.deactivate()
        refreshSelectionSummary()
    }
    
    func select(by criteria: BulkSelectionCriteria) {
        let matches = sections.flatMap { $0.items }.filter { criteria.matches($0) }
        guard !matches.isEmpty else { return }
        selectionState.updateContext(currentSelectionContext())
        selectionState.activate()
        selectionState.clear()
        selectionState.selectMany(matches.map(\.objectID))
        refreshSelectionSummary()
    }
    
    func performBulkAction(_ action: BulkAction) async {
        let ids = Array(selectionState.selectedObjectIDs)
        guard !ids.isEmpty else { return }
        do {
            try await bulkService.perform(action: action, on: ids, context: selectionState.context)
            try? coreData.save()
            clearSearchCache()
            await reload(reset: true)
        } catch {
            lastBulkActionError = error.localizedDescription
        }
    }
    
    func undoLastBulkAction() async {
        do {
            try await bulkService.undo()
            clearSearchCache()
            await reload(reset: true)
        } catch {
            lastBulkActionError = error.localizedDescription
        }
    }
    
    func redoLastBulkAction() async {
        do {
            try await bulkService.redo()
            clearSearchCache()
            await reload(reset: true)
        } catch {
            lastBulkActionError = error.localizedDescription
        }
    }
    
    func cancelBulkAction() {
        bulkService.cancel()
    }

    func refreshMetadata() async {
        isRefreshing = true
        defer { isRefreshing = false }
        let targets = allBookmarks
        let requests: [BookmarkPreviewRequest] = targets.compactMap { bookmark in
            guard let url = bookmark.url else { return nil }
            return BookmarkPreviewRequest(
                objectID: bookmark.objectID,
                url: url,
                existingPreview: bookmark.previewImage,
                existingFavicon: bookmark.favicon
            )
        }
        await withTaskGroup(of: Void.self) { group in
            for request in requests {
                group.addTask {
                    _ = await BookmarkPreviewLoader.shared.assets(for: request)
                }
            }
        }
        await MainActor.run {
            resortCurrentBookmarks()
        }
    }

    func toggleFavorite(_ b: Bookmark) {
        do {
            try coreData.setBookmark(b, favorite: !b.isFavorite)
            clearSearchCache()
            resortCurrentBookmarks()
        } catch {
            lastBulkActionError = error.localizedDescription
        }
        enqueueOperation(for: b, type: .update, changes: ["favorite": b.isFavorite.description])
    }
    
    func toggleWatched(_ b: Bookmark) {
        do {
            try coreData.setBookmark(b, watched: !b.isWatched)
            clearSearchCache()
            resortCurrentBookmarks()
        } catch {
            lastBulkActionError = error.localizedDescription
        }
    }
    
    func toggleArchive(_ b: Bookmark) {
        do {
            try coreData.setBookmark(b, archived: !b.isArchived)
            clearSearchCache()
            Task { @MainActor in await self.reload(reset: true) }
        } catch {
            lastBulkActionError = error.localizedDescription
        }
        enqueueOperation(for: b, type: .update, changes: ["archived": b.isArchived.description])
    }

    func delete(_ b: Bookmark) {
        enqueueOperation(for: b, type: .delete, changes: [:])
        coreData.viewContext.delete(b)
        try? coreData.save()
        clearSearchCache()
        allBookmarks.removeAll { $0.objectID == b.objectID }
        resortCurrentBookmarks()
        Task { await BookmarkPreviewIndex.shared.remove(objectID: b.objectID) }
#if canImport(CoreSpotlight)
        Task { await BookmarkSpotlightIndexer.shared.remove(objectID: b.objectID) }
#endif
    }

    func applyCollectionFilter(named name: String?) {
        if let name = name, !name.isEmpty {
            appliedCollectionFilter = name
            appliedTagFilter = nil
            activeFilter = .collections
            searchText = ""
        } else {
            appliedCollectionFilter = nil
            if activeFilter == .collections {
                activeFilter = .all
            }
        }
    }

    func applyTagFilter(named name: String?) {
        if let name = name, !name.isEmpty {
            appliedTagFilter = name
            appliedCollectionFilter = nil
            activeFilter = .tags
            searchText = name
        } else {
            appliedTagFilter = nil
            if activeFilter == .tags {
                activeFilter = .all
            }
        }
    }

    func clearDeepLinkFilters() {
        appliedCollectionFilter = nil
        appliedTagFilter = nil
    }
    
    func setContentTypeFilter(_ type: BookmarkContentType?) {
        if activeContentType == type {
            activeContentType = nil
        } else {
            activeContentType = type
        }
    }
    
    func clearContentTypeFilter() {
        activeContentType = nil
    }
    
    // MARK: - Helpers
    
    private func refreshSelectionSummary() {
        if selectionState.isActive {
            selectionSummary = selectionState.summary()
        } else {
            selectionSummary = BulkSelectionSummary(count: 0, contextTitle: currentSelectionContext().title)
        }
    }
    
    private func clearSearchCache() {
        searchCache.removeAll()
    }
    
    private func resortCurrentBookmarks() {
        let sorted = sortBookmarks(allBookmarks)
        sections = groupByContentType(sorted)
        pruneSelection(with: sorted)
        selectionState.updateContext(currentSelectionContext())
        refreshSelectionSummary()
    }
    
    private func currentSelectionContext() -> BulkSelectionContext {
        if let name = appliedCollectionFilter, !name.isEmpty {
            return .collection(name)
        }
        if let tag = appliedTagFilter, !tag.isEmpty {
            return .tag(tag)
        }
        if let type = activeContentType {
            return .contentType(type)
        }
        switch activeFilter {
        case .favorites:
            return .favorites
        default:
            break
        }
        if !searchText.isEmpty {
            return .search(query: searchText)
        }
        return .library
    }
    
    private func pruneSelection(with bookmarks: [Bookmark]) {
        let ids = Set(bookmarks.map(\.objectID))
        selectionState.keepOnly(ids)
    }
    
    private func enqueueOperation(for bookmark: Bookmark,
                                  type: OfflineOperation.OperationType,
                                  changes: [String: String]) {
        let bookmarkID = bookmark.objectID.uriRepresentation().absoluteString
        let payload = BookmarkOperationPayload(changes: changes, timestamp: Date())
        let encoded = try? JSONEncoder().encode(payload)
        let operation = OfflineOperation(entityName: "Bookmark",
                                         objectIdentifier: bookmarkID,
                                         payload: encoded,
                                         type: type)
        syncManager.enqueueBookmarkOperation(operation)
    }

    // MARK: - Context actions

    func createCalendarEvent(from bookmark: Bookmark) async {
        await performContextAction(
            actionName: "Create Event",
            successMessage: "\"\(bookmark.title ?? bookmark.url ?? "Bookmark")\" added to calendar.",
            task: {
                _ = try BookmarkCalendarLinkService.shared.createEvent(from: bookmark)
            }
        )
    }

    func createReadingTask(from bookmark: Bookmark) async {
        await performContextAction(
            actionName: "Create Task",
            successMessage: "Reading task scheduled.",
            task: {
                _ = try BookmarkTaskLinkService.shared.createReadLaterTask(from: bookmark)
            }
        )
    }

    func createNoteShare(from bookmark: Bookmark) async {
        await performContextAction(
            actionName: "Create Note",
            successMessage: "Shareable note created.",
            task: {
                _ = try BookmarkNoteLinkService.shared.createNote(from: bookmark)
            }
        )
    }

    private func performContextAction(actionName: String,
                                      successMessage: String,
                                      task: () throws -> Void) async {
        do {
            try task()
            await MainActor.run {
                contextActionMessage = BookmarkContextActionMessage(
                    title: "Success",
                    message: successMessage
                )
            }
        } catch {
            await MainActor.run {
                lastBulkActionError = "\(actionName) failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func sortBookmarks(_ list: [Bookmark]) -> [Bookmark] {
        switch sort {
        case .recent:
            return list.sorted { ($0.lastOpenedDate ?? $0.createdDate ?? .distantPast) > ($1.lastOpenedDate ?? $1.createdDate ?? .distantPast) }
        case .oldest:
            return list.sorted { ($0.createdDate ?? .distantPast) < ($1.createdDate ?? .distantPast) }
        case .mostVisited:
            return list.sorted { $0.openCount > $1.openCount }
        case .alphabetical:
            return list.sorted { ($0.title ?? $0.url ?? "").localizedCaseInsensitiveCompare($1.title ?? $1.url ?? "") == .orderedAscending }
        case .custom:
            return list // placeholder - customize later
        }
    }

    private func groupByContentType(_ list: [Bookmark]) -> [(String, [Bookmark])] {
        guard activeContentType == nil else {
            let title = titleForContentType(activeContentType ?? .unknown)
            return [(title, list)]
        }
        var buckets: [BookmarkContentType: [Bookmark]] = [:]
        for bookmark in list {
            let type = bookmark.contentTypeValue
            buckets[type, default: []].append(bookmark)
        }
        var result: [(String, [Bookmark])] = []
        for type in contentTypeDisplayOrder {
            guard let items = buckets.removeValue(forKey: type), !items.isEmpty else { continue }
            result.append((titleForContentType(type), items))
        }
        for (type, items) in buckets.sorted(by: { $0.key.rawValue < $1.key.rawValue }) where !items.isEmpty {
            result.append((titleForContentType(type), items))
        }
        return result
    }

    private func orderedContentTypes(from list: [Bookmark]) -> [BookmarkContentType] {
        let present = Set(list.map { $0.contentTypeValue })
        var ordered = contentTypeDisplayOrder.filter { present.contains($0) && $0 != .unknown }
        if present.contains(.unknown) {
            ordered.append(.unknown)
        }
        return ordered
    }

    private func applyContentTypeFilter(to list: [Bookmark]) -> [Bookmark] {
        guard let filter = activeContentType else { return list }
        return list.filter { $0.contentTypeValue == filter }
    }

    private func titleForContentType(_ type: BookmarkContentType) -> String {
        switch type {
        case .article: return "Articles"
        case .video: return "Videos"
        case .pdf: return "PDFs"
        case .image: return "Images"
        case .social: return "Social Posts"
        case .product: return "Products"
        case .repository: return "GitHub Repos"
        case .recipe: return "Recipes"
        case .unknown: return "Other"
        }
    }

    func toggleReadLater(for bookmark: Bookmark) {
        do {
            let added = try readLaterService.toggleReadLater(for: bookmark)
            contextActionMessage = BookmarkContextActionMessage(
                title: added ? "Added to Read Later" : "Removed from Read Later",
                message: bookmark.title ?? bookmark.url ?? "Bookmark"
            )
        } catch {
            lastBulkActionError = "Read Later update failed: \(error.localizedDescription)"
        }
    }
    
    func markBookmarkAsRead(_ bookmark: Bookmark) {
        do {
            try readLaterService.markRead(bookmark)
        } catch {
            lastBulkActionError = "Mark as read failed: \(error.localizedDescription)"
        }
    }
    
    func markBookmarkAsUnread(_ bookmark: Bookmark) {
        do {
            try readLaterService.markUnread(bookmark)
        } catch {
            lastBulkActionError = "Mark as unread failed: \(error.localizedDescription)"
        }
    }
    
    func readLaterBookmarks(includeRead: Bool = false) -> [Bookmark] {
        readLaterService.readLaterBookmarks(sortedBy: readLaterSort, includeRead: includeRead)
    }
    
    private func updateReadLaterSnapshot() {
        readLaterCount = readLaterService.unreadCount
    }
}

private struct BookmarkOperationPayload: Codable {
    let changes: [String: String]
    let timestamp: Date
}

struct BookmarkContextActionMessage: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}



