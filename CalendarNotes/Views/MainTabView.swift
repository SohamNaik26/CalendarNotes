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
    
    private let tabs = [
        TabItem(icon: "calendar", title: "Calendar"),
        TabItem(icon: "magnifyingglass", title: "Search"),
        TabItem(icon: "note.text", title: "Notes"),
        TabItem(icon: "checkmark.circle", title: "Tasks"),
        TabItem(icon: "gear", title: "Settings")
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Content Area with Smooth Transitions
            GeometryReader { geometry in
                ZStack {
                    // Calendar View
                    if selectedTab == 0 {
                        CalendarView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .leading).combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            ))
                    }
                    
                    // Search View
                    if selectedTab == 1 {
                        SearchView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                    
                    // Notes View
                    if selectedTab == 2 {
                        NotesView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                    }
                    
                    // Tasks View
                    if selectedTab == 3 {
                        EnhancedTasksView()
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                    }
                    
                    // Settings View
                    if selectedTab == 4 {
                        SettingsView()
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.8).combined(with: .opacity),
                                removal: .scale(scale: 1.2).combined(with: .opacity)
                            ))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: selectedTab)
            }
            
            // Animated Tab Bar
            AnimatedTabBar(selectedTab: $selectedTab, tabs: tabs)
                .background(Color.cnBackground)
                .overlay(
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 0.5),
                    alignment: .top
                )
        }
        .accentColor(.cnPrimary)
        .withErrorHandling()
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

