//
//  QuickAddBookmarkSheet.swift
//  CalendarNotes
//

import SwiftUI
import CoreData

struct QuickAddBookmarkSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context

    // Prefill URL if provided
    let initialURL: URL?
    let initialCollectionName: String?

    @ObservedObject private var templateService = BookmarkTemplateService.shared
    @ObservedObject private var presetStore = QuickAddPresetStore.shared

    @State private var urlString: String = ""
    @State private var title: String = ""
    @State private var descriptionText: String = ""
    @State private var isFavorite: Bool = false
    @State private var selectedCollection: String = ""
    @State private var tagInput: String = ""
    @State private var selectedTags: [String] = []
    @State private var linkToDate: Bool = false
    @State private var linkedDate: Date = Date()
    @State private var showAdvanced: Bool = false
    @State private var notes: String = ""
    @State private var isFetching: Bool = false
    @State private var errorMessage: String?

    @State private var availableCollections: [String] = []
    @State private var availableTags: [String] = []

    private let coreData = CoreDataManager.shared
    @State private var handledCallback = false
    @State private var activeTemplate: BookmarkTemplate?
    @State private var templateFieldValues: [UUID: BookmarkTemplateFieldValue] = [:]
    @State private var showingTemplateGallery = false
    @State private var showingSaveTemplateAlert = false
    @State private var newTemplateName: String = ""
    @State private var hasEditedNotes = false
    @State private var activePresetId: UUID?
    @State private var showingSavePresetAlert = false
    @State private var newPresetName: String = ""
    @State private var isApplyingPreset = false

    var body: some View {
        ZStack {
            Color.cnBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                // Title bar
                HStack {
                    Button("Cancel") {
                        handledCallback = true
                        Task { await DeepLinkRouter.shared.notifyAddBookmarkCancelled() }
                        dismiss()
                    }
                        .keyboardShortcut(.cancelAction)
                    Spacer()
                    Text("Add Bookmark")
                        .font(.headline)
                    Spacer()
                    Button("Save") { Task { await save() } }
                        .keyboardShortcut("s", modifiers: [.command])
                        .disabled(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.cnSecondaryBackground)

                Divider()

                Form {
                    Section("Link") {
                        HStack(spacing: 8) {
                            TextField("https://example.com", text: $urlString)
                                .disableAutocorrection(true)
                                #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .keyboardType(.URL)
                                #endif
                                .onSubmit { Task { await fetchMetadataIfNeeded() } }
                            Button("Paste") { pasteFromClipboard() }
                        }
                        if isFetching { ProgressView("Fetching metadata…") }
                        if let msg = errorMessage { Text(msg).foregroundColor(.red) }
                    }

                    Section("Template") {
                        VStack(alignment: .leading, spacing: 12) {
                            if let template = activeTemplate {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: template.systemImageName)
                                        .font(.system(size: 28))
                                        .foregroundStyle(Color.cnAccent)
                                        .frame(width: 32, height: 32)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(template.name)
                                            .font(.headline)
                                        Text(template.shortDescription)
                                            .font(.subheadline)
                                            .foregroundColor(.cnSecondaryText)
                                    }
                                    Spacer()
                                }
                            } else {
                                Text("Templates prefill common bookmark layouts with collections, tags, notes, and custom fields.")
                                    .font(.subheadline)
                                    .foregroundColor(.cnSecondaryText)
                            }

                            HStack {
                                Button {
                                    showingTemplateGallery = true
                                } label: {
                                    Label(activeTemplate == nil ? "Choose Template" : "Change Template", systemImage: "square.grid.2x2")
                                }
                                if activeTemplate != nil {
                                    Button(role: .destructive) {
                                        clearTemplate()
                                    } label: {
                                        Label("Clear", systemImage: "xmark.circle")
                                    }
                                }
                                Spacer()
                                Button {
                                    showingSaveTemplateAlert = true
                                } label: {
                                    Label("Save as Template", systemImage: "plus.circle")
                                }
                            }
                            .buttonStyle(.bordered)
                        }

                        if let template = activeTemplate, !template.customFields.isEmpty {
                            Divider()
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Custom Fields")
                                    .font(.subheadline)
                                    .foregroundColor(.cnSecondaryText)
                                ForEach(template.customFields) { field in
                                    customFieldEditor(for: field)
                                }
                            }
                        }
                    }

                    Section("Quick Add Presets") {
                        if presetStore.presets.isEmpty {
                            Text("Save your favourite collection & tag combos for one-tap capture.")
                                .font(.subheadline)
                                .foregroundColor(.cnSecondaryText)
                                .padding(.vertical, 4)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(presetStore.presets) { preset in
                                        Button {
                                            applyPreset(preset)
                                        } label: {
                                            HStack(spacing: 6) {
                                                if preset.templateId != nil {
                                                    Image(systemName: "square.grid.2x2")
                                                        .font(.caption)
                                                }
                                                Text(preset.name)
                                                    .font(.footnote)
                                                    .fontWeight(activePresetId == preset.id ? .semibold : .regular)
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(
                                                Capsule()
                                                    .fill(activePresetId == preset.id ? Color.cnAccent.opacity(0.2) : Color.cnTertiaryBackground)
                                            )
                                        }
                                        .buttonStyle(.plain)
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                presetStore.delete(preset)
                                            } label: {
                                                Label("Delete preset", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        Button {
                            showingSavePresetAlert = true
                        } label: {
                            Label("Save current as preset", systemImage: "bookmark.circle.fill")
                        }
                    }

                    Section("Details") {
                        TextField("Title", text: $title)
                        TextField("Description (optional)", text: $descriptionText, axis: .vertical)
                            .lineLimit(1...4)
                    }

                    Section("Organize") {
                        Picker("Collection", selection: $selectedCollection) {
                            Text("None").tag("")
                            ForEach(availableCollections, id: \.self) { name in
                                Text(name).tag(name)
                            }
                        }

                        VStack(alignment: .leading) {
                            HStack {
                                TextField("Add tag", text: $tagInput)
                                    .onSubmit(addTagFromInput)
                                Button("Add") { addTagFromInput() }
                            }
                            if !availableTags.isEmpty {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(suggestedTags(prefix: 8), id: \.self) { t in
                                            Button(action: { addTag(t) }) {
                                                Text(t)
                                                    .font(.caption)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 4)
                                                    .background(Color.cnTertiaryBackground)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }
                            if !selectedTags.isEmpty {
                                WrapTagsView(tags: selectedTags, onRemove: removeTag)
                            }
                        }
                    }

                    Section("Links") {
                        Toggle("Link to date", isOn: $linkToDate)
                        if linkToDate {
                            DatePicker("Date", selection: $linkedDate, displayedComponents: [.date])
                        }
                        // Placeholders for event/note pickers (integrate with existing managers when ready)
                        Label("Link to event", systemImage: "calendar.badge.clock")
                            .foregroundColor(.cnSecondaryText)
                        Label("Link to note", systemImage: "note.text")
                            .foregroundColor(.cnSecondaryText)
                    }

                    Section("Options") {
                        Toggle("Save to Favorites", isOn: $isFavorite)
                        DisclosureGroup(isExpanded: $showAdvanced) {
                            TextField("Notes", text: $notes, axis: .vertical)
                                .lineLimit(3...6)
                            Label("Custom preview image (coming soon)", systemImage: "photo")
                                .foregroundColor(.cnSecondaryText)
                            Label("Custom favicon (coming soon)", systemImage: "app")
                                .foregroundColor(.cnSecondaryText)
                        } label: {
                            Text("Advanced options")
                        }
                    }
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .background(Color.cnSecondaryBackground)
            }
            .frame(maxWidth: 620)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.cnSecondaryBackground)
                    .shadow(radius: 20)
            )
            .padding(24)
        }
        .task { await loadInitial() }
        .sheet(isPresented: $showingTemplateGallery) {
            BookmarkTemplateGalleryView(
                onSelect: { template in
                    applyTemplate(template, resetNotes: notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                },
                onCreateCustom: {
                    showingSaveTemplateAlert = true
                }
            )
        }
        .alert("Save Template", isPresented: $showingSaveTemplateAlert) {
            TextField("Template name", text: $newTemplateName)
            Button("Save") {
                let trimmed = newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    saveCurrentAsTemplate(named: trimmed)
                }
                newTemplateName = ""
            }
            Button("Cancel", role: .cancel) {
                newTemplateName = ""
            }
        } message: {
            Text("Creates a reusable bookmark template from the current fields.")
        }
        .alert("Save Quick Add Preset", isPresented: $showingSavePresetAlert) {
            TextField("Preset name", text: $newPresetName)
            Button("Save") {
                let trimmed = newPresetName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    saveCurrentAsPreset(named: trimmed)
                }
                newPresetName = ""
            }
            Button("Cancel", role: .cancel) {
                newPresetName = ""
            }
        } message: {
            Text("Presets remember your favourite collection, tags, favorite toggle, and optional template.")
        }
        .onDisappear {
            if !handledCallback {
                Task { await DeepLinkRouter.shared.notifyAddBookmarkCancelled() }
            }
        }
        .onChange(of: notes) { _, _ in hasEditedNotes = true }
        .onChange(of: selectedCollection) { _, _ in
            guard !isApplyingPreset else { return }
            clearActivePreset()
        }
        .onChange(of: selectedTags) { _, _ in
            guard !isApplyingPreset else { return }
            clearActivePreset()
        }
        .onChange(of: isFavorite) { _, _ in
            guard !isApplyingPreset else { return }
            clearActivePreset()
        }
    }

    // MARK: - Actions

    private func loadInitial() async {
        // Prefill from clipboard if empty
        if let initialURL = initialURL { urlString = initialURL.absoluteString }
        else if urlString.isEmpty, let clip = readClipboardURL() { urlString = clip.absoluteString }

        if BookmarkPreferenceStore.autoFetchMetadata {
            await fetchMetadataIfNeeded()
        }

        availableCollections = fetchCollectionNames()
        availableTags = fetchTagNames()

        if let initialCollectionName = initialCollectionName, !initialCollectionName.isEmpty {
            if !availableCollections.contains(initialCollectionName) {
                availableCollections.insert(initialCollectionName, at: 0)
            }
            selectedCollection = initialCollectionName
        } else if let defaultCollection = BookmarkPreferenceStore.defaultCollectionName, !defaultCollection.isEmpty {
            if !availableCollections.contains(defaultCollection) {
                availableCollections.insert(defaultCollection, at: 0)
            }
            selectedCollection = defaultCollection
        }
    }

    private func pasteFromClipboard() {
        if let u = readClipboardURL() { urlString = u.absoluteString }
        Task { await fetchMetadataIfNeeded() }
    }

    private func readClipboardURL() -> URL? {
        #if os(macOS)
        if let s = NSPasteboard.general.string(forType: .string), let u = URL(string: s), u.scheme?.hasPrefix("http") == true { return u }
        #else
        if let s = UIPasteboard.general.string, let u = URL(string: s), u.scheme?.hasPrefix("http") == true { return u }
        #endif
        return nil
    }

    private func fetchMetadataIfNeeded() async {
        guard BookmarkPreferenceStore.autoFetchMetadata else { return }
        guard let u = URL(string: urlString), u.scheme?.hasPrefix("http") == true else { return }
        isFetching = true
        defer { isFetching = false }
        do {
            let meta = try await BookmarkService.shared.fetchMetadata(for: u)
            if title.isEmpty { title = meta.title ?? readableTitle(from: u) }
            if descriptionText.isEmpty { descriptionText = meta.description ?? "" }
            var combined = meta.suggestedTags
            let ai = SmartBookmarkService.shared.suggestTags(title: title, description: descriptionText, urlString: u.absoluteString)
            combined.append(contentsOf: ai)
            let deduped = Array(Set(combined)).sorted()
            if selectedTags.isEmpty { selectedTags = Array(deduped.prefix(8)) }
        } catch {
            errorMessage = "Failed to fetch metadata."
        }
    }

    private func save() async {
        errorMessage = nil
        guard let u = URL(string: urlString), u.scheme?.hasPrefix("http") == true else {
            errorMessage = "Please enter a valid URL."
            return
        }
        // Duplicate check (smart)
        if BookmarkPreferenceStore.duplicateDetectionEnabled,
           SmartBookmarkService.shared.isDuplicate(url: u) {
            errorMessage = "This URL is already saved."
            return
        }
        do {
            let finalNotes = buildNotes()
            let bookmark = try coreData.createBookmark(
                url: u.absoluteString,
                title: title.isEmpty ? readableTitle(from: u) : title,
                description: descriptionText.isEmpty ? nil : descriptionText,
                tags: selectedTags,
                collectionName: selectedCollection.isEmpty ? nil : selectedCollection,
                isFavorite: isFavorite,
                isArchived: false,
                notes: finalNotes,
                linkedCalendarDate: linkToDate ? linkedDate : nil,
                linkedEventID: nil,
                linkedNoteID: nil
            )
#if canImport(CoreSpotlight)
            BookmarkSpotlightIndexer.shared.index([bookmark])
#endif
            let payload = BookmarkCreationPayload(title: bookmark.title ?? "",
                                                  url: bookmark.url ?? u.absoluteString,
                                                  tags: bookmark.decodedTags,
                                                  collection: bookmark.collectionName,
                                                  createdAt: Date())
            let encoded = try? JSONEncoder().encode(payload)
            let operation = OfflineOperation(entityName: "Bookmark",
                                             objectIdentifier: bookmark.objectID.uriRepresentation().absoluteString,
                                             payload: encoded,
                                             type: .create)
            SyncManager.shared.enqueueBookmarkOperation(operation)
            handledCallback = true
            Task { await DeepLinkRouter.shared.notifyAddBookmarkSucceeded(bookmark: bookmark) }
            dismiss()
        } catch {
            errorMessage = "Failed to save bookmark."
        }
    }

    private func readableTitle(from url: URL) -> String {
        var host = url.host?.replacingOccurrences(of: "www.", with: "") ?? url.absoluteString
        host = host.split(separator: ".").first.map(String.init) ?? host
        let path = url.deletingPathExtension().lastPathComponent
        if path.isEmpty || path == "/" { return host.capitalized }
        return path.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ").capitalized
    }

    private func suggestedTags(prefix: Int) -> [String] {
        if tagInput.isEmpty { return Array(availableTags.prefix(prefix)) }
        return availableTags.filter { $0.localizedCaseInsensitiveContains(tagInput) }.prefix(prefix).map { $0 }
    }

    private func addTagFromInput() {
        let t = tagInput.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty else { return }
        addTag(t)
        tagInput = ""
    }

    private func addTag(_ t: String) {
        guard !selectedTags.contains(t) else { return }
        selectedTags.append(t)
        selectedTags.sort()
        if !isApplyingPreset {
            clearActivePreset()
        }
    }

    private func removeTag(_ t: String) {
        selectedTags.removeAll { $0 == t }
        if !isApplyingPreset {
            clearActivePreset()
        }
    }
}

private struct BookmarkCreationPayload: Codable {
    let title: String
    let url: String
    let tags: [String]
    let collection: String?
    let createdAt: Date
}

// MARK: - Local fetch helpers
extension QuickAddBookmarkSheet {
    private func applyTemplate(_ template: BookmarkTemplate, resetNotes: Bool = true) {
        activeTemplate = template
        if urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            urlString = template.placeholderURL
        }
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let defaultTitle = template.defaultTitle {
            title = defaultTitle
        }
        if let collection = template.defaultCollection, !collection.isEmpty {
            ensureCollectionListed(collection)
            selectedCollection = collection
        }
        if selectedTags.isEmpty {
            selectedTags = template.defaultTags
        } else {
            selectedTags = Array(Set(selectedTags + template.defaultTags)).sorted()
        }
        if resetNotes {
            notes = template.noteTemplate
            hasEditedNotes = false
        }
        templateFieldValues = Dictionary(uniqueKeysWithValues: template.customFields.map { field in
            (field.id, field.resolvedDefaultValue())
        })
        clearActivePreset()
    }

    private func clearTemplate() {
        activeTemplate = nil
        templateFieldValues = [:]
        clearActivePreset()
    }

    private func ensureCollectionListed(_ name: String) {
        guard !name.isEmpty else { return }
        if !availableCollections.contains(name) {
            availableCollections.insert(name, at: 0)
        }
    }

    private func clearActivePreset() {
        if !isApplyingPreset {
            activePresetId = nil
        }
    }

    private func saveCurrentAsTemplate(named name: String) {
        var customFields: [BookmarkTemplate.CustomField] = []
        if let template = activeTemplate {
            customFields = template.customFields.map { field in
                var field = field
                if let value = templateFieldValues[field.id] {
                    field.defaultValue = value.stringValue()
                }
                return field
            }
        }
        let placeholder = urlString.isEmpty ? (activeTemplate?.placeholderURL ?? "https://example.com") : urlString
        let template = BookmarkTemplateService.shared.createCustomTemplate(
            name: name,
            description: descriptionText.isEmpty ? "Custom template" : descriptionText,
            placeholderURL: placeholder,
            defaultTitle: title.isEmpty ? nil : title,
            defaultCollection: selectedCollection.isEmpty ? nil : selectedCollection,
            defaultTags: selectedTags,
            noteTemplate: notes,
            customFields: customFields,
            systemImageName: activeTemplate?.systemImageName ?? "bookmark"
        )
        applyTemplate(template, resetNotes: false)
    }

    private func saveCurrentAsPreset(named name: String) {
        let templateId = activeTemplate?.id
        QuickAddPresetStore.shared.createPreset(
            name: name,
            collectionName: selectedCollection.isEmpty ? nil : selectedCollection,
            tags: selectedTags,
            isFavorite: isFavorite,
            templateId: templateId
        )
        activePresetId = QuickAddPresetStore.shared.presets.last?.id
    }

    private func applyPreset(_ preset: QuickAddPreset) {
        isApplyingPreset = true
        defer { isApplyingPreset = false }
        activePresetId = preset.id
        if let collection = preset.collectionName {
            ensureCollectionListed(collection)
            selectedCollection = collection
        } else {
            selectedCollection = ""
        }
        selectedTags = preset.tags
        isFavorite = preset.isFavorite
        if let templateId = preset.templateId,
           let template = templateService.template(withId: templateId) {
            let shouldResetNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            applyTemplate(template, resetNotes: shouldResetNotes)
        }
    }

    private func buildNotes() -> String? {
        var content = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if let template = activeTemplate, !template.customFields.isEmpty {
            let details = template.customFields.compactMap { field -> String? in
                guard let value = templateFieldValues[field.id] else { return nil }
                let display = displayValue(for: value, field: field)
                guard !display.isEmpty else { return nil }
                return "- \(field.label): \(display)"
            }
            if !details.isEmpty {
                if !content.isEmpty {
                    content += "\n\n"
                }
                content += "## Template Details\n"
                content += details.joined(separator: "\n")
            }
        }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    @ViewBuilder
    private func customFieldEditor(for field: BookmarkTemplate.CustomField) -> some View {
        switch field.type {
        case .text, .url:
            TextField(field.label, text: stringBinding(for: field))
                .textContentType(field.type == .url ? .URL : .none)
                #if os(iOS)
                .keyboardType(field.type == .url ? .URL : .default)
                #endif
        case .longText:
            VStack(alignment: .leading, spacing: 4) {
                Text(field.label)
                    .font(.subheadline)
                TextEditor(text: stringBinding(for: field))
                    .frame(minHeight: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.cnTertiaryText.opacity(0.2))
                    )
            }
        case .toggle:
            Toggle(isOn: boolBinding(for: field)) {
                Text(field.label)
            }
        case .number:
            TextField(field.label, text: numberBinding(for: field))
                #if os(iOS)
                .keyboardType(.decimalPad)
                #endif
        case .date:
            DatePicker(field.label, selection: dateBinding(for: field), displayedComponents: [.date])
        }
    }

    private func stringBinding(for field: BookmarkTemplate.CustomField) -> Binding<String> {
        Binding {
            switch templateFieldValues[field.id] ?? field.resolvedDefaultValue() {
            case .text(let value):
                return value
            case .url(let value):
                return value
            case .number(let number):
                return number.flatMap { String($0) } ?? ""
            case .toggle(let flag):
                return flag ? "true" : "false"
            case .date(let date):
                guard let date else { return "" }
                return formattedDate(for: date)
            }
        } set: { newValue in
            switch field.type {
            case .text, .longText:
                templateFieldValues[field.id] = .text(newValue)
            case .url:
                templateFieldValues[field.id] = .url(newValue)
            case .number:
                templateFieldValues[field.id] = .number(Double(newValue))
            case .toggle:
                templateFieldValues[field.id] = .toggle((newValue as NSString).boolValue)
            case .date:
                if let parsed = ISO8601DateFormatter().date(from: newValue) {
                    templateFieldValues[field.id] = .date(parsed)
                }
            }
        }
    }

    private func boolBinding(for field: BookmarkTemplate.CustomField) -> Binding<Bool> {
        Binding {
            switch templateFieldValues[field.id] ?? field.resolvedDefaultValue() {
            case .toggle(let value):
                return value
            case .text(let text):
                return (text as NSString).boolValue
            case .number(let number):
                return number ?? 0 > 0
            case .url(let string):
                return (string as NSString).boolValue
            case .date(let date):
                return date != nil
            }
        } set: { newValue in
            templateFieldValues[field.id] = .toggle(newValue)
        }
    }

    private func numberBinding(for field: BookmarkTemplate.CustomField) -> Binding<String> {
        Binding {
            switch templateFieldValues[field.id] ?? field.resolvedDefaultValue() {
            case .number(let number):
                if let number {
                    return String(number)
                }
                return ""
            case .text(let text):
                return text
            default:
                return ""
            }
        } set: { newValue in
            templateFieldValues[field.id] = .number(Double(newValue))
        }
    }

    private func dateBinding(for field: BookmarkTemplate.CustomField) -> Binding<Date> {
        Binding {
            switch templateFieldValues[field.id] ?? field.resolvedDefaultValue() {
            case .date(let date):
                return date ?? Date()
            case .text(let text):
                return ISO8601DateFormatter().date(from: text) ?? Date()
            default:
                return Date()
            }
        } set: { newValue in
            templateFieldValues[field.id] = .date(newValue)
        }
    }

    private func displayValue(for value: BookmarkTemplateFieldValue, field: BookmarkTemplate.CustomField) -> String {
        switch value {
        case .text(let string):
            return string
        case .url(let url):
            return url
        case .toggle(let flag):
            return flag ? "Yes" : "No"
        case .number(let number):
            guard let number else { return "" }
            let formatter = NumberFormatter()
            formatter.maximumFractionDigits = 2
            formatter.minimumFractionDigits = 0
            return formatter.string(from: NSNumber(value: number)) ?? String(number)
        case .date(let date):
            guard let date else { return "" }
            return formattedDate(for: date)
        }
    }

    private func formattedDate(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func fetchCollectionNames() -> [String] {
        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return (try? context.fetch(request).compactMap { $0.name }.filter { !$0.isEmpty }) ?? []
    }
    private func fetchTagNames() -> [String] {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        return (try? context.fetch(request).compactMap { $0.name }.filter { !$0.isEmpty }) ?? []
    }
}

// Simple wrapped tags view with remove option
private struct WrapTagsView: View {
    let tags: [String]
    let onRemove: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(wrapped(), id: \.id) { row in
                HStack(spacing: 8) {
                    ForEach(row.tags, id: \.self) { t in
                        HStack(spacing: 4) {
                            Text(t).font(.caption)
                            Button(action: { onRemove(t) }) { Image(systemName: "xmark.circle.fill").font(.caption2) }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cnTertiaryBackground)
                        .clipShape(Capsule())
                    }
                    Spacer()
                }
            }
        }
    }

    private func wrapped() -> [(id: UUID, tags: [String])] {
        var rows: [(id: UUID, tags: [String])] = []
        var current: [String] = []
        for tag in tags {
            current.append(tag)
            if current.count >= 3 { rows.append((UUID(), current)); current = [] }
        }
        if !current.isEmpty { rows.append((UUID(), current)) }
        return rows
    }
}


