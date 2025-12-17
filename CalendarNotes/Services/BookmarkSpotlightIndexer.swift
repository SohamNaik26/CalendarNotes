//
//  BookmarkSpotlightIndexer.swift
//  CalendarNotes
//
//  Created by Cursor AI on 09/11/25.
//

#if canImport(CoreSpotlight)

import CoreSpotlight
import UniformTypeIdentifiers
import CoreData

@MainActor
final class BookmarkSpotlightIndexer {
    static let shared = BookmarkSpotlightIndexer()

    private init() {}

    func index(_ bookmarks: [Bookmark]) {
        guard !bookmarks.isEmpty else { return }
        let items: [CSSearchableItem] = bookmarks.compactMap { bookmark in
            guard let identifier = bookmark.objectID.uriRepresentation().absoluteString as String?,
                  let urlString = bookmark.url,
                  let url = URL(string: urlString)
            else { return nil }

            let attributeSet = CSSearchableItemAttributeSet(contentType: .url)
            attributeSet.title = bookmark.title ?? bookmark.url ?? "Bookmark"
            attributeSet.contentDescription = bookmark.bookmarkDescription
            attributeSet.keywords = bookmark.decodedTags
            attributeSet.url = url
            attributeSet.relatedUniqueIdentifier = identifier

            return CSSearchableItem(
                uniqueIdentifier: identifier,
                domainIdentifier: "com.calendarnotes.bookmarks",
                attributeSet: attributeSet
            )
        }

        guard !items.isEmpty else { return }

        CSSearchableIndex.default().indexSearchableItems(items) { error in
            if let error {
                print("Spotlight index error: \(error.localizedDescription)")
            }
        }
    }

    func reindexRecentBookmarks(limit: Int = 50) {
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        request.fetchLimit = limit
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Bookmark.lastOpenedDate, ascending: false),
            NSSortDescriptor(keyPath: \Bookmark.createdDate, ascending: false)
        ]
        let bookmarks = (try? CoreDataManager.shared.viewContext.fetch(request)) ?? []
        index(bookmarks)
    }

    func remove(objectID: NSManagedObjectID) async {
        let identifier = objectID.uriRepresentation().absoluteString
        await withCheckedContinuation { continuation in
            CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: [identifier]) { _ in
                continuation.resume()
            }
        }
    }
}

#endif


