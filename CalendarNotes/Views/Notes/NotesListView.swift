//
//  NotesListView.swift
//  CalendarNotes
//
//  Notes list view with search and tags
//

import SwiftUI
import CoreData

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct NotesListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Note.createdDate, ascending: false)],
        animation: .default
    ) private var notes: FetchedResults<Note>
    
    @State private var searchText = ""
    @State private var selectedNote: Note?
    
    var filteredNotes: [Note] {
        if searchText.isEmpty {
            return Array(notes)
        }
        return notes.filter { note in
            (note.content?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (note.summaryText?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (note.tags?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    private var groupedBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemGroupedBackground)
        #endif
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // "Notes" title (34pt, bold) - improved spacing
            Text("Notes")
                .font(.system(size: 34, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)
            
            // Search bar with rounded gray background
            SearchBar(text: $searchText, placeholder: "Search notes...")
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 4)
            
            // ScrollView with LazyVStack of note cards or empty state
            if filteredNotes.isEmpty {
                EmptyStateView(icon: "note.text", message: "No notes")
                    .padding(.top, 60)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredNotes, id: \.objectID) { note in
                            NoteCard(note: note)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
            }
        }
        .background(groupedBackgroundColor)
        .ignoresSafeArea(.all, edges: [.top, .bottom])
    }
}

// MARK: - Note Card Component

struct NoteCard: View {
    let note: Note
    @Environment(\.managedObjectContext) private var viewContext
    @State private var showEditor = false
    
    // Color for left border - alternate between blue and green
    private var borderColor: Color {
        let hash = note.objectID.hashValue
        return hash % 2 == 0 ? Color.blue : Color.green
    }
    
    var body: some View {
        NavigationLink {
            NoteEditorView(viewModel: NoteEditorViewModel(note: note))
        } label: {
            HStack(spacing: 0) {
                // Colored left border (4pt wide)
                Rectangle()
                    .fill(borderColor)
                    .frame(width: 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    // Title and timestamp row
                    HStack {
                        Text(noteTitle)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(relativeTimeText)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    
                    // Preview text
                    if !previewText.isEmpty {
                        Text(previewText)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Swipe action for delete
            Button(role: .destructive) {
                deleteNote()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            
            // Swipe action for edit
            Button {
                showEditor = true
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(.blue)
        }
        .sheet(isPresented: $showEditor) {
            NoteEditorView(viewModel: NoteEditorViewModel(note: note))
        }
    }
    
    private var relativeTimeText: String {
        guard let date = note.createdDate else { return "" }
        let now = Date()
        let calendar = Calendar.current
        
        if calendar.isDate(date, inSameDayAs: now) {
            let hours = calendar.dateComponents([.hour], from: date, to: now).hour ?? 0
            if hours == 0 {
                let minutes = calendar.dateComponents([.minute], from: date, to: now).minute ?? 0
                if minutes < 1 {
                    return "Just now"
                }
                return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
            }
            return "\(hours) hour\(hours == 1 ? "" : "s") ago"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let days = calendar.dateComponents([.day], from: date, to: now).day ?? 0
            if days < 7 {
                return "\(days) day\(days == 1 ? "" : "s") ago"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d, yyyy"
                return formatter.string(from: date)
            }
        }
    }
    
    private var noteTitle: String {
        // Extract first line as title, or use "Untitled Note"
        if let content = note.content, !content.isEmpty {
            let firstLine = content.components(separatedBy: "\n").first?.trimmingCharacters(in: .whitespaces) ?? ""
            if !firstLine.isEmpty {
                return firstLine
            }
        }
        return "Untitled Note"
    }
    
    private var previewText: String {
        // Get preview text (skip first line if it's the title)
        if let content = note.content, !content.isEmpty {
            let lines = content.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            if lines.count > 1 {
                return lines.dropFirst().joined(separator: " ")
            } else if lines.count == 1 {
                return lines[0]
            }
        }
        return ""
    }
    
    private func deleteNote() {
        viewContext.delete(note)
        try? viewContext.save()
    }
}

// Note already conforms to Hashable via NSManagedObject

#Preview {
    NotesListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
