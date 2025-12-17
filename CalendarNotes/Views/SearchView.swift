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
    @State private var selectedBookmark: Bookmark?
    @State private var showingEventDetail = false
    @State private var showingNoteDetail = false
    @State private var showingTaskDetail = false
    @State private var showingBookmarkDetail = false
    
    var body: some View {
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
                // Search Bar
            LegacySearchBar(
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
                        },
                        onBookmarkTap: { bookmark in
                            selectedBookmark = bookmark
                            showingBookmarkDetail = true
                        }
                    )
                }
            }
            }
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        .navigationBarTitleDisplayMode(.large)
        .safeAreaInset(edge: .top) {
            Color.clear.frame(height: ScreenSize.statusBarHeight)
        }
        #endif
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
                .presentationCornerRadius(20)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $showingBookmarkDetail) {
            if let bookmark = selectedBookmark {
                BookmarkDetailView(bookmark: bookmark)
                    .presentationCornerRadius(20)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $viewModel.showFilters) {
            FiltersView(viewModel: viewModel)
                .presentationCornerRadius(20)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkPerformSearch)) { note in
            if let query = note.userInfo?[DeepLinkUserInfoKey.searchQuery] as? String {
                viewModel.searchText = query
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

struct LegacySearchBar: View {
    @Binding var text: String
    let isSearching: Bool
    let onClear: () -> Void
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search events, notes, tasks, bookmarks...", text: $text)
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

// MARK: - Search Results List

struct SearchResultsList: View {
    @ObservedObject var viewModel: SearchViewModel
    let onEventTap: (CalendarEvent) -> Void
    let onNoteTap: (Note) -> Void
    let onTaskTap: (TodoItem) -> Void
    let onBookmarkTap: (Bookmark) -> Void
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16, pinnedViews: [.sectionHeaders]) {
                // Bookmarks Section
                if !viewModel.bookmarkResults.isEmpty {
                    Section {
                        ForEach(viewModel.bookmarkResults, id: \.id) { bookmark in
                            BookmarkSearchResult(
                                bookmark: bookmark,
                                searchQuery: viewModel.searchText,
                                onTap: { onBookmarkTap(bookmark) }
                            )
                            .padding(.horizontal)
                        }
                    } header: {
                        SearchSectionHeader(
                            title: "Bookmarks",
                            count: viewModel.bookmarkResults.count,
                            icon: "bookmark",
                            color: .cnAccent
                        )
                    }
                }
                
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

struct BookmarkSearchResult: View {
    let bookmark: Bookmark
    let searchQuery: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "bookmark.fill")
                    .font(.title3)
                    .foregroundColor(.cnAccent)
                
                VStack(alignment: .leading, spacing: 4) {
                    HighlightedText(
                        text: bookmark.title ?? bookmark.url ?? "Untitled Bookmark",
                        highlight: searchQuery
                    )
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    
                    if let description = bookmark.bookmarkDescription, !description.isEmpty {
                        HighlightedText(
                            text: description,
                            highlight: searchQuery
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    } else if let url = bookmark.url {
                        HighlightedText(
                            text: url,
                            highlight: searchQuery
                        )
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    }
                    
                    HStack(spacing: 8) {
                        Label(bookmark.contentTypeDisplayName, systemImage: "tag")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        if let created = bookmark.createdDate {
                            Label(formatDate(created), systemImage: "clock")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Filters View

struct FiltersView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: SearchViewModel
    @State private var selectedFilters: Set<String> = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Show section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Show")
                            .font(.system(size: 17, weight: .semibold))
                        
                        HStack(spacing: 12) {
                            FilterButton(
                                title: "Events",
                                icon: "calendar",
                                isSelected: true
                            ) {
                                // Events are always shown in search
                            }
                            
                            FilterButton(
                                title: "Tasks",
                                icon: "checkmark.square",
                                isSelected: true
                            ) {
                                // Tasks are always shown in search
                            }
                        }
                    }
                    
                    // Categories section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Categories")
                            .font(.system(size: 17, weight: .semibold))
                        
                        ForEach(EventCategory.allCases, id: \.rawValue) { category in
                            CategoryToggleRow(
                                category: category,
                                isSelected: viewModel.selectedCategories.contains(category.rawValue)
                            ) {
                                viewModel.toggleCategory(category.rawValue)
                            }
                        }
                    }
                    
                    // Date Range section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Date Range")
                            .font(.system(size: 17, weight: .semibold))
                        
                        Toggle("Enable Date Range", isOn: $viewModel.dateRangeEnabled)
                            .font(.subheadline)
                        
                        if viewModel.dateRangeEnabled {
                            VStack(spacing: 12) {
                                DatePicker("From", selection: $viewModel.dateRangeStart, displayedComponents: .date)
                                DatePicker("To", selection: $viewModel.dateRangeEnd, displayedComponents: .date)
                            }
                            .onChange(of: viewModel.dateRangeStart) { _, _ in
                                viewModel.applyDateRangeFilter()
                            }
                            .onChange(of: viewModel.dateRangeEnd) { _, _ in
                                viewModel.applyDateRangeFilter()
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Filters")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Clear All") {
                        viewModel.clearFilters()
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Clear All") {
                        viewModel.clearFilters()
                    }
                    .foregroundColor(.red)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                }
                #endif
            }
        }
    }
}

// MARK: - Filter Button

struct FilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.cnPrimary.opacity(0.2) : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? .cnPrimary : .secondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.cnPrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Toggle Row

struct CategoryToggleRow: View {
    let category: EventCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: category.icon)
                    .font(.caption)
                    .foregroundColor(isSelected ? category.color : .secondary)
                
                Text(category.rawValue)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .foregroundColor(category.color)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? category.color.opacity(0.2) : Color.gray.opacity(0.1))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? category.color : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SearchView()
}

