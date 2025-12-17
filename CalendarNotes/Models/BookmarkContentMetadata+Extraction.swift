//
//  BookmarkContentMetadata+Extraction.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation

extension BookmarkContentMetadata {
    struct ExtractionMetadata: Codable, Hashable {
        var summary: String?
        var keywords: [String]
        var lastExtractedAt: Date?
        var hasFullArticle: Bool
        var hasMedia: Bool
        var hasProductInfo: Bool

        init(summary: String? = nil, keywords: [String] = [], lastExtractedAt: Date? = nil, hasFullArticle: Bool = false, hasMedia: Bool = false, hasProductInfo: Bool = false) {
            self.summary = summary
            self.keywords = keywords
            self.lastExtractedAt = lastExtractedAt
            self.hasFullArticle = hasFullArticle
            self.hasMedia = hasMedia
            self.hasProductInfo = hasProductInfo
        }
    }

    var extraction: ExtractionMetadata? {
        get { extractionMetadataStorage }
        set { extractionMetadataStorage = newValue }
    }
}

private enum ExtractionMetadataAssociatedKeys {
    // Use a unique static byte as the association key to avoid taking an UnsafeRawPointer to a Swift String
    static var storageKey: UInt8 = 0
}

private extension BookmarkContentMetadata {
    var extractionMetadataStorage: ExtractionMetadata? {
        get {
            if let data = objc_getAssociatedObject(self, &ExtractionMetadataAssociatedKeys.storageKey) as? Data {
                return try? JSONDecoder().decode(ExtractionMetadata.self, from: data)
            }
            return nil
        }
        set {
            if let value = newValue, let data = try? JSONEncoder().encode(value) {
                objc_setAssociatedObject(self, &ExtractionMetadataAssociatedKeys.storageKey, data, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            } else {
                objc_setAssociatedObject(self, &ExtractionMetadataAssociatedKeys.storageKey, nil, .OBJC_ASSOCIATION_ASSIGN)
            }
        }
    }
}
