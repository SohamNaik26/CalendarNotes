//
//  TagDetailView.swift
//  CalendarNotes
//
//  Presents detailed controls for a specific tag including synonyms,
//  hierarchy, groups, and advanced operations.
//

import SwiftUI
import CoreData

struct TagDetailView: View {
    @ObservedObject var viewModel: TagManagerViewModel
    @ObservedObject var tag: Tag

    @State private var synonymText: String = ""
    @State private var splitText: String = ""
    @State private var parentSelection: Tag?
    @State private var newGroupName: String = ""
    @State private var findText: String = ""
    @State private var replaceText: String = ""

    private var synonyms: [TagSynonym] {
        (tag.synonyms as? Set<TagSynonym>)?.sorted { ($0.value ?? "") < ($1.value ?? "") } ?? []
    }

    private var relatedEdges: [TagManagerViewModel.TagNetworkEdge] {
        guard let tagID = tag.id else { return [] }
        return viewModel.networkEdges.filter { edge in
            edge.sourceID == tagID || edge.targetID == tagID
        }
    }

    private var groups: [TagGroup] {
        tag.tagGroups
    }

    var body: some View {
        Form {
            basicSection
            synonymsSection
            parentSection
            groupsSection
            analyticsSection
            operationsSection
            relatedSection
        }
        .navigationTitle(tag.primaryDisplayName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            parentSelection = tag.parentTag
        }
    }

    private var basicSection: some View {
        Section(header: Text("Details")) {
            HStack {
                Text("Color")
                Spacer()
                Circle()
                    .fill(Color.hex(tag.color ?? "#999999") ?? .gray)
                    .frame(width: 20, height: 20)
            }
            if let created = tag.createdDate {
                Text("Created: \(created.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let lastUsed = tag.lastUsedDate {
                Text("Last Used: \(lastUsed.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Never used")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var synonymsSection: some View {
        Section(header: Text("Synonyms")) {
            if synonyms.isEmpty {
                Text("No synonyms yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(synonyms, id: \.objectID) { synonym in
                    HStack {
                        Text(synonym.value ?? "")
                        Spacer()
                        Button(role: .destructive) {
                            viewModel.removeSynonym(synonym)
                        } label: {
                            Image(systemName: "trash")
                        }
                    }
                }
            }

            HStack {
                TextField("Add synonym", text: $synonymText)
                Button {
                    viewModel.addSynonym(synonymText, to: tag)
                    synonymText = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .disabled(synonymText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var parentSection: some View {
        Section(header: Text("Hierarchy")) {
            Picker("Parent Tag", selection: $parentSelection) {
                Text("None").tag(Optional<Tag>.none)
                ForEach(viewModel.tags.filter { $0.objectID != tag.objectID }) { candidate in
                    Text(candidate.primaryDisplayName).tag(Optional<Tag>(candidate))
                }
            }
            .onChange(of: parentSelection) { _, newParent in
                viewModel.assignParent(newParent, to: tag)
            }

            if !tag.childTags.isEmpty {
                VStack(alignment: .leading) {
                    Text("Children")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(tag.childTags) { child in
                        Text(child.primaryDisplayName)
                            .font(.caption2)
                    }
                }
            }
        }
    }

    private var groupsSection: some View {
        Section(header: Text("Groups")) {
            if groups.isEmpty {
                Text("No groups assigned")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(groups, id: \.objectID) { group in
                    HStack {
                        Text(group.name ?? "")
                        Spacer()
                        Button("Remove") {
                            viewModel.remove(tag: tag, from: group)
                        }
                        .foregroundColor(.red)
                        .font(.caption)
                    }
                }
            }

            HStack {
                TextField("Add to group", text: $newGroupName)
                Button {
                    let name = newGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    viewModel.add(tag: tag, toGroupNamed: name)
                    newGroupName = ""
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
        }
    }

    private var analyticsSection: some View {
        Section(header: Text("Analytics")) {
            HStack {
                Label("Usage Count", systemImage: "number")
                Spacer()
                Text("\(tag.usageCount)")
            }
            if let stat = viewModel.tagUsageStats.first(where: { $0.tag.objectID == tag.objectID }) {
                HStack {
                    Label("Share", systemImage: "chart.pie")
                    Spacer()
                    Text(String(format: "%.1f%%", stat.percentage))
                }
            }
        }
    }

    private var operationsSection: some View {
        Section(header: Text("Operations")) {
            VStack(alignment: .leading) {
                Text("Split Tag")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Comma separated tag names", text: $splitText)
                Button("Split") {
                    let names = splitText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    do {
                        try viewModel.splitTag(tag, into: names)
                        splitText = ""
                    } catch {
                        // handled by viewModel error message
                    }
                }
                .disabled(splitText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            VStack(alignment: .leading) {
                Text("Find & Replace")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("Find tag", text: $findText)
                TextField("Replacement tags (comma separated)", text: $replaceText)
                Button("Replace") {
                    let replacements = replaceText.split(separator: ",").map { String($0) }
                    try? viewModel.findAndReplaceTags(search: findText, replacements: replacements)
                    findText = ""
                    replaceText = ""
                }
                .disabled(findText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var relatedSection: some View {
        Section(header: Text("Related Tags")) {
            if relatedEdges.isEmpty {
                Text("No related tags yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(relatedEdges) { edge in
                    let partnerName = edge.sourceID == tag.id ? edge.targetName : edge.sourceName
                    HStack {
                        Text(partnerName)
                        Spacer()
                        Text(String(format: "%.2f", edge.strength))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}
