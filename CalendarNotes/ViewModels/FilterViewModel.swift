//
//  FilterViewModel.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Filter Preset

struct FilterPreset: Codable, Identifiable {
    let id: UUID
    var name: String
    var selectedCategories: Set<String>
    var dateRangeEnabled: Bool
    var dateRangeStart: Date
    var dateRangeEnd: Date
    var showEvents: Bool
    var showTasks: Bool
    var includeCompleted: Bool
    var selectedPriorities: Set<String>
    
    init(
        id: UUID = UUID(),
        name: String,
        selectedCategories: Set<String> = Set(EventCategory.allCases.map { $0.rawValue }),
        dateRangeEnabled: Bool = false,
        dateRangeStart: Date = Date(),
        dateRangeEnd: Date = Date().addingTimeInterval(7 * 24 * 3600),
        showEvents: Bool = true,
        showTasks: Bool = true,
        includeCompleted: Bool = false,
        selectedPriorities: Set<String> = Set(TodoItem.Priority.allCases.map { $0.rawValue })
    ) {
        self.id = id
        self.name = name
        self.selectedCategories = selectedCategories
        self.dateRangeEnabled = dateRangeEnabled
        self.dateRangeStart = dateRangeStart
        self.dateRangeEnd = dateRangeEnd
        self.showEvents = showEvents
        self.showTasks = showTasks
        self.includeCompleted = includeCompleted
        self.selectedPriorities = selectedPriorities
    }
}

// MARK: - Filter View Model

class FilterViewModel: ObservableObject {
    // MARK: - Published Properties
    
    // Category Filters
    @Published var selectedCategories: Set<String> = Set(EventCategory.allCases.map { $0.rawValue })
    
    // Date Range Filters
    @Published var dateRangeEnabled: Bool = false
    @Published var dateRangeStart: Date = Date()
    @Published var dateRangeEnd: Date = Date().addingTimeInterval(7 * 24 * 3600)
    
    // Content Type Filters
    @Published var showEvents: Bool = true
    @Published var showTasks: Bool = true
    
    // Task-Specific Filters
    @Published var includeCompleted: Bool = false
    @Published var selectedPriorities: Set<String> = Set(TodoItem.Priority.allCases.map { $0.rawValue })
    
    // Presets
    @Published var filterPresets: [FilterPreset] = []
    @Published var activePresetId: UUID?
    
    // UI State
    @Published var showFilterPanel: Bool = false
    
    // MARK: - Computed Properties
    
    var activeFilterCount: Int {
        var count = 0
        
        // Category filter
        if selectedCategories.count < EventCategory.allCases.count {
            count += 1
        }
        
        // Date range filter
        if dateRangeEnabled {
            count += 1
        }
        
        // Content type filter
        if !showEvents || !showTasks {
            count += 1
        }
        
        // Completed filter
        if !includeCompleted {
            count += 1
        }
        
        // Priority filter
        if selectedPriorities.count < TodoItem.Priority.allCases.count {
            count += 1
        }
        
        return count
    }
    
    var hasActiveFilters: Bool {
        activeFilterCount > 0
    }
    
    var activePreset: FilterPreset? {
        guard let id = activePresetId else { return nil }
        return filterPresets.first { $0.id == id }
    }
    
    // MARK: - Private Properties
    
    private let userDefaults = UserDefaults.standard
    private let presetsKey = "filterPresets"
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        loadPresets()
        setupDefaultPresets()
    }
    
    // MARK: - Category Management
    
    func toggleCategory(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
        clearActivePreset()
    }
    
    func selectAllCategories() {
        selectedCategories = Set(EventCategory.allCases.map { $0.rawValue })
        clearActivePreset()
    }
    
    func deselectAllCategories() {
        selectedCategories.removeAll()
        clearActivePreset()
    }
    
    // MARK: - Priority Management
    
    func togglePriority(_ priority: String) {
        if selectedPriorities.contains(priority) {
            selectedPriorities.remove(priority)
        } else {
            selectedPriorities.insert(priority)
        }
        clearActivePreset()
    }
    
    func selectAllPriorities() {
        selectedPriorities = Set(TodoItem.Priority.allCases.map { $0.rawValue })
        clearActivePreset()
    }
    
    // MARK: - Quick Filters
    
    func clearAllFilters() {
        selectedCategories = Set(EventCategory.allCases.map { $0.rawValue })
        dateRangeEnabled = false
        showEvents = true
        showTasks = true
        includeCompleted = false
        selectedPriorities = Set(TodoItem.Priority.allCases.map { $0.rawValue })
        clearActivePreset()
    }
    
    func showOnlyTodayItems() {
        dateRangeEnabled = true
        let today = Calendar.current.startOfDay(for: Date())
        dateRangeStart = today
        dateRangeEnd = Calendar.current.date(byAdding: .day, value: 1, to: today)!
        clearActivePreset()
    }
    
    func showOnlyThisWeek() {
        dateRangeEnabled = true
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) else { return }
        dateRangeStart = weekInterval.start
        dateRangeEnd = weekInterval.end
        clearActivePreset()
    }
    
    func showOnlyHighPriority() {
        selectedPriorities = Set(["High", "Urgent"])
        clearActivePreset()
    }
    
    // MARK: - Preset Management
    
    func saveCurrentAsPreset(name: String) {
        let preset = FilterPreset(
            name: name,
            selectedCategories: selectedCategories,
            dateRangeEnabled: dateRangeEnabled,
            dateRangeStart: dateRangeStart,
            dateRangeEnd: dateRangeEnd,
            showEvents: showEvents,
            showTasks: showTasks,
            includeCompleted: includeCompleted,
            selectedPriorities: selectedPriorities
        )
        
        filterPresets.append(preset)
        savePresets()
    }
    
    func deletePreset(_ preset: FilterPreset) {
        filterPresets.removeAll { $0.id == preset.id }
        if activePresetId == preset.id {
            activePresetId = nil
        }
        savePresets()
    }
    
    func applyPreset(_ preset: FilterPreset) {
        selectedCategories = preset.selectedCategories
        dateRangeEnabled = preset.dateRangeEnabled
        dateRangeStart = preset.dateRangeStart
        dateRangeEnd = preset.dateRangeEnd
        showEvents = preset.showEvents
        showTasks = preset.showTasks
        includeCompleted = preset.includeCompleted
        selectedPriorities = preset.selectedPriorities
        activePresetId = preset.id
    }
    
    private func clearActivePreset() {
        activePresetId = nil
    }
    
    // MARK: - Persistence
    
    private func loadPresets() {
        guard let data = userDefaults.data(forKey: presetsKey),
              let decoded = try? JSONDecoder().decode([FilterPreset].self, from: data) else {
            return
        }
        filterPresets = decoded
    }
    
    private func savePresets() {
        if let encoded = try? JSONEncoder().encode(filterPresets) {
            userDefaults.set(encoded, forKey: presetsKey)
        }
    }
    
    private func setupDefaultPresets() {
        guard filterPresets.isEmpty else { return }
        
        // Today's Items
        filterPresets.append(FilterPreset(
            name: "Today",
            dateRangeEnabled: true,
            dateRangeStart: Calendar.current.startOfDay(for: Date()),
            dateRangeEnd: Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
        ))
        
        // This Week
        let calendar = Calendar.current
        if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: Date()) {
            filterPresets.append(FilterPreset(
                name: "This Week",
                dateRangeEnabled: true,
                dateRangeStart: weekInterval.start,
                dateRangeEnd: weekInterval.end
            ))
        }
        
        // Work Only
        filterPresets.append(FilterPreset(
            name: "Work",
            selectedCategories: Set(["Work"])
        ))
        
        // High Priority
        filterPresets.append(FilterPreset(
            name: "High Priority",
            selectedPriorities: Set(["High", "Urgent"])
        ))
        
        savePresets()
    }
    
    // MARK: - Filter Application
    
    func filterEvents(_ events: [CalendarEvent]) -> [CalendarEvent] {
        var filtered = events
        
        // Show/Hide events
        if !showEvents {
            return []
        }
        
        // Category filter
        if !selectedCategories.isEmpty && selectedCategories.count < EventCategory.allCases.count {
            filtered = filtered.filter { event in
                selectedCategories.contains(event.category ?? "Other")
            }
        }
        
        // Date range filter
        if dateRangeEnabled {
            filtered = filtered.filter { event in
                guard let startDate = event.startDate else { return false }
                return startDate >= dateRangeStart && startDate <= dateRangeEnd
            }
        }
        
        return filtered
    }
    
    func filterTasks(_ tasks: [TodoItem]) -> [TodoItem] {
        var filtered = tasks
        
        // Show/Hide tasks
        if !showTasks {
            return []
        }
        
        // Category filter
        if !selectedCategories.isEmpty && selectedCategories.count < EventCategory.allCases.count {
            filtered = filtered.filter { task in
                selectedCategories.contains(task.category ?? "Other")
            }
        }
        
        // Date range filter
        if dateRangeEnabled {
            filtered = filtered.filter { task in
                guard let dueDate = task.dueDate else { return false }
                return dueDate >= dateRangeStart && dueDate <= dateRangeEnd
            }
        }
        
        // Completed filter
        if !includeCompleted {
            filtered = filtered.filter { !$0.isCompleted }
        }
        
        // Priority filter
        if !selectedPriorities.isEmpty && selectedPriorities.count < TodoItem.Priority.allCases.count {
            filtered = filtered.filter { task in
                selectedPriorities.contains(task.priority ?? "Medium")
            }
        }
        
        return filtered
    }
    
    func filterNotes(_ notes: [Note]) -> [Note] {
        var filtered = notes
        
        // Date range filter
        if dateRangeEnabled {
            filtered = filtered.filter { note in
                guard let createdDate = note.createdDate else { return false }
                return createdDate >= dateRangeStart && createdDate <= dateRangeEnd
            }
        }
        
        return filtered
    }
}

