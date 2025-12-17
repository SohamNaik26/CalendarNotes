//
//  BookmarkExtension.swift
//  CalendarNotes
//
//  Convenience initializers and helpers for Bookmark
//

import Foundation
import CoreData
import SwiftUI

extension Bookmark {
    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        url: String,
        title: String,
        bookmarkDescription: String? = nil,
        favicon: Data? = nil,
        previewImage: Data? = nil,
        tags: [String] = [],
        collection: Collection? = nil,
        collectionName: String? = nil,
        isFavorite: Bool = false,
        isArchived: Bool = false,
        createdDate: Date = Date(),
        lastModifiedDate: Date = Date(),
        lastOpenedDate: Date? = nil,
        openCount: Int32 = 0,
        notes: String? = nil,
        linkedCalendarDate: Date? = nil,
        linkedEventID: UUID? = nil,
        linkedNoteID: UUID? = nil,
        contentType: BookmarkContentType = .unknown,
        contentSubtype: String? = nil,
        contentMetadata: BookmarkContentMetadata? = nil,
        isWatched: Bool = false,
        videoDuration: TimeInterval? = nil,
        videoProgress: TimeInterval? = nil,
        pdfPageCount: Int32? = nil,
        pdfHasAnnotations: Bool = false,
        pdfOCRText: String? = nil,
        imageWidth: Int32? = nil,
        imageHeight: Int32? = nil,
        imageFileSize: Int64? = nil,
        recipeIngredients: [String]? = nil,
        recipeCookTimeMinutes: Int32? = nil,
        gitHubStars: Int32? = nil,
        gitHubForks: Int32? = nil,
        gitHubLanguage: String? = nil,
        gitHubLastUpdated: Date? = nil,
        productPrice: Decimal? = nil,
        productCurrency: String? = nil,
        socialPlatform: String? = nil,
        socialAuthor: String? = nil,
        isReadLater: Bool = false,
        readLaterAddedDate: Date? = nil,
        isRead: Bool = false,
        readDate: Date? = nil,
        readingPriority: ReadingPriority = .medium,
        estimatedReadingMinutes: Int32? = nil,
        readingProgress: Double? = nil,
        totalReadingTime: Double? = nil,
        lastReadingSessionDate: Date? = nil
    ) {
        self.init(context: context)
        self.id = id
        self.url = url
        self.title = title
        self.bookmarkDescription = bookmarkDescription
        self.favicon = favicon
        self.previewImage = previewImage
        self.tags = Bookmark.encodeTags(tags)
        self.collection = collection
        self.collectionName = collectionName
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.createdDate = createdDate
        self.lastModifiedDate = lastModifiedDate
        self.lastOpenedDate = lastOpenedDate
        self.openCount = openCount
        self.notes = notes
        self.linkedCalendarDate = linkedCalendarDate
        self.linkedEventID = linkedEventID
        self.linkedNoteID = linkedNoteID
        self.contentType = contentType.rawValue
        self.contentSubtype = contentSubtype
        self.contentMetadata = Bookmark.encodeMetadata(contentMetadata)
        self.setValue(isWatched, forKey: "isWatched")
        if let videoDuration { self.setValue(videoDuration, forKey: "videoDuration") }
        if let videoProgress { self.setValue(videoProgress, forKey: "videoProgress") }
        if let pdfPageCount { self.setValue(pdfPageCount, forKey: "pdfPageCount") }
        self.setValue(pdfHasAnnotations, forKey: "pdfHasAnnotations")
        self.setValue(pdfOCRText, forKey: "pdfOCRText")
        if let imageWidth { self.setValue(imageWidth, forKey: "imageWidth") }
        if let imageHeight { self.setValue(imageHeight, forKey: "imageHeight") }
        if let imageFileSize { self.setValue(imageFileSize, forKey: "imageFileSize") }
        self.recipeIngredientsJSON = Bookmark.encodeArray(recipeIngredients)
        if let recipeCookTimeMinutes { self.setValue(recipeCookTimeMinutes, forKey: "recipeCookTimeMinutes") }
        if let gitHubStars { self.setValue(gitHubStars, forKey: "gitHubStars") }
        if let gitHubForks { self.setValue(gitHubForks, forKey: "gitHubForks") }
        self.gitHubLanguage = gitHubLanguage
        self.gitHubLastUpdated = gitHubLastUpdated
        if let price = productPrice { self.setValue(NSDecimalNumber(decimal: price), forKey: "productPrice") }
        self.productCurrency = productCurrency
        self.socialPlatform = socialPlatform
        self.socialAuthor = socialAuthor
        self.setValue(isReadLater, forKey: "isReadLater")
        self.readLaterAddedDate = readLaterAddedDate
        self.setValue(isRead, forKey: "isRead")
        self.readDate = readDate
        self.readingPriorityRawValue = readingPriority.rawValue
        if let minutes = estimatedReadingMinutes { self.setValue(minutes, forKey: "estimatedReadingMinutes") }
        if let readingProgress { self.setValue(readingProgress, forKey: "readingProgress") }
        if let totalReadingTime { self.setValue(totalReadingTime, forKey: "totalReadingTime") }
        self.lastReadingSessionDate = lastReadingSessionDate
    }
}

extension Bookmark {
    static func encodeTags(_ tags: [String]) -> String? {
        guard !tags.isEmpty else { return nil }
        if let data = try? JSONSerialization.data(withJSONObject: tags, options: []) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    static func decodeTags(_ json: String?) -> [String] {
        guard let json = json, let data = json.data(using: .utf8) else { return [] }
        if let arr = try? JSONSerialization.jsonObject(with: data, options: []) as? [String] {
            return arr
        }
        return []
    }
    
    static func encodeMetadata(_ metadata: BookmarkContentMetadata?) -> Data? {
        guard let metadata else { return nil }
        return try? JSONEncoder().encode(metadata)
    }
    
    static func decodeMetadata(_ data: Data?) -> BookmarkContentMetadata? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(BookmarkContentMetadata.self, from: data)
    }
    
    static func encodeArray(_ array: [String]?) -> String? {
        guard let array, !array.isEmpty else { return nil }
        if let data = try? JSONSerialization.data(withJSONObject: array, options: []) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    static func decodeArray(_ json: String?) -> [String] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        if let arr = try? JSONSerialization.jsonObject(with: data, options: []) as? [String] {
            return arr
        }
        return []
    }
    
    var decodedTags: [String] {
        get { Bookmark.decodeTags(self.tags) }
        set { self.tags = Bookmark.encodeTags(newValue) }
    }
    
    var contentTypeValue: BookmarkContentType {
        get { BookmarkContentType(rawValue: self.contentType ?? "") ?? .unknown }
        set { self.contentType = newValue.rawValue }
    }
    
    var contentMetadataValue: BookmarkContentMetadata? {
        get { Bookmark.decodeMetadata(contentMetadata) }
        set { self.contentMetadata = Bookmark.encodeMetadata(newValue) }
    }
    
    var recipeIngredients: [String] {
        get { Bookmark.decodeArray(recipeIngredientsJSON) }
        set { recipeIngredientsJSON = Bookmark.encodeArray(newValue) }
    }
    
    var contentTypeDisplayName: String {
        switch contentTypeValue {
        case .article: return "Article"
        case .video: return "Video"
        case .pdf: return "PDF"
        case .image: return "Image"
        case .social: return "Social"
        case .product: return "Product"
        case .repository: return "Repository"
        case .recipe: return "Recipe"
        case .unknown: return "Other"
        }
    }
    
    enum ReadingPriority: String, CaseIterable {
        case low
        case medium
        case high
        
        var displayName: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }
        
        var sortIndex: Int {
            switch self {
            case .high: return 0
            case .medium: return 1
            case .low: return 2
            }
        }
    }
    
    var readingPriorityRawValue: String {
        get { (self.value(forKey: "readingPriority") as? String) ?? ReadingPriority.medium.rawValue }
        set { self.setValue(newValue, forKey: "readingPriority") }
    }
    
    var readingPriorityValue: ReadingPriority {
        get { ReadingPriority(rawValue: readingPriorityRawValue) ?? .medium }
        set { readingPriorityRawValue = newValue.rawValue }
    }
    
    var isInReadLater: Bool {
        get { (self.value(forKey: "isReadLater") as? NSNumber)?.boolValue ?? false }
        set { self.setValue(newValue, forKey: "isReadLater") }
    }
    
    var isReadValue: Bool {
        get { (self.value(forKey: "isRead") as? NSNumber)?.boolValue ?? false }
        set { self.setValue(newValue, forKey: "isRead") }
    }
    
    var estimatedReadingMinutesValue: Int {
        get { (self.value(forKey: "estimatedReadingMinutes") as? NSNumber)?.intValue ?? 0 }
        set { self.setValue(Int32(newValue), forKey: "estimatedReadingMinutes") }
    }
    
    var readingProgressValue: Double {
        get { (self.value(forKey: "readingProgress") as? NSNumber)?.doubleValue ?? 0 }
        set { self.setValue(newValue, forKey: "readingProgress") }
    }
    
    var totalReadingTimeValue: Double {
        get { (self.value(forKey: "totalReadingTime") as? NSNumber)?.doubleValue ?? 0 }
        set { self.setValue(newValue, forKey: "totalReadingTime") }
    }
    
    var linkObjects: [BookmarkLink] {
        let set = (self.value(forKey: "links") as? Set<BookmarkLink>) ?? []
        return set.sorted { ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast) }
    }
    
    var linkedEvents: [CalendarEvent] { linkObjects.compactMap { $0.event } }
    var linkedNotes: [Note] { linkObjects.compactMap { $0.note } }
    var linkedTasks: [TodoItem] { linkObjects.compactMap { $0.task } }
    
    func markAsRead(on date: Date = Date()) {
        isReadValue = true
        readDate = date
        readingProgressValue = 1.0
    }
    
    func markAsUnread() {
        isReadValue = false
        readDate = nil
        readingProgressValue = 0
    }
    
    var estimatedReadingDescription: String? {
        let minutes = estimatedReadingMinutesValue
        guard minutes > 0 else { return nil }
        if minutes < 5 { return "Quick read" }
        return "\(minutes) min read"
    }
    
    var readingProgressDisplay: String? {
        guard readingProgressValue > 0 else { return nil }
        return "\(Int(readingProgressValue * 100))%"
    }
    
    var readLaterStatusIcon: String {
        if isReadValue { return "checkmark.circle.fill" }
        return "bookmark"
    }
    
    var readLaterStatusColor: Color {
        if isReadValue { return .green }
        return .cnAccent
    }
    
    var videoDurationSeconds: TimeInterval? {
        if let stored = self.value(forKey: "videoDuration") as? NSNumber {
            return stored.doubleValue
        }
        return contentMetadataValue?.video?.duration
    }
    
    var formattedVideoDuration: String? {
        guard let duration = videoDurationSeconds else { return nil }
        return Bookmark.formatDuration(duration)
    }
    
    var pdfPageCountValue: Int? {
        if let stored = self.value(forKey: "pdfPageCount") as? NSNumber {
            return stored.intValue
        }
        return contentMetadataValue?.pdf?.pageCount
    }
    
    var pdfAllowsAnnotations: Bool {
        if let stored = self.value(forKey: "pdfHasAnnotations") as? NSNumber {
            return stored.boolValue
        }
        return contentMetadataValue?.pdf?.allowsAnnotations ?? false
    }
    
    var pdfOCRPreview: String? {
        if let text = self.value(forKey: "pdfOCRText") as? String, !text.isEmpty {
            return text
        }
        return contentMetadataValue?.pdf?.extractedTextPreview
    }
    
    var imageDimensionsDescription: String? {
        if let widthNumber = self.value(forKey: "imageWidth") as? NSNumber,
           let heightNumber = self.value(forKey: "imageHeight") as? NSNumber {
            return "\(widthNumber.intValue) × \(heightNumber.intValue)"
        }
        if let image = contentMetadataValue?.image,
           let width = image.width,
           let height = image.height {
            return "\(width) × \(height)"
        }
        return nil
    }
    
    var recipeCookTimeDescription: String? {
        if let minutesNumber = self.value(forKey: "recipeCookTimeMinutes") as? NSNumber {
            return Bookmark.formatMinutes(minutesNumber.intValue)
        }
        if let minutes = contentMetadataValue?.recipe?.cookTimeMinutes ?? contentMetadataValue?.recipe?.totalTimeMinutes {
            return Bookmark.formatMinutes(minutes)
        }
        return nil
    }
    
    var gitHubStatistics: (stars: Int?, forks: Int?, language: String?, lastUpdated: Date?) {
        let repoMeta = contentMetadataValue?.repository
        let stars = (self.value(forKey: "gitHubStars") as? NSNumber)?.intValue ?? repoMeta?.stars
        let forks = (self.value(forKey: "gitHubForks") as? NSNumber)?.intValue ?? repoMeta?.forks
        let language = (self.value(forKey: "gitHubLanguage") as? String) ?? repoMeta?.language
        let updated = (self.value(forKey: "gitHubLastUpdated") as? Date) ?? repoMeta?.lastUpdated
        return (stars, forks, language, updated)
    }
    
    var productPriceDisplay: String? {
        guard let number = self.value(forKey: "productPrice") as? NSDecimalNumber else {
            if let price = contentMetadataValue?.product?.price {
                return price.description
            }
            return nil
        }
        let currency = (self.value(forKey: "productCurrency") as? String) ?? contentMetadataValue?.product?.currencyCode
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        if let currency { formatter.currencyCode = currency }
        return formatter.string(from: number) ?? number.stringValue
    }
    
    var productCurrencyCode: String? {
        (self.value(forKey: "productCurrency") as? String) ?? contentMetadataValue?.product?.currencyCode
    }
    
    var socialPlatformName: String? {
        (self.value(forKey: "socialPlatform") as? String) ?? contentMetadataValue?.social?.platform
    }
    
    var socialAuthorHandle: String? {
        (self.value(forKey: "socialAuthor") as? String) ?? contentMetadataValue?.social?.authorHandle
    }
    
    var articleReadTimeDescription: String? {
        if let minutes = contentMetadataValue?.article?.estimatedReadTimeMinutes, minutes > 0 {
            return Bookmark.formatMinutes(minutes)
        }
        return nil
    }
}

extension Bookmark {
    static func formatDuration(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%02d:%02d", minutes, secs)
        }
    }
    
    static func formatMinutes(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let remaining = minutes % 60
        if remaining == 0 {
            return "\(hours) hr"
        }
        return "\(hours) hr \(remaining) min"
    }
}


