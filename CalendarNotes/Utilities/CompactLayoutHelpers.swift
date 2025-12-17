//
//  CompactLayoutHelpers.swift
//  CalendarNotes
//
//  Helper utilities for optimizing layouts on small screens
//

import SwiftUI

// MARK: - Toolbar Optimization Helper

struct CompactToolbarItemGroup: View {
    let items: [CompactToolbarItem]
    
    var body: some View {
        if ScreenSize.isSmallDevice {
            // Use menu on small devices
            Menu {
                ForEach(items, id: \.id) { item in
                    Button(action: item.action) {
                        Label(item.title, systemImage: item.icon)
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
        } else {
            // Show all buttons on larger devices
            HStack {
                ForEach(items, id: \.id) { item in
                    Button(action: item.action) {
                        Label(item.title, systemImage: item.icon)
                    }
                }
            }
        }
    }
}

struct CompactToolbarItem: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let action: () -> Void
}

// MARK: - Navigation Bar Display Mode Helper

extension View {
    /// Use inline navigation bar on small devices, large on larger devices
    func compactNavigationBarTitleDisplayMode() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(ScreenSize.isSmallDevice ? .inline : .large)
        #else
        self
        #endif
    }
    
    /// Force inline navigation bar for compact layouts
    func inlineNavigationBar() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }
}

// MARK: - Image Size Helper

func compactImageSize() -> CGFloat {
    if ScreenSize.isSmallDevice { return 60 }
    if ScreenSize.isMediumDevice { return 80 }
    return 100
}

// MARK: - Card Width Helper

func compactCardWidth() -> CGFloat {
    if ScreenSize.isSmallDevice {
        return ScreenSize.width * 0.75
    }
    return ScreenSize.width * 0.65
}

// MARK: - Line Limit Helper

extension View {
    func compactLineLimit() -> some View {
        self.lineLimit(ScreenSize.isSmallDevice ? 2 : 4)
            .truncationMode(.tail)
    }
}

// MARK: - Horizontal Scrollable Cards

struct HorizontalScrollableCards<Content: View>: View {
    let items: [Any]
    let content: (Any) -> Content
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(0..<items.count, id: \.self) { index in
                    content(items[index])
                        .frame(width: compactCardWidth())
                }
            }
            .padding(.horizontal)
        }
    }
}

