//
//  BookmarkPreferences.swift
//  CalendarNotes
//
//  Centralised helpers for reading and writing bookmark-related preferences.
//

import Foundation

enum BookmarkPreviewDownloadMode: String, CaseIterable, Sendable {
    case wifiOnly
    case always
    case never
    
    var displayName: String {
        switch self {
        case .wifiOnly: return "Wi-Fi Only"
        case .always: return "Always"
        case .never: return "Never"
        }
    }
}

enum BookmarkPreviewRetentionPolicy: RawRepresentable, CaseIterable, Sendable, Equatable, Hashable {
    typealias RawValue = Int
    
    case days(Int)
    case forever
    
    init?(rawValue: Int) {
        switch rawValue {
        case -1: self = .forever
        case 7, 30, 90: self = .days(rawValue)
        default: return nil
        }
    }
    
    var rawValue: Int {
        switch self {
        case .forever: return -1
        case .days(let value): return value
        }
    }
    
    var displayName: String {
        switch self {
        case .days(let value): return "\(value) days"
        case .forever: return "Forever"
        }
    }
    
    static var allCases: [BookmarkPreviewRetentionPolicy] {
        [.days(7), .days(30), .days(90), .forever]
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(rawValue)
    }
}

enum BookmarkOpenMode: String, CaseIterable, Sendable {
    case safari
    case inApp
    case ask
    
    var displayName: String {
        switch self {
        case .safari: return "Safari"
        case .inApp: return "In-App"
        case .ask: return "Ask Each Time"
        }
    }
}

enum BookmarkSwipeAction: String, CaseIterable, Sendable {
    case favorite
    case archive
    case delete
    case readLater
    
    var label: String {
        switch self {
        case .favorite: return "Favorite"
        case .archive: return "Archive"
        case .delete: return "Delete"
        case .readLater: return "Read Later"
        }
    }
    
    static let defaultSet: Set<BookmarkSwipeAction> = [.favorite, .archive, .readLater, .delete]
    
    static func decode(from raw: String) -> Set<BookmarkSwipeAction> {
        let parts = raw.split(separator: ",").map { String($0) }
        let values = parts.compactMap { BookmarkSwipeAction(rawValue: $0) }
        return values.isEmpty ? defaultSet : Set(values)
    }
    
    static func encodedString(from set: Set<BookmarkSwipeAction>) -> String {
        set.map(\.rawValue).sorted().joined(separator: ",")
    }
}

enum BookmarkDataFormat: String, CaseIterable, Sendable {
    case html
    case json
    case csv
    
    var displayName: String {
        rawValue.uppercased()
    }
}

struct BookmarkPreferenceStore {
    private enum Key {
        static let defaultCollection = "bookmark.defaultCollection"
        static let autoFetchMetadata = "bookmark.autoFetchMetadata"
        static let downloadMode = "bookmark.previewDownloadMode"
        static let retention = "bookmark.previewRetentionDays"
        static let defaultView = "bookmark.defaultView"
        static let gridColumns = "bookmark.gridColumns"
        static let sortOrder = "bookmark.sortOrder"
        static let openMode = "bookmark.openMode"
        static let swipeActions = "bookmark.swipeActions"
        static let duplicateDetection = "bookmark.duplicateDetection"
        static let defaultImportFormat = "bookmark.defaultImportFormat"
        static let defaultExportFormat = "bookmark.defaultExportFormat"
        static let quickImport = "bookmark.quickImportShortcut"
        static let quickExport = "bookmark.quickExportShortcut"
        static let lastOpenedBookmarkURI = "bookmark.lastOpenedBookmarkURI"
        static let lastOpenedBookmarkTitle = "bookmark.lastOpenedBookmarkTitle"
        static let requireBiometric = "bookmark.requireBiometricCollections"
        static let experimental = "bookmark.experimentalFeatures"
        static let debugMode = "bookmark.debugMode"
        static let readLaterSort = "bookmark.readLater.sort"
        static let readingFontFamily = "bookmark.reading.fontFamily"
        static let readingFontSize = "bookmark.reading.fontSize"
        static let readingLineHeight = "bookmark.reading.lineHeight"
        static let readingTheme = "bookmark.reading.theme"
        static let readingMargin = "bookmark.reading.margin"
        static let readingAlignment = "bookmark.reading.alignment"
    }
    
    private static let defaults = UserDefaults.standard
    
    static var defaultCollectionName: String? {
        get {
            guard let value = defaults.string(forKey: Key.defaultCollection), !value.isEmpty else {
                return nil
            }
            return value
        }
        set {
            defaults.setValue(newValue?.isEmpty == true ? nil : newValue, forKey: Key.defaultCollection)
        }
    }
    
    static var autoFetchMetadata: Bool {
        get { defaults.object(forKey: Key.autoFetchMetadata) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.autoFetchMetadata) }
    }
    
    static var previewDownloadMode: BookmarkPreviewDownloadMode {
        get { BookmarkPreviewDownloadMode(rawValue: defaults.string(forKey: Key.downloadMode) ?? "") ?? .wifiOnly }
        set { defaults.set(newValue.rawValue, forKey: Key.downloadMode) }
    }
    
    static var previewRetention: BookmarkPreviewRetentionPolicy {
        get {
            let raw = defaults.object(forKey: Key.retention) as? Int ?? 30
            return BookmarkPreviewRetentionPolicy(rawValue: raw) ?? .days(30)
        }
        set { defaults.set(newValue.rawValue, forKey: Key.retention) }
    }
    
    static var defaultViewMode: String {
        get { defaults.string(forKey: Key.defaultView) ?? "grid" }
        set { defaults.set(newValue, forKey: Key.defaultView) }
    }
    
    static var gridColumns: Int {
        get {
            let value = defaults.integer(forKey: Key.gridColumns)
            if value == 0 { return 3 }
            return max(2, min(value, 4))
        }
        set { defaults.set(max(2, min(newValue, 4)), forKey: Key.gridColumns) }
    }
    
    static var sortOrder: String {
        get { defaults.string(forKey: Key.sortOrder) ?? "recent" }
        set { defaults.set(newValue, forKey: Key.sortOrder) }
    }
    
    static var openMode: BookmarkOpenMode {
        get { BookmarkOpenMode(rawValue: defaults.string(forKey: Key.openMode) ?? "") ?? .ask }
        set { defaults.set(newValue.rawValue, forKey: Key.openMode) }
    }
    
    static var enabledSwipeActions: Set<BookmarkSwipeAction> {
        get {
            let raw = defaults.string(forKey: Key.swipeActions) ?? BookmarkSwipeAction.encodedString(from: BookmarkSwipeAction.defaultSet)
            return BookmarkSwipeAction.decode(from: raw)
        }
        set {
            let normalised = newValue.isEmpty ? BookmarkSwipeAction.defaultSet : newValue
            defaults.set(BookmarkSwipeAction.encodedString(from: normalised), forKey: Key.swipeActions)
        }
    }
    
    static var duplicateDetectionEnabled: Bool {
        get { defaults.object(forKey: Key.duplicateDetection) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.duplicateDetection) }
    }
    
    static var defaultImportFormat: BookmarkDataFormat {
        get { BookmarkDataFormat(rawValue: defaults.string(forKey: Key.defaultImportFormat) ?? "") ?? .html }
        set { defaults.set(newValue.rawValue, forKey: Key.defaultImportFormat) }
    }
    
    static var defaultExportFormat: BookmarkDataFormat {
        get { BookmarkDataFormat(rawValue: defaults.string(forKey: Key.defaultExportFormat) ?? "") ?? .html }
        set { defaults.set(newValue.rawValue, forKey: Key.defaultExportFormat) }
    }
    
    static var quickImportShortcut: Bool {
        get { defaults.object(forKey: Key.quickImport) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.quickImport) }
    }
    
    static var quickExportShortcut: Bool {
        get { defaults.object(forKey: Key.quickExport) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.quickExport) }
    }
    
    static var lastOpenedBookmarkURI: String? {
        get { defaults.string(forKey: Key.lastOpenedBookmarkURI) }
        set { defaults.set(newValue, forKey: Key.lastOpenedBookmarkURI) }
    }

    static var lastOpenedBookmarkTitle: String? {
        get { defaults.string(forKey: Key.lastOpenedBookmarkTitle) }
        set { defaults.set(newValue, forKey: Key.lastOpenedBookmarkTitle) }
    }

    static var requireBiometric: Bool {
        get { defaults.object(forKey: Key.requireBiometric) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.requireBiometric) }
    }
    
    static var experimentalFeatures: Bool {
        get { defaults.object(forKey: Key.experimental) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.experimental) }
    }
    
    static var debugMode: Bool {
        get { defaults.object(forKey: Key.debugMode) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Key.debugMode) }
    }
    
    static var readLaterSortOption: ReadLaterService.SortOption {
        get {
            let raw = defaults.string(forKey: Key.readLaterSort) ?? ReadLaterService.SortOption.addedDate.rawValue
            return ReadLaterService.SortOption(rawValue: raw) ?? .addedDate
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.readLaterSort)
        }
    }
    
    static var readingFontFamily: String {
        get { defaults.string(forKey: Key.readingFontFamily) ?? "Serif" }
        set { defaults.set(newValue, forKey: Key.readingFontFamily) }
    }
    
    static var readingFontSize: Double {
        get {
            let value = defaults.double(forKey: Key.readingFontSize)
            return value == 0 ? 17 : value
        }
        set { defaults.set(newValue, forKey: Key.readingFontSize) }
    }
    
    static var readingLineHeight: Double {
        get {
            let value = defaults.double(forKey: Key.readingLineHeight)
            return value == 0 ? 1.4 : value
        }
        set { defaults.set(newValue, forKey: Key.readingLineHeight) }
    }
    
    static var readingTheme: String {
        get { defaults.string(forKey: Key.readingTheme) ?? "day" }
        set { defaults.set(newValue, forKey: Key.readingTheme) }
    }
    
    static var readingMarginWidth: Double {
        get {
            let value = defaults.double(forKey: Key.readingMargin)
            return value == 0 ? 20 : value
        }
        set { defaults.set(newValue, forKey: Key.readingMargin) }
    }
    
    static var readingAlignment: String {
        get { defaults.string(forKey: Key.readingAlignment) ?? ReadingAppearanceSettings.TextAlignmentOption.leading.rawValue }
        set { defaults.set(newValue, forKey: Key.readingAlignment) }
    }
    
    static func reset() {
        [
            Key.defaultCollection,
            Key.autoFetchMetadata,
            Key.downloadMode,
            Key.retention,
            Key.defaultView,
            Key.gridColumns,
            Key.sortOrder,
            Key.openMode,
            Key.swipeActions,
            Key.duplicateDetection,
            Key.defaultImportFormat,
            Key.defaultExportFormat,
            Key.quickImport,
            Key.quickExport,
            Key.requireBiometric,
            Key.experimental,
            Key.debugMode,
            Key.readLaterSort,
            Key.readingFontFamily,
            Key.readingFontSize,
            Key.readingLineHeight,
            Key.readingTheme,
            Key.readingMargin,
            Key.readingAlignment
        ].forEach { defaults.removeObject(forKey: $0) }
    }
}


