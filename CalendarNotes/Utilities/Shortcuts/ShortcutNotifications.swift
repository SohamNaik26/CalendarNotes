//
//  ShortcutNotifications.swift
//  CalendarNotes
//
//  Created by Cursor AI on 08/11/25.
//

import Foundation

extension Notification.Name {
    static let keyboardShortcutFocusSearch = Notification.Name("KeyboardShortcutFocusSearch")
    static let keyboardShortcutReload = Notification.Name("KeyboardShortcutReload")
    static let keyboardShortcutCloseModal = Notification.Name("KeyboardShortcutCloseModal")
    static let keyboardShortcutOpenBookmark = Notification.Name("KeyboardShortcutOpenBookmark")
    static let keyboardShortcutEditBookmark = Notification.Name("KeyboardShortcutEditBookmark")
    static let keyboardShortcutDeleteBookmark = Notification.Name("KeyboardShortcutDeleteBookmark")
    static let keyboardShortcutToggleFavorite = Notification.Name("KeyboardShortcutToggleFavorite")
    static let keyboardShortcutCopyURL = Notification.Name("KeyboardShortcutCopyURL")
    static let keyboardShortcutSelectAll = Notification.Name("KeyboardShortcutSelectAll")
    static let keyboardShortcutSwitchTab = Notification.Name("KeyboardShortcutSwitchTab")
    static let keyboardShortcutNavigateBack = Notification.Name("KeyboardShortcutNavigateBack")
    static let keyboardShortcutNavigateForward = Notification.Name("KeyboardShortcutNavigateForward")
    static let keyboardShortcutNewCollection = Notification.Name("KeyboardShortcutNewCollection")
    static let quickActionAddBookmark = Notification.Name("QuickActionAddBookmark")
    static let quickActionPasteAndSave = Notification.Name("QuickActionPasteAndSave")
    static let quickActionOpenLastBookmark = Notification.Name("QuickActionOpenLastBookmark")
    static let quickActionSearchBookmarks = Notification.Name("QuickActionSearchBookmarks")
    static let quickActionOpenBookmark = Notification.Name("QuickActionOpenBookmark")
}

enum ShortcutUserInfoKey {
    static let tabIndex = "tabIndex"
}


