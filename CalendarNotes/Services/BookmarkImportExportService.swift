//
//  BookmarkImportExportService.swift
//  CalendarNotes
//

import Foundation
import Combine
import CoreData
import UniformTypeIdentifiers

// MARK: - Options (top-level to avoid actor isolation issues)

struct ImportOptions {
    var assignToCollectionName: String?
    var preserveFoldersAsCollections: Bool = true
    var deduplicate: Bool = true
    var fetchMetadata: Bool = true
}

struct ExportOptions {
    var includeArchived: Bool = false
    var includeTags: Bool = true
    var includeMetadata: Bool = true
    var includeNotes: Bool = true
}

@MainActor
final class BookmarkImportExportService: ObservableObject {
    static let shared = BookmarkImportExportService()
    private init() {}

    private let coreData = CoreDataManager.shared
    private let smart = SmartBookmarkService.shared

    @Published var progress: Double = 0
    @Published var currentStep: String = ""
    @Published var lastErrorReport: String = ""

    // moved structs above

    // MARK: - Import

    func importData(_ data: Data, type: UTType, options: ImportOptions? = nil) async throws -> [Bookmark] {
        let opts = options ?? ImportOptions()
        lastErrorReport = ""
        currentStep = "Parsing"
        progress = 0
        let parsed = try parse(data: data, type: type)
        return try await persist(parsed: parsed, options: opts)
    }

    // MARK: - Export

    func export(type: UTType, options: ExportOptions? = nil) throws -> Data {
        let opts = options ?? ExportOptions()
        let ctx = coreData.viewContext
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        if !opts.includeArchived { request.predicate = NSPredicate(format: "isArchived == NO") }
        let items = (try? ctx.fetch(request)) ?? []
        switch type {
        case .json:
            let payload = items.map { self.jsonObject(for: $0, options: opts) }
            return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted])
        case .commaSeparatedText:
            let header = "title,url,tags,collection,notes\n"
            let rows = items.map { self.csvRow(for: $0, options: opts) }.joined()
            return Data((header + rows).utf8)
        case .plainText: // Markdown
            let body = items.map { self.markdownRow(for: $0, options: opts) }.joined(separator: "\n\n")
            return Data(body.utf8)
        default:
            // HTML
            let html = htmlDocument(for: items, options: opts)
            return Data(html.utf8)
        }
    }

    // MARK: - Parsing

    func parse(data: Data, type: UTType) throws -> [(title: String, url: String, folder: String?, tags: [String], notes: String?)] {
        if type == .json { return try parseJSON(data) }
        if type == .commaSeparatedText { return try parseCSV(data) }
        // Treat as HTML (Safari/Generic)
        return parseHTML(data)
    }

    private func parseJSON(_ data: Data) throws -> [(String, String, String?, [String], String?)] {
        // Support Chrome/Firefox/Pocket generic JSON arrays {title,url,tags,folder,notes}
        if let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return arr.compactMap { d in
                guard let url = d["url"] as? String else { return nil }
                let title = (d["title"] as? String) ?? url
                let folder = d["folder"] as? String
                let tags = d["tags"] as? [String] ?? []
                let notes = d["notes"] as? String
                return (title, url, folder, tags, notes)
            }
        }
        // Chrome export structure
        struct Node: Decodable { let name: String; let type: String?; let url: String?; let children: [Node]? }
        struct Root: Decodable { let roots: [String: Node] }
        if let root = try? JSONDecoder().decode(Root.self, from: data) {
            var out: [(String, String, String?, [String], String?)] = []
            func walk(_ node: Node, folder: String?) {
                if let url = node.url { out.append((node.name, url, folder, [], nil)); return }
                node.children?.forEach { walk($0, folder: node.name) }
            }
            for (_, node) in root.roots { walk(node, folder: nil) }
            return out
        }
        return []
    }

    private func parseCSV(_ data: Data) throws -> [(String, String, String?, [String], String?)] {
        guard let text = String(data: data, encoding: .utf8) else { return [] }
        let lines = text.split(whereSeparator: { $0 == "\n" || $0 == "\r" })
        guard lines.count > 1 else { return [] }
        let rows = lines.dropFirst()
        return rows.compactMap { line in
            let cols = line.split(separator: ",", omittingEmptySubsequences: false).map { String($0) }
            guard cols.count >= 2 else { return nil }
            let title = cols[0]
            let url = cols[1]
            let tags = cols.count > 2 ? cols[2].split(separator: "|").map(String.init) : []
            let collection = cols.count > 3 ? cols[3] : nil
            let notes = cols.count > 4 ? cols[4] : nil
            return (title, url, collection, tags, notes)
        }
    }

    private func parseHTML(_ data: Data) -> [(String, String, String?, [String], String?)] {
        // Minimal parser: find <A HREF="...">Title</A> inside folders (<H3>Folder</H3>)
        guard let html = String(data: data, encoding: .utf8) else { return [] }
        var currentFolder: String? = nil
        var results: [(String, String, String?, [String], String?)] = []
        for line in html.components(separatedBy: "\n") {
            if let range = line.range(of: "<H3") ?? line.range(of: "<h3") {
                if let close = line.range(of: ">", range: range.upperBound..<line.endIndex), let end = line.range(of: "</H3>") ?? line.range(of: "</h3>") {
                    currentFolder = String(line[close.upperBound..<end.lowerBound]).trimmingCharacters(in: .whitespaces)
                }
            }
            if let hrefRange = line.range(of: "<A HREF=\"") ?? line.range(of: "<a href=\"") {
                let after = hrefRange.upperBound
                if let end = line[after...].firstIndex(of: "\"") {
                    let url = String(line[after..<end])
                    let titleStart = line[...].range(of: ">", options: .backwards, range: end..<line.endIndex)?.upperBound ?? end
                    let titleEnd = line.range(of: "</A>") ?? line.range(of: "</a>")
                    let title = titleEnd != nil ? String(line[titleStart..<(titleEnd!.lowerBound)]) : url
                    results.append((title, url, currentFolder, [], nil))
                }
            }
        }
        return results
    }

    // MARK: - Persist

    private func persist(parsed: [(String, String, String?, [String], String?)], options: ImportOptions) async throws -> [Bookmark] {
        var imported: [Bookmark] = []
        let total = max(1, parsed.count)
        let ctx = coreData.viewContext
        for (idx, item) in parsed.enumerated() {
            progress = Double(idx) / Double(total)
            currentStep = "Importing \(idx+1)/\(total)"
            let sanitizedString = URLPrivacySanitizer.sanitized(item.1)
            guard let url = URL(string: sanitizedString) else { continue }
            if options.deduplicate && smart.isDuplicate(url: url, in: ctx) { continue }
            let collectionName = options.assignToCollectionName ?? (options.preserveFoldersAsCollections ? item.2 : nil)
            let collection = collectionName.map { fetchOrCreateCollection(named: $0, in: ctx) }
            let b = Bookmark(context: ctx, url: url.absoluteString, title: item.0, bookmarkDescription: item.4, tags: item.3, collection: collection, collectionName: collection?.name)
            imported.append(b)
        }
        try ctx.save()
        if options.fetchMetadata {
            await withTaskGroup(of: Void.self) { group in
                for b in imported {
                    guard let s = b.url, let u = URL(string: s) else { continue }
                    group.addTask {
                        if let meta = try? await BookmarkService.shared.fetchMetadata(for: u) {
                            await MainActor.run {
                                b.title = b.title ?? meta.title
                                if let d = meta.description, !(d).isEmpty { b.bookmarkDescription = d }
                            }
                        }
                    }
                }
            }
            try ctx.save()
        }
        progress = 1
        currentStep = "Done"
        return imported
    }

    private func fetchOrCreateCollection(named name: String, in ctx: NSManagedObjectContext) -> Collection {
        let req: NSFetchRequest<Collection> = Collection.fetchRequest()
        req.predicate = NSPredicate(format: "name == %@", name)
        if let c = try? ctx.fetch(req).first { return c }
        return Collection(context: ctx, name: name)
    }

    // MARK: - Export helpers

    private func jsonObject(for b: Bookmark, options: ExportOptions) -> [String: Any] {
        var obj: [String: Any] = [
            "title": b.title ?? (URL(string: b.url ?? "")?.host ?? "Untitled"),
            "url": b.url ?? "",
            "collection": b.collectionName ?? ""
        ]
        if options.includeTags { obj["tags"] = b.decodedTags }
        if options.includeNotes { obj["notes"] = b.notes ?? "" }
        if options.includeMetadata {
            obj["isArchived"] = b.isArchived
            obj["isFavorite"] = b.isFavorite
            obj["createdDate"] = b.createdDate?.timeIntervalSince1970 ?? 0
            obj["lastOpenedDate"] = b.lastOpenedDate?.timeIntervalSince1970 ?? 0
        }
        return obj
    }

    private func csvRow(for b: Bookmark, options: ExportOptions) -> String {
        let title = (b.title ?? "").replacingOccurrences(of: ",", with: " ")
        let url = (b.url ?? "")
        let tags = options.includeTags ? b.decodedTags.joined(separator: "|") : ""
        let collection = b.collectionName ?? ""
        let notes = options.includeNotes ? (b.notes ?? "").replacingOccurrences(of: ",", with: " ") : ""
        return "\(title),\(url),\(tags),\(collection),\(notes)\n"
    }

    private func markdownRow(for b: Bookmark, options: ExportOptions) -> String {
        var line = "- [\(b.title ?? (URL(string: b.url ?? "")?.host ?? "Untitled"))](\(b.url ?? ""))"
        if options.includeTags && !b.decodedTags.isEmpty { line += "  — tags: \(b.decodedTags.joined(separator: ", "))" }
        if options.includeNotes, let n = b.notes, !n.isEmpty { line += "\n  > \(n)" }
        return line
    }

    private func htmlDocument(for items: [Bookmark], options: ExportOptions) -> String {
        var body = "<DL><p>\n"
        for b in items {
            let title = b.title ?? (URL(string: b.url ?? "")?.host ?? "Untitled")
            let url = b.url ?? ""
            body += "<DT><A HREF=\"\(url)\">\(title)</A>\n"
        }
        body += "</DL>\n"
        return "<!DOCTYPE NETSCAPE-Bookmark-file-1><META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\"><TITLE>Bookmarks</TITLE><H1>Bookmarks</H1>\n" + body
    }
}


