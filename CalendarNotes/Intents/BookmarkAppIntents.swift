import Foundation

#if canImport(AppIntents) && os(iOS)
import AppIntents

// MARK: - Intents

public struct SaveBookmarkIntent: AppIntent {
    static var title: LocalizedStringResource = "Save bookmark"
    static var description = IntentDescription("Save a bookmark by URL.")

    @Parameter(title: "URL") var urlString: String
    @Parameter(title: "Collection", default: nil) var collection: String?

    static var parameterSummary: some ParameterSummary {
        Summary("Save \(\.$urlString) to \(\.$collection)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // SiriShortcutsFeatureFlags.isEnabled is a simple static property
        guard SiriShortcutsFeatureFlags.isEnabled else { 
            return .result(dialog: "Feature not enabled.")
        }
        // TODO: Wire to add-bookmark flow; for now, just confirm
        return .result(dialog: "Saved bookmark request received.")
    }
}

public struct OpenBookmarkIntent: AppIntent {
    static var title: LocalizedStringResource = "Open bookmark"
    static var description = IntentDescription("Open a bookmark by title.")

    @Parameter(title: "Title") var titleQuery: String

    static var parameterSummary: some ParameterSummary { Summary("Open \(\.$titleQuery)") }

    func perform() async throws -> some IntentResult {
        return .result(dialog: "Opening bookmark: \(titleQuery)")
    }
}

public struct ShowBookmarksInCollectionIntent: AppIntent {
    static var title: LocalizedStringResource = "Show bookmarks in collection"
    static var description = IntentDescription("Show bookmarks from a specific collection.")

    @Parameter(title: "Collection") var collection: String

    static var parameterSummary: some ParameterSummary { Summary("Show in \(\.$collection)") }

    func perform() async throws -> some IntentResult {
        return .result(dialog: "Showing bookmarks in \(collection)")
    }
}

struct AddBookmarkToCollectionIntent: AppIntent {
    static var title: LocalizedStringResource = "Add bookmark to collection"
    static var description = IntentDescription("Add an existing bookmark to a collection.")

    @Parameter(title: "Title or URL") var identifier: String
    @Parameter(title: "Collection") var collection: String

    static var parameterSummary: some ParameterSummary { Summary("Add \(\.$identifier) to \(\.$collection)") }

    func perform() async throws -> some IntentResult {
        return .result(dialog: "Added to \(collection)")
    }
}

struct SearchBookmarksIntent: AppIntent {
    static var title: LocalizedStringResource = "Search bookmarks"
    static var description = IntentDescription("Search bookmarks for a query.")

    @Parameter(title: "Query") var query: String
    @Parameter(title: "Limit", default: 10) var limit: Int

    static var parameterSummary: some ParameterSummary { Summary("Search \(\.$query) limit \(\.$limit)") }

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        // Return matched titles as placeholder
        let results = Array(repeating: "Bookmark", count: max(0, min(limit, 10)))
        return .result(value: results, dialog: "Found \(results.count) items")
    }
}

struct OpenRandomBookmarkIntent: AppIntent {
    static var title: LocalizedStringResource = "Open random bookmark"
    static var description = IntentDescription("Open a random bookmark.")

    func perform() async throws -> some IntentResult {
        return .result(dialog: "Opening a random bookmark")
    }
}

public struct OpenLastBookmarkIntent: AppIntent {
    static var title: LocalizedStringResource = "Open last bookmark"
    static var description = IntentDescription("Open the most recently viewed bookmark.")

    func perform() async throws -> some IntentResult {
        let title = await MainActor.run { BookmarkPreferenceStore.lastOpenedBookmarkTitle }
        guard let title = title else {
            return .result(dialog: "No recent bookmark available.")
        }
        await MainActor.run {
            NotificationCenter.default.post(name: .quickActionOpenLastBookmark, object: nil)
        }
        return .result(dialog: "Opening \(title)")
    }
}

public struct CreateReadingTaskFromBookmarkIntent: AppIntent {
    static var title: LocalizedStringResource = "Create reading task"
    static var description = IntentDescription("Create a reading task from a bookmark.")

    @Parameter(title: "Bookmark Title") var bookmarkTitle: String

    func perform() async throws -> some IntentResult {
        // Trigger the in-app automation to create a task from a bookmark title (best effort).
        await MainActor.run {
            NotificationCenter.default.post(
                name: .quickActionSearchBookmarks,
                object: nil,
                userInfo: ["presetQuery": bookmarkTitle]
            )
        }
        return .result(dialog: "Creating a reading task for \(bookmarkTitle)")
    }
}

// MARK: - Custom Shortcuts (Get-type actions)

public struct GetRecentBookmarksIntent: AppIntent {
    static var title: LocalizedStringResource = "Get recent bookmarks"
    static var description = IntentDescription("Return recent bookmarks.")

    @Parameter(title: "Limit", default: 5) var limit: Int

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let items = (0..<max(0, min(limit, 20))).map { "Recent Bookmark \($0 + 1)" }
        return .result(value: items)
    }
}

struct GetBookmarksWithTagIntent: AppIntent {
    static var title: LocalizedStringResource = "Get bookmarks with tag"
    static var description = IntentDescription("Return bookmarks for a tag.")

    @Parameter(title: "Tag") var tag: String
    @Parameter(title: "Limit", default: 10) var limit: Int

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let items = (0..<max(0, min(limit, 20))).map { "\(tag) Bookmark \($0 + 1)" }
        return .result(value: items)
    }
}

struct GetFavoriteBookmarksIntent: AppIntent {
    static var title: LocalizedStringResource = "Get favorite bookmarks"
    static var description = IntentDescription("Return favorite bookmarks.")

    @Parameter(title: "Limit", default: 10) var limit: Int

    func perform() async throws -> some IntentResult & ReturnsValue<[String]> {
        let items = (0..<max(0, min(limit, 20))).map { "Favorite Bookmark \($0 + 1)" }
        return .result(value: items)
    }
}

public struct SaveClipboardAsBookmarkIntent: AppIntent {
    static var title: LocalizedStringResource = "Save clipboard as bookmark"
    static var description = IntentDescription("Saves the current clipboard URL as a bookmark.")

    func perform() async throws -> some IntentResult {
        return .result(dialog: "Saved clipboard link (placeholder)")
    }
}

struct OpenMostVisitedBookmarkIntent: AppIntent {
    static var title: LocalizedStringResource = "Open most visited bookmark"
    static var description = IntentDescription("Open your most visited bookmark.")

    func perform() async throws -> some IntentResult {
        return .result(dialog: "Opening most visited (placeholder)")
    }
}

// MARK: - App Shortcuts

struct BookmarkAppShortcuts: AppShortcutsProvider {
    static var shortcutTileColor: ShortcutTileColor = .blue

    static var appShortcuts: [AppShortcut] {
        guard SiriShortcutsFeatureFlags.isEnabled else { return [] }
        return [
            AppShortcut(intent: SaveClipboardAsBookmarkIntent(), phrases: [
                "Save from clipboard in \(.applicationName)"
            ], shortTitle: "Save from clipboard", systemImageName: "doc.on.clipboard"),

            AppShortcut(intent: {
                let intent = ShowBookmarksInCollectionIntent()
                // Note: Parameters are set by the system when the shortcut is invoked
                // For preview/suggestion purposes, we use the default init
                return intent
            }(), phrases: [
                "Morning reading in \(.applicationName)"
            ], shortTitle: "Morning reading", systemImageName: "sun.max"),

            AppShortcut(intent: {
                let intent = SaveBookmarkIntent()
                // Note: Parameters are set by the system when the shortcut is invoked
                return intent
            }(), phrases: [
                "Add to read later in \(.applicationName)"
            ], shortTitle: "Add to Read Later", systemImageName: "bookmark"),

            AppShortcut(intent: OpenLastBookmarkIntent(), phrases: [
                "Revisit last bookmark in \(.applicationName)",
                "Show me my recent bookmark in \(.applicationName)"
            ], shortTitle: "Revisit bookmark", systemImageName: "book"),

            AppShortcut(intent: {
                let intent = CreateReadingTaskFromBookmarkIntent()
                // Note: Parameters are set by the system when the shortcut is invoked
                return intent
            }(), phrases: [
                "Create a reading task in \(.applicationName)",
                "Remind me to read in \(.applicationName)"
            ], shortTitle: "Reading task", systemImageName: "checklist"),

            AppShortcut(intent: {
                let intent = GetRecentBookmarksIntent()
                // Note: Parameters are set by the system when the shortcut is invoked
                // The limit parameter has a default value of 5
                return intent
            }(), phrases: [
                "Recent bookmarks in \(.applicationName)",
                "What should I revisit in \(.applicationName)"
            ], shortTitle: "Recent picks", systemImageName: "clock.arrow.circlepath")
        ]
    }
}

#endif


