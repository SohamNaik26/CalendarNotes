//
//  MacRootSplitView.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

#if os(macOS)
enum MacSidebarDestination: String, CaseIterable, Identifiable {
    case calendar, search, notes, tasks, bookmarks, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .calendar: return "Calendar"
        case .search: return "Search"
        case .notes: return "Notes"
        case .tasks: return "Tasks"
        case .bookmarks: return "Bookmarks"
        case .settings: return "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .calendar: return "calendar"
        case .search: return "magnifyingglass"
        case .notes: return "note.text"
        case .tasks: return "checkmark.circle"
        case .bookmarks: return "bookmark"
        case .settings: return "gearshape"
        }
    }
}

struct MacRootSplitView: View {
    @State private var selection: MacSidebarDestination = .calendar
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        NavigationSplitView(sidebar: {
            List(MacSidebarDestination.allCases, selection: $selection) { destination in
                Label(destination.title, systemImage: destination.systemImage)
                    .tag(destination)
            }
            .listStyle(.sidebar)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button {
                        toggleSidebar()
                    } label: {
                        Image(systemName: "sidebar.leading")
                    }
                    .help("Toggle Sidebar")
                }
            }
        }, detail: {
            Group {
                switch selection {
                case .calendar:
                    CalendarView()
                case .search:
                    SearchView()
                case .notes:
                    NotesView()
                case .tasks:
                    TasksView()
                case .bookmarks:
                    BookmarksView()
                case .settings:
                    SettingsView()
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .navigation) {
                    Button {
                        openWindow(id: "macBookmarksWindow")
                    } label: {
                        Label("New Window", systemImage: "plus.square.on.square")
                    }
                }
                ToolbarItemGroup(placement: .automatic) {
                    Button {
                        ShortcutActionHandler.shared.perform(.newBookmark)
                    } label: {
                        Label("New Bookmark", systemImage: "bookmark.fill")
                    }
                    Button {
                        ShortcutActionHandler.shared.perform(.focusSearch)
                    } label: {
                        Label("Search", systemImage: "magnifyingglass")
                    }
                }
            }
        })
        .navigationSplitViewStyle(.balanced)
    }

    private func toggleSidebar() {
        #if canImport(AppKit)
        NSApp.keyWindow?.firstResponder?.tryToPerform(#selector(NSSplitViewController.toggleSidebar(_:)), with: nil)
        #endif
    }
}
#endif

