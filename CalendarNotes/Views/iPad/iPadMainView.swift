//
//  iPadMainView.swift
//  CalendarNotes
//
//  Created to provide desktop‑class iPad layouts with a split view experience.
//

import SwiftUI

#if os(iOS)

/// High‑level destinations for the iPad split view, mirroring the main tabs.
enum IPadSidebarDestination: Hashable, Identifiable {
    case calendar
    case search
    case notes
    case tasks
    case bookmarks
    case settings
    
    var id: Self { self }
    
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

/// Root entry point for iPad that uses a three‑column NavigationSplitView.
struct IPadMainView: View {
    @State private var selection: IPadSidebarDestination? = .calendar
    
    var body: some View {
        NavigationSplitView {
            IPadSidebarView(selection: $selection)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 300)
        } content: {
            IPadContentListView(selection: selection)
                .navigationSplitViewColumnWidth(min: 320, ideal: 380, max: 500)
        } detail: {
            IPadDetailView(selection: selection)
        }
        .navigationSplitViewStyle(.balanced)
    }
}

/// Sidebar with main sections and (future) collections/groups.
struct IPadSidebarView: View {
    @Binding var selection: IPadSidebarDestination?
    
    var body: some View {
        List(selection: $selection) {
            Section("Main") {
                sidebarRow(.calendar)
                sidebarRow(.search)
                sidebarRow(.notes)
                sidebarRow(.tasks)
                sidebarRow(.bookmarks)
            }
            
            Section("Settings") {
                sidebarRow(.settings)
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("CalendarNotes")
    }
    
    private func sidebarRow(_ destination: IPadSidebarDestination) -> some View {
        NavigationLink(value: destination) {
            Label(destination.title, systemImage: destination.systemImage)
        }
    }
}

/// Middle column list view – for now delegates to main section views that naturally show lists.
struct IPadContentListView: View {
    let selection: IPadSidebarDestination?
    
    var body: some View {
        Group {
            switch selection ?? .calendar {
            case .calendar:
                // Multi‑column calendar shell can live here later; for now show full calendar.
                CalendarView()
            case .search:
                SearchView()
            case .notes:
                NotesView()
            case .tasks:
                EnhancedTasksView()
            case .bookmarks:
                BookmarksView()
            case .settings:
                SettingsView()
            }
        }
        .navigationTitle(title(for: selection ?? .calendar))
    }
    
    private func title(for destination: IPadSidebarDestination) -> String {
        destination.title
    }
}

/// Detail column – placeholder until individual detail flows are wired.
struct IPadDetailView: View {
    let selection: IPadSidebarDestination?
    
    var body: some View {
        Group {
            switch selection ?? .calendar {
            case .calendar:
                Text("Select a day or event to see details")
                    .foregroundColor(.secondary)
            case .search:
                Text("Search results detail")
                    .foregroundColor(.secondary)
            case .notes:
                Text("Select a note to see details")
                    .foregroundColor(.secondary)
            case .tasks:
                Text("Select a task to see details")
                    .foregroundColor(.secondary)
            case .bookmarks:
                Text("Select a bookmark to preview")
                    .foregroundColor(.secondary)
            case .settings:
                Text("Settings")
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cnBackground)
    }
}

#endif


