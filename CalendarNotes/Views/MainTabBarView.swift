//
//  MainTabBarView.swift
//  CalendarNotes
//
//  Main tab bar with 5 tabs and floating action button
//  MVVM architecture with proper separation
//

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct MainTabBarView: View {
    @State private var selectedTab: TabItem = .calendar
    @State private var showAddSheet = false
    @State private var showingAddEvent = false
    @State private var showingAddNote = false
    @State private var showingAddTask = false
    @State private var showingAddBookmark = false
    
    // ViewModels for editors
    @StateObject private var calendarViewModel = CalendarViewModel()
    @StateObject private var tasksViewModel = TasksViewModel()
    
    @Environment(\.colorScheme) var colorScheme
    
    private var systemBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    enum TabItem: Int, CaseIterable {
        case calendar = 0
        case notes = 1
        case tasks = 2
        case bookmarks = 3
        case settings = 4
        
        var icon: String {
            switch self {
            case .calendar: return "calendar"
            case .notes: return "note.text"
            case .tasks: return "checkmark.circle"
            case .bookmarks: return "bookmark"
            case .settings: return "gearshape"
            }
        }
        
        var selectedIcon: String {
            switch self {
            case .calendar: return "calendar.fill"
            case .notes: return "note.text"
            case .tasks: return "checkmark.circle.fill"
            case .bookmarks: return "bookmark.fill"
            case .settings: return "gearshape.fill"
            }
        }
        
        var title: String {
            switch self {
            case .calendar: return "Calendar"
            case .notes: return "Notes"
            case .tasks: return "Tasks"
            case .bookmarks: return "Bookmarks"
            case .settings: return "Settings"
            }
        }
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                systemBackgroundColor
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Main Content
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
                    .transition(.opacity)
                    .id(selectedTab)
                    
                    // Bottom Tab Bar
                    CustomTabBarView(
                        selectedTab: Binding(
                            get: { selectedTab.rawValue },
                            set: { selectedTab = TabItem(rawValue: $0) ?? .calendar }
                        ),
                        showAddSheet: $showAddSheet,
                        safeAreaBottom: geometry.safeAreaInsets.bottom
                    )
                }
            }
        }
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
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

// MARK: - Custom Tab Bar View

struct CustomTabBarView: View {
    @Binding var selectedTab: Int
    @Binding var showAddSheet: Bool
    let safeAreaBottom: CGFloat
    @Environment(\.colorScheme) var colorScheme
    
    private var systemBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    private var accentColor: Color {
        DesignSystem.accentColor
    }
    
    private var accentColorDark: Color {
        DesignSystem.accentColorDark
    }
    
    private let tabs: [(icon: String, selectedIcon: String, title: String)] = [
        ("calendar", "calendar.fill", "Calendar"),
        ("note.text", "note.text", "Notes"),
        ("checkmark.circle", "checkmark.circle.fill", "Tasks"),
        ("bookmark", "bookmark.fill", "Bookmarks"),
        ("gearshape", "gearshape.fill", "Settings")
    ]
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab bar background
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    // Left tabs (Calendar, Notes)
                    MainTabBarButton(
                        icon: tabs[0].icon,
                        selectedIcon: tabs[0].selectedIcon,
                        title: tabs[0].title,
                        tab: 0,
                        selectedTab: $selectedTab
                    )
                    
                    MainTabBarButton(
                        icon: tabs[1].icon,
                        selectedIcon: tabs[1].selectedIcon,
                        title: tabs[1].title,
                        tab: 1,
                        selectedTab: $selectedTab
                    )
                    
                    // Spacer for center button - ensures proper spacing
                    Spacer()
                        .frame(width: 80)
                    
                    // Right tabs (Tasks, Bookmarks, Settings)
                    MainTabBarButton(
                        icon: tabs[2].icon,
                        selectedIcon: tabs[2].selectedIcon,
                        title: tabs[2].title,
                        tab: 2,
                        selectedTab: $selectedTab
                    )
                    
                    MainTabBarButton(
                        icon: tabs[3].icon,
                        selectedIcon: tabs[3].selectedIcon,
                        title: tabs[3].title,
                        tab: 3,
                        selectedTab: $selectedTab
                    )
                    
                    MainTabBarButton(
                        icon: tabs[4].icon,
                        selectedIcon: tabs[4].selectedIcon,
                        title: tabs[4].title,
                        tab: 4,
                        selectedTab: $selectedTab
                    )
                }
                .frame(height: 50)
                .padding(.horizontal, 8)
                .background(DesignSystem.tabBarBlurMaterial)
                .overlay(
                    Rectangle()
                        .fill(Color.black.opacity(0.05))
                        .frame(height: 0.5),
                    alignment: .top
                )
                
                // Safe area bottom spacer
                Color.clear
                    .frame(height: safeAreaBottom)
                    .background(systemBackgroundColor)
            }
            
            // Floating add button (positioned absolutely in center)
            Button(action: {
                #if os(iOS)
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                #endif
                showAddSheet = true
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: DesignSystem.floatingButtonSize, height: DesignSystem.floatingButtonSize)
                    .background(DesignSystem.accentGradient)
                    .clipShape(Circle())
                    .shadow(
                        color: DesignSystem.floatingButtonShadow.color,
                        radius: DesignSystem.floatingButtonShadow.radius,
                        y: DesignSystem.floatingButtonShadow.y
                    )
            }
            .offset(y: -(DesignSystem.floatingButtonSize / 2) - 4) // Half button height + spacing
        }
        .frame(height: DesignSystem.tabBarHeight + safeAreaBottom)
    }
}

// MARK: - Tab Button

struct MainTabBarButton: View {
    let icon: String
    let selectedIcon: String
    let title: String
    let tab: Int
    @Binding var selectedTab: Int
    
    private var accentColor: Color {
        DesignSystem.accentColor
    }
    
    var body: some View {
        Button(action: {
            #if os(iOS)
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
            #endif
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        }) {
            VStack(spacing: 4) {
                // Icon above label (24pt)
                Image(systemName: selectedTab == tab ? selectedIcon : icon)
                    .font(.system(size: 24))
                    .foregroundColor(selectedTab == tab ? accentColor : .gray)
                
                // Label below icon (10pt, medium weight)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(selectedTab == tab ? accentColor : .gray)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Note: View wrappers are defined in ContentView.swift
// MainTabBarView uses its own TabItem enum and CustomTabBarView (Int-based)
// ContentView uses Tab enum and CustomTabBar (Tab enum-based)
// The view wrappers (CalendarMainViewWrapper, NotesMainView, etc.) are shared from ContentView.swift

// MARK: - Preview

#Preview {
    MainTabBarView()
        .environmentObject(AuthManager.shared)
}

