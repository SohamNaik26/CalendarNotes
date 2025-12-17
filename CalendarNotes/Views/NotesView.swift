//
//  NotesView.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct NotesView: View {
    @StateObject private var viewModel = NotesViewModel()
    @State private var showingAddNote = false
    @State private var showingDateFilter = false
    @State private var showingSortOptions = false
    @State private var isRefreshing = false
    @State private var selectedNote: Note?
    @State private var showingNoteDetail = false
    @State private var pendingNoteForActions: Note?
    @State private var showingNoteActions = false
    
    private var controlBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    private var windowBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    @State private var viewMode: ViewMode = .list
    @Environment(\.colorScheme) var colorScheme
    
    enum ViewMode: String, CaseIterable {
        case list = "list"
        case grid = "grid"
        
        var icon: String {
            switch self {
            case .list: return "list.bullet"
            case .grid: return "square.grid.2x2"
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            #if os(macOS)
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()
            #else
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            #endif
            
            VStack(spacing: 0) {
                    // Header with Add Note Button
                    HStack {
                        Text("Notes")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Button(action: {
                            showingAddNote = true
                            #if os(iOS)
                            generateHapticFeedback(style: .medium)
                            #endif
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "plus")
                                    .font(.system(size: 14, weight: .semibold))
                                Text("Add Note")
                                    .font(.system(size: 14, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(
                                        LinearGradient(
                                            gradient: Gradient(colors: [.cnPrimary, .cnAccent]),
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        
                        // View Toggle Buttons
                        HStack(spacing: 8) {
                            ForEach(ViewMode.allCases, id: \.self) { mode in
                                Button(action: {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewMode = mode
                                    }
                                    #if os(iOS)
                                    generateHapticFeedback(style: .light)
                                    #endif
                                }) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(viewMode == mode ? .white : .primary)
                                        .frame(width: 32, height: 32)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6)
                                                .fill(viewMode == mode ? Color.accentColor : controlBackgroundColor)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                    
                    // Search and Filter Bar
                    SearchAndFilterBar(
                        searchText: $viewModel.searchText,
                        sortOption: $viewModel.sortOption,
                        onDateFilter: { showingDateFilter = true },
                        onSortOptions: { showingSortOptions = true }
                    )
                    if !viewModel.availableKinds.isEmpty {
                        noteKindFilters
                            .padding(.horizontal)
                            .padding(.bottom, 4)
                    }
                    
                    // Date Filter Banner
                if viewModel.selectedDate != nil {
                        DateFilterBanner(
                            selectedDate: viewModel.selectedDate!,
                            onClear: { viewModel.filterByDate(nil) }
                        )
                    }
                    
                    // Notes List with Grouping
                    Group {
                        switch viewModel.notesState {
                        case .idle:
                            EmptyView()
                        case .loading:
                            ScrollView {
                                VStack(spacing: 12) {
                                    ForEach(0..<5, id: \.self) { _ in
                                        NoteCardSkeleton()
                                    }
                                }
                                .padding()
                            }
                        case .loaded:
                            if viewModel.groupedNotes.isEmpty {
                                if viewModel.searchText.isEmpty {
                                    NotesEmptyState {
                                        showingAddNote = true
                                    }
                                } else {
                                    SearchNoResultsState(searchTerm: viewModel.searchText) {
                                        viewModel.searchText = ""
                                    }
                                }
                            } else {
                                GroupedNotesList(
                                    groupedNotes: viewModel.groupedNotes,
                                    viewMode: viewMode,
                                    onTap: { note in
                                        pendingNoteForActions = note
                                        showingNoteActions = true
                                    },
                                    onDelete: { note in
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            viewModel.deleteNote(note)
                                        }
                                    },
                                    onShare: { note in
                                        viewModel.shareNote(note)
                                    },
                                    onRefresh: {
                                        await refreshNotes()
                                    }
                                )
                            }
                        case .error(let error):
                            ErrorView(error: error) {
                                viewModel.loadNotes()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Floating Action Button
                FloatingAddButton {
                    showingAddNote = true
                    #if os(iOS)
                    generateHapticFeedback(style: .medium)
                    #endif
                }
                .padding(.bottom, 20)
                .padding(.trailing, 20)
            }
            .navigationTitle("Notes")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Menu {
                        Button(action: { showingDateFilter = true }) {
                            Label("Filter by Date", systemImage: "calendar")
                        }
                        
                        Button(action: { showingSortOptions = true }) {
                            Label("Sort Options", systemImage: "arrow.up.arrow.down")
                        }
                        
                        Button(action: { showingAddNote = true }) {
                            Label("New Note", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .sheet(isPresented: $showingAddNote, onDismiss: {
                viewModel.loadNotes()
            }) {
                #if os(macOS)
                NoteEditorView(viewModel: NoteEditorViewModel(note: nil))
                    .frame(minWidth: 900, minHeight: 760)
                    .padding(24)
                #else
                NoteEditorView(viewModel: NoteEditorViewModel(note: nil))
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                #endif
            }
            .sheet(isPresented: $showingNoteDetail, onDismiss: {
                viewModel.loadNotes()
            }) {
                if let selectedNote = selectedNote {
                    #if os(macOS)
                    NoteEditorView(viewModel: NoteEditorViewModel(note: selectedNote))
                        .frame(minWidth: 900, minHeight: 760)
                        .padding(24)
                    #else
                    NoteEditorView(viewModel: NoteEditorViewModel(note: selectedNote))
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                    #endif
                }
            }
            .sheet(isPresented: $showingDateFilter) {
                adaptiveSheet(width: 420, height: 320) {
                    DateFilterView(selectedDate: $viewModel.selectedDate) { date in
                        viewModel.filterByDate(date)
                    }
                }
            }
            .sheet(isPresented: $showingSortOptions) {
                adaptiveSheet(width: 360, height: 280) {
                    SortOptionsView(sortOption: $viewModel.sortOption)
                }
            }
            .confirmationDialog("Note Options", isPresented: $showingNoteActions, presenting: pendingNoteForActions) { note in
                Button("Open Note") {
                    openNote(note)
                }
                Button("Share Note") {
                    shareNote(note)
                }
                Button("Delete Note", role: .destructive) {
                    deleteNote(note)
                }
                Button("Cancel", role: .cancel) {
                    pendingNoteForActions = nil
                }
            } message: { _ in
                Text("Choose how you'd like to interact with this note.")
            }
            .task {
                viewModel.loadNotes()
            }
    }
    
    private func refreshNotes() async {
        isRefreshing = true
        await viewModel.refresh()
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        isRefreshing = false
    }
    
    private func openNote(_ note: Note) {
        pendingNoteForActions = nil
        selectedNote = note
        showingNoteDetail = true
    }
    
    private func shareNote(_ note: Note) {
        pendingNoteForActions = nil
        viewModel.shareNote(note)
    }
    
    private func deleteNote(_ note: Note) {
        pendingNoteForActions = nil
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.deleteNote(note)
        }
    }
    
    #if os(iOS)
    private func generateHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    #endif
}

private extension NotesView {
    var noteKindFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(viewModel.availableKinds, id: \.self) { kind in
                    let isActive = viewModel.activeKind == kind
                    Button {
                        viewModel.setKindFilter(kind)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: kind.iconName)
                            Text(kind.displayName)
                                .font(.caption)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(isActive ? Color.cnAccent.opacity(0.2) : Color.cnTertiaryBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isActive ? Color.cnAccent : Color.clear, lineWidth: 1.5)
                        )
                        .cornerRadius(10)
                        .foregroundColor(isActive ? .cnAccent : .cnPrimaryText)
                    }
                    .buttonStyle(.plain)
                }
                if viewModel.activeKind != nil {
                    Button("Clear") {
                        viewModel.clearKindFilter()
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.cnSecondaryBackground)
                    .cornerRadius(10)
                }
            }
            .padding(.vertical, 2)
        }
    }
}

// MARK: - Search and Filter Bar

struct SearchAndFilterBar: View {
    @Binding var searchText: String
    @Binding var sortOption: NoteSortOption
    let onDateFilter: () -> Void
    let onSortOptions: () -> Void
    
    private var controlBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    private var windowBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("Search notes...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.cnSecondaryBackground)
                .cornerRadius(10)
                
                // Filter Button
                Button(action: onDateFilter) {
                    Image(systemName: "calendar")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.cnPrimary, .cnAccent]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .shadow(color: .cnPrimary.opacity(0.3), radius: 6, x: 0, y: 3)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 0.2), value: false)
                }
                .buttonStyle(ScaleButtonStyle())
                .onHover { isHovered in
                    // Hover effect handled by ScaleButtonStyle
                }
                
                // Sort Button
                Button(action: onSortOptions) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.cnAccent, .cnPrimary]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                        .shadow(color: .cnAccent.opacity(0.3), radius: 6, x: 0, y: 3)
                        .scaleEffect(1.0)
                        .animation(.easeInOut(duration: 0.2), value: false)
                }
                .buttonStyle(ScaleButtonStyle())
                .onHover { isHovered in
                    // Hover effect handled by ScaleButtonStyle
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)
        }
    }
}

// MARK: - Date Filter Banner

struct DateFilterBanner: View {
    let selectedDate: Date
    let onClear: () -> Void
    
    private var controlBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    private var windowBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    var body: some View {
        HStack {
            Image(systemName: "calendar")
                .foregroundColor(.cnPrimary)
            
            Text("Filtered by: \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Button("Clear") {
                onClear()
            }
            .font(.subheadline)
            .foregroundColor(.cnPrimary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.cnPrimary.opacity(0.1))
    }
}

// MARK: - Grouped Notes List

struct GroupedNotesList: View {
    let groupedNotes: [NoteGroup]
    let viewMode: NotesView.ViewMode
    let onTap: (Note) -> Void
    let onDelete: (Note) -> Void
    let onShare: (Note) -> Void
    let onRefresh: () async -> Void
    
    private var controlBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    private var windowBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    var body: some View {
        if viewMode == .list {
            List {
                ForEach(groupedNotes, id: \.title) { group in
                    Section(group.title) {
                        ForEach(group.notes, id: \.id) { note in
                            Button(action: {
                                onTap(note)
                            }) {
                                NoteCardView(note: note)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive, action: {
                                    onDelete(note)
                                }) {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button(action: {
                                    onShare(note)
                                }) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive, action: {
                                        onDelete(note)
                                    }) {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    
                                    Button(action: {
                                        onShare(note)
                                    }) {
                                        Label("Share", systemImage: "square.and.arrow.up")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                }
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.sidebar)
            #endif
            .refreshable {
                await onRefresh()
            }
        } else {
            // Grid View
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(groupedNotes, id: \.title) { group in
                        VStack(alignment: .leading, spacing: 12) {
                            // Section Header
                            HStack {
                                Text(group.title)
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.horizontal)
                            
                            // Grid Layout
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 12),
                                GridItem(.flexible(), spacing: 12)
                            ], spacing: 12) {
                                ForEach(group.notes, id: \.id) { note in
                                    Button(action: {
                                        onTap(note)
                                    }) {
                                        NoteGridCardView(note: note)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button(role: .destructive, action: {
                                            onDelete(note)
                                        }) {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        
                                        Button(action: {
                                            onShare(note)
                                        }) {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.vertical)
            }
            .refreshable {
                await onRefresh()
            }
        }
    }
}

// MARK: - Note Grid Card View

struct NoteGridCardView: View {
    let note: Note
    @Environment(\.colorScheme) var colorScheme
    
    private var controlBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    private var windowBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: note.noteKind.iconName)
                    .foregroundColor(.cnAccent)
                    .font(.caption)
                Text(note.noteKind.displayName)
                    .font(.caption)
                    .foregroundColor(.cnAccent)
                Spacer()
                Text(noteDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Text(noteTitle)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Text(noteSummary)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(4)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            metadataFooter
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 120, maxHeight: 150)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(controlBackgroundColor)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var noteTitle: String {
        let content = note.content ?? ""
        return String(content.prefix(50)) + (content.count > 50 ? "..." : "")
    }
    
    private var noteSummary: String {
        if let summary = note.summaryText, !summary.isEmpty {
            return summary
        }
        let content = note.content ?? ""
        return content.isEmpty ? "No content yet" : String(content.prefix(140))
    }
    
    private var noteDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        if let createdDate = note.createdDate {
            return formatter.string(from: createdDate)
        } else {
            return "No date"
        }
    }
    
    private var metadataFooter: some View {
        HStack(spacing: 10) {
            if !note.actionItems.isEmpty {
                Label("\(note.actionItems.count)", systemImage: "checkmark.circle")
                    .font(.caption2)
                    .foregroundColor(.cnAccent)
            }
            if !note.detectedPeopleList.isEmpty {
                Label("\(note.detectedPeopleList.count)", systemImage: "person.2")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Label("~\(note.estimatedReadingMinutes) min", systemImage: "clock")
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            if let sentiment = note.sentimentValue {
                Image(systemName: sentimentIcon(sentiment))
                    .foregroundColor(sentimentColor(sentiment))
                    .font(.caption)
            }
        }
    }
    
    private func sentimentIcon(_ sentiment: Note.NoteSentiment) -> String {
        switch sentiment {
        case .positive: return "face.smiling"
        case .neutral: return "face.dashed"
        case .negative: return "face.frown"
        }
    }
    
    private func sentimentColor(_ sentiment: Note.NoteSentiment) -> Color {
        switch sentiment {
        case .positive: return .green
        case .neutral: return .secondary
        case .negative: return .red
        }
    }
}

// MARK: - Note Card View

struct NoteCardView: View {
    let note: Note
    @Environment(\.colorScheme) var colorScheme
    
    private var controlBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    private var windowBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: note.noteKind.iconName)
                    .foregroundColor(.cnAccent)
                    .font(.caption)
                Text(note.noteKind.displayName)
                    .font(.caption)
                    .foregroundColor(.cnAccent)
                Spacer()
                if let sentiment = note.sentimentValue {
                    Image(systemName: sentimentIcon(sentiment))
                        .foregroundColor(sentimentColor(sentiment))
                        .font(.caption)
                }
            }
            
            Text(noteTitle)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(2)
                .foregroundColor(.primary)
            
            Text(noteSummary)
                .font(.subheadline)
                .lineLimit(4)
                .foregroundColor(.secondary)
            
            // Tags and Date Row
            HStack {
                // Tags
                if let tags = note.tags, !tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                    ForEach(note.tagArray, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption)
                                    .fontWeight(.medium)
                            .foregroundColor(.cnAccent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.cnAccent.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                }
                
                Spacer()
                
                // Date
                VStack(alignment: .trailing, spacing: 2) {
                    if let linkedDate = note.linkedDate {
                        Label(linkedDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(.cnPrimary)
                    }
                    
                    Text(note.createdDate?.formatted(date: .abbreviated, time: .omitted) ?? "")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            metadataFooter
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                #if os(iOS)
                .fill(colorScheme == .dark ? Color(white: 0.1) : Color(.systemBackground))
                #else
                .fill(colorScheme == .dark ? Color(white: 0.1) : Color.white)
                #endif
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 2, x: 0, y: 1)
    }
    
    private var noteTitle: String {
        let content = note.content ?? ""
        let firstLine = content.components(separatedBy: .newlines).first ?? ""
        return firstLine.isEmpty ? "Untitled Note" : firstLine
    }
    
    private var noteSummary: String {
        if let summary = note.summaryText, !summary.isEmpty {
            return summary
        }
        let content = note.content ?? ""
        return content.isEmpty ? "Add some content to this note." : String(content.prefix(220))
    }
    
    private var metadataFooter: some View {
        HStack(spacing: 12) {
            if !note.actionItems.isEmpty {
                Label("\(note.actionItems.count) actions", systemImage: "checkmark.circle")
                    .font(.caption2)
                    .foregroundColor(.cnAccent)
            }
            if !note.detectedPeopleList.isEmpty {
                Label(note.detectedPeopleList.joined(separator: ", "), systemImage: "person.2")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            Label("\(note.estimatedReadingMinutes) min", systemImage: "clock")
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
        }
    }
    
    private func sentimentIcon(_ sentiment: Note.NoteSentiment) -> String {
        switch sentiment {
        case .positive: return "face.smiling"
        case .neutral: return "face.dashed"
        case .negative: return "face.frown"
        }
    }
    
    private func sentimentColor(_ sentiment: Note.NoteSentiment) -> Color {
        switch sentiment {
        case .positive: return .green
        case .neutral: return .secondary
        case .negative: return .red
        }
    }
}


// MARK: - Date Filter View

struct DateFilterView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedDate: Date?
    let onDateSelected: (Date?) -> Void
    
    @State private var tempSelectedDate: Date?
    
    private var controlBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    private var windowBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Filter Notes by Date")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Date Picker
            DatePicker("Select Date", selection: Binding(
                get: { tempSelectedDate ?? Date() },
                set: { tempSelectedDate = $0 }
            ), displayedComponents: .date)
            .datePickerStyle(.graphical)
            .padding(.horizontal)
            
            // Action Buttons
            HStack(spacing: 12) {
                Button("Clear Filter") {
                    onDateSelected(nil)
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Apply") {
                    onDateSelected(tempSelectedDate)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.horizontal)
            .padding(.bottom)
            
            Spacer()
        }
        .frame(width: 400, height: 500)
        .background(windowBackgroundColor)
        .cornerRadius(12)
        .shadow(radius: 10)
        .onAppear {
            tempSelectedDate = selectedDate
        }
    }
}

// MARK: - Sort Options View

struct SortOptionsView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var sortOption: NoteSortOption
    
    private var controlBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    private var windowBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Sort Options")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top)
            .padding(.bottom, 8)
            
            // Sort Options List
            VStack(spacing: 0) {
                ForEach(NoteSortOption.allCases, id: \.self) { option in
                    Button(action: {
                        sortOption = option
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: option.icon)
                                .foregroundColor(.cnPrimary)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(option.title)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Text(option.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            if sortOption == option {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.cnPrimary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    
                    if option != NoteSortOption.allCases.last {
                        Divider()
                            .padding(.horizontal)
                    }
                }
            }
            .background(controlBackgroundColor)
            .cornerRadius(8)
            .padding(.horizontal)
            
            Spacer()
        }
        .frame(width: 350, height: 300)
        .background(windowBackgroundColor)
        .cornerRadius(12)
        .shadow(radius: 10)
    }
}

// MARK: - Floating Add Button

private struct NotesFloatingAddButton: View {
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    private var controlBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    private var windowBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    var body: some View {
        HStack {
            Spacer()
            
            Button(action: action) {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.cnPrimary, .cnAccent]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: Color.cnPrimary.opacity(0.4), radius: 8, x: 0, y: 4)
            }
        }
    }
}

#if os(macOS)
private struct AdaptiveSheetContainer<Content: View>: View {
    let width: CGFloat
    let height: CGFloat
    let content: () -> Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
                .padding(24)
        }
        .frame(minWidth: width, maxWidth: width, minHeight: height, maxHeight: height)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: Color.black.opacity(0.18), radius: 18, x: 0, y: 14)
        )
        .padding(32)
    }
}
#endif

fileprivate func adaptiveSheet<Content: View>(width: CGFloat, height: CGFloat, @ViewBuilder content: @escaping () -> Content) -> some View {
    #if os(macOS)
    return AnyView(
        VStack(alignment: .leading, spacing: 0) {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(24)
        }
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(NSColor.windowBackgroundColor))
                .shadow(color: .black.opacity(0.2), radius: 20, x: 0, y: 14)
        )
        .padding(32)
    )
    #else
    return AnyView(content())
    #endif
}

#Preview {
    NotesView()
}

