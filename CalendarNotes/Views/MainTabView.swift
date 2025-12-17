//
//  MainTabView.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0
    @Namespace private var tabNamespace
    @Environment(\.themeManager) var themeManager
    @StateObject private var onboardingService = BookmarkOnboardingService.shared
    @State private var showingOnboarding = false
    @State private var showingAddSheet = false
    @State private var showingAddEvent = false
    @State private var showingAddNote = false
    @State private var showingAddTask = false
    @State private var showingAddBookmark = false
    
    // ViewModels for editors
    @StateObject private var calendarViewModel = CalendarViewModel()
    @StateObject private var tasksViewModel = TasksViewModel()
    
    #if os(iOS)
    @EnvironmentObject private var orientationManager: OrientationManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    
    // Modern bottom tab bar items (5 items like reference images)
    private let bottomTabItems: [TabBarItem] = [
        TabBarItem(id: 0, icon: "house.fill", title: "Home"),
        TabBarItem(id: 1, icon: "calendar", title: "Calendar", iconSelected: "calendar.fill"),
        TabBarItem(id: 2, icon: "plus.circle.fill", title: ""), // Center button
        TabBarItem(id: 3, icon: "bookmark", title: "Bookmarks", iconSelected: "bookmark.fill"),
        TabBarItem(id: 4, icon: "person.circle", title: "Profile", iconSelected: "person.circle.fill")
    ]
    
    // Internal tabs for content switching
    private let contentTabs = [
        TabItem(icon: "calendar", title: "Calendar"),
        TabItem(icon: "magnifyingglass", title: "Search"),
        TabItem(icon: "note.text", title: "Notes"),
        TabItem(icon: "checkmark.circle", title: "Tasks"),
        TabItem(icon: "bookmark", title: "Bookmarks"),
        TabItem(icon: "gear", title: "Settings")
    ]
    
    // Map bottom tab to content view
    private var currentContentView: Int {
        switch selectedTab {
        case 0: return 0 // Home -> Calendar
        case 1: return 0 // Calendar -> Calendar
        case 2: return -1 // Plus -> Show sheet
        case 3: return 4 // Bookmarks -> Bookmarks
        case 4: return 5 // Profile -> Settings
        default: return 0
        }
    }
    
    private var backgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    var body: some View {
        ZStack {
            // Background
            backgroundColor
                .ignoresSafeArea()
            
            #if os(iOS)
            // Use MainTabBarView for all iOS devices
            MainTabBarView()
            #else
            // macOS: Keep original tab bar
            VStack(spacing: 0) {
                // Content Area - Smooth view switching with transitions
                Group {
                    let contentIndex = currentContentView
                    if contentIndex == 0 {
                        CalendarView()
                            .transition(.opacity)
                    } else if contentIndex == 1 {
                        SearchView()
                            .transition(.opacity)
                    } else if contentIndex == 2 {
                        NotesView()
                            .transition(.opacity)
                    } else if contentIndex == 3 {
                        EnhancedTasksView()
                            .transition(.opacity)
                    } else if contentIndex == 4 {
                        BookmarksView()
                            .transition(.opacity)
                    } else if contentIndex == 5 {
                        SettingsView()
                            .transition(.opacity)
                    } else {
                        CalendarView()
                            .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .id(selectedTab) // Force view identity change for proper transitions
                
                AnimatedTabBar(selectedTab: $selectedTab, tabs: contentTabs)
                    .background(backgroundColor)
                    .overlay(
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 0.5),
                        alignment: .top
                    )
            }
            #endif
        }
        .accentColor(.cnPrimary)
        .background(backgroundColor)
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .withErrorHandling()
        .onAppear {
            if !onboardingService.hasCompletedOnboarding {
                onboardingService.startIfNeeded()
                showingOnboarding = true
            }
        }
        .onReceive(onboardingService.$hasCompletedOnboarding) { completed in
            if completed {
                showingOnboarding = false
            }
        }
        .sheet(isPresented: $showingOnboarding) {
            BookmarkOnboardingView(service: onboardingService)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddItemActionSheet(onSelect: { option in
                showingAddSheet = false
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
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkNavigateToTab)) { notification in
            if let target = notification.userInfo?[DeepLinkUserInfoKey.tabIndex] as? Int,
               target >= 0, target < bottomTabItems.count {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = target
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .keyboardShortcutSwitchTab)) { notification in
            if let target = notification.userInfo?[ShortcutUserInfoKey.tabIndex] as? Int,
               target >= 0, target < bottomTabItems.count {
                withAnimation(.easeInOut(duration: 0.2)) {
                    selectedTab = target
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .keyboardShortcutNavigateBack)) { _ in
            guard selectedTab > 0 else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab -= 1
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .keyboardShortcutNavigateForward)) { _ in
            guard selectedTab < bottomTabItems.count - 1 else { return }
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab += 1
            }
        }
    }
    
    private func tabIcon(for index: Int) -> String {
        switch index {
        case 0: return "calendar"
        case 1: return "magnifyingglass"
        case 2: return "note.text"
        case 3: return "checkmark.circle"
        case 4: return "gear"
        default: return "calendar"
        }
    }
    
    private func tabTitle(for index: Int) -> String {
        switch index {
        case 0: return "Calendar"
        case 1: return "Search"
        case 2: return "Notes"
        case 3: return "Tasks"
        case 4: return "Settings"
        default: return "Calendar"
        }
    }
}

#Preview {
    MainTabView()
}

// Device previews for testing responsive layouts
struct MainTabViewPreviews: PreviewProvider {
    static var previews: some View {
        Group {
            MainTabView()
                .previewDevice("iPhone SE (3rd generation)")
                .previewDisplayName("iPhone SE")
            
            MainTabView()
                .previewDevice("iPhone 15")
                .previewDisplayName("iPhone 15")
            
            MainTabView()
                .previewDevice("iPhone 15 Pro Max")
                .previewDisplayName("iPhone 15 Pro Max")
            
            MainTabView()
                .previewDevice("iPhone 17 Pro Max")
                .previewDisplayName("iPhone 17 Pro Max")
            
            MainTabView()
                .previewDevice("iPad Pro (11-inch)")
                .previewDisplayName("iPad Pro 11\"")
            
            MainTabView()
                .previewDevice("iPad Pro (12.9-inch)")
                .previewDisplayName("iPad Pro 12.9\"")
        }
    }
}

