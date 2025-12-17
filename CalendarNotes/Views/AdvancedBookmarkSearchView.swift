//
//  AdvancedBookmarkSearchView.swift
//  CalendarNotes
//

import SwiftUI
import CoreData

struct AdvancedBookmarkSearchView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var query: String = ""
    @State private var results: [Bookmark] = []
    @State private var filters = BookmarkSearchFilters()
    @State private var sort: BookmarkSort = .recent
    @State private var showFilters = true
    @State private var showingSaveSheet = false
    @State private var newSmartName: String = ""
    
    private let service = AdvancedBookmarkSearchService.shared
    
    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            resultsList
        }
        .navigationTitle("Bookmark Search")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Save as Smart") { newSmartName = query.isEmpty ? "Smart Search" : query; showingSaveSheet = true } }
        }
        .onAppear { runSearch() }
        .sheet(isPresented: $showingSaveSheet) {
            NavigationView {
                Form {
                    Section(header: Text("Name")) {
                        TextField("Smart collection name", text: $newSmartName)
                    }
                }
                .navigationTitle("Save Search")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showingSaveSheet = false } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { saveAsSmartCollection() } }
                }
            }
        }
    }
    
    private var sidebar: some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.cnSecondaryText)
                        .font(.system(size: 16))
                    TextField("Search bookmarks", text: $query)
                        .onChange(of: query) { _, _ in
                            withAnimation(.smooth) {
                                runSearch()
                            }
                        }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cnTertiaryBackground)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
            }
            .padding()
            Divider()
            ScrollView {
                filterPanel
                    .padding()
            }
            Spacer()
        }
        .frame(minWidth: 320, idealWidth: 360)
        .background(Color.cnSecondaryBackground)
    }
    
    private var resultsList: some View {
        Group {
            if results.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 64, weight: .light))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.cnAccent, Color.cnAccent.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.pulse, options: .repeating)
                    VStack(spacing: 8) {
                        Text("No results")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.cnPrimaryText)
                        Text("Try adjusting your search or filters")
                            .font(.subheadline)
                            .foregroundColor(.cnSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.cnBackground)
                .transition(.scaleAndFade)
            } else {
                List(Array(results.enumerated()), id: \.element.objectID) { index, b in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    b.isFavorite
                                        ? LinearGradient(
                                            colors: [Color.yellow.opacity(0.3), Color.yellow.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                        : LinearGradient(
                                            colors: [Color.cnAccent.opacity(0.2), Color.cnAccent.opacity(0.1)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                )
                                .frame(width: 32, height: 32)
                            Image(systemName: b.isFavorite ? "star.fill" : "bookmark.fill")
                                .font(.system(size: 14))
                                .foregroundColor(b.isFavorite ? .yellow : .cnAccent)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(b.title ?? b.url ?? "Untitled")
                                .font(.body)
                                .fontWeight(.medium)
                                .lineLimit(2)
                                .foregroundColor(.cnPrimaryText)
                            if let host = URL(string: b.url ?? "")?.host {
                                Text(host)
                                    .font(.caption)
                                    .foregroundColor(.cnSecondaryText)
                            }
                        }
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        )
                    )
                    .animation(
                        .smooth.delay(Double(index % 10) * 0.03),
                        value: results.count
                    )
                }
                .listStyle(.sidebar)
                .background(Color.cnBackground)
            }
        }
    }
    
    private var filterPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Filters")
                .font(.headline)
                .foregroundColor(.cnPrimaryText)
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Sort By")
                        .font(.subheadline)
                        .foregroundColor(.cnSecondaryText)
                    Picker("Sort", selection: $sort) {
                        Text("Recent").tag(BookmarkSort.recent)
                        Text("Oldest").tag(BookmarkSort.oldest)
                        Text("Most Visited").tag(BookmarkSort.mostVisited)
                        Text("A-Z").tag(BookmarkSort.alphabetical)
                    }
                    .pickerStyle(.menu)
                    .onChange(of: sort) { _, _ in runSearch() }
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quick Filters")
                        .font(.subheadline)
                        .foregroundColor(.cnSecondaryText)
                    VStack(alignment: .leading, spacing: 8) {
                        Toggle("Favorites only", isOn: Binding(get: { filters.isFavorite ?? false }, set: { filters.isFavorite = $0; runSearch() }))
                        Toggle("Archived", isOn: Binding(get: { filters.isArchived ?? false }, set: { filters.isArchived = $0; runSearch() }))
                        Toggle("Has notes", isOn: Binding(get: { filters.hasNotes ?? false }, set: { filters.hasNotes = $0; runSearch() }))
                    }
                    .toggleStyle(.switch)
                }
                
                Divider()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tag Logic")
                        .font(.subheadline)
                        .foregroundColor(.cnSecondaryText)
                    Toggle("AND tags (all must match)", isOn: $filters.tagModeAnd)
                        .toggleStyle(.switch)
                        .onChange(of: filters.tagModeAnd) { _, _ in runSearch() }
                }
            }
        }
    }
    
    private func runSearch() {
        withAnimation(.smooth) {
            results = (try? service.search(query: query, filters: filters, sort: sort)) ?? []
        }
        service.addHistory(query)
    }

    private func saveAsSmartCollection() {
        let name = newSmartName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let c = Collection(context: context)
        c.id = UUID()
        c.name = name
        c.icon = "tray"
        c.color = "#7F7F7F"
        var rules = CollectionEditorViewModel.SmartCollectionRules()
        // Map available filters to existing rules schema
        if !filters.tags.isEmpty { rules.tagFilter = filters.tags.joined(separator: ", ") }
        if let d = filters.domain, !d.isEmpty { rules.domainFilter = d }
        rules.dateRangeStart = filters.dateSavedFrom
        rules.dateRangeEnd = filters.dateSavedTo
        rules.favoriteStatus = filters.isFavorite
        rules.isEnabled = true
        SmartCollectionService.shared.saveRules(rules, for: c)
        try? context.save()
        showingSaveSheet = false
    }
}


