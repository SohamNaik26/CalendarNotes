//
//  SharedWidgetData.swift
//  CalendarNotes
//

#if canImport(WidgetKit) && os(iOS)
import Foundation
import SwiftUI

struct WidgetBookmark: Codable, Hashable, Identifiable {
    var id: String
    var title: String
    var url: String
    var domain: String
    var isFavorite: Bool
    var created: TimeInterval
}

enum WidgetDisplayMode: String, Codable, CaseIterable, Identifiable {
    case recent
    case favorites
    case random
    var id: String { rawValue }
}

struct WidgetConfigurationModel: Codable {
    var mode: WidgetDisplayMode
    var collection: String?
}

enum WidgetShared {
    static var appGroupId: String { SharedContainer.appGroupId }
    static func containerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
    }
    static func bookmarksURL() -> URL? { containerURL()?.appendingPathComponent("widget_bookmarks.json") }
    static func actionQueueURL() -> URL? { containerURL()?.appendingPathComponent("WidgetActions", isDirectory: true) }
}

struct WidgetDataSource {
    static func loadBookmarks() -> [WidgetBookmark] {
        guard let url = WidgetShared.bookmarksURL(), let data = try? Data(contentsOf: url) else {
            return placeholder()
        }
        return (try? JSONDecoder().decode([WidgetBookmark].self, from: data)) ?? placeholder()
    }
    
    static func placeholder() -> [WidgetBookmark] {
        return [
            WidgetBookmark(id: UUID().uuidString, title: "Example Article", url: "https://example.com/a", domain: "example.com", isFavorite: false, created: Date().timeIntervalSince1970),
            WidgetBookmark(id: UUID().uuidString, title: "SwiftUI Tips", url: "https://swift.org/", domain: "swift.org", isFavorite: true, created: Date().addingTimeInterval(-3600).timeIntervalSince1970)
        ]
    }
}

// Enqueue an action for the host app to process
enum WidgetActionWriter {
    static func enqueue(_ action: [String: Any]) {
        guard let dir = WidgetShared.actionQueueURL() else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("\(UUID().uuidString).json")
        if let data = try? JSONSerialization.data(withJSONObject: action, options: []) {
            try? data.write(to: file)
        }
    }
}

#endif


