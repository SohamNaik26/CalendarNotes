//
//  BookmarkWidgets.swift
//  CalendarNotes
//

#if canImport(WidgetKit) && os(iOS)
import WidgetKit
import SwiftUI
import AppIntents

// MARK: - App Intents

enum DisplayModeIntent: String, AppEnum, CaseDisplayRepresentable { // iOS 17+
    case recent
    case favorites
    case random
    
    static var allCases: [DisplayModeIntent] {
        [.recent, .favorites, .random]
    }
    
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Display Mode" }
    static var caseDisplayRepresentations: [Self : DisplayRepresentation] = [
        .recent: "Recent",
        .favorites: "Favorites",
        .random: "Random"
    ]
}

struct BookmarkWidgetConfiguration: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Bookmark Widget"
    // WidgetConfigurationIntent requires all parameters to be optional with defaults
    @Parameter(title: "Mode", default: nil) var mode: String?
    @Parameter(title: "Collection", default: nil) var collection: String?
    
    var displayMode: DisplayModeIntent {
        guard let mode = mode, !mode.isEmpty, let modeEnum = DisplayModeIntent(rawValue: mode) else {
            return .recent
        }
        return modeEnum
    }
    
    init() {
        // Default initializer for WidgetConfigurationIntent
    }
    
    init(mode: String?, collection: String?) {
        self.mode = mode
        self.collection = collection
    }
    
    static var openAppWhenRun: Bool = false
}

// MARK: - Timeline

struct BookmarkEntry: TimelineEntry { let date: Date; let items: [WidgetBookmark]; let mode: DisplayModeIntent }

struct BookmarkProvider: AppIntentTimelineProvider {
    typealias Intent = BookmarkWidgetConfiguration
    
    func placeholder(in context: Context) -> BookmarkEntry {
        BookmarkEntry(date: .now, items: WidgetDataSource.placeholder(), mode: .recent)
    }
    func snapshot(for configuration: BookmarkWidgetConfiguration, in context: Context) async -> BookmarkEntry {
        BookmarkEntry(date: .now, items: loadItems(configuration), mode: configuration.displayMode)
    }
    func timeline(for configuration: BookmarkWidgetConfiguration, in context: Context) async -> Timeline<BookmarkEntry> {
        Timeline(entries: [BookmarkEntry(date: .now, items: loadItems(configuration), mode: configuration.displayMode)], policy: .after(Date().addingTimeInterval(900)))
    }
    private func loadItems(_ config: BookmarkWidgetConfiguration) -> [WidgetBookmark] {
        var items = WidgetDataSource.loadBookmarks()
        switch config.displayMode {
        case .recent: items.sort { $0.created > $1.created }
        case .favorites: items = items.filter { $0.isFavorite }
        case .random: items.shuffle()
        }
        return items
    }
}

// MARK: - Widget

struct BookmarkWidget: Widget {
    var body: some WidgetConfiguration {
        if #available(iOS 17.0, *) {
            return AppIntentConfiguration(kind: "BookmarkWidget", intent: BookmarkWidgetConfiguration.self, provider: BookmarkProvider()) { entry in
                BookmarkWidgetView(entry: entry)
            }
            .configurationDisplayName("Bookmarks")
            .description("Quick access to your bookmarks")
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        } else {
            return StaticConfiguration(kind: "BookmarkWidgetLegacy", provider: LegacyProvider()) { entry in
                LegacyWidgetView(entry: entry)
            }.supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        }
    }
}

// MARK: - Views

struct BookmarkWidgetView: View { // iOS 17+
    @Environment(\.widgetFamily) var family
    let entry: BookmarkEntry
    var body: some View {
        switch family {
        case .systemSmall: SmallWidget(items: entry.items)
        case .systemMedium: MediumWidget(items: Array(entry.items.prefix(4)))
        default: LargeWidget(items: Array(entry.items.prefix(8)))
        }
    }
}

struct SmallWidget: View {
    let items: [WidgetBookmark]
    var body: some View {
        VStack(alignment: .leading) {
            Text("Bookmarks").font(.headline)
            Text("\(items.count)").font(.largeTitle).bold()
            if #available(iOS 17.0, *) {
                Button(intent: QuickAddIntent()) { Label("Add", systemImage: "plus.circle.fill") }
            }
        }
        .padding()
    }
}

struct MediumWidget: View {
    let items: [WidgetBookmark]
    var body: some View {
        VStack(alignment: .leading) {
            HStack { Text("Recent").font(.headline); Spacer(); if #available(iOS 17.0, *) { Button(intent: QuickAddIntent()) { Image(systemName: "plus") } } }
            ForEach(items.prefix(4)) { b in RowLink(bookmark: b) }
        }.padding(8)
    }
}

struct LargeWidget: View {
    let items: [WidgetBookmark]
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Discover").font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                ForEach(items.prefix(8)) { b in RowLink(bookmark: b) }
            }
        }.padding(8)
    }
}

struct RowLink: View {
    let bookmark: WidgetBookmark
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: bookmark.isFavorite ? "star.fill" : "bookmark")
                .foregroundColor(bookmark.isFavorite ? .yellow : .accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text(bookmark.title).lineLimit(1)
                Text(bookmark.domain).font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            if #available(iOS 17.0, *) { Button(intent: ToggleFavoriteIntent(url: bookmark.url)) { Image(systemName: "star") } }
        }
    }
}

// MARK: - Actions

struct ToggleFavoriteIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Favorite"
    @Parameter(title: "URL") var url: String
    
    init() {
        self.url = ""
    }
    
    init(url: String) {
        self.url = url
    }
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            WidgetActionWriter.enqueue(["type": "toggleFavorite", "url": url])
        }
        return .result()
    }
}

struct QuickAddIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick Add"
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            WidgetActionWriter.enqueue(["type": "quickAddPrompt"])
        }
        return .result()
    }
}

// MARK: - Legacy (iOS 16-)

struct LegacyEntry: TimelineEntry { let date: Date; let items: [WidgetBookmark] }
struct LegacyProvider: TimelineProvider {
    func placeholder(in context: Context) -> LegacyEntry { LegacyEntry(date: .now, items: WidgetDataSource.placeholder()) }
    func getSnapshot(in context: Context, completion: @escaping (LegacyEntry) -> ()) { completion(LegacyEntry(date: .now, items: WidgetDataSource.loadBookmarks())) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<LegacyEntry>) -> ()) { completion(Timeline(entries: [LegacyEntry(date: .now, items: WidgetDataSource.loadBookmarks())], policy: .after(Date().addingTimeInterval(900)))) }
}

struct LegacyWidgetView: View { let entry: LegacyEntry; var body: some View { MediumWidget(items: Array(entry.items.prefix(4))) } }

// MARK: - Lock Screen Widget

@available(iOS 16.0, *)
struct BookmarkLockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "BookmarkLock", provider: LegacyProvider()) { entry in
            ZStack { Text("\(entry.items.count)").font(.headline) }
        }
        .supportedFamilies([.accessoryCircular, .accessoryInline])
    }
}

#endif


