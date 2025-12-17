//
//  BulkTagOperationsView.swift
//  CalendarNotes
//
//  Bulk tag operations interface
//

import SwiftUI
import CoreData

struct BulkTagOperationsView: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var viewModel: TagManagerViewModel
    
    @State private var selectedBookmarks: Set<Bookmark> = []
    @State private var selectedTag: Tag?
    @State private var replacementTag: Tag?
    @State private var operationType: OperationType = .add
    @State private var showingBookmarkPicker = false
    
    enum OperationType: String, CaseIterable {
        case add = "Add Tag"
        case remove = "Remove Tag"
        case replace = "Replace Tag"
    }
    
    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: TagManagerViewModel(context: context))
    }
    
    var body: some View {
        Form {
            Section(header: Text("Operation Type")) {
                Picker("Operation", selection: $operationType) {
                    ForEach(OperationType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
            }
            
            Section(header: Text("Select Tag")) {
                Picker("Tag", selection: $selectedTag) {
                    Text("None").tag(nil as Tag?)
                    ForEach(viewModel.tags) { tag in
                        HStack {
                            Circle()
                                .fill(Color.hex(tag.color ?? "#999999") ?? .gray)
                                .frame(width: 12, height: 12)
                            Text(tag.name ?? "Unnamed")
                        }
                        .tag(tag as Tag?)
                    }
                }
            }
            
            if operationType == .replace {
                Section(header: Text("Replace With")) {
                    Picker("New Tag", selection: $replacementTag) {
                        Text("None").tag(nil as Tag?)
                        ForEach(viewModel.tags) { tag in
                            HStack {
                                Circle()
                                    .fill(Color.hex(tag.color ?? "#999999") ?? .gray)
                                    .frame(width: 12, height: 12)
                                Text(tag.name ?? "Unnamed")
                            }
                            .tag(tag as Tag?)
                        }
                    }
                }
            }
            
            Section(header: Text("Select Bookmarks")) {
                Button {
                    showingBookmarkPicker = true
                } label: {
                    HStack {
                        Text("Choose Bookmarks")
                        Spacer()
                        Text("\(selectedBookmarks.count) selected")
                            .foregroundColor(.secondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Section {
                Button(role: .destructive) {
                    performOperation()
                } label: {
                    HStack {
                        Spacer()
                        Text(operationType.rawValue)
                        Spacer()
                    }
                }
                .disabled(selectedTag == nil || selectedBookmarks.isEmpty || (operationType == .replace && replacementTag == nil))
            }
        }
        .navigationTitle("Bulk Tag Operations")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(isPresented: $showingBookmarkPicker) {
            BookmarkPickerView(selectedBookmarks: $selectedBookmarks)
        }
    }
    
    private func performOperation() {
        guard let tag = selectedTag else { return }
        
        let bookmarkArray = Array(selectedBookmarks)
        
        switch operationType {
        case .add:
            try? viewModel.addTagToBookmarks(tag, bookmarks: bookmarkArray)
        case .remove:
            try? viewModel.removeTagFromBookmarks(tag, bookmarks: bookmarkArray)
        case .replace:
            if let replacement = replacementTag {
                try? viewModel.replaceTagAcrossBookmarks(oldTag: tag, newTag: replacement)
            }
        }
        
        selectedBookmarks.removeAll()
        replacementTag = nil
    }
}

// MARK: - Bookmark Picker View

struct BookmarkPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @Binding var selectedBookmarks: Set<Bookmark>
    
    @State private var bookmarks: [Bookmark] = []
    @State private var searchText: String = ""
    
    var filteredBookmarks: [Bookmark] {
        if searchText.isEmpty {
            return bookmarks
        }
        return bookmarks.filter { bookmark in
            (bookmark.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (bookmark.url?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                ForEach(filteredBookmarks, id: \.objectID) { bookmark in
                    BookmarkSelectionRow(
                        bookmark: bookmark,
                        isSelected: selectedBookmarks.contains(bookmark),
                        onToggle: {
                            if selectedBookmarks.contains(bookmark) {
                                selectedBookmarks.remove(bookmark)
                            } else {
                                selectedBookmarks.insert(bookmark)
                            }
                        }
                    )
                }
            }
            .searchable(text: $searchText)
            .navigationTitle("Select Bookmarks")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadBookmarks()
            }
        }
    }
    
    private func loadBookmarks() {
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: false)]
        bookmarks = (try? context.fetch(request)) ?? []
    }
}

struct BookmarkSelectionRow: View {
    let bookmark: Bookmark
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(bookmark.title ?? "Untitled")
                        .foregroundColor(.primary)
                    
                    if let url = bookmark.url {
                        Text(url)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
            }
        }
    }
}

// Bookmark already conforms to Hashable through NSManagedObject
// Use objectID for Set operations

