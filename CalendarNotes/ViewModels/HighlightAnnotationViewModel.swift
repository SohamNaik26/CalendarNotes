//
//  HighlightAnnotationViewModel.swift
//  CalendarNotes
//
//  ViewModel for managing highlights and annotations
//

import Foundation
import SwiftUI
import CoreData
import Combine

@MainActor
final class HighlightAnnotationViewModel: ObservableObject {
    // MARK: - Published Properties
    
    @Published var highlights: [Highlight] = []
    @Published var selectedHighlight: Highlight?
    @Published var searchText: String = ""
    @Published var filterColor: String? = nil
    @Published var filterHasNotes: Bool? = nil
    @Published var statistics: HighlightStatistics = HighlightStatistics()
    
    // MARK: - Private Properties
    
    private let context: NSManagedObjectContext
    private let coreDataManager = CoreDataManager.shared
    private var bookmark: Bookmark?
    
    // MARK: - Statistics
    
    struct HighlightStatistics {
        var totalHighlights: Int = 0
        var highlightsByColor: [String: Int] = [:]
        var highlightsWithNotes: Int = 0
        var mostHighlightedText: String? = nil
        var mostHighlightedCount: Int = 0
    }
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext, bookmark: Bookmark? = nil) {
        self.context = context
        self.bookmark = bookmark
        loadHighlights()
    }
    
    // MARK: - Public Methods
    
    func loadHighlights() {
        let request: NSFetchRequest<Highlight> = Highlight.fetchRequest()
        
        var predicates: [NSPredicate] = []
        
        if let bookmark = bookmark {
            predicates.append(NSPredicate(format: "bookmark == %@", bookmark))
        }
        
        if !searchText.isEmpty {
            let textPredicate = NSPredicate(format: "selectedText CONTAINS[cd] %@ OR note CONTAINS[cd] %@", searchText, searchText)
            predicates.append(textPredicate)
        }
        
        if let color = filterColor {
            predicates.append(NSPredicate(format: "color == %@", color))
        }
        
        if let hasNotes = filterHasNotes {
            if hasNotes {
                predicates.append(NSPredicate(format: "note != nil AND note != ''"))
            } else {
                predicates.append(NSPredicate(format: "note == nil OR note == ''"))
            }
        }
        
        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }
        
        request.sortDescriptors = [
            NSSortDescriptor(key: "createdDate", ascending: false)
        ]
        
        highlights = (try? context.fetch(request)) ?? []
        updateStatistics()
    }
    
    func createHighlight(
        bookmark: Bookmark,
        selectedText: String,
        color: String = HighlightColor.yellow.rawValue,
        rangeStart: Int32 = 0,
        rangeEnd: Int32 = 0,
        xpath: String? = nil,
        offset: Int32 = 0
    ) throws -> Highlight {
        let highlight = Highlight(
            context: context,
            bookmark: bookmark,
            selectedText: selectedText,
            color: color,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            xpath: xpath,
            offset: offset
        )
        
        try coreDataManager.save()
        loadHighlights()
        return highlight
    }
    
    func updateHighlight(_ highlight: Highlight, note: String?, color: String? = nil) throws {
        if let note = note {
            highlight.note = note.isEmpty ? nil : note
        }
        if let color = color {
            highlight.color = color
        }
        // Update lastModifiedDate if property exists
        if highlight.responds(to: Selector(("setLastModifiedDate:"))) {
            highlight.setValue(Date(), forKey: "lastModifiedDate")
        }
        
        try coreDataManager.save()
        loadHighlights()
    }
    
    func deleteHighlight(_ highlight: Highlight) throws {
        context.delete(highlight)
        try coreDataManager.save()
        loadHighlights()
    }
    
    func deleteHighlights(_ highlights: [Highlight]) throws {
        for highlight in highlights {
            context.delete(highlight)
        }
        try coreDataManager.save()
        loadHighlights()
    }
    
    func exportHighlightsToNote(bookmark: Bookmark) throws -> String {
        let request: NSFetchRequest<Highlight> = Highlight.fetchRequest()
        request.predicate = NSPredicate(format: "bookmark == %@", bookmark)
        request.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: true)]
        
        let bookmarkHighlights = (try? context.fetch(request)) ?? []
        
        var noteContent = "# Highlights from: \(bookmark.title ?? "Bookmark")\n\n"
        noteContent += "URL: \(bookmark.url ?? "")\n\n"
        noteContent += "---\n\n"
        
        for (index, highlight) in bookmarkHighlights.enumerated() {
            noteContent += "## Highlight \(index + 1)\n\n"
            noteContent += "\(highlight.selectedText ?? "")\n\n"
            
            if let note = highlight.note, !note.isEmpty {
                noteContent += "**Note:** \(note)\n\n"
            }
            
            if let color = highlight.color {
                noteContent += "*Color: \(HighlightColor(rawValue: color)?.name ?? "Unknown")*\n\n"
            }
            
            noteContent += "---\n\n"
        }
        
        // Update bookmark's notes field with the exported highlights
        bookmark.notes = (bookmark.notes ?? "") + "\n\n" + noteContent
        try coreDataManager.save()
        
        return noteContent
    }
    
    func createCalendarEvent(from highlight: Highlight, title: String, date: Date) throws -> String {
        guard let bookmark = highlight.bookmark else {
            throw HighlightError.missingBookmark
        }
        
        var eventNotes = "From bookmark: \(bookmark.title ?? "")\n"
        eventNotes += "URL: \(bookmark.url ?? "")\n\n"
        eventNotes += "Highlighted text:\n\(highlight.selectedText ?? "")\n"
        
        if let note = highlight.note {
            eventNotes += "\nNote: \(note)"
        }
        
        // Link the bookmark to the calendar date
        bookmark.linkedCalendarDate = date
        try coreDataManager.save()
        
        // Return event description for external calendar integration
        return "\(title)\n\n\(eventNotes)"
    }
    
    func searchHighlights(query: String) -> [Highlight] {
        guard !query.isEmpty else { return highlights }
        
        return highlights.filter { highlight in
            (highlight.selectedText?.localizedCaseInsensitiveContains(query) ?? false) ||
            (highlight.note?.localizedCaseInsensitiveContains(query) ?? false)
        }
    }
    
    func getHighlightsByColor(color: String) -> [Highlight] {
        return highlights.filter { $0.color == color }
    }
    
    func getHighlightsWithNotes() -> [Highlight] {
        return highlights.filter { highlight in
            guard let note = highlight.note else { return false }
            return !note.isEmpty
        }
    }
    
    // MARK: - Statistics
    
    func updateStatistics() {
        let request: NSFetchRequest<Highlight> = Highlight.fetchRequest()
        if let bookmark = bookmark {
            request.predicate = NSPredicate(format: "bookmark == %@", bookmark)
        }
        
        let allHighlights = (try? context.fetch(request)) ?? []
        
        var stats = HighlightStatistics()
        stats.totalHighlights = allHighlights.count
        
        // Count by color
        var colorCounts: [String: Int] = [:]
        for highlight in allHighlights {
            let color = highlight.color ?? HighlightColor.yellow.rawValue
            colorCounts[color, default: 0] += 1
        }
        stats.highlightsByColor = colorCounts
        
        // Count with notes
        stats.highlightsWithNotes = allHighlights.filter { highlight in
            guard let note = highlight.note else { return false }
            return !note.isEmpty
        }.count
        
        // Most highlighted text
        var textCounts: [String: Int] = [:]
        for highlight in allHighlights {
            if let text = highlight.selectedText {
                let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !normalized.isEmpty {
                    textCounts[normalized, default: 0] += 1
                }
            }
        }
        
        if let (mostText, count) = textCounts.max(by: { $0.value < $1.value }) {
            stats.mostHighlightedText = mostText
            stats.mostHighlightedCount = count
        }
        
        statistics = stats
    }
}

enum HighlightError: LocalizedError {
    case missingBookmark
    case invalidRange
    
    var errorDescription: String? {
        switch self {
        case .missingBookmark:
            return "Highlight must be associated with a bookmark"
        case .invalidRange:
            return "Invalid text range for highlight"
        }
    }
}

