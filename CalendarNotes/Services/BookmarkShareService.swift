//
//  BookmarkShareService.swift
//  CalendarNotes
//

import Foundation
import SwiftUI
import CoreData

final class BookmarkShareService {
    static let shared = BookmarkShareService()
    private init() {}
    
    // MARK: - Single Bookmark
    func shareItems(for bookmark: Bookmark, includeImage: Bool = true) -> [Any] {
        var items: [Any] = []
        if let urlString = bookmark.url, let url = URL(string: urlString) {
            items.append(url)
        }
        let text = [bookmark.title, bookmark.url].compactMap { $0 }.joined(separator: "\n")
        if !text.isEmpty { items.append(text) }
        #if os(iOS)
        if includeImage, let image = previewImage(for: bookmark) { items.append(image) }
        #endif
        return items
    }
    
    #if os(iOS)
    @available(iOS 16.0, *)
    func previewImage(for bookmark: Bookmark) -> UIImage? {
        let card = BookmarkShareCardView(bookmark: bookmark).frame(width: 600, height: 314)
        let renderer = ImageRenderer(content: card)
        return renderer.uiImage
    }
    #endif
    
    // MARK: - Collection Export
    func exportCollectionHTML(_ collection: Collection, context: NSManagedObjectContext) -> URL? {
        let req: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        req.predicate = NSPredicate(format: "collection == %@", collection)
        let list = (try? context.fetch(req)) ?? []
        var html = "<html><head><meta charset=\"utf-8\"><title>\(collection.name ?? "Collection")</title></head><body>"
        html += "<h1>\(collection.name ?? "Collection")</h1><ul>"
        for b in list {
            let title = (b.title ?? b.url ?? "Bookmark").replacingOccurrences(of: "\"", with: "&quot;")
            if let s = b.url { html += "<li><a href=\"\(s)\">\(title)</a></li>" }
        }
        html += "</ul></body></html>"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(collection.name ?? "Collection").html")
        try? html.data(using: .utf8)?.write(to: url)
        return url
    }
    
    func exportCollectionJSON(_ collection: Collection, context: NSManagedObjectContext) -> URL? {
        let req: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        req.predicate = NSPredicate(format: "collection == %@", collection)
        let list = (try? context.fetch(req)) ?? []
        let payload: [[String: Any]] = list.map { b in
            [
                "title": b.title ?? "",
                "url": b.url ?? "",
                "description": b.bookmarkDescription ?? "",
                "tags": b.decodedTags,
                "favorite": b.isFavorite,
                "createdDate": (b.createdDate ?? Date()).timeIntervalSince1970
            ]
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(collection.name ?? "Collection").json")
        if let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) {
            try? data.write(to: url)
            return url
        }
        return nil
    }
}

// MARK: - Share Card View (for image rendering)

struct BookmarkShareCardView: View {
    let bookmark: Bookmark
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16).fill(Color.cnSecondaryBackground)
            VStack(alignment: .leading, spacing: 12) {
                Text(bookmark.title ?? bookmark.url ?? "Untitled")
                    .font(.title3).bold()
                    .lineLimit(2)
                Text(URL(string: bookmark.url ?? "")?.absoluteString ?? "")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                Spacer()
                HStack {
                    Image(systemName: "bookmark.fill").foregroundColor(.accentColor)
                    Text("Shared from CalendarNotes").font(.caption).foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(20)
        }
        .background(Color.cnBackground)
    }
}


