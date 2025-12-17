//
//  HighlightManagerView.swift
//  CalendarNotes
//
//  Main view for managing highlights and annotations
//

import SwiftUI
import CoreData

struct HighlightManagerView: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var viewModel: HighlightAnnotationViewModel
    @Environment(\.dismiss) private var dismiss
    
    let bookmark: Bookmark
    
    @State private var showingHighlightEditor = false
    @State private var showingStatistics = false
    @State private var showingExportOptions = false
    @State private var showingColorFilter = false
    @State private var editingHighlight: Highlight?
    
    init(context: NSManagedObjectContext, bookmark: Bookmark) {
        self.bookmark = bookmark
        _viewModel = StateObject(wrappedValue: HighlightAnnotationViewModel(context: context, bookmark: bookmark))
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Filter Bar
                filterBar
                
                // Highlights List
                if viewModel.highlights.isEmpty {
                    emptyStateView
                } else {
                    highlightsList
                }
            }
            .navigationTitle("Highlights")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingStatistics = true
                        } label: {
                            Label("Statistics", systemImage: "chart.bar")
                        }
                        
                        Button {
                            showingExportOptions = true
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .searchable(text: $viewModel.searchText)
            .onChange(of: viewModel.searchText) { _, _ in
                viewModel.loadHighlights()
            }
            .sheet(isPresented: $showingHighlightEditor) {
                if let highlight = editingHighlight {
                    HighlightEditorView(highlight: highlight, viewModel: viewModel)
                }
            }
            .sheet(isPresented: $showingStatistics) {
                HighlightStatisticsView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingExportOptions) {
                HighlightExportView(viewModel: viewModel, bookmark: bookmark)
            }
        }
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                // Color Filter
                Menu {
                    Button {
                        viewModel.filterColor = nil
                        viewModel.loadHighlights()
                    } label: {
                        Text("All Colors")
                    }
                    
                    ForEach(HighlightColor.allCases) { color in
                        Button {
                            viewModel.filterColor = color.rawValue
                            viewModel.loadHighlights()
                        } label: {
                            HStack {
                                Circle()
                                    .fill(color.displayColor)
                                    .frame(width: 12, height: 12)
                                Text(color.name)
                                
                                if viewModel.filterColor == color.rawValue {
                                    Spacer()
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack {
                        if let colorHex = viewModel.filterColor,
                           let color = HighlightColor(rawValue: colorHex) {
                            Circle()
                                .fill(color.displayColor)
                                .frame(width: 16, height: 16)
                            Text(color.name)
                        } else {
                            Image(systemName: "paintpalette")
                            Text("Color")
                        }
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                
                // Notes Filter
                Menu {
                    Button {
                        viewModel.filterHasNotes = nil
                        viewModel.loadHighlights()
                    } label: {
                        Text("All")
                    }
                    
                    Button {
                        viewModel.filterHasNotes = true
                        viewModel.loadHighlights()
                    } label: {
                        HStack {
                            Text("With Notes")
                            if viewModel.filterHasNotes == true {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    
                    Button {
                        viewModel.filterHasNotes = false
                        viewModel.loadHighlights()
                    } label: {
                        HStack {
                            Text("Without Notes")
                            if viewModel.filterHasNotes == false {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                } label: {
                    HStack {
                        Image(systemName: viewModel.filterHasNotes != nil ? "note.text" : "note")
                        Text(viewModel.filterHasNotes == true ? "With Notes" : viewModel.filterHasNotes == false ? "No Notes" : "Notes")
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // Clear Filters
                if viewModel.filterColor != nil || viewModel.filterHasNotes != nil {
                    Button {
                        viewModel.filterColor = nil
                        viewModel.filterHasNotes = nil
                        viewModel.loadHighlights()
                    } label: {
                        Text("Clear")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
        }
        .background(Color.secondary.opacity(0.05))
    }
    
    // MARK: - Highlights List
    
    private var highlightsList: some View {
        List {
            ForEach(viewModel.highlights) { highlight in
                HighlightRowView(
                    highlight: highlight,
                    onTap: {
                        editingHighlight = highlight
                        showingHighlightEditor = true
                    },
                    onDelete: {
                        try? viewModel.deleteHighlight(highlight)
                    }
                )
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "highlighter")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Highlights")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Select text in the article to create highlights")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Highlight Row View

struct HighlightRowView: View {
    let highlight: Highlight
    let onTap: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Highlighted Text
                HStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(highlightColor)
                        .frame(width: 4)
                    
                    Text(highlight.selectedText ?? "")
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                }
                
                // Note (if exists)
                if let note = highlight.note, !note.isEmpty {
                    HStack {
                        Image(systemName: "note.text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(note)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.leading, 8)
                }
                
                // Metadata
                HStack {
                    if let color = highlight.color,
                       let highlightColor = HighlightColor(rawValue: color) {
                        Circle()
                            .fill(highlightColor.displayColor)
                            .frame(width: 12, height: 12)
                    }
                    
                    if let date = highlight.createdDate {
                        Text(date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button {
                            onTap()
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        
                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
    
    private var highlightColor: Color {
        guard let colorHex = highlight.color,
              let color = HighlightColor(rawValue: colorHex) else {
            return HighlightColor.yellow.displayColor.opacity(0.3)
        }
        return color.displayColor.opacity(0.3)
    }
}

