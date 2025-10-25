//
//  SearchViewModel.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import Foundation
import CoreData
import Combine
import SwiftUI

// MARK: - Search Result Types

enum SearchResultType {
    case event
    case note
    case task
}

struct SearchResult: Identifiable {
    let id = UUID()
    let type: SearchResultType
    let title: String
    let subtitle: String?
    let date: Date?
    let category: String?
    let isCompleted: Bool?
    let object: Any
    
    var iconName: String {
        switch type {
        case .event: return "calendar"
        case .note: return "doc.text"
        case .task: return "checkmark.square"
        }
    }
    
    var tintColor: Color {
        switch type {
        case .event: return .cnAccent
        case .note: return .cnSecondary
        case .task: return .cnPrimary
        }
    }
}

// MARK: - Search View Model

class SearchViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var searchText: String = ""
    @Published var eventResults: [CalendarEvent] = []
    @Published var noteResults: [Note] = []
    @Published var taskResults: [TodoItem] = []
    @Published var isSearching: Bool = false
    @Published var recentSearches: [String] = []
    
    // Filters
    @Published var selectedCategories: Set<String> = Set(EventCategory.allCases.map { $0.rawValue })
    @Published var dateRangeEnabled: Bool = false
    @Published var dateRangeStart: Date = Date()
    @Published var dateRangeEnd: Date = Date().addingTimeInterval(7 * 24 * 3600)
    @Published var showFilters: Bool = false
    
    // MARK: - Computed Properties
    
    var hasResults: Bool {
        !eventResults.isEmpty || !noteResults.isEmpty || !taskResults.isEmpty
    }
    
    var totalResultCount: Int {
        eventResults.count + noteResults.count + taskResults.count
    }
    
    var allResults: [SearchResult] {
        var results: [SearchResult] = []
        
        // Add event results
        results += eventResults.map { event in
            SearchResult(
                type: .event,
                title: event.title ?? "Untitled Event",
                subtitle: formatEventSubtitle(event),
                date: event.startDate,
                category: event.category,
                isCompleted: nil,
                object: event
            )
        }
        
        // Add note results
        results += noteResults.map { note in
            SearchResult(
                type: .note,
                title: extractTitle(from: note.content ?? ""),
                subtitle: extractPreview(from: note.content ?? ""),
                date: note.createdDate,
                category: nil,
                isCompleted: nil,
                object: note
            )
        }
        
        // Add task results
        results += taskResults.map { task in
            SearchResult(
                type: .task,
                title: task.title ?? "Untitled Task",
                subtitle: task.category,
                date: task.dueDate,
                category: task.category,
                isCompleted: task.isCompleted,
                object: task
            )
        }
        
        return results
    }
    
    // MARK: - Private Properties
    
    private let coreDataManager = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let userDefaults = UserDefaults.standard
    private let recentSearchesKey = "recentSearches"
    private let maxRecentSearches = 10
    
    // MARK: - Initialization
    
    init() {
        loadRecentSearches()
        setupSearchDebouncing()
    }
    
    // MARK: - Search Debouncing
    
    private func setupSearchDebouncing() {
        $searchText
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch(query: query)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Search Execution
    
    private func performSearch(query: String) {
        guard !query.isEmpty else {
            clearResults()
            return
        }
        
        isSearching = true
        
        Task { @MainActor in
            do {
                async let events = searchEvents(query: query)
                async let notes = searchNotes(query: query)
                async let tasks = searchTasks(query: query)
                
                (eventResults, noteResults, taskResults) = try await (events, notes, tasks)
                
                // Save to recent searches
                if hasResults {
                    addToRecentSearches(query)
                }
                
                isSearching = false
            } catch {
                print("Search error: \(error.localizedDescription)")
                isSearching = false
            }
        }
    }
    
    private func searchEvents(query: String) async throws -> [CalendarEvent] {
        let request: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
        var predicates: [NSPredicate] = [
            NSPredicate(format: "title CONTAINS[cd] %@", query)
        ]
        
        // Apply category filter
        if !selectedCategories.isEmpty && selectedCategories.count < EventCategory.allCases.count {
            predicates.append(NSPredicate(format: "category IN %@", Array(selectedCategories)))
        }
        
        // Apply date range filter
        if dateRangeEnabled {
            predicates.append(NSPredicate(
                format: "startDate >= %@ AND startDate <= %@",
                dateRangeStart as NSDate,
                dateRangeEnd as NSDate
            ))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CalendarEvent.startDate, ascending: false)]
        request.fetchLimit = 50
        
        return try await coreDataManager.fetchAsync(request)
    }
    
    private func searchNotes(query: String) async throws -> [Note] {
        let request: NSFetchRequest<Note> = Note.fetchRequest()
        var predicates: [NSPredicate] = [
            NSPredicate(format: "content CONTAINS[cd] %@ OR tags CONTAINS[cd] %@", query, query)
        ]
        
        // Apply date range filter
        if dateRangeEnabled {
            predicates.append(NSPredicate(
                format: "createdDate >= %@ AND createdDate <= %@",
                dateRangeStart as NSDate,
                dateRangeEnd as NSDate
            ))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Note.createdDate, ascending: false)]
        request.fetchLimit = 50
        
        return try await coreDataManager.fetchAsync(request)
    }
    
    private func searchTasks(query: String) async throws -> [TodoItem] {
        let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
        var predicates: [NSPredicate] = [
            NSPredicate(format: "title CONTAINS[cd] %@", query)
        ]
        
        // Apply category filter
        if !selectedCategories.isEmpty && selectedCategories.count < EventCategory.allCases.count {
            predicates.append(NSPredicate(format: "category IN %@", Array(selectedCategories)))
        }
        
        // Apply date range filter
        if dateRangeEnabled {
            predicates.append(NSPredicate(
                format: "dueDate >= %@ AND dueDate <= %@",
                dateRangeStart as NSDate,
                dateRangeEnd as NSDate
            ))
        }
        
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TodoItem.dueDate, ascending: true)]
        request.fetchLimit = 50
        
        return try await coreDataManager.fetchAsync(request)
    }
    
    // MARK: - Helpers
    
    private func clearResults() {
        eventResults = []
        noteResults = []
        taskResults = []
    }
    
    private func formatEventSubtitle(_ event: CalendarEvent) -> String {
        var parts: [String] = []
        
        if let startDate = event.startDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            parts.append(formatter.string(from: startDate))
        }
        
        if let location = event.location, !location.isEmpty {
            parts.append(location)
        }
        
        return parts.joined(separator: " • ")
    }
    
    private func extractTitle(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        return lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Untitled Note"
    }
    
    private func extractPreview(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        let preview = lines.dropFirst().joined(separator: " ")
        let trimmed = preview.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(100))
    }
    
    // MARK: - Recent Searches
    
    private func loadRecentSearches() {
        if let saved = userDefaults.stringArray(forKey: recentSearchesKey) {
            recentSearches = saved
        }
    }
    
    private func addToRecentSearches(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Remove if already exists
        recentSearches.removeAll { $0 == trimmed }
        
        // Add to beginning
        recentSearches.insert(trimmed, at: 0)
        
        // Limit to max count
        if recentSearches.count > maxRecentSearches {
            recentSearches = Array(recentSearches.prefix(maxRecentSearches))
        }
        
        // Save to UserDefaults
        userDefaults.set(recentSearches, forKey: recentSearchesKey)
    }
    
    func clearSearchHistory() {
        recentSearches = []
        userDefaults.removeObject(forKey: recentSearchesKey)
    }
    
    func removeRecentSearch(_ query: String) {
        recentSearches.removeAll { $0 == query }
        userDefaults.set(recentSearches, forKey: recentSearchesKey)
    }
    
    // MARK: - Filters
    
    func toggleCategory(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
        
        // Re-run search if active
        if !searchText.isEmpty {
            performSearch(query: searchText)
        }
    }
    
    func selectAllCategories() {
        selectedCategories = Set(EventCategory.allCases.map { $0.rawValue })
        if !searchText.isEmpty {
            performSearch(query: searchText)
        }
    }
    
    func applyDateRangeFilter() {
        if !searchText.isEmpty {
            performSearch(query: searchText)
        }
    }
    
    func clearFilters() {
        selectedCategories = Set(EventCategory.allCases.map { $0.rawValue })
        dateRangeEnabled = false
        if !searchText.isEmpty {
            performSearch(query: searchText)
        }
    }
}

