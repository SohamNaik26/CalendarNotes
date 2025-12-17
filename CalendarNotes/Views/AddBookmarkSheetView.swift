//
//  AddBookmarkSheetView.swift
//  CalendarNotes
//

import SwiftUI
import CoreData

struct AddBookmarkSheetView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    let url: URL
    let initialTitle: String
    let onSaved: () -> Void

    @State private var title: String = ""
    @State private var descriptionText: String = ""
    @State private var notes: String = ""
    @State private var tagsText: String = ""
    @State private var selectedCollection: Collection?
    @State private var collections: [Collection] = []
    @State private var isFetching = false
    @State private var mlSuggestion: BookmarkMLSuggestion?
    @State private var isLoadingSuggestion = false
    @State private var mlContentSnippet: String?

    private let mlService = BookmarkMLService.shared

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Page")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $descriptionText)
                    HStack {
                        Text("URL")
                        Spacer()
                        Text(url.absoluteString)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Section(header: Text("Save To")) {
                    Picker("Collection", selection: $selectedCollection) {
                        Text("All").tag(Collection?.none)
                        ForEach(collections, id: \.objectID) { col in
                            Text(col.name ?? "Untitled").tag(Collection?.some(col))
                        }
                    }
                }

                Section(header: Text("Tags (comma-separated)")) {
                    TextField("e.g. reading, swift, reference", text: $tagsText)
                }

                smartSuggestionsSection

                Section(header: Text("Notes")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Add Bookmark")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveBookmark() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if title.isEmpty { title = initialTitle }
                loadCollections()
                fetchMetadataIfNeeded()
                Task { await updateSmartSuggestionsIfNeeded() }
            }
        }
    }

    private func loadCollections() {
        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        collections = (try? context.fetch(request)) ?? []
    }

    private func fetchMetadataIfNeeded() {
        guard initialTitle.isEmpty else { return }
        isFetching = true
        Task {
            if let meta = try? await BookmarkService.shared.fetchMetadata(for: url) {
                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let t = meta.title { title = t }
                if descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let d = meta.description { descriptionText = d }
                let ai = SmartBookmarkService.shared.suggestTags(title: title, description: descriptionText, urlString: url.absoluteString)
                if tagsText.isEmpty && !ai.isEmpty { tagsText = ai.prefix(6).joined(separator: ", ") }
                mlContentSnippet = meta.htmlSnippet
            }
            isFetching = false
            await updateSmartSuggestionsIfNeeded()
        }
    }

    @ViewBuilder
    private var smartSuggestionsSection: some View {
        if mlService.smartCategorizationEnabled {
            Section(header: Text("Smart Suggestions")) {
                if isLoadingSuggestion {
                    HStack {
                        ProgressView()
                        Text("Analyzing content…")
                            .foregroundColor(.secondary)
                    }
                } else if let suggestion = mlSuggestion, suggestion.hasContent {
                    if let collection = suggestion.suggestedCollection {
                        HStack {
                            Label("Suggested Collection", systemImage: "folder.fill")
                            Spacer()
                            Text(collection)
                                .foregroundColor(.secondary)
                        }
                    }
                    if !suggestion.suggestedTags.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Suggested Tags", systemImage: "tag")
                            Text(suggestion.suggestedTags.joined(separator: ", "))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    Button("Apply Suggestions") {
                        applySuggestion(suggestion)
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Text("No smart suggestions available yet.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Button("Refresh Suggestions") {
                    Task { await updateSmartSuggestionsIfNeeded(force: true) }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func applySuggestion(_ suggestion: BookmarkMLSuggestion) {
        if let collectionName = suggestion.suggestedCollection,
           let match = collections.first(where: { ($0.name ?? "").localizedCaseInsensitiveCompare(collectionName) == .orderedSame }) {
            selectedCollection = match
        }
        guard !suggestion.suggestedTags.isEmpty else { return }
        var existing = Set(tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty })
        for tag in suggestion.suggestedTags {
            existing.insert(tag.lowercased())
        }
        tagsText = existing.sorted().joined(separator: ", ")
    }

    private func updateSmartSuggestionsIfNeeded(force: Bool = false) async {
        guard mlService.smartCategorizationEnabled else {
            mlSuggestion = nil
            return
        }
        let input = BookmarkInput(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : title,
            description: descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : descriptionText,
            contentSnippet: mlContentSnippet
        )
        guard input.combinedText != nil || force else { return }
        isLoadingSuggestion = true
        let suggestion = await mlService.suggestedMetadata(for: input)
        await MainActor.run {
            mlSuggestion = suggestion
            isLoadingSuggestion = false
        }
    }

    private func saveBookmark() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }

        let tagArray = tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        _ = Bookmark(
            context: context,
            url: url.absoluteString,
            title: trimmedTitle,
            bookmarkDescription: descriptionText.isEmpty ? nil : descriptionText,
            tags: tagArray,
            collection: selectedCollection,
            collectionName: selectedCollection?.name,
            notes: notes.isEmpty ? nil : notes
        )

        do {
            try CoreDataManager.shared.save()
            onSaved()
            dismiss()
        } catch {
            // Fallback attempt saving via context directly
            try? context.save()
            onSaved()
            dismiss()
        }
    }
}


