//
//  DeepLinkNotifications.swift
//  CalendarNotes
//

import Foundation
import CoreData

extension Notification.Name {
    static let deepLinkNavigateToTab = Notification.Name("DeepLinkNavigateToTab")
    static let deepLinkOpenBookmark = Notification.Name("DeepLinkOpenBookmark")
    static let deepLinkShowCollection = Notification.Name("DeepLinkShowCollection")
    static let deepLinkShowTag = Notification.Name("DeepLinkShowTag")
    static let deepLinkPerformSearch = Notification.Name("DeepLinkPerformSearch")
    static let deepLinkPrefillCollectionForNewBookmark = Notification.Name("DeepLinkPrefillCollectionForNewBookmark")
}

enum DeepLinkUserInfoKey {
    static let tabIndex = "tabIndex"
    static let bookmarkObjectID = "bookmarkObjectID"
    static let collectionID = "collectionID"
    static let collectionName = "collectionName"
    static let tagName = "tagName"
    static let searchQuery = "searchQuery"
    static let wasRandomSelection = "wasRandomSelection"
}

