//
//  ShortcutActionHandler.swift
//  CalendarNotes
//
//  Created by Cursor AI on 08/11/25.
//

import Foundation
import SwiftUI
import Combine

final class ShortcutActionHandler: ObservableObject {
    typealias ObjectWillChangePublisher = ObservableObjectPublisher
    let objectWillChange = ObservableObjectPublisher()
    
    static let shared = ShortcutActionHandler()
    
    private let notificationCenter: NotificationCenter
    private let registry: ShortcutRegistry
    
    init(notificationCenter: NotificationCenter = .default,
         registry: ShortcutRegistry = .shared) {
        self.notificationCenter = notificationCenter
        self.registry = registry
    }
    
    func perform(_ identifier: ShortcutIdentifier) {
        switch identifier {
        case .newBookmark:
            notificationCenter.post(name: .init("OpenAddBookmark"), object: nil)
        case .focusSearch:
            notificationCenter.post(name: .keyboardShortcutFocusSearch, object: nil)
        case .switchTab(let index):
            notificationCenter.post(name: .keyboardShortcutSwitchTab,
                                    object: nil,
                                    userInfo: [ShortcutUserInfoKey.tabIndex: index])
        case .newCollection:
            notificationCenter.post(name: .keyboardShortcutNewCollection, object: nil)
        case .refresh:
            notificationCenter.post(name: .keyboardShortcutReload, object: nil)
        case .openSettings:
            // Treat as navigating to settings tab (index 5)
            notificationCenter.post(name: .keyboardShortcutSwitchTab,
                                    object: nil,
                                    userInfo: [ShortcutUserInfoKey.tabIndex: 5])
        case .closeModal:
            notificationCenter.post(name: .keyboardShortcutCloseModal, object: nil)
        case .openBookmark:
            notificationCenter.post(name: .keyboardShortcutOpenBookmark, object: nil)
        case .editBookmark:
            notificationCenter.post(name: .keyboardShortcutEditBookmark, object: nil)
        case .deleteBookmark:
            notificationCenter.post(name: .keyboardShortcutDeleteBookmark, object: nil)
        case .toggleFavorite:
            notificationCenter.post(name: .keyboardShortcutToggleFavorite, object: nil)
        case .copyURL:
            notificationCenter.post(name: .keyboardShortcutCopyURL, object: nil)
        case .navigateBack:
            notificationCenter.post(name: .keyboardShortcutNavigateBack, object: nil)
        case .navigateForward:
            notificationCenter.post(name: .keyboardShortcutNavigateForward, object: nil)
        case .selectAll:
            notificationCenter.post(name: .keyboardShortcutSelectAll, object: nil)
        }
    }
    
    func shortcut(for identifier: ShortcutIdentifier) -> KeyboardShortcut? {
        registry.shortcut(for: identifier)
    }
}


