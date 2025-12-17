//
//  WatchBookmarkSnapshotProvider.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation
import CoreData

@MainActor
struct WatchBookmarkSnapshotProvider {
    private let coreData = CoreDataManager.shared

    func buildSnapshot(limit: Int = 10) -> WatchBookmarkSnapshot {
        let context = coreData.viewContext
        let bookmarkRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        bookmarkRequest.sortDescriptors = [
            NSSortDescriptor(key: "lastOpenedDate", ascending: false),
            NSSortDescriptor(key: "createdDate", ascending: false)
        ]
        bookmarkRequest.fetchLimit = limit

        let totalCount = (try? context.count(for: NSFetchRequest<Bookmark>(entityName: "Bookmark"))) ?? 0
        let unreadCount = countUnread(in: context)
        let favoriteCount = countFavorites(in: context)
        let topBookmarks = (try? context.fetch(bookmarkRequest))?.map { bookmark in
            WatchBookmarkSummary(
                id: bookmark.id ?? UUID(),
                title: bookmark.title ?? (bookmark.url ?? "Untitled"),
                url: bookmark.url ?? "",
                collectionName: bookmark.collectionName,
                isFavorite: bookmark.isFavorite,
                isUnread: !bookmark.isRead
            )
        } ?? []

        return WatchBookmarkSnapshot(
            totalCount: totalCount,
            unreadCount: unreadCount,
            favoriteCount: favoriteCount,
            topBookmarks: topBookmarks
        )
    }

    private func countFavorites(in context: NSManagedObjectContext) -> Int {
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        request.predicate = NSPredicate(format: "isFavorite == YES")
        return (try? context.count(for: request)) ?? 0
    }

    private func countUnread(in context: NSManagedObjectContext) -> Int {
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        request.predicate = NSPredicate(format: "isRead == NO")
        return (try? context.count(for: request)) ?? 0
    }
}


