//
//  OptimizedNotesViewModel.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 23/10/25.
//

import Foundation
import CoreData
import Combine
#if os(iOS)
import UIKit
#endif

// MARK: - Optimized Notes View Model

class OptimizedNotesViewModel: ObservableObject {
    @Published var notes: [Note] = []
    @Published var selectedDate: Date?
    @Published var sortOption: NoteSortOption = .dateCreated
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMoreNotes = true
    @Published var error: Error?
    
    // Search functionality
    let searchService = DebouncedSearchService(debounceDelay: 0.3)
    @Published var isSearching = false
    
    private let coreDataService: OptimizedCoreDataService
    private var cancellables = Set<AnyCancellable>()
    
    // Pagination
    private var currentPage = 0
    private let pageSize = 20
    
    // Performance optimization
    private var groupedNotesCache: [NoteGroup] = []
    private var lastCacheKey: String = ""
    
    init(coreDataService: OptimizedCoreDataService = OptimizedCoreDataService()) {
        self.coreDataService = coreDataService
        setupSearch()
        loadInitialNotes()
    }
    
    // MARK: - Setup
    
    private func setupSearch() {
        searchService.$debouncedSearchText
            .sink { [weak self] searchText in
                self?.performSearch(searchText)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    func loadInitialNotes() {
        currentPage = 0
        hasMoreNotes = true
        notes = []
        groupedNotesCache = []
        lastCacheKey = ""
        
        loadNotes()
    }
    
    func loadNotes() {
        guard !isLoading else { return }
        
        isLoading = true
        error = nil
        
        let searchText = searchService.debouncedSearchText.isEmpty ? nil : searchService.debouncedSearchText
        
        coreDataService.fetchNotesAsync(
            linkedToDate: selectedDate,
            page: currentPage,
            pageSize: pageSize,
            searchText: searchText
        )
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoading = false
                if case .failure(let error) = completion {
                    self?.error = error
                }
            },
            receiveValue: { [weak self] newNotes in
                self?.handleNewNotes(newNotes)
            }
        )
        .store(in: &cancellables)
    }
    
    func loadMoreNotes() {
        guard !isLoadingMore && hasMoreNotes && !isLoading else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        let searchText = searchService.debouncedSearchText.isEmpty ? nil : searchService.debouncedSearchText
        
        coreDataService.fetchNotesAsync(
            linkedToDate: selectedDate,
            page: currentPage,
            pageSize: pageSize,
            searchText: searchText
        )
        .sink(
            receiveCompletion: { [weak self] completion in
                self?.isLoadingMore = false
                if case .failure(let error) = completion {
                    self?.error = error
                    self?.currentPage -= 1 // Revert page increment on error
                }
            },
            receiveValue: { [weak self] newNotes in
                self?.handleNewNotes(newNotes, append: true)
            }
        )
        .store(in: &cancellables)
    }
    
    private func handleNewNotes(_ newNotes: [Note], append: Bool = false) {
        if append {
            notes.append(contentsOf: newNotes)
        } else {
            notes = newNotes
        }
        
        // Update pagination state
        hasMoreNotes = newNotes.count >= pageSize
        
        // Clear cache to force recalculation
        groupedNotesCache = []
        lastCacheKey = ""
    }
    
    // MARK: - Search
    
    private func performSearch(_ searchText: String) {
        isSearching = !searchText.isEmpty
        loadInitialNotes()
    }
    
    func clearSearch() {
        searchService.clearSearch()
        isSearching = false
        loadInitialNotes()
    }
    
    // MARK: - Optimized Grouping with Caching
    
    var groupedNotes: [NoteGroup] {
        let cacheKey = "\(selectedDate?.timeIntervalSince1970.description ?? "all")_\(sortOption.rawValue)_\(notes.count)"
        
        // Return cached result if available
        if cacheKey == lastCacheKey && !groupedNotesCache.isEmpty {
            return groupedNotesCache
        }
        
        let sortedNotes = getSortedNotes()
        let groups = groupNotesByDate(sortedNotes)
        
        // Cache the result
        groupedNotesCache = groups
        lastCacheKey = cacheKey
        
        return groups
    }
    
    private func getSortedNotes() -> [Note] {
        return sortNotes(notes)
    }
    
    private func sortNotes(_ notes: [Note]) -> [Note] {
        switch sortOption {
        case .dateCreated:
            return notes.sorted { ($0.createdDate ?? Date.distantPast) > ($1.createdDate ?? Date.distantPast) }
        case .dateModified:
            return notes.sorted { ($0.createdDate ?? Date.distantPast) > ($1.createdDate ?? Date.distantPast) }
        case .linkedDate:
            return notes.sorted { ($0.linkedDate ?? Date.distantPast) > ($1.linkedDate ?? Date.distantPast) }
        case .alphabetical:
            return notes.sorted { ($0.content ?? "") < ($1.content ?? "") }
        }
    }
    
    private func groupNotesByDate(_ notes: [Note]) -> [NoteGroup] {
        let calendar = Calendar.current
        let now = Date()
        
        var groups: [NoteGroup] = []
        
        // Today
        let todayNotes = notes.filter { note in
            guard let date = note.createdDate else { return false }
            return calendar.isDate(date, inSameDayAs: now)
        }
        if !todayNotes.isEmpty {
            groups.append(NoteGroup(title: "Today", notes: todayNotes))
        }
        
        // Yesterday
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let yesterdayNotes = notes.filter { note in
            guard let date = note.createdDate else { return false }
            return calendar.isDate(date, inSameDayAs: yesterday)
        }
        if !yesterdayNotes.isEmpty {
            groups.append(NoteGroup(title: "Yesterday", notes: yesterdayNotes))
        }
        
        // This Week
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let thisWeekNotes = notes.filter { note in
            guard let date = note.createdDate else { return false }
            return date >= weekStart && !calendar.isDate(date, inSameDayAs: now) && !calendar.isDate(date, inSameDayAs: yesterday)
        }
        if !thisWeekNotes.isEmpty {
            groups.append(NoteGroup(title: "This Week", notes: thisWeekNotes))
        }
        
        // This Month
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let thisMonthNotes = notes.filter { note in
            guard let date = note.createdDate else { return false }
            return date >= monthStart && date < weekStart
        }
        if !thisMonthNotes.isEmpty {
            groups.append(NoteGroup(title: "This Month", notes: thisMonthNotes))
        }
        
        // Older
        let olderNotes = notes.filter { note in
            guard let date = note.createdDate else { return false }
            return date < monthStart
        }
        if !olderNotes.isEmpty {
            groups.append(NoteGroup(title: "Older", notes: olderNotes))
        }
        
        return groups
    }
    
    // MARK: - CRUD Operations
    
    func addNote(content: String, linkedDate: Date? = nil, tags: String? = nil) {
        coreDataService.createNoteAsync(content: content, linkedDate: linkedDate, tags: tags)
            .sink(
                receiveCompletion: { [weak self] completion in
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] _ in
                    self?.loadInitialNotes()
                }
            )
            .store(in: &cancellables)
    }
    
    func deleteNote(_ note: Note) {
        do {
            // Use the original CoreDataService for deletion
            let originalService = CoreDataService()
            try originalService.deleteNote(note)
            loadInitialNotes()
        } catch {
            self.error = error
        }
    }
    
    func filterByDate(_ date: Date?) {
        selectedDate = date
        loadInitialNotes()
    }
    
    func shareNote(_ note: Note) {
        #if os(iOS)
        let activityViewController = UIActivityViewController(
            activityItems: [note.content ?? ""],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
        #else
        // macOS sharing implementation would go here
        // For now, we'll just print the content
        print("Sharing note: \(note.content ?? "")")
        #endif
    }
    
    // MARK: - Performance Helpers
    
    func preloadNextPage() {
        // Preload next page when user scrolls near the end
        if hasMoreNotes && !isLoadingMore {
            loadMoreNotes()
        }
    }
    
    func clearCache() {
        groupedNotesCache = []
        lastCacheKey = ""
        coreDataService.clearAllCache()
    }
    
    // MARK: - Statistics
    
    func getPerformanceStats() -> (cacheSize: Int, notesCount: Int, hasMore: Bool) {
        let cacheStats = coreDataService.getCacheStatistics()
        return (
            cacheSize: cacheStats.notes,
            notesCount: notes.count,
            hasMore: hasMoreNotes
        )
    }
}

