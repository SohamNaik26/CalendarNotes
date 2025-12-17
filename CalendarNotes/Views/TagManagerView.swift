//
//  TagManagerView.swift
//  CalendarNotes
//
//  Comprehensive tag management interface with advanced relationships,
//  analytics, automation, and visualization tools.
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct TagManagerView: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var viewModel: TagManagerViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingCreateTag = false
    @State private var showingImportSheet = false

    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: TagManagerViewModel(context: context))
    }

    var body: some View {
        NavigationView {
            List {
                analyticsSection
                visualizationsSection
                relationshipsSection
                templatesSection
                automationSection
                bulkOperationsSection
                dataManagementSection
            }
            #if os(iOS)
            .listStyle(.insetGrouped)
            #else
            .listStyle(.inset)
            #endif
            .navigationTitle("Tag Manager")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateTag = true
                    } label: {
                        Label("Create Tag", systemImage: "plus")
                    }
                }
            }
            .searchable(text: $viewModel.searchText)
            .sheet(isPresented: $showingCreateTag) {
                CreateTagView(viewModel: viewModel)
            }
            .fileImporter(
                isPresented: $showingImportSheet,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                handleImport(result: result)
            }
        }
    }

    // MARK: - Sections

    private var analyticsSection: some View {
        Section(header: Text("Overview")) {
            HStack {
                VStack(alignment: .leading) {
                    Text("Tags")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.tags.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Spacer()
                VStack(alignment: .center) {
                    Text("Bookmarks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("\(viewModel.totalBookmarks)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Spacer()
                VStack(alignment: .trailing) {
                    Text("Diversity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.0f%%", viewModel.analyticsSnapshot?.diversityScore ?? 0))
                        .font(.title2)
                        .fontWeight(.bold)
                }
            }

            let trendingList = viewModel.trendingTags
            if !trendingList.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Trending Tags")
                        .font(.headline)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(trendingList) { usage in
                                Label("\(usage.name) · \(usage.count)", systemImage: "flame.fill")
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .foregroundColor(.white)
                                    .background(Capsule().fill(Color.orange))
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            let unusedList = viewModel.unusedTags
            if !unusedList.isEmpty {
                DisclosureGroup("Unused Tags") {
                    ForEach(unusedList.prefix(10)) { stat in
                        Text(stat.name)
                            .foregroundColor(.secondary)
                    }
                    if unusedList.count > 10 {
                        Text("+\(unusedList.count - 10) more")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var visualizationsSection: some View {
        Section(header: Text("Visualizations")) {
            NavigationLink {
                TagCloudView()
            } label: {
                Label("Tag Cloud", systemImage: "cloud.fill")
            }

            NavigationLink {
                TagNetworkGraphView(edges: viewModel.networkEdges)
            } label: {
                Label("Network Graph", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
            }

            NavigationLink {
                TagTimelineView(points: viewModel.growthTimeline)
            } label: {
                Label("Usage Timeline", systemImage: "chart.xyaxis.line")
            }

            NavigationLink {
                TagHeatmapView(cells: viewModel.heatmapCells)
            } label: {
                Label("Usage Heatmap", systemImage: "square.grid.3x3.fill")
            }
        }
    }

    private var relationshipsSection: some View {
        Section(header: Text("Tags")) {
            ForEach(viewModel.tags) { tag in
                NavigationLink {
                    TagDetailView(viewModel: viewModel, tag: tag)
                } label: {
                    TagRowView(tag: tag, usageStat: viewModel.tagUsageStats.first { $0.tag.id == tag.id })
                }
            }
        }
    }

    private var templatesSection: some View {
        Section(header: Text("Tag Templates")) {
            if viewModel.templates.isEmpty {
                Text("No templates yet. Save frequently used tag combinations for quick reuse.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.templates) { template in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(template.name)
                                .font(.headline)
                            if template.isSystem {
                                Label("System", systemImage: "star.fill")
                                    .font(.caption)
                                    .foregroundColor(.yellow)
                            }
                        }
                        Text(template.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(template.tags, id: \.self) { tag in
                                    Label(tag, systemImage: "tag")
                                        .font(.caption2)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                                }
                            }
                        }
                        Button {
                            let bookmarks = try? viewModel.filterBookmarks(by: [], mode: .or)
                            viewModel.applyTemplate(template, to: bookmarks ?? [])
                        } label: {
                            Label("Apply to All Bookmarks", systemImage: "square.and.arrow.down")
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
        }
    }

    private var automationSection: some View {
        Section(header: Text("Automation")) {
            if viewModel.automationRules.isEmpty {
                Text("Create automation rules to auto-tag bookmarks based on URL patterns or keywords.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(viewModel.automationRules) { rule in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(rule.name)
                                .font(.headline)
                            if !rule.isEnabled {
                                Text("Disabled")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Text(rule.type.rawValue.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if let pattern = rule.pattern {
                            Text(pattern)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if !rule.tags.isEmpty {
                            Text("Tags: \(rule.tags.joined(separator: ", "))")
                                .font(.caption2)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Button {
                let bookmarks = try? viewModel.filterBookmarks(by: [], mode: .or)
                viewModel.autoTag(bookmarks ?? [])
            } label: {
                Label("Run Auto-Tag Suggestions", systemImage: "wand.and.stars")
            }
        }
    }

    private var bulkOperationsSection: some View {
        Section(header: Text("Bulk Operations")) {
            NavigationLink("Bulk Tag Editor") {
                BulkTagOperationsView(context: context)
            }
        }
    }

    private var dataManagementSection: some View {
        Section(header: Text("Data Management")) {
            if let message = viewModel.lastOperationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button {
                showingImportSheet = true
            } label: {
                Label("Import Tags", systemImage: "square.and.arrow.down")
            }

            if let data = viewModel.exportTags() {
                ShareLink(item: data, preview: SharePreview("tags-export.json")) {
                    Label("Export Tags", systemImage: "square.and.arrow.up")
                }
            }
        }
    }

    // MARK: - Import Handler

    private func handleImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            if let data = try? Data(contentsOf: url) {
                try? viewModel.importTags(from: data)
            }
        case .failure:
            break
        }
    }
}

// MARK: - Tag Row View

struct TagRowView: View {
    @ObservedObject var tag: Tag
    let usageStat: TagManagerViewModel.TagUsageStat?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(tag.primaryDisplayName)
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(Color.hex(tag.color ?? "#999999") ?? .gray)
                    .frame(width: 12, height: 12)
            }
            if let stat = usageStat {
                HStack(spacing: 12) {
                    Label("\(stat.count) uses", systemImage: "number")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Label(String(format: "%.0f%%", stat.percentage), systemImage: "chart.pie")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            if !tag.synonymValues.isEmpty {
                Text("Aliases: \(tag.synonymValues.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            if let parent = tag.parentTag {
                Text("Parent: \(parent.primaryDisplayName)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Create Tag View

struct CreateTagView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: TagManagerViewModel

    @State private var tagName: String = ""
    @State private var selectedColor: String = "#999999"

    init(viewModel: TagManagerViewModel) {
        _viewModel = ObservedObject(wrappedValue: viewModel)
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Tag Details")) {
                    TextField("Tag Name", text: $tagName)
                    ColorPickerRow(selectedColor: $selectedColor)
                }
            }
            .navigationTitle("New Tag")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        try? viewModel.createTag(name: tagName, color: selectedColor)
                        dismiss()
                    }
                    .disabled(tagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct ColorPickerRow: View {
    @Binding var selectedColor: String
    @State private var showingColorPicker = false

    var body: some View {
        Button {
            showingColorPicker = true
        } label: {
            HStack {
                Text("Color")
                Spacer()
                Circle()
                    .fill(Color.hex(selectedColor) ?? .gray)
                    .frame(width: 24, height: 24)
            }
        }
        .sheet(isPresented: $showingColorPicker) {
            ColorPickerView(selectedColor: $selectedColor)
        }
    }
}
