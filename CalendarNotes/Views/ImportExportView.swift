//
//  ImportExportView.swift
//  CalendarNotes
//

import SwiftUI
import UniformTypeIdentifiers
import CoreData

struct ImportExportView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = BookmarkImportExportService.shared
    @StateObject private var automationService = BookmarkImportAutomationService.shared
    @StateObject private var ruleService = BookmarkImportRuleService.shared

    @State private var showImporter = false
    @State private var importType: UTType = .json
    @State private var importOptions = ImportOptions()
    @State private var exportOptions = ExportOptions()
    @State private var previewItems: [(String, String, String?, [String], String?)] = []
    @State private var previewError: String?
    @State private var showExporter = false
    @State private var exportData: Data = Data()
    @State private var exportType: UTType = .json

    @State private var newEmailSource = ""
    @State private var newRSSFeed = ""
    @State private var pocketToken = ""
    @State private var instapaperUsername = ""
    @State private var instapaperPassword = ""
    @State private var readLaterIntegrationName = ""
    @State private var statusMessage: String?

    @State private var extractionInput: String = ""
    @State private var extractedURLs: [URL] = []
    @State private var showExtractionImporter = false
    @State private var pendingExtractionKind: ExtractionFileKind?

    @State private var newRuleName = ""
    @State private var newRulePattern = ""
    @State private var selectedRuleStrategy: BookmarkImportRule.MatchStrategy = .domain
    @State private var newRuleAssignCollection = ""
    @State private var newRuleTags = ""
    @State private var newRuleArchive = false
    @State private var newRuleSkipDuplicates = false

    private let supportedImportTypes: [UTType] = [.json, .commaSeparatedText, .html]

    private static let historyDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    private var extractionImporterTypes: [UTType] {
        switch pendingExtractionKind {
        case .pdf:
            return [.pdf]
        case .email:
            var types: [UTType] = [.plainText]
            if let eml = UTType(filenameExtension: "eml") { types.append(eml) }
            if let msg = UTType(filenameExtension: "msg") { types.append(msg) }
            return types
        case .notes:
            var types: [UTType] = [.plainText]
            if let md = UTType(filenameExtension: "md") { types.append(md) }
            if let rtf = UTType(filenameExtension: "rtf") { types.append(rtf) }
            return types
        case .none:
            return [.data]
        }
    }

    var body: some View {
        #if os(macOS)
        ZStack {
            Color.cnBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text("Import / Export").font(.headline)
                    Spacer()
                    Button("Done") { dismiss() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.cnSecondaryBackground)

                Divider()

                Form {
                    formContent
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .background(Color.cnSecondaryBackground)
            }
            .frame(maxWidth: 760)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.cnSecondaryBackground)
                    .shadow(radius: 20)
            )
            .padding(24)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: supportedImportTypes, onCompletion: handlePrimaryImportFile)
        .fileExporter(isPresented: $showExporter, document: RawDataDocument(data: exportData, contentType: exportType), contentType: exportType, defaultFilename: defaultExportFilename()) { _ in }
        .fileImporter(isPresented: $showExtractionImporter, allowedContentTypes: extractionImporterTypes, onCompletion: handleExtractionFile)
        #else
        NavigationView {
            Form {
                formContent
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Import / Export")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
        .navigationViewStyle(.stack)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: supportedImportTypes, onCompletion: handlePrimaryImportFile)
        .fileExporter(isPresented: $showExporter, document: RawDataDocument(data: exportData, contentType: exportType), contentType: exportType, defaultFilename: defaultExportFilename()) { _ in }
        .fileImporter(isPresented: $showExtractionImporter, allowedContentTypes: extractionImporterTypes, onCompletion: handleExtractionFile)
        #endif
    }

    private var formContent: some View {
        Group {
            importSection
            automationSection
            extractionSection
            rulesSection
            exportSection
            historySection
            statusSection
        }
    }

    private var importSection: some View {
        Section(header: Text("Import")) {
            Picker("Format", selection: $importType) {
                Text("JSON / Chrome / Firefox / Pocket").tag(UTType.json)
                Text("CSV / Instapaper").tag(UTType.commaSeparatedText)
                Text("HTML / Safari").tag(UTType.html)
            }
            Button("Choose File…") { showImporter = true }
            if !previewItems.isEmpty || previewError != nil {
                NavigationLink("Preview (\(previewItems.count))") {
                    importPreview
                }
            }
            if service.progress > 0 && service.progress < 1 {
                ProgressView(service.currentStep, value: service.progress, total: 1)
            }
            Toggle("Preserve folder structure", isOn: $importOptions.preserveFoldersAsCollections)
            Toggle("Deduplicate", isOn: $importOptions.deduplicate)
            Toggle("Fetch metadata", isOn: $importOptions.fetchMetadata)
            TextField("Assign to collection (optional)", text: Binding(
                get: { importOptions.assignToCollectionName ?? "" },
                set: { importOptions.assignToCollectionName = $0.isEmpty ? nil : $0 }
            ))
            Button("Import Now") { Task { await runImport() } }
                .disabled(previewItems.isEmpty && previewError == nil)
        }
    }

    private var automationSection: some View {
        Section(header: Text("Automatic Imports")) {
            Toggle("Watch clipboard for URLs", isOn: Binding(
                get: { automationService.clipboardWatchingEnabled },
                set: { newValue in
                    automationService.setClipboardWatchingEnabled(newValue)
                    statusMessage = newValue ? "Clipboard watcher enabled." : "Clipboard watcher disabled."
                }
            ))

            VStack(alignment: .leading, spacing: 8) {
                Text("Email ingestion")
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack {
                    TextField("sender@example.com", text: $newEmailSource)
                        .textContentType(.emailAddress)
                    Button("Add") {
                        do {
                            try automationService.registerEmailSource(address: newEmailSource.trimmingCharacters(in: .whitespaces))
                            statusMessage = "Email source added."
                            newEmailSource = ""
                        } catch {
                            statusMessage = error.localizedDescription
                        }
                    }
                    .disabled(newEmailSource.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if !automationService.emailSources.isEmpty {
                    ForEach(automationService.emailSources, id: \.self) { address in
                        HStack {
                            Text(address)
                            Spacer()
                            Button(role: .destructive) {
                                automationService.unregisterEmailSource(address: address)
                                statusMessage = "Removed \(address)."
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } else {
                    Text("No email sources configured.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("RSS feeds")
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack {
                    TextField("https://example.com/feed", text: $newRSSFeed)
                        .textContentType(.URL)
                    Button("Add") {
                        guard let url = URL(string: newRSSFeed.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                            statusMessage = "Invalid feed URL."
                            return
                        }
                        automationService.addRSSFeed(url)
                        statusMessage = "Feed added."
                        newRSSFeed = ""
                    }
                    .disabled(newRSSFeed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if !automationService.rssFeeds.isEmpty {
                    ForEach(automationService.rssFeeds, id: \.self) { feed in
                        HStack {
                            Text(feed.absoluteString)
                                .lineLimit(1)
                            Spacer()
                            Button(role: .destructive) {
                                automationService.removeRSSFeed(feed)
                                statusMessage = "Removed feed."
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } else {
                    Text("No feeds configured.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Pocket")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("Access token", text: $pocketToken)
                HStack {
                    Button(automationService.pocketIntegrationActive ? "Refresh token" : "Connect Pocket") {
                        guard !pocketToken.isEmpty else {
                            statusMessage = "Provide a Pocket token first."
                            return
                        }
                        automationService.enablePocketIntegration(token: pocketToken)
                        statusMessage = "Pocket integration enabled."
                    }
                    .disabled(pocketToken.isEmpty)
                    if automationService.pocketIntegrationActive {
                        Button("Disconnect", role: .destructive) {
                            automationService.disablePocketIntegration()
                            statusMessage = "Pocket integration disabled."
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Instapaper")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("Username", text: $instapaperUsername)
                SecureField("Password", text: $instapaperPassword)
                HStack {
                    Button(automationService.instapaperIntegrationActive ? "Update credentials" : "Connect Instapaper") {
                        guard !instapaperUsername.isEmpty, !instapaperPassword.isEmpty else {
                            statusMessage = "Enter Instapaper credentials."
                            return
                        }
                        automationService.enableInstapaperIntegration(username: instapaperUsername, password: instapaperPassword)
                        statusMessage = "Instapaper integration enabled."
                    }
                    .disabled(instapaperUsername.isEmpty || instapaperPassword.isEmpty)
                    if automationService.instapaperIntegrationActive {
                        Button("Disconnect", role: .destructive) {
                            automationService.disableInstapaperIntegration()
                            statusMessage = "Instapaper integration disabled."
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Read-it-later services")
                    .font(.subheadline)
                    .fontWeight(.medium)
                HStack {
                    TextField("Service identifier", text: $readLaterIntegrationName)
                    Button("Register") {
                        automationService.registerReadLaterIntegration(identifier: readLaterIntegrationName)
                        statusMessage = "Registered \(readLaterIntegrationName)."
                        readLaterIntegrationName = ""
                    }
                    .disabled(readLaterIntegrationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                if !automationService.readLaterIntegrations.isEmpty {
                    ForEach(Array(automationService.readLaterIntegrations), id: \.self) { identifier in
                        HStack {
                            Text(identifier)
                            Spacer()
                            Button(role: .destructive) {
                                automationService.unregisterReadLaterIntegration(identifier: identifier)
                                statusMessage = "Removed \(identifier)."
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } else {
                    Text("No third-party read-it-later services connected.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var extractionSection: some View {
        Section(header: Text("URL Extraction")) {
            TextEditor(text: $extractionInput)
                .frame(minHeight: 100)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2)))

            HStack {
                Button("Extract from text") {
                    extractedURLs = automationService.extractURLs(fromText: extractionInput)
                    statusMessage = "Found \(extractedURLs.count) URL(s) in text."
                }
                .disabled(extractionInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Clear") {
                    extractionInput = ""
                    extractedURLs = []
                }
            }

            HStack {
                Button("Import PDF…") {
                    pendingExtractionKind = .pdf
                    showExtractionImporter = true
                }
                Button("Import email…") {
                    pendingExtractionKind = .email
                    showExtractionImporter = true
                }
                Button("Import notes…") {
                    pendingExtractionKind = .notes
                    showExtractionImporter = true
                }
            }

            if !extractedURLs.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Extracted URLs (\(extractedURLs.count))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    ForEach(extractedURLs, id: \.self) { url in
                        Text(url.absoluteString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
            } else {
                Text("Paste any text or import a file to extract links.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var rulesSection: some View {
        Section(header: Text("Import Rules")) {
            VStack(alignment: .leading, spacing: 8) {
                TextField("Rule name", text: $newRuleName)
                Picker("Match strategy", selection: $selectedRuleStrategy) {
                    ForEach(BookmarkImportRule.MatchStrategy.allCases, id: \.self) { strategy in
                        Text(strategyDisplayName(strategy)).tag(strategy)
                    }
                }
                TextField("Pattern", text: $newRulePattern)
                TextField("Assign collection (optional)", text: $newRuleAssignCollection)
                TextField("Add tags (comma separated)", text: $newRuleTags)
                Toggle("Archive after import", isOn: $newRuleArchive)
                Toggle("Skip if duplicate", isOn: $newRuleSkipDuplicates)
                Button("Save Rule") {
                    createRule()
                }
                .disabled(newRulePattern.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if ruleService.rules.isEmpty {
                Text("No import rules defined yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(ruleService.rules) { rule in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Toggle(rule.name, isOn: Binding(
                                get: { rule.isEnabled },
                                set: { value in
                                    ruleService.toggle(ruleID: rule.id, isEnabled: value)
                                    statusMessage = "\(rule.name) \(value ? "enabled" : "disabled")."
                                }
                            ))
                            .toggleStyle(.switch)

                            Spacer()
                            Button(role: .destructive) {
                                ruleService.remove(ruleID: rule.id)
                                statusMessage = "Removed rule \(rule.name)."
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.borderless)
                        }
                        Text("If \(strategyDisplayName(rule.strategy)) matches \(rule.pattern)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(ruleActionsDescription(rule))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private var exportSection: some View {
        Section(header: Text("Export")) {
            Picker("Format", selection: $exportType) {
                Text("JSON").tag(UTType.json)
                Text("CSV").tag(UTType.commaSeparatedText)
                Text("HTML").tag(UTType.html)
                Text("Markdown").tag(UTType.plainText)
            }
            Toggle("Include archived", isOn: $exportOptions.includeArchived)
            Toggle("Include tags", isOn: $exportOptions.includeTags)
            Toggle("Include metadata", isOn: $exportOptions.includeMetadata)
            Toggle("Include notes", isOn: $exportOptions.includeNotes)
            Button("Export") { runExport() }
        }
    }

    private var historySection: some View {
        Section(header: Text("Import History")) {
            if automationService.lastJobs.isEmpty {
                Text("No import activity yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(automationService.lastJobs) { job in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(job.summary.isEmpty ? job.source.displayName : job.summary)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(job.status.rawValue.capitalized)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Text(Self.historyDateFormatter.string(from: job.createdAt))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if job.itemCount > 0 {
                            Text("Items: \(job.itemCount)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        if let error = job.errorDescription {
                            Text(error)
                                .font(.caption2)
                                .foregroundColor(.red)
                        }
                        HStack {
                            Button("Re-import") {
                                Task { await handleReimport(for: job) }
                            }
                            .disabled(job.artifactURL == nil)

                            if job.status == .completed {
                                Button("Rollback", role: .destructive) {
                                    do {
                                        try automationService.rollback(jobID: job.id)
                                        statusMessage = "Rollback scheduled."
                                    } catch {
                                        statusMessage = error.localizedDescription
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            HStack {
                Button("Refresh") {
                    _ = automationService.loadHistory()
                    statusMessage = "History refreshed."
                }
                Button("Clear History", role: .destructive) {
                    automationService.clearHistory()
                    statusMessage = "History cleared."
                }
            }
        }
    }

    private var statusSection: some View {
        Section {
            if let message = statusMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var importPreview: some View {
        List {
            if let err = previewError {
                Text("Error: \(err)").foregroundColor(.red)
            }
            ForEach(Array(previewItems.enumerated()), id: \.offset) { _, item in
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.0).font(.body)
                    Text(item.1).font(.caption).foregroundColor(.secondary)
                    if let folder = item.2 {
                        Text("Folder: \(folder)").font(.caption2)
                    }
                }
            }
        }
        .navigationTitle("Preview")
    }

    private func runImport() async {
        guard !previewItems.isEmpty else { return }
        let payload = previewItems.map { ["title": $0.0, "url": $0.1, "folder": $0.2 ?? "", "tags": $0.3, "notes": $0.4 ?? ""] as [String: Any] }
        if let data = try? JSONSerialization.data(withJSONObject: payload) {
            _ = try? await BookmarkImportExportService.shared.importData(data, type: .json, options: importOptions)
            statusMessage = "Import complete."
        }
    }

    private func runExport() {
        if let data = try? BookmarkImportExportService.shared.export(type: exportType, options: exportOptions) {
            exportData = data
            showExporter = true
            statusMessage = "Export ready."
        }
    }

    private func detectType(url: URL) -> UTType {
        if url.pathExtension.lowercased() == "csv" { return .commaSeparatedText }
        if ["html", "htm"].contains(url.pathExtension.lowercased()) { return .html }
        return .json
    }

    private func defaultExportFilename() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmm"
        return "Bookmarks-\(df.string(from: Date()))"
    }

    private func handlePrimaryImportFile(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let data = try Data(contentsOf: url)
                previewItems = try BookmarkImportExportService.shared
                    .performPreview(data: data, type: detectType(url: url))
                previewError = nil
                statusMessage = "Ready to import \(previewItems.count) items."
            } catch {
                previewItems = []
                previewError = error.localizedDescription
                statusMessage = error.localizedDescription
            }
        case .failure(let err):
            previewItems = []
            previewError = err.localizedDescription
            statusMessage = err.localizedDescription
        }
    }

    private func handleExtractionFile(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let data = try Data(contentsOf: url)
                switch pendingExtractionKind {
                case .pdf:
                    extractedURLs = try automationService.extractURLs(fromPDFData: data)
                    statusMessage = "Parsed PDF with \(extractedURLs.count) link(s)."
                case .email:
                    extractedURLs = automationService.extractURLs(fromEMLData: data)
                    statusMessage = "Parsed email with \(extractedURLs.count) link(s)."
                case .notes:
                    extractedURLs = automationService.extractURLs(fromNotesData: data)
                    statusMessage = "Parsed notes with \(extractedURLs.count) link(s)."
                case .none:
                    extractedURLs = []
                }
            } catch {
                extractedURLs = []
                statusMessage = error.localizedDescription
            }
        case .failure(let error):
            extractedURLs = []
            statusMessage = error.localizedDescription
        }
        pendingExtractionKind = nil
    }

    private func createRule() {
        var actions: [BookmarkImportRule.Action] = []
        var parameters: [String: String] = [:]
        let tags = newRuleTags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        if !newRuleAssignCollection.trimmingCharacters(in: .whitespaces).isEmpty {
            actions.append(.assignCollection)
            parameters["collection"] = newRuleAssignCollection.trimmingCharacters(in: .whitespaces)
        }
        if !tags.isEmpty {
            actions.append(.addTags)
            parameters["tags"] = tags.joined(separator: ",")
        }
        if newRuleArchive { actions.append(.archive) }
        if newRuleSkipDuplicates { actions.append(.skip) }

        guard !actions.isEmpty else {
            statusMessage = "Add at least one action to save the rule."
            return
        }

        let rule = BookmarkImportRule(
            name: newRuleName.isEmpty ? "Rule \(ruleService.rules.count + 1)" : newRuleName,
            strategy: selectedRuleStrategy,
            pattern: newRulePattern.trimmingCharacters(in: .whitespaces),
            actions: actions,
            parameters: parameters,
            priority: ruleService.rules.count + 1
        )
        ruleService.add(rule)
        statusMessage = "Rule saved."

        newRuleName = ""
        newRulePattern = ""
        newRuleAssignCollection = ""
        newRuleTags = ""
        newRuleArchive = false
        newRuleSkipDuplicates = false
    }

    private func handleReimport(for job: BookmarkImportJob) async {
        guard let artifact = job.artifactURL else {
            statusMessage = "No source artifact available for re-import."
            return
        }
        do {
            let data = try Data(contentsOf: artifact)
            _ = try await BookmarkImportExportService.shared.importData(data, type: .json, options: importOptions)
            statusMessage = "Re-import initiated."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func strategyDisplayName(_ strategy: BookmarkImportRule.MatchStrategy) -> String {
        switch strategy {
        case .host: return "Host equals"
        case .domain: return "Domain contains"
        case .pathPrefix: return "Path starts with"
        case .regex: return "Regex matches"
        case .queryContains: return "Query contains"
        }
    }

    private func ruleActionsDescription(_ rule: BookmarkImportRule) -> String {
        var parts: [String] = []
        for action in rule.actions {
            switch action {
            case .assignCollection:
                if let value = rule.parameters["collection"] { parts.append("Assign to \(value)") }
            case .addTags:
                if let value = rule.parameters["tags"] { parts.append("Add tags \(value)") }
            case .skip:
                parts.append("Skip duplicates")
            case .archive:
                parts.append("Archive after import")
            case .updateExisting:
                parts.append("Update existing entries")
            }
        }
        return parts.joined(separator: " • ")
    }

    private enum ExtractionFileKind {
        case pdf
        case email
        case notes
    }
}

// MARK: - Helpers

extension BookmarkImportExportService {
    // Lightweight preview using parsers without persisting
    func performPreview(data: Data, type: UTType) throws -> [(String, String, String?, [String], String?)] {
        try parse(data: data, type: type)
    }
}

struct RawDataDocument: FileDocument {
    static var readableContentTypes: [UTType] { [] }
    var data: Data
    var contentType: UTType
    init(data: Data, contentType: UTType) { self.data = data; self.contentType = contentType }
    init(configuration: ReadConfiguration) throws { self.data = Data(); self.contentType = .plainText }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}


