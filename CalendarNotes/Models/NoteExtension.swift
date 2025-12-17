//
//  NoteExtension.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import Foundation
import CoreData
import Combine

extension Note {
    enum NoteKind: String, CaseIterable {
        case meeting
        case checklist
        case research
        case journal
        case idea
        case code
        case personal
        case summary
        case general
        
        var displayName: String {
            switch self {
            case .meeting: return "Meeting"
            case .checklist: return "Checklist"
            case .research: return "Research"
            case .journal: return "Journal"
            case .idea: return "Idea"
            case .code: return "Code"
            case .personal: return "Personal"
            case .summary: return "Summary"
            case .general: return "General"
            }
        }
        
        var iconName: String {
            switch self {
            case .meeting: return "person.2.fill"
            case .checklist: return "checklist"
            case .research: return "doc.text.magnifyingglass"
            case .journal: return "book.closed"
            case .idea: return "lightbulb"
            case .code: return "curlybraces"
            case .personal: return "heart"
            case .summary: return "text.book.closed"
            case .general: return "doc.text"
            }
        }
    }
    
    enum NoteSentiment: String, CaseIterable {
        case positive
        case neutral
        case negative
    }
    
    convenience init(context: NSManagedObjectContext, content: String, linkedDate: Date? = nil, tags: String? = nil) {
        self.init(context: context)
        self.id = UUID()
        self.content = content
        self.createdDate = Date()
        self.linkedDate = linkedDate
        self.tags = tags
        self.noteType = NoteKind.general.rawValue
    }
    
    var tagArray: [String] {
        get {
            guard let tags = tags else { return [] }
            return tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        set {
            tags = newValue.joined(separator: ", ")
        }
    }

    var linkedBookmarks: [Bookmark] {
        let set = (self.value(forKey: "bookmarkLinks") as? Set<BookmarkLink>) ?? []
        return set.compactMap { $0.bookmark }
    }

    var noteKind: NoteKind {
        get { NoteKind(rawValue: noteType ?? "general") ?? .general }
        set { noteType = newValue.rawValue }
    }
    
    var sentimentValue: NoteSentiment? {
        get {
            guard let raw = sentiment else { return nil }
            return NoteSentiment(rawValue: raw)
        }
        set { sentiment = newValue?.rawValue }
    }
    
    var actionItems: [String] {
        guard let data = actionItemsJSON?.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
    
    var detectedPeopleList: [String] {
        guard let detectedPeople, !detectedPeople.isEmpty else { return [] }
        return detectedPeople
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    var detectedDateStrings: [String] {
        guard let data = detectedDatesJSON?.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
    
    var detectedDates: [Date] {
        let formatter = ISO8601DateFormatter()
        return detectedDateStrings.compactMap { formatter.date(from: $0) }
    }
    
    var summaryText: String? {
        if let detectedSummary, !detectedSummary.isEmpty { return detectedSummary }
        guard let content else { return nil }
        return String(content.prefix(180))
    }
    
    var estimatedReadingMinutes: Int {
        let words = max(Int(wordCount), 0)
        return max(1, Int(round(Double(words) / 200.0)))
    }
    
    func updateActionItems(_ items: [String]) {
        actionItemsJSON = encodeStringArray(items)
    }
    
    func updateDetectedDates(_ dates: [Date]) {
        let formatter = ISO8601DateFormatter()
        let strings = dates.map { formatter.string(from: $0) }
        detectedDatesJSON = encodeStringArray(strings)
    }
    
    private func encodeStringArray(_ items: [String]) -> String? {
        guard let data = try? JSONEncoder().encode(items) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

