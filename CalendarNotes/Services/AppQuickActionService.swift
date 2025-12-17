//
//  AppQuickActionService.swift
//  CalendarNotes
//
//  Created by Cursor AI on 09/11/25.
//

#if os(iOS)

import UIKit

@MainActor
final class AppQuickActionService {
    static let shared = AppQuickActionService()

    private init() {}

    enum ActionType: String {
        case addBookmark = "com.calendarnotes.quickaction.add"
        case pasteAndSave = "com.calendarnotes.quickaction.paste"
        case openLastBookmark = "com.calendarnotes.quickaction.openLast"
        case searchBookmarks = "com.calendarnotes.quickaction.search"
    }

    func configureInitialShortcuts() {
        updateDynamicQuickActions()
    }

    func updateDynamicQuickActions() {
        var items: [UIApplicationShortcutItem] = [
            UIApplicationShortcutItem(
                type: ActionType.addBookmark.rawValue,
                localizedTitle: "Add Bookmark",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "plus"),
                userInfo: nil
            ),
            UIApplicationShortcutItem(
                type: ActionType.pasteAndSave.rawValue,
                localizedTitle: "Paste & Save",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "doc.on.clipboard"),
                userInfo: nil
            ),
            UIApplicationShortcutItem(
                type: ActionType.searchBookmarks.rawValue,
                localizedTitle: "Search Bookmarks",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "magnifyingglass"),
                userInfo: nil
            )
        ]

        if let uriString = BookmarkPreferenceStore.lastOpenedBookmarkURI,
           let title = BookmarkPreferenceStore.lastOpenedBookmarkTitle,
           !uriString.isEmpty {
            let userInfo: [String: NSSecureCoding] = ["bookmarkURI": uriString as NSString]
            let item = UIApplicationShortcutItem(
                type: ActionType.openLastBookmark.rawValue,
                localizedTitle: "Open Last Bookmark",
                localizedSubtitle: title,
                icon: UIApplicationShortcutIcon(systemImageName: "book"),
                userInfo: userInfo
            )
            items.insert(item, at: 1)
        }

        UIApplication.shared.shortcutItems = items
    }

    func handle(_ shortcutItem: UIApplicationShortcutItem) -> Bool {
        guard let action = ActionType(rawValue: shortcutItem.type) else { return false }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            switch action {
            case .addBookmark:
                NotificationCenter.default.post(name: .quickActionAddBookmark, object: nil)
            case .pasteAndSave:
                NotificationCenter.default.post(name: .quickActionPasteAndSave, object: nil)
            case .openLastBookmark:
                var userInfo: [AnyHashable: Any] = [:]
                if let stored = shortcutItem.userInfo?["bookmarkURI"] as? String {
                    userInfo["bookmarkURI"] = stored
                }
                NotificationCenter.default.post(name: .quickActionOpenLastBookmark, object: nil, userInfo: userInfo)
            case .searchBookmarks:
                NotificationCenter.default.post(name: .quickActionSearchBookmarks, object: nil)
            }
        }
        return true
    }
}

#endif


