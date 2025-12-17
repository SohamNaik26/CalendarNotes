import Foundation
import CoreData

final class EventAnalysisService {
    static let shared = EventAnalysisService()
    private init() {}
    
    private let calendar = Calendar.current
    private let bookmarkLinks = BookmarkLinkService.shared
    private let coreData = CoreDataManager.shared
    
    struct AnalysisResult {
        let kind: CalendarEvent.EventKind
        let summary: String?
        let agenda: [String]
        let attendees: [String]
        let checklist: [String]
        let sentiment: CalendarEvent.EventSentiment?
        let recommendedBookmarkURIs: [URL]
        let recommendedNoteURIs: [URL]
        let durationMinutes: Int32
    }
    
    func analyze(event: CalendarEvent, autoSave: Bool = true) {
        guard let context = event.managedObjectContext else { return }
        context.perform {
            let result = self.performAnalysis(on: event, in: context)
            event.eventKind = result.kind
            event.detectedSummary = result.summary
            event.updateAgendaItems(result.agenda)
            event.detectedPeople = result.attendees.joined(separator: ", ")
            event.updatePreparationChecklist(result.checklist)
            event.eventSentiment = result.sentiment
            event.updateRecommendedBookmarks(result.recommendedBookmarkURIs)
            event.updateRecommendedNotes(result.recommendedNoteURIs)
            event.durationMinutes = result.durationMinutes
            event.lastAnalyzedAt = Date()
            if autoSave {
                do {
                    try context.save()
                } catch {
                    print("EventAnalysisService save error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func performAnalysis(on event: CalendarEvent, in context: NSManagedObjectContext) -> AnalysisResult {
        let title = event.title ?? ""
        let notes = event.notes ?? ""
        let combined = "\(title)\n\(notes)"
        let summary = generateSummary(from: combined)
        let agenda = extractAgendaItems(from: notes)
        let attendees = extractAttendees(from: combined)
        var checklist = extractChecklist(from: combined)
        let sentiment = estimateSentiment(from: combined)
        let recommendedBookmarks = recommendedBookmarks(for: event, title: title, context: context)
        let recommendedNotes = recommendedNotes(for: event, title: title, context: context)
        let durationMinutes = Int32(max(0, Int((event.duration / 60.0).rounded())))
        if checklist.isEmpty {
            checklist = fallbackChecklist(for: event, bookmarks: recommendedBookmarks, notes: recommendedNotes)
        }
        return AnalysisResult(
            kind: determineKind(event: event, agenda: agenda, attendees: attendees),
            summary: summary,
            agenda: agenda,
            attendees: attendees,
            checklist: checklist,
            sentiment: sentiment,
            recommendedBookmarkURIs: recommendedBookmarks,
            recommendedNoteURIs: recommendedNotes,
            durationMinutes: durationMinutes
        )
    }
    
    private func generateSummary(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let sentences = trimmed
            .components(separatedBy: CharacterSet(charactersIn: ".!?"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if sentences.isEmpty {
            return String(trimmed.prefix(160))
        }
        let primary = sentences.prefix(2).joined(separator: ". ")
        return primary.isEmpty ? String(trimmed.prefix(160)) : primary
    }
    
    private func extractAgendaItems(from notes: String) -> [String] {
        guard !notes.isEmpty else { return [] }
        return notes.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("- ") || $0.range(of: "^\\u2022", options: .regularExpression) != nil }
            .map { line in
                line.replacingOccurrences(of: "- ", with: "")
                    .replacingOccurrences(of: "\u{2022}", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
            .filter { !$0.isEmpty }
    }
    
    private func extractAttendees(from text: String) -> [String] {
        var attendees: Set<String> = []
        let keywords = ["attendees:", "participants:", "with:", "cc:"]
        for line in text.lowercased().components(separatedBy: .newlines) {
            for keyword in keywords where line.contains(keyword) {
                let names = line.replacingOccurrences(of: keyword, with: "")
                    .components(separatedBy: CharacterSet(charactersIn: ",;•-"))
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                names.forEach { attendees.insert(capitalize($0)) }
            }
        }
        let mentionRegex = try? NSRegularExpression(pattern: "@([A-Za-z0-9._-]+)")
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = mentionRegex?.matches(in: text, options: [], range: range) ?? []
        for match in matches {
            if match.numberOfRanges > 1,
               let range = Range(match.range(at: 1), in: text) {
                attendees.insert(capitalize(String(text[range])))
            }
        }
        return attendees.sorted()
    }
    
    private func extractChecklist(from text: String) -> [String] {
        let lines = text.components(separatedBy: .newlines)
        var items: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("prep:") {
                items.append(trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces))
            } else if trimmed.lowercased().hasPrefix("todo:") {
                items.append(trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces))
            } else if trimmed.lowercased().hasPrefix("review:") {
                items.append("Review " + trimmed.dropFirst(7).trimmingCharacters(in: .whitespaces))
            }
        }
        return items.filter { !$0.isEmpty }
    }
    
    private func fallbackChecklist(for event: CalendarEvent, bookmarks: [URL], notes: [URL]) -> [String] {
        var items: [String] = []
        if !bookmarks.isEmpty {
            items.append("Review linked bookmarks (\(bookmarks.count))")
        }
        if !notes.isEmpty {
            items.append("Revisit linked notes (\(notes.count))")
        }
        if let startDate = event.startDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            items.append("Confirm agenda for \(formatter.string(from: startDate))")
        }
        return Array(Set(items)).filter { !$0.isEmpty }
    }
    
    private func recommendedBookmarks(for event: CalendarEvent, title: String, context: NSManagedObjectContext) -> [URL] {
        var uris = bookmarkLinks.bookmarks(for: event).map { $0.objectID.uriRepresentation() }
        if uris.count >= 3 { return Array(uris.prefix(5)) }
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        request.fetchLimit = 8
        if !title.isEmpty {
            request.predicate = NSPredicate(format: "title CONTAINS[cd] %@ OR bookmarkDescription CONTAINS[cd] %@", title, title)
        }
        let additional = (try? context.fetch(request)) ?? []
        for bookmark in additional where uris.count < 5 {
            let uri = bookmark.objectID.uriRepresentation()
            if !uris.contains(uri) {
                uris.append(uri)
            }
        }
        return uris
    }
    
    private func recommendedNotes(for event: CalendarEvent, title: String, context: NSManagedObjectContext) -> [URL] {
        guard let start = event.startDate else { return [] }
        let notesForDay = (try? coreData.fetchNotes(linkedToDate: start, context: context)) ?? []
        var uris = notesForDay.prefix(5).map { $0.objectID.uriRepresentation() }
        if uris.count < 3 && !title.isEmpty {
            let additional = (try? coreData.fetchNotes(containingText: title, context: context)) ?? []
            for note in additional where uris.count < 5 {
                let uri = note.objectID.uriRepresentation()
                if !uris.contains(uri) {
                    uris.append(uri)
                }
            }
        }
        return uris
    }
    
    private func determineKind(event: CalendarEvent, agenda: [String], attendees: [String]) -> CalendarEvent.EventKind {
        let title = (event.title ?? "").lowercased()
        let category = event.category ?? ""
        let notes = (event.notes ?? "").lowercased()
        if category == EventCategory.health.rawValue || notes.contains("doctor") || title.contains("dentist") {
            return .appointment
        }
        if title.contains("flight") || title.contains("travel") || notes.contains("airport") {
            return .travel
        }
        if title.contains("birthday") || title.contains("party") || notes.contains("celebrate") {
            return .celebration
        }
        if title.contains("workshop") || notes.contains("workshop") {
            return .workshop
        }
        if title.contains("call") || title.contains("dial") {
            return .call
        }
        if title.contains("focus") || title.contains("deep work") {
            return .focus
        }
        if category == EventCategory.personal.rawValue {
            return .personal
        }
        if category == EventCategory.work.rawValue || !attendees.isEmpty || title.contains("meeting") || notes.contains("agenda") {
            return .meeting
        }
        return .other
    }
    
    private func estimateSentiment(from text: String) -> CalendarEvent.EventSentiment? {
        let lowered = text.lowercased()
        guard !lowered.isEmpty else { return nil }
        let positiveWords = ["excited", "great", "success", "win", "celebrate", "launch"]
        let negativeWords = ["issue", "blocked", "problem", "delay", "risk", "concern"]
        let positiveScore = positiveWords.reduce(0) { $0 + (lowered.contains($1) ? 1 : 0) }
        let negativeScore = negativeWords.reduce(0) { $0 + (lowered.contains($1) ? 1 : 0) }
        if positiveScore == 0 && negativeScore == 0 { return .neutral }
        if positiveScore > negativeScore { return .positive }
        if negativeScore > positiveScore { return .negative }
        return .neutral
    }
    
    private func capitalize(_ name: String) -> String {
        name.split(separator: " ").map { part in
            part.prefix(1).uppercased() + part.dropFirst()
        }.joined(separator: " ")
    }
}
