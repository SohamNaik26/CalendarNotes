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
                    
                    // Date Filter Banner
                if viewModel.selectedDate != nil {
                        DateFilterBanner(
                            selectedDate: viewModel.selectedDate!,
                            onClear: { viewModel.filterByDate(nil) }
                        )
                    }
                    
                    // Notes List with Grouping
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
                                selectedNote = note
                                showingNoteDetail = true
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
                NoteEditorView(viewModel: NoteEditorViewModel(note: nil))
            }
            .sheet(isPresented: $showingNoteDetail, onDismiss: {
                viewModel.loadNotes()
            }) {
                if let selectedNote = selectedNote {
                    NoteEditorView(viewModel: NoteEditorViewModel(note: selectedNote))
                }
            }
            .sheet(isPresented: $showingDateFilter) {
                DateFilterView(selectedDate: $viewModel.selectedDate) { date in
                    viewModel.filterByDate(date)
                }
            }
            .sheet(isPresented: $showingSortOptions) {
                SortOptionsView(sortOption: $viewModel.sortOption)
            }
            .task {
                viewModel.loadNotes()
            }
    }
    
    private func refreshNotes() async {
        isRefreshing = true
        viewModel.loadNotes()
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 second delay
        isRefreshing = false
    }
    
    #if os(iOS)
    private func generateHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    #endif
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
            // Note Title
            Text(noteTitle)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            // Note Content Preview
            Text(noteContent)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            // Tags and Date
            HStack {
                if let tags = note.tags, !tags.isEmpty {
                    Text(tags)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.accentColor)
                        )
                }
                
                Spacer()
                
                Text(noteDate)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
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
    
    private var noteContent: String {
        let content = note.content ?? ""
        if content.count > 50 {
            return String(content.dropFirst(50))
        } else {
            return content
        }
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
            // Note Title (first line)
            Text(noteTitle)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .foregroundColor(.primary)
            
            // Note Preview (2-3 lines)
            Text(note.content ?? "")
                .font(.body)
                .lineLimit(3)
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

private struct FloatingAddButton: View {
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

#Preview {
    NotesView()
}

