//
//  AdaptiveNavigation.swift
//  CalendarNotes
//
//  Created for adaptive navigation system
//

import SwiftUI

struct AdaptiveNavigationView<Sidebar: View, Content: View>: View {
    let sidebar: () -> Sidebar
    let content: () -> Content
    
    var body: some View {
        if ScreenSize.isPad {
            NavigationSplitView {
                sidebar()
            } detail: {
                content()
            }
        } else {
            NavigationStack {
                content()
            }
        }
    }
}

// Convenience wrapper for views that don't need a sidebar
struct AdaptiveNavigationStack<Content: View>: View {
    let content: () -> Content
    
    var body: some View {
        if ScreenSize.isPad {
            NavigationSplitView {
                // Empty sidebar for iPad - can be customized
                Text("Menu")
                    .navigationTitle("Calendar Notes")
            } detail: {
                content()
            }
        } else {
            NavigationStack {
                content()
            }
        }
    }
}

