//
//  BookmarkDetailView.swift
//  CalendarNotes
//

import SwiftUI
import CoreData

#if os(iOS)
import SafariServices
import UIKit
import AVKit
import PDFKit
import Photos
#else
import AppKit
import AVKit
import PDFKit
#endif

struct BookmarkDetailView: View {
    let bookmark: Bookmark
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context

    @State private var notes: String = ""
    @State private var showingSafari = false
    @State private var showingInApp = false
    @State private var showingQRCode = false
    @State private var showingShareSheet = false
    @State private var shareItems: [Any] = []
    @State private var showingEditSheet = false
    @State private var related: [Bookmark] = []
    @State private var linkedNotes: [Note] = []
    @State private var showingQuickNote = false
    @State private var noteToOpen: Note?
    @State private var showingSchedule = false
    @State private var scheduleDate = Date()
    @State private var isVideoOfflineAvailable = false
    @State private var showingVideoPlayer = false
    @State private var videoPlaybackURL: URL?
    @State private var showingPDFPreview = false
    @State private var pdfDocumentData: Data?
    @State private var showingImageViewer = false
    @State private var originalImageData: Data?
    @State private var isSavingPhoto = false
    @State private var pendingImageShare = false
    @State private var contextActionMessage: BookmarkContextActionMessage?
    #if os(iOS)
    @State private var pendingPhotoSave = false
    #endif

    private let coreData = CoreDataManager.shared
    private let downloadManager = OfflineDownloadManager.shared

    var body: some View {
        navigationContainer
            .task { loadRelated(); loadLinkedNotes(); refreshOfflineState() }
            .sheet(isPresented: $showingSafari) {
                if let urlString = bookmark.url, let url = URL(string: urlString) {
                    #if os(iOS)
                    SafariView(url: url)
                    #else
                    Text("Open: \(urlString)")
                        .padding()
                    #endif
                }
            }
            .sheet(isPresented: $showingQRCode) {
                adaptiveSheet(width: 420, height: 420) {
                    QRCodeSheet(urlString: bookmark.url ?? "")
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                adaptiveSheet(width: 520, height: 480) {
                    EditBookmarkSheet(bookmark: bookmark)
                }
            }
            .sheet(isPresented: $showingInApp) {
                if let urlString = bookmark.url, let url = URL(string: urlString) {
                    InAppBrowserView(url: url, bookmark: bookmark)
                }
            }
            .sheet(isPresented: $showingVideoPlayer) {
                if let url = videoPlaybackURL {
                    VideoPlayerContainer(url: url)
                } else {
                    Text("Video unavailable")
                        .padding()
                }
            }
            .sheet(isPresented: $showingPDFPreview) {
                if let data = pdfDocumentData {
                    PDFPreviewContainer(data: data)
                } else {
                    ProgressView()
                }
            }
            .sheet(isPresented: $showingImageViewer) {
                if let data = originalImageData {
                    ImagePreviewContainer(data: data)
                } else {
                    ProgressView()
                }
            }
    }

    @ViewBuilder
    private var navigationContainer: some View {
        if #available(iOS 16.0, macOS 13.0, *) {
            NavigationStack {
                detailContent
            }
        } else {
            #if os(iOS)
            NavigationView {
                detailContent
            }
            .navigationViewStyle(.stack)
            #else
            NavigationView {
                detailContent
            }
            #endif
        }
    }

    private var detailContent: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Preview Image
                    previewImageSection

                    // Header: Favicon + Title
                    headerSection

                    // URL
                    urlSection

                    // Description
                    if let desc = bookmark.bookmarkDescription, !desc.isEmpty {
                        descriptionSection(desc)
                    }

                    // User Notes (Editable)
                    notesSection

                    // Tags
                    tagsSection

                    // Collection Badge
                    collectionBadge

                    // Quick Actions
                    quickActions

                    readLaterSection

                    linkedResourcesSection

                    typeSpecificSection

                    // Metadata
                    metadataSection

                    // Linked Calendar/Event/Note
                    linkedItemsSection

                    // Related Bookmarks
                    if !related.isEmpty {
                        relatedSection
                    }
                    // Notes about this bookmark
                    if !linkedNotes.isEmpty {
                        notesSectionView
                    }
                }
                .padding(.vertical)
                .padding(.bottom, 100) // Extra padding for action buttons
            }
            
            // Fixed action buttons at bottom
            VStack(spacing: 0) {
                Divider()
                actionButtons
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                    .background(Color.cnBackground)
            }
        }
        .navigationTitle(bookmark.title ?? "Bookmark")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            #if os(iOS)
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") { dismiss() }
            }
            #else
            ToolbarItem(placement: .automatic) {
                Button("Done") { dismiss() }
            }
            #endif
        }
    }

    // MARK: - Sections

    private var previewImageSection: some View {
        Group {
            if let previewData = bookmark.previewImage {
                #if os(macOS)
                if let nsImage = NSImage(data: previewData) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxHeight: 240)
                        .clipped()
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                #else
                if let uiImage = UIImage(data: previewData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxHeight: 240)
                        .clipped()
                        .cornerRadius(12)
                        .padding(.horizontal)
                }
                #endif
            }
        }
    }

    private var headerSection: some View {
        HStack(spacing: 12) {
            // Favicon placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.cnTertiaryBackground)
                .frame(width: 40, height: 40)
                .overlay(
                    Group {
                        #if os(macOS)
                        if let faviconData = bookmark.favicon, let img = NSImage(data: faviconData) {
                            Image(nsImage: img).resizable().scaledToFit()
                        } else {
                            Image(systemName: "bookmark.fill").foregroundColor(.cnSecondaryText)
                        }
                        #else
                        if let faviconData = bookmark.favicon, let img = UIImage(data: faviconData) {
                            Image(uiImage: img).resizable().scaledToFit()
                        } else {
                            Image(systemName: "bookmark.fill").foregroundColor(.cnSecondaryText)
                        }
                        #endif
                    }
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(bookmark.title ?? "Untitled")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.cnPrimaryText)
                if let domain = URL(string: bookmark.url ?? "")?.host {
                    Text(domain)
                        .font(.caption)
                        .foregroundColor(.cnSecondaryText)
                }
            }
            Spacer()
        }
        .padding(.horizontal)
    }

    private var urlSection: some View {
        Group {
            if let urlString = bookmark.url, let url = URL(string: urlString) {
                Button(action: { openURL(url) }) {
                    HStack {
                        Image(systemName: "link")
                        Text(urlString)
                            .font(.caption)
                            .foregroundColor(.cnAccent)
                            .lineLimit(2)
                        Spacer()
                        Image(systemName: "arrow.up.right.square")
                    }
                    .padding()
                    .background(Color.cnSecondaryBackground)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
    }

    private func descriptionSection(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Description")
                .font(.headline)
            Text(text)
                .font(.body)
                .foregroundColor(.cnPrimaryText)
        }
        .padding(.horizontal)
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(.headline)
            TextEditor(text: $notes)
                .frame(minHeight: 100)
                .padding(8)
                .background(Color.cnSecondaryBackground)
                .cornerRadius(8)
                .onChange(of: notes) { saveNotes() }
        }
        .padding(.horizontal)
        .onAppear { notes = bookmark.notes ?? "" }
    }

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(.headline)
            if bookmark.decodedTags.isEmpty {
                Text("No tags")
                    .font(.caption)
                    .foregroundColor(.cnSecondaryText)
            } else {
                TagFlowView(tags: bookmark.decodedTags)
            }
        }
        .padding(.horizontal)
    }

    private var collectionBadge: some View {
        Group {
            if let coll = bookmark.collection?.name ?? bookmark.collectionName, !coll.isEmpty {
                HStack {
                    Text("Collection")
                        .font(.headline)
                    Spacer()
                    Text(coll)
                        .font(.subheadline)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.cnSecondaryBackground)
                        .cornerRadius(6)
                }
                .padding(.horizontal)
            }
        }
    }

    private var quickActions: some View {
        HStack(spacing: 16) {
            quickActionButton(title: bookmark.isFavorite ? "Favorited" : "Favorite", icon: "star.fill", isActive: bookmark.isFavorite) {
                try? coreData.setBookmark(bookmark, favorite: !bookmark.isFavorite)
            }
            quickActionButton(title: bookmark.isInReadLater ? "Remove Read Later" : "Read Later",
                               icon: bookmark.isInReadLater ? "bookmark.slash" : "bookmark",
                               isActive: bookmark.isInReadLater) {
                toggleReadLater()
            }
        }
        .padding(.horizontal)
    }

    private func quickActionButton(title: String, icon: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .foregroundColor(isActive ? .yellow : .cnSecondaryText)
                Text(title)
                    .foregroundColor(.cnPrimaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isActive ? Color.yellow.opacity(0.15) : Color.cnSecondaryBackground)
            .cornerRadius(8)
        }
    }

    private func toggleReadLater() {
        do {
            let added = try ReadLaterService.shared.toggleReadLater(for: bookmark)
            contextActionMessage = BookmarkContextActionMessage(
                title: added ? "Added" : "Removed",
                message: added ? "Queued for Read Later." : "Removed from Read Later."
            )
        } catch {
            lastError("Read Later update failed: \(error.localizedDescription)")
        }
    }

    private var metadataSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Metadata")
                .font(.headline)
            metadataRow(label: "Saved", value: formatDate(bookmark.createdDate))
            if let opened = bookmark.lastOpenedDate {
                metadataRow(label: "Last opened", value: formatDate(opened))
            }
            metadataRow(label: "Opened", value: "\(bookmark.openCount) times")
            metadataRow(label: "Preview status", value: bookmark.previewImage != nil ? "Available" : "Not available")
        }
        .padding(.horizontal)
    }

    private func metadataRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.cnSecondaryText)
            Spacer()
            Text(value)
                .foregroundColor(.cnPrimaryText)
        }
    }

    private func relativeDateString(from date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatReadableTime(_ seconds: Double) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = seconds >= 3600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: seconds) ?? ""
    }

    private var linkedItemsSection: some View {
        Group {
            if let date = bookmark.linkedCalendarDate {
                linkedCalendarRow(date)
            }
            if bookmark.linkedEventID != nil {
                linkedEventRow
            }
        }
    }

    private func linkedCalendarRow(_ date: Date) -> some View {
        Button(action: { NotificationCenter.default.post(name: .init("NavigateToCalendarDate"), object: date) }) {
            HStack {
                Image(systemName: "calendar")
                Text("Linked to \(formatDate(date))")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(Color.cnSecondaryBackground)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }

    private var linkedEventRow: some View {
        Button(action: { NotificationCenter.default.post(name: .init("NavigateToEvent"), object: bookmark.linkedEventID) }) {
            HStack {
                Image(systemName: "calendar.badge.clock")
                Text("Linked Event")
                Spacer()
                Image(systemName: "chevron.right")
            }
            .padding()
            .background(Color.cnSecondaryBackground)
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }

    private var notesSectionView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes about this bookmark").font(.headline)
            ForEach(linkedNotes, id: \.objectID) { n in
                Button(action: { noteToOpen = n }) {
                    HStack {
                        Image(systemName: "note.text")
                        Text(previewTitle(n))
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color.cnSecondaryBackground)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Primary Actions
            HStack(spacing: 12) {
                actionButton(title: "Open in Safari", icon: "safari", color: .blue) {
                    if let urlString = bookmark.url, let url = URL(string: urlString) {
                        openURL(url)
                    }
                }
                actionButton(title: "In-App", icon: "eye", color: .green) { showingInApp = true }
            }

            // Secondary Actions
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                actionButton(title: "Copy URL", icon: "doc.on.doc", color: .gray) { copyURL() }
                actionButton(title: "Copy App Link", icon: "link", color: .gray) { copyDeepLink() }
                actionButton(title: "Share", icon: "square.and.arrow.up", color: .gray) { shareBookmark() }
                actionButton(title: "QR Code", icon: "qrcode", color: .gray) { showingQRCode = true }
                actionButton(title: "Edit", icon: "pencil", color: .gray) { showingEditSheet = true }
                actionButton(title: bookmark.isArchived ? "Unarchive" : "Archive", icon: "archivebox", color: .orange) {
                    try? coreData.setBookmark(bookmark, archived: !bookmark.isArchived)
                }
                actionButton(title: "Schedule Read", icon: "calendar.badge.clock", color: .cnAccent) { showingSchedule = true }
                actionButton(title: "Read Later Task", icon: "checkmark.square", color: .cnAccent) {
                    let _ = try? BookmarkTaskLinkService.shared.createReadLaterTask(from: bookmark)
                }
                actionButton(title: "Quick Note", icon: "note.text", color: .cnAccent) { createQuickNote() }
                actionButton(title: "Delete", icon: "trash", color: .red) {
                    coreData.viewContext.delete(bookmark)
                    try? coreData.save()
                    dismiss()
                }
            }
        }
        .padding(.horizontal)
        #if os(iOS)
        .sheet(isPresented: $showingShareSheet) {
            ShareSheet(activityItems: shareItems)
        }
        #endif
        .sheet(isPresented: $showingSchedule) {
            adaptiveSheet(width: 420, height: 320) {
                ScheduleReadSheet(scheduleDate: $scheduleDate, bookmark: bookmark) {
                    showingSchedule = false
                }
            }
        }
        .sheet(item: $noteToOpen) { n in
            NoteEditorView(viewModel: NoteEditorViewModel(note: n))
        }
    }

    private func actionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(8)
        }
    }

    private var relatedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Related Bookmarks")
                .font(.headline)
            ForEach(related.prefix(5), id: \.objectID) { b in
                Button(action: {}) {
                    HStack {
                        Image(systemName: "bookmark.fill")
                        Text(b.title ?? b.url ?? "Untitled")
                            .lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .padding()
                    .background(Color.cnSecondaryBackground)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func formatDate(_ date: Date?) -> String {
        guard let d = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: d)
    }

    private func openURL(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
        try? coreData.markBookmarkOpened(bookmark)
    }

    private func copyURL() {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(bookmark.url ?? "", forType: .string)
        #else
        UIPasteboard.general.string = bookmark.url
        #endif
    }

    private func copyDeepLink() {
        guard let id = bookmark.id else { return }
        let deepLink = "calendarnotes://bookmark/\(id.uuidString.lowercased())"
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(deepLink, forType: .string)
        #else
        UIPasteboard.general.string = deepLink
        #endif
    }

    private func shareBookmark() {
        #if os(iOS)
        shareItems = BookmarkShareService.shared.shareItems(for: bookmark, includeImage: true)
        showingShareSheet = true
        #else
        // macOS: copy link as a minimal share action for now
        if let s = bookmark.url { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(s, forType: .string) }
        #endif
    }


    private func saveNotes() {
        try? coreData.update(bookmark) { b in b.notes = notes }
        try? coreData.save()
    }

    private func loadRelated() {
        let tags = bookmark.decodedTags
        let coll = bookmark.collectionName
        do {
            let all = try coreData.fetchBookmarks(limit: 100)
            related = all.filter { b in
                b.objectID != bookmark.objectID && (
                    !tags.isEmpty && !Set(b.decodedTags).isDisjoint(with: Set(tags)) ||
                    coll != nil && (b.collectionName == coll || b.collection?.name == coll)
                )
            }
        } catch {
            related = []
        }
    }

    private func loadLinkedNotes() {
        linkedNotes = BookmarkNoteLinkService.shared.notesReferencing(bookmark)
    }

    private func createQuickNote() {
        if let n = try? BookmarkNoteLinkService.shared.createNote(from: bookmark, template: "\n## Reading Notes\n\n- Summary:\n- Key points:\n- Follow-ups:\n") {
            noteToOpen = n
            loadLinkedNotes()
        }
    }

    private func previewTitle(_ note: Note) -> String {
        let first = (note.content ?? "").split(separator: "\n").first.map(String.init) ?? "Note"
        return first.trimmingCharacters(in: .whitespaces)
    }

    @ViewBuilder
    private func adaptiveSheet<Content: View>(width: CGFloat, height: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        #if os(macOS)
        VStack(alignment: .leading, spacing: 0) {
            content()
                .padding(24)
        }
        .frame(minWidth: width, maxWidth: width, minHeight: height, maxHeight: height)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.cnSecondaryBackground)
                .shadow(color: Color.black.opacity(0.15), radius: 18, x: 0, y: 12)
        )
        .padding(32)
        #else
        content()
        #endif
    }

    private func refreshOfflineState() {
        let id = bookmark.objectID.uriRepresentation().absoluteString
        isVideoOfflineAvailable = downloadManager.isOfflineAvailable(bookmarkID: id)
    }

    private var videoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Video")
                .font(.headline)
            if let duration = bookmark.formattedVideoDuration {
                Label("Duration \(duration)", systemImage: "clock")
                    .foregroundColor(.cnSecondaryText)
            }
            if let channel = bookmark.contentMetadataValue?.video?.channelName {
                Label(channel, systemImage: "person.text.rectangle")
                    .foregroundColor(.cnSecondaryText)
            }
            if let date = bookmark.contentMetadataValue?.video?.uploadDate {
                Label("Uploaded \(formatDate(date))", systemImage: "calendar")
                    .foregroundColor(.cnSecondaryText)
            }
            HStack(spacing: 12) {
                Button(action: prepareVideoPlayback) {
                    Label("Play in App", systemImage: "play.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button(action: toggleWatched) {
                    Label(bookmark.isWatched ? "Mark Unwatched" : "Mark Watched", systemImage: bookmark.isWatched ? "eye" : "eye.slash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            Button(action: toggleVideoOffline) {
                Label(isVideoOfflineAvailable ? "Remove Offline Copy" : "Download for Offline", systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }

    private var pdfSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("PDF")
                .font(.headline)
            if let pages = bookmark.pdfPageCountValue {
                Label("\(pages) pages", systemImage: "doc.on.doc")
                    .foregroundColor(.cnSecondaryText)
            }
            Label(pdfAllowsAnnotationsText, systemImage: bookmark.pdfAllowsAnnotations ? "pencil.and.outline" : "nosign")
                .foregroundColor(.cnSecondaryText)
            if let snippet = bookmark.pdfOCRPreview {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OCR Preview")
                        .font(.subheadline)
                        .foregroundColor(.cnSecondaryText)
                    Text(snippet)
                        .font(.caption)
                        .foregroundColor(.cnPrimaryText)
                        .lineLimit(4)
                }
            }
            Button(action: loadPDFPreview) {
                Label("Preview PDF", systemImage: "doc.text.magnifyingglass")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
    }

    private var imageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Image")
                .font(.headline)
            if let dims = bookmark.imageDimensionsDescription {
                Label(dims, systemImage: "aspectratio")
                    .foregroundColor(.cnSecondaryText)
            }
            HStack(spacing: 12) {
                Button(action: { loadImageData(presentViewer: true) }) {
                    Label("View Full Resolution", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                Button(action: initiateImageShare) {
                    Label("Download", systemImage: "arrow.down.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            #if os(iOS)
            Button(action: initiatePhotoSave) {
                Label("Add to Photo Library", systemImage: "plus.rectangle.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isSavingPhoto)
            #endif
        }
        .padding(.horizontal)
    }

    private var recipeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recipe")
                .font(.headline)
            if let cook = bookmark.recipeCookTimeDescription {
                Label("Cook Time \(cook)", systemImage: "timer")
                    .foregroundColor(.cnSecondaryText)
            }
            if !bookmark.recipeIngredients.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ingredients")
                        .font(.subheadline)
                        .foregroundColor(.cnSecondaryText)
                    ForEach(bookmark.recipeIngredients, id: \.self) { ingredient in
                        Text("• \(ingredient)")
                            .font(.caption)
                    }
                }
            }
            Button(action: addToMealPlanner) {
                Label("Add to Meal Planner", systemImage: "calendar.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }

    private var repositorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Repository")
                .font(.headline)
            let stats = bookmark.gitHubStatistics
            HStack(spacing: 16) {
                if let stars = stats.stars {
                    Label("\(stars)", systemImage: "star.fill")
                        .foregroundColor(.yellow)
                }
                if let forks = stats.forks {
                    Label("\(forks)", systemImage: "tuningfork")
                        .foregroundColor(.cnSecondaryText)
                }
                if let language = stats.language {
                    Label(language, systemImage: "chevron.left.slash.chevron.right")
                        .foregroundColor(.cnSecondaryText)
                }
            }
            if let updated = stats.lastUpdated {
                Label("Updated \(formatDate(updated))", systemImage: "clock.arrow.circlepath")
                    .foregroundColor(.cnSecondaryText)
            }
            Button(action: openRepository) {
                Label("Open on GitHub", systemImage: "safari")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal)
    }

    private var productSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Product")
                .font(.headline)
            if let price = bookmark.productPriceDisplay {
                Label(price, systemImage: "tag")
                    .foregroundColor(.cnSecondaryText)
            }
            if let availability = bookmark.contentMetadataValue?.product?.availability {
                Label(availability, systemImage: "shippingbox")
                    .foregroundColor(.cnSecondaryText)
            }
            Button(action: openExternal) {
                Label("Open Product Page", systemImage: "link")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal)
    }

    private var socialSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Social Post")
                .font(.headline)
            if let platform = bookmark.socialPlatformName {
                Label(platform, systemImage: "person.2")
                    .foregroundColor(.cnSecondaryText)
            }
            if let author = bookmark.socialAuthorHandle {
                Label(author, systemImage: "at")
                    .foregroundColor(.cnSecondaryText)
            }
            if let timestamp = bookmark.contentMetadataValue?.social?.timestamp {
                Label("Posted \(formatDate(timestamp))", systemImage: "clock")
                    .foregroundColor(.cnSecondaryText)
            }
        }
        .padding(.horizontal)
    }

    private var articleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Article")
                .font(.headline)
            if let author = bookmark.contentMetadataValue?.article?.author {
                Label(author, systemImage: "person")
                    .foregroundColor(.cnSecondaryText)
            }
            if let publication = bookmark.contentMetadataValue?.article?.publication {
                Label(publication, systemImage: "newspaper")
                    .foregroundColor(.cnSecondaryText)
            }
            if let readTime = bookmark.articleReadTimeDescription {
                Label("Read Time \(readTime)", systemImage: "book")
                    .foregroundColor(.cnSecondaryText)
            }
        }
        .padding(.horizontal)
    }

    private func toggleWatched() {
        try? coreData.setBookmark(bookmark, watched: !bookmark.isWatched)
    }

    private func toggleVideoOffline() {
        let id = bookmark.objectID.uriRepresentation().absoluteString
        let enable = !isVideoOfflineAvailable
        downloadManager.toggleOffline(for: bookmark, enable: enable)
        isVideoOfflineAvailable = downloadManager.isOfflineAvailable(bookmarkID: id)
    }

    private func prepareVideoPlayback() {
        guard let metadata = bookmark.contentMetadataValue?.video else {
            openExternal()
            return
        }
        if let direct = metadata.downloadURL, isStreamable(url: direct) {
            videoPlaybackURL = direct
            showingVideoPlayer = true
            return
        }
        if let embed = metadata.embedURL, isStreamable(url: embed) {
            videoPlaybackURL = embed
            showingVideoPlayer = true
            return
        }
        showingInApp = true
    }

    private func loadPDFPreview() {
        guard let urlString = bookmark.url, let url = URL(string: urlString) else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                await MainActor.run {
                    pdfDocumentData = data
                    showingPDFPreview = true
                }
            } catch {
                await MainActor.run {
                    lastError("Failed to load PDF: \(error.localizedDescription)")
                }
            }
        }
    }

    private func loadImageData(presentViewer: Bool) {
        if let data = originalImageData {
            if presentViewer {
                showingImageViewer = true
            }
            if pendingImageShare {
                shareImage(data: data)
                pendingImageShare = false
            }
            #if os(iOS)
            if pendingPhotoSave {
                saveImageToLibrary(data: data)
                pendingPhotoSave = false
            }
            #endif
            return
        }
        guard let remote = bookmark.contentMetadataValue?.image?.remoteURL ?? URL(string: bookmark.url ?? "") else { return }
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: remote)
                await MainActor.run {
                    originalImageData = data
                    if presentViewer {
                        showingImageViewer = true
                    }
                    if pendingImageShare {
                        shareImage(data: data)
                        pendingImageShare = false
                    }
                    #if os(iOS)
                    if pendingPhotoSave {
                        saveImageToLibrary(data: data)
                        pendingPhotoSave = false
                    }
                    #endif
                }
            } catch {
                await MainActor.run {
                    lastError("Failed to load image: \(error.localizedDescription)")
                    pendingImageShare = false
                    #if os(iOS)
                    pendingPhotoSave = false
                    #endif
                }
            }
        }
    }

    private func initiateImageShare() {
        if let data = originalImageData {
            shareImage(data: data)
        } else {
            pendingImageShare = true
            loadImageData(presentViewer: false)
        }
    }

    private func shareImage(data: Data) {
        #if os(iOS)
        if let image = UIImage(data: data) {
            shareItems = [image]
            showingShareSheet = true
        }
        #else
        shareItems = [data]
        showingShareSheet = true
        #endif
    }

    #if os(iOS)
    private func initiatePhotoSave() {
        if let data = originalImageData {
            saveImageToLibrary(data: data)
        } else {
            pendingPhotoSave = true
            loadImageData(presentViewer: false)
        }
    }

    private func saveImageToLibrary(data: Data) {
        guard let image = UIImage(data: data) else { return }
        isSavingPhoto = true
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                isSavingPhoto = false
                return
            }
            UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
            DispatchQueue.main.async {
                isSavingPhoto = false
                contextActionMessage = BookmarkContextActionMessage(title: "Saved", message: "Image added to Photos.")
            }
        }
    }
    #endif

    private func addToMealPlanner() {
        contextActionMessage = BookmarkContextActionMessage(title: "Meal Planner", message: "Recipe queued for meal planner integration.")
    }

    private func openRepository() {
        openExternal()
    }

    private func openExternal() {
        if let urlString = bookmark.url, let url = URL(string: urlString) {
            #if os(macOS)
            NSWorkspace.shared.open(url)
            #else
            UIApplication.shared.open(url)
            #endif
        }
    }

    private func lastError(_ message: String) {
        contextActionMessage = BookmarkContextActionMessage(title: "Error", message: message)
    }

    private var pdfAllowsAnnotationsText: String {
        bookmark.pdfAllowsAnnotations ? "Annotations supported" : "Annotations disabled"
    }
    
    private func isStreamable(url: URL) -> Bool {
        let streamableExtensions = ["mp4", "mov", "m4v", "mkv", "webm", "m3u8"]
        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty, streamableExtensions.contains(ext) {
            return true
        }
        return url.scheme?.hasPrefix("http") == true && url.absoluteString.contains(".m3u8")
    }

    private var linkedResourcesSection: some View {
        let events = bookmark.linkedEvents
        let tasks = bookmark.linkedTasks
        let notes = bookmark.linkedNotes
        return Group {
            if !events.isEmpty || !tasks.isEmpty || !notes.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Linked Resources")
                        .font(.headline)
                    if !events.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(events, id: \.objectID) { event in
                                Button {
                                    NotificationCenter.default.post(name: .init("NavigateToEvent"), object: event.objectID)
                                } label: {
                                    HStack {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.cnAccent)
                                        Text(event.title ?? "Untitled Event")
                                            .foregroundColor(.cnPrimaryText)
                                        Spacer()
                                        if let date = event.startDate {
                                            Text(formatDate(date))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(8)
                                .background(Color.cnSecondaryBackground)
                                .cornerRadius(8)
                            }
                        }
                    }
                    if !tasks.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(tasks, id: \.objectID) { task in
                                Button {
                                    NotificationCenter.default.post(name: .init("NavigateToTask"), object: task.objectID)
                                } label: {
                                    HStack {
                                        Image(systemName: "checkmark.square")
                                            .foregroundColor(.cnPrimary)
                                        Text(task.title ?? "Untitled Task")
                                            .foregroundColor(.cnPrimaryText)
                                        Spacer()
                                        if let due = task.dueDate {
                                            Text(formatDate(due))
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(8)
                                .background(Color.cnSecondaryBackground)
                                .cornerRadius(8)
                            }
                        }
                    }
                    if !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(notes, id: \.objectID) { note in
                                Button {
                                    NotificationCenter.default.post(name: .init("NavigateToNote"), object: note.objectID)
                                } label: {
                                    HStack {
                                        Image(systemName: "doc.text")
                                            .foregroundColor(.cnSecondary)
                                        Text(previewTitle(note))
                                            .foregroundColor(.cnPrimaryText)
                                        Spacer()
                                    }
                                }
                                .buttonStyle(.plain)
                                .padding(8)
                                .background(Color.cnSecondaryBackground)
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 4)
            }
        }
    }

    private var typeSpecificSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if bookmark.contentTypeValue == .video {
                videoSection
            }
            if bookmark.contentTypeValue == .pdf {
                pdfSection
            }
            if bookmark.contentTypeValue == .image {
                imageSection
            }
            if bookmark.contentTypeValue == .recipe {
                recipeSection
            }
            if bookmark.contentTypeValue == .repository {
                repositorySection
            }
            if bookmark.contentTypeValue == .product {
                productSection
            }
            if bookmark.contentTypeValue == .social {
                socialSection
            }
            if bookmark.contentTypeValue == .article {
                articleSection
            }
        }
        .padding(.horizontal)
    }

    private var readLaterSection: some View {
        Group {
            if bookmark.isInReadLater || bookmark.readingProgressValue > 0 {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Read Later")
                            .font(.headline)
                        Spacer()
                        if let added = bookmark.readLaterAddedDate {
                            Text("Added \(relativeDateString(from: added))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    HStack(spacing: 12) {
                        Label(bookmark.isReadValue ? "Completed" : "In Queue",
                              systemImage: bookmark.readLaterStatusIcon)
                            .foregroundColor(bookmark.readLaterStatusColor)
                        if let estimate = bookmark.estimatedReadingDescription {
                            Label(estimate, systemImage: "clock")
                                .foregroundColor(.cnSecondaryText)
                        }
                    }
                    if bookmark.totalReadingTimeValue > 0 {
                        Label("Reading time \(formatReadableTime(bookmark.totalReadingTimeValue))", systemImage: "timer")
                            .foregroundColor(.cnSecondaryText)
                    }
                    ProgressView(value: bookmark.readingProgressValue)
                        .progressViewStyle(.linear)
                        .tint(.cnAccent)
                        .opacity(bookmark.readingProgressValue > 0 ? 1 : 0)
                    HStack(spacing: 12) {
                        Button(bookmark.isReadValue ? "Mark Unread" : "Mark Read") {
                            if bookmark.isReadValue {
                                try? ReadLaterService.shared.markUnread(bookmark)
                            } else {
                                try? ReadLaterService.shared.markRead(bookmark)
                            }
                        }
                        .buttonStyle(.bordered)
                        Button("Open Reader") {
                            NotificationCenter.default.post(name: .init("OpenReadLater"), object: bookmark.objectID)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
        }
    }
}

// MARK: - Supporting Views

#if os(iOS)
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
#endif

struct QRCodeSheet: View {
    let urlString: String
    @Environment(\.dismiss) private var dismiss
    @State private var qrImage: Data?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            sheetHeader(title: "Share via QR")
            Group {
                if let data = qrImage {
                    #if os(macOS)
                    if let nsImage = NSImage(data: data) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .cornerRadius(12)
                    }
                    #else
                    if let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 200, height: 200)
                            .cornerRadius(12)
                    }
                    #endif
                } else {
                    ProgressView()
                }
            }
            Text(urlString)
                .font(.callout)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 8)
            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .task {
            qrImage = BookmarkService.shared.generateQRCode(for: urlString)
        }
    }
}

struct TagFlowView: View {
    let tags: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(wrappedTags(), id: \.id) { row in
                HStack(spacing: 8) {
                    ForEach(row.tags, id: \.self) { tag in
                        tagButton(tag)
                    }
                    Spacer()
                }
            }
        }
    }
    
    private func wrappedTags() -> [(id: UUID, tags: [String])] {
        var rows: [(id: UUID, tags: [String])] = []
        var currentRow: [String] = []
        for tag in tags {
            currentRow.append(tag)
            if currentRow.count >= 3 { // Simple wrapping at 3 tags per row
                rows.append((UUID(), currentRow))
                currentRow = []
            }
        }
        if !currentRow.isEmpty {
            rows.append((UUID(), currentRow))
        }
        return rows
    }
    
    private func tagButton(_ tag: String) -> some View {
        Button(action: { NotificationCenter.default.post(name: .init("FilterByTag"), object: tag) }) {
            HStack(spacing: 4) {
                Image(systemName: "tag.fill")
                Text(tag)
            }
            .font(.caption)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.cnAccent.opacity(0.15))
            .foregroundColor(.cnAccent)
            .clipShape(Capsule())
        }
    }
}

struct EditBookmarkSheet: View {
    let bookmark: Bookmark
    @Environment(\.dismiss) private var dismiss
    @State private var title: String = ""
    @State private var urlString: String = ""
    @State private var description: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            sheetHeader(title: "Edit Bookmark")
            VStack(alignment: .leading, spacing: 12) {
                Text("Title").font(.caption).foregroundColor(.secondary)
                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)
                Text("URL").font(.caption).foregroundColor(.secondary)
                TextField("URL", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                Text("Description").font(.caption).foregroundColor(.secondary)
                TextEditor(text: $description)
                    .frame(minHeight: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.separator, lineWidth: 1)
                    )
            }
            Spacer()
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                Button("Save") {
                    try? CoreDataManager.shared.update(bookmark) { b in
                        b.title = title
                        let sanitized = URLPrivacySanitizer.sanitized(urlString)
                        b.url = sanitized
                        b.bookmarkDescription = description.isEmpty ? nil : description
                    }
                    try? CoreDataManager.shared.save()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .onAppear {
            title = bookmark.title ?? ""
            urlString = bookmark.url ?? ""
            description = bookmark.bookmarkDescription ?? ""
        }
    }
}

struct ScheduleReadSheet: View {
    @Binding var scheduleDate: Date
    let bookmark: Bookmark
    let onComplete: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            sheetHeader(title: "Schedule to Read")
            VStack(alignment: .leading, spacing: 12) {
                if let url = bookmark.url, let u = URL(string: url) {
                    Text(u.absoluteString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }
                DatePicker("Date", selection: $scheduleDate, displayedComponents: [.date, .hourAndMinute])
                    .datePickerStyle(.graphical)
            }
            Spacer()
            HStack {
                Button("Cancel") { onComplete() }
                Spacer()
                Button("Add") {
                    let title = (bookmark.title ?? URL(string: bookmark.url ?? "")?.host ?? "Bookmark") + " — Reading"
                    _ = CalendarEvent(context: CoreDataManager.shared.viewContext, title: title, startDate: scheduleDate, endDate: scheduleDate.addingTimeInterval(45*60), category: "Reading", notes: bookmark.url)
                    bookmark.linkedCalendarDate = scheduleDate
                    try? CoreDataManager.shared.save()
                    onComplete()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

@ViewBuilder
private func sheetHeader(title: String) -> some View {
    Text(title)
        .font(.title3.weight(.semibold))
        .frame(maxWidth: .infinity, alignment: .leading)
}

private extension Color {
    static var separator: Color {
        #if os(macOS)
        return Color(NSColor.separatorColor)
        #else
        return Color(UIColor.separator)
        #endif
    }
}

#if canImport(AVKit)
struct VideoPlayerContainer: View {
    let url: URL
    var body: some View {
        VideoPlayer(player: AVPlayer(url: url))
            .ignoresSafeArea()
    }
}
#endif

#if canImport(PDFKit)
struct PDFPreviewContainer: View {
    let data: Data
    var body: some View {
        PDFKitRepresentedView(data: data)
            .ignoresSafeArea()
    }
}

#if os(iOS)
struct PDFKitRepresentedView: UIViewRepresentable {
    let data: Data
    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument(data: data)
        view.autoScales = true
        return view
    }
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
#else
struct PDFKitRepresentedView: NSViewRepresentable {
    let data: Data
    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument(data: data)
        view.autoScales = true
        return view
    }
    func updateNSView(_ nsView: PDFView, context: Context) {}
}
#endif

#endif

struct ImagePreviewContainer: View {
    let data: Data
    var body: some View {
        #if os(macOS)
        if let image = NSImage(data: data) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .padding()
        }
        #else
        if let image = UIImage(data: data) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .padding()
        }
        #endif
    }
}

