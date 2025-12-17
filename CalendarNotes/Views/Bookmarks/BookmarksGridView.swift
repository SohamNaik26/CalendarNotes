//
//  BookmarksGridView.swift
//  CalendarNotes
//
//  Bookmarks grid view
//

import SwiftUI
import CoreData

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct BookmarksGridView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Bookmark.createdDate, ascending: false)],
        animation: .default
    ) private var bookmarks: FetchedResults<Bookmark>
    
    @State private var searchText = ""
    
    var filteredBookmarks: [Bookmark] {
        if searchText.isEmpty {
            return Array(bookmarks)
        }
        return bookmarks.filter { bookmark in
            (bookmark.title?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (bookmark.url?.localizedCaseInsensitiveContains(searchText) ?? false) ||
            (bookmark.tags?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
    }
    
    private var groupedBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemGroupedBackground)
        #endif
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // "Bookmarks" title (34pt, bold) - improved spacing
            Text("Bookmarks")
                .font(.system(size: 34, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)
            
            // Search bar: "Search bookmarks..." placeholder - fixed placeholder
            SearchBar(text: $searchText, placeholder: "Search bookmarks...")
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 4)
            
            // Empty state or bookmarks list
            if filteredBookmarks.isEmpty {
                EmptyStateView(
                    icon: "bookmark",
                    message: "No Bookmarks"
                )
                .padding(.top, 60)
            } else {
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredBookmarks, id: \.objectID) { bookmark in
                            BookmarkCard(bookmark: bookmark)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 120)
                }
            }
        }
        .background(groupedBackgroundColor)
        .ignoresSafeArea(.all, edges: [.top, .bottom])
    }
}

// MARK: - Bookmark Card Component

struct BookmarkCard: View {
    let bookmark: Bookmark
    
    // Gradient colors based on bookmark type/URL
    private var gradientColors: [Color] {
        let hash = bookmark.objectID.hashValue
        switch hash % 4 {
        case 0:
            return [Color(red: 0.67, green: 0.49, blue: 0.92), Color(red: 0.95, green: 0.38, blue: 0.75)] // Purple to pink
        case 1:
            return [Color(red: 0.26, green: 0.56, blue: 0.96), Color(red: 0.26, green: 0.56, blue: 0.96)] // Blue
        case 2:
            return [Color(red: 0.20, green: 0.70, blue: 0.40), Color(red: 0.20, green: 0.70, blue: 0.40)] // Green
        default:
            return [Color(red: 1.0, green: 0.45, blue: 0.20), Color(red: 0.95, green: 0.20, blue: 0.20)] // Orange to red
        }
    }
    
    private var iconName: String {
        if let url = bookmark.url {
            if url.contains("claude.ai") {
                return "sparkles"
            } else if url.contains("github.com") {
                return "chevron.left.slash.chevron.right"
            } else if url.contains("mozilla.org") || url.contains("developer.mozilla.org") {
                return "doc.text"
            } else if url.contains("dribbble.com") {
                return "paintpalette"
            }
        }
        return "globe"
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Gradient header with icon
            ZStack {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(height: 120)
                
                Image(systemName: iconName)
                    .font(.system(size: 40, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Content Section
            VStack(alignment: .leading, spacing: 8) {
                Text(bookmark.title ?? "Untitled Bookmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let url = bookmark.url, let host = URL(string: url)?.host {
                    Text(host)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Description (if available from bookmarkDescription or notes)
                if let description = (bookmark.bookmarkDescription?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap({ $0.isEmpty ? nil : $0 })
                    ?? (bookmark.notes?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap({ $0.isEmpty ? nil : $0 }) {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    BookmarksGridView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
