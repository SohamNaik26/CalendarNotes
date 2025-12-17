//
//  BookmarkWatchView.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import SwiftUI

struct BookmarkWatchView: View {
    let snapshot: WatchBookmarkSnapshot
    let onOpen: (WatchBookmarkSummary) -> Void
    let onToggleRead: (WatchBookmarkSummary) -> Void
    let onToggleFavorite: (WatchBookmarkSummary) -> Void
    let onQuickAdd: () -> Void

    var body: some View {
        List {
            Section(header: Text("Summary")) {
                HStack {
                    Label("All", systemImage: "bookmark.fill")
                    Spacer()
                    Text("\(snapshot.totalCount)")
                }
                HStack {
                    Label("Unread", systemImage: "book")
                    Spacer()
                    Text("\(snapshot.unreadCount)")
                }
                HStack {
                    Label("Favorites", systemImage: "star.fill")
                    Spacer()
                    Text("\(snapshot.favoriteCount)")
                }
                Button {
                    onQuickAdd()
                } label: {
                    Label("Quick Add", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
            }

            Section(header: Text("Recently Saved")) {
                if snapshot.topBookmarks.isEmpty {
                    Text("No bookmarks synced yet.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(snapshot.topBookmarks, id: \.id) { bookmark in
                        Button {
                            onOpen(bookmark)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(bookmark.title)
                                    .font(.headline)
                                    .lineLimit(2)
                                if let collection = bookmark.collectionName {
                                    Text(collection)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .contextMenu {
                            Button(bookmark.isUnread ? "Mark as Read" : "Mark as Unread") {
                                onToggleRead(bookmark)
                            }
                            Button(bookmark.isFavorite ? "Remove Favorite" : "Add Favorite") {
                                onToggleFavorite(bookmark)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Bookmarks")
    }
}

#Preview {
    BookmarkWatchView(
        snapshot: WatchBookmarkSnapshot(
            totalCount: 42,
            unreadCount: 7,
            favoriteCount: 5,
            topBookmarks: [
                WatchBookmarkSummary(
                    id: UUID(),
                    title: "Design Patterns in SwiftUI",
                    url: "https://example.com",
                    collectionName: "Reading",
                    isFavorite: true,
                    isUnread: true
                )
            ]
        ),
        onOpen: { _ in },
        onToggleRead: { _ in },
        onToggleFavorite: { _ in },
        onQuickAdd: {}
    )
}

