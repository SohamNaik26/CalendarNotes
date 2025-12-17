//
//  ContentView.swift
//  CalendarNotes
//
//  Main container view that holds all tabs
//

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Tab Enum

enum Tab {
    case calendar
    case notes
    case tasks
    case bookmarks
    case settings
}

struct ContentView: View {
    @State private var selectedTab: Tab = .calendar
    @State private var showAddSheet = false
    @State private var selectedCreateOption: CreateOption? = nil
    @State private var showingAddEvent = false
    @State private var showingAddNote = false
    @State private var showingAddTask = false
    @State private var showingAddBookmark = false
    
    // ViewModels for editors
    @StateObject private var calendarViewModel = CalendarViewModel()
    @StateObject private var tasksViewModel = TasksViewModel()
    
    private var groupedBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemGroupedBackground)
        #endif
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background color that extends to bottom
            groupedBackgroundColor
                .ignoresSafeArea(.all)
            
            // Tab content
            Group {
                switch selectedTab {
                case .calendar:
                    CalendarMainViewWrapper()
                case .notes:
                    NotesMainView()
                case .tasks:
                    TasksMainView()
                case .bookmarks:
                    BookmarksMainView()
                case .settings:
                    SettingsMainView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea(.all, edges: .top)
            
            // Custom tab bar overlay
            CustomTabBar(selectedTab: $selectedTab, showAddSheet: $showAddSheet)
        }
        .ignoresSafeArea(.keyboard) // Prevent tab bar from moving with keyboard
        .sheet(isPresented: $showAddSheet) {
            AddItemActionSheet(onSelect: { option in
                showAddSheet = false
                // Use a small delay to ensure the menu dismisses before showing the editor
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    switch option {
                    case .event:
                        showingAddEvent = true
                    case .note:
                        showingAddNote = true
                    case .task:
                        showingAddTask = true
                    case .bookmark:
                        showingAddBookmark = true
                    }
                }
            })
            .presentationCornerRadius(20)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(viewModel: calendarViewModel)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAddNote) {
            NoteEditorView(viewModel: NoteEditorViewModel(note: nil))
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAddTask) {
            EnhancedTaskEditorView(viewModel: tasksViewModel, task: nil)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAddBookmark) {
            QuickAddBookmarkSheet(initialURL: nil, initialCollectionName: nil)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Placeholder Views (to be replaced with actual implementations)

struct CalendarMainViewWrapper: View {
    var body: some View {
        CalendarMainView()
    }
}

struct NotesMainView: View {
    var body: some View {
        NotesListView()
    }
}

struct TasksMainView: View {
    var body: some View {
        TasksListView()
    }
}

struct BookmarksMainView: View {
    var body: some View {
        BookmarksGridView()
    }
}

struct SettingsMainView: View {
    var body: some View {
        GeometryReader { geometry in
            SettingsView()
                .frame(minHeight: geometry.size.height)
        }
        .ignoresSafeArea(.all, edges: [.top, .bottom])
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager.shared)
}
