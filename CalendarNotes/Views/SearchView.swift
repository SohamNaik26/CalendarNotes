//
//  SearchView.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import SwiftUI

struct SearchView: View {
    @StateObject private var viewModel = SearchViewModel()
    @State private var selectedEvent: CalendarEvent?
    @State private var selectedNote: Note?
    @State private var selectedTask: TodoItem?
    @State private var showingEventDetail = false
    @State private var showingNoteDetail = false
    @State private var showingTaskDetail = false
    
    var body: some View {
        VStack(spacing: 0) {
                // Search Bar
                SearchBar(
                    text: $viewModel.searchText,
                    isSearching: viewModel.isSearching,
                    onClear: {
                        viewModel.searchText = ""
                    }
                )
                .padding()
                
                // Filter Toggle
                HStack {
                    Button(action: {
                        withAnimation {
                            viewModel.showFilters.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                            Text("Filters")
                            if activeFilterCount > 0 {
                                Text("(\(activeFilterCount))")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(.cnPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.cnSecondaryBackground)
                        )
                    }
                    
                    Spacer()
                    
                    if viewModel.hasResults {
                        Text("\(viewModel.totalResultCount) results")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
                
                // Filters Panel
                if viewModel.showFilters {
                    FiltersPanel(viewModel: viewModel)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Divider()
                
                // Content
                ScrollView {
                    if viewModel.searchText.isEmpty {
                    // Recent Searches
                    RecentSearchesView(
                        recentSearches: viewModel.recentSearches,
                        onSelect: { query in
                            viewModel.searchText = query
                        },
                        onDelete: { query in
                            viewModel.removeRecentSearch(query)
                        },
                        onClearAll: {
                            viewModel.clearSearchHistory()
                        }
                    )
                } else if viewModel.isSearching {
                    // Loading
                    LoadingView()
                } else if !viewModel.hasResults {
                    // Empty state
                    SearchNoResultsState(searchTerm: viewModel.searchText) {
                        viewModel.searchText = ""
                    }
                } else {
                    // Results
                    SearchResultsList(
                        viewModel: viewModel,
                        onEventTap: { event in
                            selectedEvent = event
                            showingEventDetail = true
                        },
                        onNoteTap: { note in
                            selectedNote = note
                            showingNoteDetail = true
                        },
                        onTaskTap: { task in
                            selectedTask = task
                            showingTaskDetail = true
                        }
                    )
                }
            }
            .navigationTitle("Search")
            .sheet(isPresented: $showingTaskDetail) {
                if let task = selectedTask {
                    TaskDetailSheetView(
                        task: task,
                        onToggleComplete: {
                            // Toggle and refresh
                        },
                        onConvertToEvent: {
                            // Convert task
                        },
                        onEdit: {
                            // Edit task
                        },
                        onDelete: {
                            // Delete task
                        }
                    )
                }
                }
            }
    }
    
    private var activeFilterCount: Int {
        var count = 0
        if viewModel.selectedCategories.count < EventCategory.allCases.count {
            count += 1
        }
        if viewModel.dateRangeEnabled {
            count += 1
        }
        return count
    }
}

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    let isSearching: Bool
    let onClear: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search events, notes, tasks...", text: $text)
                .focused($isFocused)
                #if os(iOS)
                .autocapitalization(.none)
                #endif
                .textFieldStyle(.plain)
            
            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            } else if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.cnSecondaryBackground)
        .cornerRadius(10)
    }
}

// MARK: - Filters Panel

struct FiltersPanel: View {
    @ObservedObject var viewModel: SearchViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Category Filter
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Categories")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Button("All") {
                        viewModel.selectAllCategories()
                    }
                    .font(.caption)
                    .foregroundColor(.cnPrimary)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(EventCategory.allCases, id: \.rawValue) { category in
                            CategoryFilterChip(
                                category: category,
                                isSelected: viewModel.selectedCategories.contains(category.rawValue),
                                onTap: {
                                    viewModel.toggleCategory(category.rawValue)
                                }
                            )
                        }
                    }
                }
            }
            
            // Date Range Filter
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Date Range", isOn: $viewModel.dateRangeEnabled)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if viewModel.dateRangeEnabled {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("From")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            DatePicker("", selection: $viewModel.dateRangeStart, displayedComponents: .date)
                                .labelsHidden()
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("To")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            DatePicker("", selection: $viewModel.dateRangeEnd, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                    .onChange(of: viewModel.dateRangeStart) { oldValue, newValue in
                        viewModel.applyDateRangeFilter()
                    }
                    .onChange(of: viewModel.dateRangeEnd) { oldValue, newValue in
                        viewModel.applyDateRangeFilter()
                    }
                }
            }
            
            // Clear Filters
            if activeFilterCount > 0 {
                Button(action: {
                    viewModel.clearFilters()
                }) {
                    HStack {
                        Image(systemName: "xmark.circle")
                        Text("Clear All Filters")
                    }
                    .foregroundColor(.cnStatusError)
                }
            }
        }
        .padding()
        .background(Color.cnSecondaryBackground)
    }
    
    private var activeFilterCount: Int {
        var count = 0
        if viewModel.selectedCategories.count < EventCategory.allCases.count {
            count += 1
        }
        if viewModel.dateRangeEnabled {
            count += 1
        }
        return count
    }
}

// MARK: - Category Filter Chip

struct CategoryFilterChip: View {
    let category: EventCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? category.color.opacity(0.2) : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? category.color : .secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? category.color : Color.clear, lineWidth: 1)
            )
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recent Searches View

struct RecentSearchesView: View {
    let recentSearches: [String]
    let onSelect: (String) -> Void
    let onDelete: (String) -> Void
    let onClearAll: () -> Void
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !recentSearches.isEmpty {
                    HStack {
                        Text("Recent Searches")
                            .font(.headline)
                        
                        Spacer()
                        
                        Button("Clear All") {
                            onClearAll()
                        }
                        .font(.caption)
                        .foregroundColor(.cnStatusError)
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    ForEach(recentSearches, id: \.self) { query in
                        Button(action: {
                            onSelect(query)
                        }) {
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.secondary)
                                
                                Text(query)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button(action: {
                                    onDelete(query)
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        
                        Divider()
                            .padding(.leading, 52)
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Recent Searches")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Text("Your search history will appear here")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                }
            }
        }
    }
}

// MARK: - Search Results List

struct SearchResultsList: View {
    @ObservedObject var viewModel: SearchViewModel
    let onEventTap: (CalendarEvent) -> Void
    let onNoteTap: (Note) -> Void
    let onTaskTap: (TodoItem) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                // Tasks Section
                if !viewModel.taskResults.isEmpty {
                    Section {
                        ForEach(viewModel.taskResults, id: \.id) { task in
                            TaskSearchResult(
                                task: task,
                                searchQuery: viewModel.searchText,
                                onTap: { onTaskTap(task) }
                            )
                            .padding(.horizontal)
                        }
                    } header: {
                        SearchSectionHeader(
                            title: "Tasks",
                            count: viewModel.taskResults.count,
                            icon: "checkmark.square",
                            color: .cnPrimary
                        )
                    }
                }
                
                // Events Section
                if !viewModel.eventResults.isEmpty {
                    Section {
                        ForEach(viewModel.eventResults, id: \.id) { event in
                            EventSearchResult(
                                event: event,
                                searchQuery: viewModel.searchText,
                                onTap: { onEventTap(event) }
                            )
                            .padding(.horizontal)
                        }
                    } header: {
                        SearchSectionHeader(
                            title: "Events",
                            count: viewModel.eventResults.count,
                            icon: "calendar",
                            color: .cnAccent
                        )
                    }
                }
                
                // Notes Section
                if !viewModel.noteResults.isEmpty {
                    Section {
                        ForEach(viewModel.noteResults, id: \.id) { note in
                            NoteSearchResult(
                                note: note,
                                searchQuery: viewModel.searchText,
                                onTap: { onNoteTap(note) }
                            )
                            .padding(.horizontal)
                        }
                    } header: {
                        SearchSectionHeader(
                            title: "Notes",
                            count: viewModel.noteResults.count,
                            icon: "doc.text",
                            color: .cnSecondary
                        )
                    }
                }
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Section Header

struct SearchSectionHeader: View {
    let title: String
    let count: Int
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Label(title, systemImage: icon)
                .font(.headline)
                .foregroundColor(color)
            
            Spacer()
            
            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color)
                .cornerRadius(12)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.cnBackground)
    }
}

// MARK: - Task Search Result

struct TaskSearchResult: View {
    let task: TodoItem
    let searchQuery: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Checkbox
                Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundColor(task.isCompleted ? .cnStatusSuccess : priorityColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Highlighted title
                    HighlightedText(
                        text: task.title ?? "Untitled",
                        highlight: searchQuery
                    )
                    .font(.body)
                    .fontWeight(.medium)
                    .strikethrough(task.isCompleted)
                    
                    HStack(spacing: 8) {
                        if let dueDate = task.dueDate {
                            Label(formatDate(dueDate), systemImage: "calendar")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Label(task.priority ?? "Medium", systemImage: "flag.fill")
                            .font(.caption)
                            .foregroundColor(priorityColor)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.cnSecondaryBackground)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private var priorityColor: Color {
        switch task.priority {
        case "Low": return .cnPriorityLow
        case "Medium": return .cnPriorityMedium
        case "High": return .cnPriorityHigh
        case "Urgent": return .cnPriorityUrgent
        default: return .cnPriorityMedium
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Event Search Result

struct EventSearchResult: View {
    let event: CalendarEvent
    let searchQuery: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Category indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(categoryColor)
                    .frame(width: 4, height: 50)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Highlighted title
                    HighlightedText(
                        text: event.title ?? "Untitled",
                        highlight: searchQuery
                    )
                    .font(.body)
                    .fontWeight(.medium)
                    
                    if let startDate = event.startDate {
                        Label(formatDateTime(startDate), systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.cnSecondaryBackground)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private var categoryColor: Color {
        EventCategory(rawValue: event.category ?? "Other")?.color ?? .cnCategoryOther
    }
    
    private func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Note Search Result

struct NoteSearchResult: View {
    let note: Note
    let searchQuery: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "doc.text")
                    .font(.title3)
                    .foregroundColor(.cnSecondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    // Highlighted title
                    HighlightedText(
                        text: extractTitle(from: note.content ?? ""),
                        highlight: searchQuery
                    )
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    
                    // Preview with highlighting
                    HighlightedText(
                        text: extractPreview(from: note.content ?? ""),
                        highlight: searchQuery
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                    
                    if let createdDate = note.createdDate {
                        Label(formatDate(createdDate), systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.cnSecondaryBackground)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
    
    private func extractTitle(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        return lines.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Untitled"
    }
    
    private func extractPreview(from content: String) -> String {
        let lines = content.components(separatedBy: .newlines)
        let preview = lines.dropFirst().joined(separator: " ")
        return String(preview.prefix(100))
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Highlighted Text

struct HighlightedText: View {
    let text: String
    let highlight: String
    
    var body: some View {
        if highlight.isEmpty {
            Text(text)
        } else {
            let parts = text.components(separatedBy: highlight.lowercased())
            
            if parts.count > 1 {
                let attributed = createAttributedString()
                Text(AttributedString(attributed))
            } else {
                Text(text)
            }
        }
    }
    
    private func createAttributedString() -> NSAttributedString {
        let attributed = NSMutableAttributedString(string: text)
        let range = NSRange(location: 0, length: text.utf16.count)
        
        let regex = try? NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: highlight), options: .caseInsensitive)
        
        regex?.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
            if let matchRange = match?.range {
                #if os(iOS)
                attributed.addAttribute(.backgroundColor, value: UIColor.systemYellow.withAlphaComponent(0.3), range: matchRange)
                attributed.addAttribute(.foregroundColor, value: UIColor.label, range: matchRange)
                #else
                attributed.addAttribute(.backgroundColor, value: NSColor.yellow.withAlphaComponent(0.3), range: matchRange)
                #endif
            }
        }
        
        return attributed
    }
}

// MARK: - Empty Search Results

struct EmptySearchResultsView: View {
    let query: String
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("No Results Found")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("No results for \"\(query)\"")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Try different keywords or adjust filters")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Searching...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SearchView()
}

