//
//  ShortcutDefinitions.swift
//  CalendarNotes
//
//  Created by Cursor AI on 08/11/25.
//

import SwiftUI
import Combine

enum ShortcutIdentifier: Hashable, Equatable {
    case newBookmark
    case focusSearch
    case switchTab(Int)
    case newCollection
    case refresh
    case openSettings
    case closeModal
    case openBookmark
    case editBookmark
    case deleteBookmark
    case toggleFavorite
    case copyURL
    case navigateBack
    case navigateForward
    case selectAll
}

extension ShortcutIdentifier {
    var defaultShortcut: KeyboardShortcut? {
        switch self {
        case .newBookmark:
            return KeyboardShortcut("n", modifiers: .command)
        case .focusSearch:
            return KeyboardShortcut("f", modifiers: .command)
        case .switchTab(let index):
            guard (0...4).contains(index) else { return nil }
            let key = KeyEquivalent(Character("\(index + 1)"))
            return KeyboardShortcut(key, modifiers: .command)
        case .newCollection:
            return KeyboardShortcut("n", modifiers: [.command, .shift])
        case .refresh:
            return KeyboardShortcut("r", modifiers: .command)
        case .openSettings:
            return KeyboardShortcut(",", modifiers: .command)
        case .closeModal:
            return KeyboardShortcut("w", modifiers: .command)
        case .openBookmark:
            return KeyboardShortcut("o", modifiers: .command)
        case .editBookmark:
            return KeyboardShortcut("e", modifiers: .command)
        case .deleteBookmark:
            return KeyboardShortcut("d", modifiers: .command)
        case .toggleFavorite:
            return KeyboardShortcut("f", modifiers: [.command, .shift])
        case .copyURL:
            return KeyboardShortcut("c", modifiers: .command)
        case .navigateBack:
            return KeyboardShortcut(KeyEquivalent("["), modifiers: .command)
        case .navigateForward:
            return KeyboardShortcut(KeyEquivalent("]"), modifiers: .command)
        case .selectAll:
            return KeyboardShortcut("a", modifiers: .command)
        }
    }
}

final class ShortcutRegistry: ObservableObject {
    typealias ObjectWillChangePublisher = ObservableObjectPublisher
    let objectWillChange = ObservableObjectPublisher()
    
    static let shared = ShortcutRegistry()
    
    func shortcut(for identifier: ShortcutIdentifier) -> KeyboardShortcut? {
        identifier.defaultShortcut
    }
}


