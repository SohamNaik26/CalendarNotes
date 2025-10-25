//
//  OptimizedViews.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 23/10/25.
//

import SwiftUI
import Combine
import CoreData

// MARK: - Optimized Data Models with Equatable

struct OptimizedNoteGroup: Equatable, Identifiable {
    let id = UUID()
    let title: String
    let notes: [OptimizedNote]
    
    static func == (lhs: OptimizedNoteGroup, rhs: OptimizedNoteGroup) -> Bool {
        return lhs.title == rhs.title && lhs.notes == rhs.notes
    }
}

struct OptimizedNote: Equatable, Identifiable {
    let id: String
    let content: String
    let createdDate: Date?
    let linkedDate: Date?
    let tags: String?
    
    init(from note: Note) {
        self.id = note.objectID.uriRepresentation().absoluteString
        self.content = note.content ?? ""
        self.createdDate = note.createdDate
        self.linkedDate = note.linkedDate
        self.tags = note.tags
    }
    
    static func == (lhs: OptimizedNote, rhs: OptimizedNote) -> Bool {
        return lhs.id == rhs.id &&
               lhs.content == rhs.content &&
               lhs.createdDate == rhs.createdDate &&
               lhs.linkedDate == rhs.linkedDate &&
               lhs.tags == rhs.tags
    }
}

struct OptimizedCalendarEvent: Equatable, Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let category: String
    let location: String?
    let notes: String?
    let isRecurring: Bool
    
    init(from event: CalendarEvent) {
        self.id = event.objectID.uriRepresentation().absoluteString
        self.title = event.title ?? ""
        self.startDate = event.startDate ?? Date()
        self.endDate = event.endDate ?? Date()
        self.category = event.category ?? ""
        self.location = event.location
        self.notes = event.notes
        self.isRecurring = event.isRecurring
    }
    
    static func == (lhs: OptimizedCalendarEvent, rhs: OptimizedCalendarEvent) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.startDate == rhs.startDate &&
               lhs.endDate == rhs.endDate &&
               lhs.category == rhs.category &&
               lhs.location == rhs.location &&
               lhs.notes == rhs.notes &&
               lhs.isRecurring == rhs.isRecurring
    }
}

struct OptimizedTodoItem: Equatable, Identifiable {
    let id: String
    let title: String
    let priority: String
    let category: String
    let dueDate: Date?
    let isCompleted: Bool
    let isRecurring: Bool
    
    init(from todo: TodoItem) {
        self.id = todo.objectID.uriRepresentation().absoluteString
        self.title = todo.title ?? ""
        self.priority = todo.priority ?? ""
        self.category = todo.category ?? ""
        self.dueDate = todo.dueDate
        self.isCompleted = todo.isCompleted
        self.isRecurring = todo.isRecurring
    }
    
    static func == (lhs: OptimizedTodoItem, rhs: OptimizedTodoItem) -> Bool {
        return lhs.id == rhs.id &&
               lhs.title == rhs.title &&
               lhs.priority == rhs.priority &&
               lhs.category == rhs.category &&
               lhs.dueDate == rhs.dueDate &&
               lhs.isCompleted == rhs.isCompleted &&
               lhs.isRecurring == rhs.isRecurring
    }
}

// MARK: - Optimized Views

struct OptimizedNotesListView: View {
    let groupedNotes: [OptimizedNoteGroup]
    let isLoading: Bool
    let isLoadingMore: Bool
    let hasMoreNotes: Bool
    let onLoadMore: () -> Void
    let onNoteTap: (OptimizedNote) -> Void
    let onNoteDelete: (OptimizedNote) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            if isLoading && groupedNotes.isEmpty {
                OptimizedLoadingView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(groupedNotes) { group in
                            OptimizedNoteGroupView(
                                group: group,
                                onNoteTap: onNoteTap,
                                onNoteDelete: onNoteDelete,
                                onLoadMore: group == groupedNotes.last ? onLoadMore : nil
                            )
                        }
                        
                        if isLoadingMore {
                            LoadingMoreView()
                        }
                        
                        if !hasMoreNotes && !groupedNotes.isEmpty {
                            EndOfListIndicator()
                        }
                    }
                    .padding()
                }
            }
        }
    }
}

struct OptimizedNoteGroupView: View, Equatable {
    let group: OptimizedNoteGroup
    let onNoteTap: (OptimizedNote) -> Void
    let onNoteDelete: (OptimizedNote) -> Void
    let onLoadMore: (() -> Void)?
    
    static func == (lhs: OptimizedNoteGroupView, rhs: OptimizedNoteGroupView) -> Bool {
        return lhs.group == rhs.group
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(group.title)
                .font(.headline)
                .foregroundColor(.primary)
                .padding(.horizontal)
            
            LazyVStack(spacing: 8) {
                ForEach(group.notes) { note in
                    OptimizedNoteRowView(
                        note: note,
                        onTap: onNoteTap,
                        onDelete: onNoteDelete
                    )
                    .onAppear {
                        // Trigger load more when approaching the end
                        if note == group.notes.last && onLoadMore != nil {
                            onLoadMore?()
                        }
                    }
                }
            }
        }
    }
}

struct OptimizedNoteRowView: View, Equatable {
    let note: OptimizedNote
    let onTap: (OptimizedNote) -> Void
    let onDelete: (OptimizedNote) -> Void
    
    static func == (lhs: OptimizedNoteRowView, rhs: OptimizedNoteRowView) -> Bool {
        return lhs.note == rhs.note
    }
    
    var body: some View {
        Button(action: { onTap(note) }) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.content)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                    
                    HStack {
                        if let date = note.createdDate {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let tags = note.tags, !tags.isEmpty {
                            Text(tags)
                                .font(.caption)
                                .foregroundColor(.cnAccent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.cnAccent.opacity(0.1))
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                    }
                }
                
                Spacer()
            }
            .padding()
            .background(Color.cnSecondaryBackground)
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button("Delete", role: .destructive) {
                onDelete(note)
            }
        }
    }
}

// MARK: - Loading Views

struct OptimizedLoadingView: View {
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .cnPrimary))
                .scaleEffect(1.2)
            
            Text("Loading notes...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct LoadingMoreView: View {
    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .cnPrimary))
                .scaleEffect(0.8)
            
            Text("Loading more...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct EndOfListIndicator: View {
    var body: some View {
        Text("That's all your notes!")
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
    }
}

// MARK: - Optimized Search Bar

struct OptimizedSearchBar: View {
    @Binding var searchText: String
    let onSearchTextChanged: (String) -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search notes...", text: $searchText)
                .textFieldStyle(.plain)
                .onChange(of: searchText) { _, newValue in
                    onSearchTextChanged(newValue)
                }
            
            if !searchText.isEmpty {
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.cnSecondaryBackground)
        .cornerRadius(10)
    }
}

// MARK: - Performance Monitor

struct PerformanceMonitorView: View {
    let cacheSize: Int
    let notesCount: Int
    let hasMore: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Cache: \(cacheSize)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Notes: \(notesCount)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if hasMore {
                Text("More available")
                    .font(.caption)
                    .foregroundColor(.cnAccent)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.cnSecondaryBackground.opacity(0.5))
        .cornerRadius(8)
    }
}

// MARK: - View Modifiers for Performance

extension View {
    func equatable() -> some View where Self: Equatable {
        self
    }
}

// MARK: - Memory Efficient List

struct MemoryEfficientList<Data, Content>: View where Data: RandomAccessCollection, Data.Element: Identifiable & Equatable, Content: View {
    let data: Data
    let content: (Data.Element) -> Content
    let onLoadMore: (() -> Void)?
    
    init(data: Data, onLoadMore: (() -> Void)? = nil, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
        self.onLoadMore = onLoadMore
    }
    
    var body: some View {
        LazyVStack(spacing: 8) {
            ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                content(item)
                    .onAppear {
                        // Trigger load more when approaching the end
                        if index == data.count - 3 && onLoadMore != nil {
                            onLoadMore?()
                        }
                    }
            }
        }
    }
}
