//
//  AdvancedBookmarkSearchService.swift
//  CalendarNotes
//

import Foundation
import CoreData

struct BookmarkSearchFilters {
    var collections: [String] = []
    var tags: [String] = []
    var tagModeAnd: Bool = false
    var dateSavedFrom: Date?
    var dateSavedTo: Date?
    var dateOpenedFrom: Date?
    var dateOpenedTo: Date?
    var isFavorite: Bool?
    var isArchived: Bool?
    var hasNotes: Bool?
    var domain: String?
    var contentType: String?
}

enum BookmarkSort: String { case recent, oldest, mostVisited, alphabetical }

final class AdvancedBookmarkSearchService {
    static let shared = AdvancedBookmarkSearchService()
    private init() {}
    
    private let core = CoreDataManager.shared
    private let historyKey = "bookmarkSearchHistory"
    
    // MARK: - History
    func loadHistory() -> [String] { (UserDefaults.standard.array(forKey: historyKey) as? [String]) ?? [] }
    func addHistory(_ q: String) {
        guard !q.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        var h = loadHistory().filter { $0.caseInsensitiveCompare(q) != .orderedSame }
        h.insert(q, at: 0); if h.count > 20 { h.removeLast(h.count - 20) }
        UserDefaults.standard.set(h, forKey: historyKey)
    }
    func clearHistory() { UserDefaults.standard.removeObject(forKey: historyKey) }
    
    // MARK: - Query Parsing → NSPredicate
    func predicate(for query: String, filters: BookmarkSearchFilters) -> NSPredicate {
        var sub: [NSPredicate] = []
        // Operators
        let tokens = tokenize(query)
        if !tokens.include.isEmpty {
            let wordsPreds = tokens.include.map { NSPredicate(format: "(title CONTAINS[cd] %@) OR (url CONTAINS[cd] %@) OR (bookmarkDescription CONTAINS[cd] %@) OR (notes CONTAINS[cd] %@) OR (tags CONTAINS[cd] %@)", $0, $0, $0, $0, $0) }
            sub.append(NSCompoundPredicate(andPredicateWithSubpredicates: wordsPreds))
        }
        if !tokens.phrases.isEmpty {
            for p in tokens.phrases { sub.append(NSPredicate(format: "(title CONTAINS[cd] %@) OR (bookmarkDescription CONTAINS[cd] %@)", p, p)) }
        }
        if !tokens.exclude.isEmpty {
            let ex = tokens.exclude.map { NSPredicate(format: "NOT (title CONTAINS[cd] %@ OR url CONTAINS[cd] %@ OR bookmarkDescription CONTAINS[cd] %@ OR tags CONTAINS[cd] %@)", $0, $0, $0, $0) }
            sub.append(contentsOf: ex)
        }
        if let d = tokens.domain { sub.append(NSPredicate(format: "url CONTAINS[cd] %@", d)) }
        if let c = tokens.collection { sub.append(NSPredicate(format: "collectionName == %@ OR collection.name == %@", c, c)) }
        if let before = tokens.before { sub.append(NSPredicate(format: "createdDate <= %@", before as NSDate)) }
        if let after = tokens.after { sub.append(NSPredicate(format: "createdDate >= %@", after as NSDate)) }
        if !tokens.tags.isEmpty {
            if filters.tagModeAnd {
                for t in tokens.tags { sub.append(NSPredicate(format: "tags CONTAINS[cd] %@", t)) }
            } else {
                sub.append(NSPredicate(format: "tags CONTAINS[cd] %@", tokens.tags.first!))
            }
        }
        // Filters
        if !filters.collections.isEmpty { sub.append(NSPredicate(format: "collectionName IN %@", filters.collections)) }
        if !filters.tags.isEmpty {
            if filters.tagModeAnd { for t in filters.tags { sub.append(NSPredicate(format: "tags CONTAINS[cd] %@", t)) } }
            else { sub.append(NSPredicate(format: "tags CONTAINS[cd] %@", filters.tags.first!)) }
        }
        if let f = filters.isFavorite { sub.append(NSPredicate(format: "isFavorite == %@", NSNumber(value: f))) }
        if let a = filters.isArchived { sub.append(NSPredicate(format: "isArchived == %@", NSNumber(value: a))) }
        if let n = filters.hasNotes { sub.append(n ? NSPredicate(format: "notes != nil AND notes != ''") : NSPredicate(format: "notes == nil OR notes == ''")) }
        if let dom = filters.domain, !dom.isEmpty { sub.append(NSPredicate(format: "url CONTAINS[cd] %@", dom)) }
        if let s = filters.dateSavedFrom { sub.append(NSPredicate(format: "createdDate >= %@", s as NSDate)) }
        if let s = filters.dateSavedTo { sub.append(NSPredicate(format: "createdDate <= %@", s as NSDate)) }
        if let s = filters.dateOpenedFrom { sub.append(NSPredicate(format: "lastOpenedDate >= %@", s as NSDate)) }
        if let s = filters.dateOpenedTo { sub.append(NSPredicate(format: "lastOpenedDate <= %@", s as NSDate)) }
        return sub.isEmpty ? NSPredicate(value: true) : NSCompoundPredicate(andPredicateWithSubpredicates: sub)
    }
    
    private func tokenize(_ q: String) -> (phrases:[String], include:[String], exclude:[String], tags:[String], collection:String?, domain:String?, before:Date?, after:Date?) {
        var phrases:[String] = []
        var rawTokens:[String] = []
        var buffer = ""
        var inQuotes = false
        for ch in q {
            if ch == "\"" {
                if inQuotes { phrases.append(buffer); buffer.removeAll() }
                inQuotes.toggle()
            } else if ch.isWhitespace && !inQuotes {
                if !buffer.isEmpty { rawTokens.append(buffer); buffer.removeAll() }
            } else {
                buffer.append(ch)
            }
        }
        if !buffer.isEmpty { inQuotes ? phrases.append(buffer) : rawTokens.append(buffer) }
        var include:[String]=[]; var exclude:[String]=[]; var tags:[String]=[]; var collection:String?; var domain:String?; var before:Date?; var after:Date?
        for token in rawTokens {
            if token.hasPrefix("-") { exclude.append(String(token.dropFirst())) }
            else if token.hasPrefix("tag:") { tags.append(String(token.dropFirst(4))) }
            else if token.hasPrefix("collection:") { collection = String(token.dropFirst(11)) }
            else if token.hasPrefix("domain:") { domain = String(token.dropFirst(7)) }
            else if token.hasPrefix("before:") { before = isoDate(String(token.dropFirst(7))) }
            else if token.hasPrefix("after:") { after = isoDate(String(token.dropFirst(6))) }
            else { include.append(token) }
        }
        return (phrases, include, exclude, tags, collection, domain, before, after)
    }
    private func isoDate(_ s: String) -> Date? { let f = ISO8601DateFormatter(); return f.date(from: s) }
    
    // MARK: - Execute
    func search(query: String, filters: BookmarkSearchFilters, sort: BookmarkSort) throws -> [Bookmark] {
        let req: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        req.predicate = predicate(for: query, filters: filters)
        switch sort {
        case .recent: req.sortDescriptors = [NSSortDescriptor(key: "lastOpenedDate", ascending: false), NSSortDescriptor(key: "createdDate", ascending: false)]
        case .oldest: req.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: true)]
        case .mostVisited: req.sortDescriptors = [NSSortDescriptor(key: "openCount", ascending: false)]
        case .alphabetical: req.sortDescriptors = [NSSortDescriptor(key: "title", ascending: true)]
        }
        return (try? core.viewContext.fetch(req)) ?? []
    }
}


