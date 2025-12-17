//
//  SmartBookmarkService.swift
//  CalendarNotes
//
//  Intelligent bookmark utilities: suggestions, detection, clustering, scoring.
//

import Foundation
import CoreData

final class SmartBookmarkService {
    static let shared = SmartBookmarkService()
    private init() {}

    private let coreData = CoreDataManager.shared

    // MARK: - Suggestions

    func suggestTags(title: String?, description: String?, urlString: String?) -> [String] {
        var candidates: [String] = []
        if let host = (urlString.flatMap { URL(string: $0)?.host })?.replacingOccurrences(of: "www.", with: "") {
            let parts = host.split(separator: ".").map(String.init)
            if let base = parts.dropLast().last { candidates.append(base) }
            candidates.append(contentsOf: parts.filter { $0.count > 2 })
        }
        [title, description].compactMap { $0 }
            .joined(separator: " ")
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 }
            .forEach { candidates.append($0) }
        let stop: Set<String> = ["with","from","that","this","about","into","your","their","them","have","will","been","were","http","https"]
        let freq = Dictionary(grouping: candidates) { $0 }
            .mapValues { $0.count }
            .sorted { $0.value > $1.value }
            .map { $0.key }
            .filter { !stop.contains($0) }
        return Array(Set(freq.prefix(6))).map { $0.replacingOccurrences(of: "-", with: " ") }
    }

    // MARK: - Duplicate detection

    func isDuplicate(url: URL, in context: NSManagedObjectContext? = nil) -> Bool {
        let ctx = context ?? coreData.viewContext
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        request.predicate = NSPredicate(format: "url == %@", url.absoluteString)
        let count = (try? ctx.count(for: request)) ?? 0
        return count > 0
    }

    // MARK: - Related bookmarks

    func relatedBookmarks(for bookmark: Bookmark, limit: Int = 10) -> [Bookmark] {
        let ctx = coreData.viewContext
        let domain = URL(string: bookmark.url ?? "")?.host ?? ""
        let tags = Set(bookmark.decodedTags)
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        request.fetchLimit = 100
        let all = (try? ctx.fetch(request)) ?? []
        let scored = all.filter { $0 != bookmark }.map { other -> (Bookmark, Int) in
            var score = 0
            if URL(string: other.url ?? "")?.host == domain { score += 2 }
            score += Set(other.decodedTags).intersection(tags).count
            return (other, score)
        }
        return scored.sorted { $0.1 > $1.1 }.prefix(limit).map { $0.0 }
    }

    // MARK: - Broken link detection

    func checkBrokenLink(_ url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 12
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse { return http.statusCode >= 400 }
            return false
        } catch { return true }
    }

    func checkBrokenLinks(for bookmarks: [Bookmark]) async -> [Bookmark] {
        // Avoid passing NSManagedObject across concurrency domains; use stable IDs
        let mapById: [String: Bookmark] = Dictionary(uniqueKeysWithValues: bookmarks.map { b in
            (b.objectID.uriRepresentation().absoluteString, b)
        })
        let pairs: [(id: String, url: URL)] = bookmarks.compactMap { b in
            guard let s = b.url, let u = URL(string: s) else { return nil }
            return (b.objectID.uriRepresentation().absoluteString, u)
        }
        let brokenIds: Set<String> = await withTaskGroup(of: (String, Bool).self) { group in
            for p in pairs {
                group.addTask { (p.id, await self.checkBrokenLink(p.url)) }
            }
            var bad: Set<String> = []
            for await (id, isBroken) in group where isBroken { bad.insert(id) }
            return bad
        }
        return mapById.filter { brokenIds.contains($0.key) }.map { $0.value }
    }

    // MARK: - Auto archive

    func autoArchiveOldBookmarks(olderThan days: Int, in context: NSManagedObjectContext? = nil) throws {
        let ctx = context ?? coreData.viewContext
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        request.predicate = NSPredicate(format: "lastOpenedDate < %@ AND isArchived == NO", cutoff as NSDate)
        let items = (try? ctx.fetch(request)) ?? []
        for b in items { b.isArchived = true }
        try ctx.save()
    }

    // MARK: - Clustering (simple: by domain, then shared tags)

    func clusters(limitPerCluster: Int = 20) -> [[Bookmark]] {
        let ctx = coreData.viewContext
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        let all = (try? ctx.fetch(request)) ?? []
        let byDomain = Dictionary(grouping: all) { URL(string: $0.url ?? "")?.host ?? "" }
        var clusters: [[Bookmark]] = []
        for (_, group) in byDomain {
            let sorted = group.sorted { Set($0.decodedTags).count > Set($1.decodedTags).count }
            clusters.append(Array(sorted.prefix(limitPerCluster)))
        }
        return clusters
    }

    // MARK: - Reading time

    func estimatedReadingTime(text: String) -> Int { // minutes
        let words = text.split { !$0.isLetter }.count
        return max(1, Int(ceil(Double(words) / 200.0)))
    }

    // MARK: - Content type detection

    func detectContentType(for url: URL) -> String {
        let path = url.path.lowercased()
        if path.hasSuffix(".pdf") { return "PDF" }
        if path.hasSuffix(".mp4") || path.hasSuffix(".mov") { return "Video" }
        if path.hasSuffix(".mp3") || path.hasSuffix(".wav") { return "Audio" }
        return "Web Article"
    }

    // MARK: - Priority scoring

    func priorityScore(for b: Bookmark) -> Double {
        let favoriteBoost = b.isFavorite ? 2.0 : 0.0
        let opens = Double(b.openCount)
        let recencyDays = b.lastOpenedDate.map { max(1.0, Date().timeIntervalSince($0) / 86400.0) } ?? 365.0
        return favoriteBoost + (opens / 5.0) + (1.0 / recencyDays)
    }

    // MARK: - Smart search (basic natural language terms -> predicate)

    func smartSearch(query: String) -> NSPredicate? {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        var subpredicates: [NSPredicate] = []
        let lower = trimmed.lowercased()
        if lower.contains("favorite") || lower.contains("starred") {
            subpredicates.append(NSPredicate(format: "isFavorite == YES"))
        }
        if lower.contains("archived") {
            subpredicates.append(NSPredicate(format: "isArchived == YES"))
        }
        // Extract tags in quotes: tag:"swift"
        let parts = trimmed.components(separatedBy: " ")
        for p in parts where p.contains(":") {
            let kv = p.split(separator: ":", maxSplits: 1).map(String.init)
            if kv.count == 2 && kv[0].lowercased() == "tag" {
                subpredicates.append(NSPredicate(format: "tags CONTAINS[cd] %@", kv[1].replacingOccurrences(of: "\"", with: "")))
            }
        }
        // Fallback text search
        subpredicates.append(NSPredicate(format: "title CONTAINS[cd] %@ OR bookmarkDescription CONTAINS[cd] %@ OR url CONTAINS[cd] %@", trimmed, trimmed, trimmed))
        return NSCompoundPredicate(andPredicateWithSubpredicates: subpredicates)
    }

    // MARK: - Trending

    func trendingThisWeek(limit: Int = 10) -> [Bookmark] {
        let ctx = coreData.viewContext
        let cutoff = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        request.predicate = NSPredicate(format: "lastOpenedDate >= %@", cutoff as NSDate)
        let items = (try? ctx.fetch(request)) ?? []
        return items.sorted { $0.openCount > $1.openCount }.prefix(limit).map { $0 }
    }

    // MARK: - Batch rules

    func archiveOlderThan(_ days: Int) throws { try autoArchiveOldBookmarks(olderThan: days) }

    func autoTagByDomain() throws {
        let ctx = coreData.viewContext
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        let items = (try? ctx.fetch(request)) ?? []
        for b in items {
            if let host = URL(string: b.url ?? "")?.host?.replacingOccurrences(of: "www.", with: ""), !host.isEmpty {
                var tags = Set(b.decodedTags)
                let base = host.split(separator: ".").dropLast().last.map(String.init)
                if let base = base { tags.insert(base) }
                tags.insert(host)
                b.decodedTags = Array(tags)
            }
        }
        try ctx.save()
    }

    func autoOrganizeIntoCollections() throws {
        // Simple heuristic: create/use collection per domain
        let ctx = coreData.viewContext
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        let items = (try? ctx.fetch(request)) ?? []
        let byDomain = Dictionary(grouping: items) { URL(string: $0.url ?? "")?.host ?? "Misc" }
        for (domain, group) in byDomain {
            let col = fetchOrCreateCollection(named: domain, in: ctx)
            for b in group { b.collection = col; b.collectionName = col.name }
        }
        try ctx.save()
    }

    private func fetchOrCreateCollection(named name: String, in ctx: NSManagedObjectContext) -> Collection {
        let req: NSFetchRequest<Collection> = Collection.fetchRequest()
        req.predicate = NSPredicate(format: "name == %@", name)
        if let c = try? ctx.fetch(req).first { return c }
        let c = Collection(context: ctx, name: name)
        return c
    }

    // MARK: - Bulk metadata refresh

    func refreshAllMetadata() async {
        let ctx = coreData.viewContext
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        let items = (try? ctx.fetch(request)) ?? []
        await withTaskGroup(of: Void.self) { group in
            for b in items {
                guard let s = b.url, let u = URL(string: s) else { continue }
                group.addTask {
                    if let meta = try? await BookmarkService.shared.fetchMetadata(for: u) {
                        await MainActor.run {
                            try? self.coreData.update(b) { bk in
                                if let t = meta.title, !t.isEmpty { bk.title = t }
                                if let d = meta.description, !d.isEmpty { bk.bookmarkDescription = d }
                            }
                            try? self.coreData.save()
                        }
                    }
                }
            }
        }
    }
}


