//
//  BookmarkNoteLinkService.swift
//  CalendarNotes
//

import Foundation
import CoreData

@MainActor
final class BookmarkNoteLinkService {
    static let shared = BookmarkNoteLinkService()
    private init() {}

    private let core = CoreDataManager.shared
    private let linkService = BookmarkLinkService.shared

    func createNote(from bookmark: Bookmark, template: String? = nil) throws -> Note {
        let title = bookmark.title ?? (URL(string: bookmark.url ?? "")?.host ?? "Bookmark")
        let url = bookmark.url ?? ""
        let excerpt = bookmark.bookmarkDescription ?? ""
        var content = "# \(title)\n\n[\(url)](\(url))\n\n"
        if !excerpt.isEmpty { content += "> \(excerpt)\n\n" }
        if let template = template { content += template }
        let note = Note(context: core.viewContext, content: content, linkedDate: Date())
        try core.save()
        _ = try linkService.link(bookmark, to: note)
        return note
    }

    func link(note: Note, to bookmark: Bookmark) throws {
        // Bidirectional: store URL in note content and set bookmark.linkedNoteID if available
        let url = bookmark.url ?? ""
        if let existing = note.content, !existing.contains(url) {
            note.content = existing + "\n\n[\(url)](\(url))\n"
        }
        bookmark.linkedNoteID = bookmark.linkedNoteID ?? note.id
        _ = try linkService.link(bookmark, to: note)
        try core.save()
    }

    func notesReferencing(_ bookmark: Bookmark) -> [Note] {
        let url = bookmark.url ?? ""
        let req: NSFetchRequest<Note> = Note.fetchRequest()
        req.predicate = NSPredicate(format: "content CONTAINS[cd] %@", url)
        req.sortDescriptors = [NSSortDescriptor(key: "linkedDate", ascending: false)]
        return (try? core.viewContext.fetch(req)) ?? []
    }
}


