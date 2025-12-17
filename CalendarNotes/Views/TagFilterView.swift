//
//  TagFilterView.swift
//  CalendarNotes
//
//  Tag filtering with AND/OR logic
//

import SwiftUI
import CoreData

struct TagFilterView: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var viewModel: TagManagerViewModel
    
    @Binding var selectedTags: Set<Tag>
    @Binding var filterMode: TagManagerViewModel.FilterMode
    @Binding var filteredBookmarks: [Bookmark]
    
    @State private var showingTagPicker = false
    
    init(context: NSManagedObjectContext, selectedTags: Binding<Set<Tag>>, filterMode: Binding<TagManagerViewModel.FilterMode>, filteredBookmarks: Binding<[Bookmark]>) {
        _viewModel = StateObject(wrappedValue: TagManagerViewModel(context: context))
        _selectedTags = selectedTags
        _filterMode = filterMode
        _filteredBookmarks = filteredBookmarks
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Filter Mode Toggle
            Picker("Filter Mode", selection: $filterMode) {
                ForEach(TagManagerViewModel.FilterMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: filterMode) { _, _ in
                applyFilter()
            }
            
            // Selected Tags
            if !selectedTags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Tags (\(selectedTags.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(selectedTags), id: \.objectID) { tag in
                                TagFilterChip(
                                    tag: tag,
                                    onRemove: {
                                        selectedTags.remove(tag)
                                        applyFilter()
                                    }
                                )
                            }
                        }
                    }
                }
            }
            
            // Add Tag Button
            Button {
                showingTagPicker = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Tag Filter")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            
            // Filter Results Count
            if !filteredBookmarks.isEmpty {
                Text("\(filteredBookmarks.count) bookmarks match")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .sheet(isPresented: $showingTagPicker) {
            TagPickerView(
                selectedTags: $selectedTags,
                availableTags: viewModel.tags
            ) {
                applyFilter()
            }
        }
        .onAppear {
            applyFilter()
        }
    }
    
    private func applyFilter() {
        do {
            filteredBookmarks = try viewModel.filterBookmarks(by: selectedTags, mode: filterMode)
        } catch {
            filteredBookmarks = []
        }
    }
}

// MARK: - Tag Filter Chip

struct TagFilterChip: View {
    let tag: Tag
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color.hex(tag.color ?? "#999999") ?? .gray)
                .frame(width: 8, height: 8)
            
            Text(tag.name ?? "Unnamed")
                .font(.caption)
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.accentColor, lineWidth: 1)
        )
        .foregroundColor(.accentColor)
    }
}

// MARK: - Tag Picker View

struct TagPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTags: Set<Tag>
    let availableTags: [Tag]
    let onSelectionChanged: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(availableTags) { tag in
                    Button {
                        if selectedTags.contains(tag) {
                            selectedTags.remove(tag)
                        } else {
                            selectedTags.insert(tag)
                        }
                        onSelectionChanged()
                    } label: {
                        HStack {
                            Circle()
                                .fill(Color.hex(tag.color ?? "#999999") ?? .gray)
                                .frame(width: 12, height: 12)
                            
                            Text(tag.name ?? "Unnamed")
                            
                            Spacer()
                            
                            if selectedTags.contains(tag) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Tags")
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
        }
    }
}

// Tag already conforms to Hashable through NSManagedObject
// Use objectID for Set operations

