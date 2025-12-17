import Foundation
import CoreData

final class NoteAnalysisService {
    static let shared = NoteAnalysisService()
    private init() {}
    
    private let calendar = Calendar.current
    private let dateDetector: NSDataDetector? = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue)
    
    struct AnalysisResult {
        let kind: Note.NoteKind
        let summary: String?
        let actionItems: [String]
        let people: [String]
        let dates: [Date]
        let sentiment: Note.NoteSentiment?
        let wordCount: Int
    }
    
    func analyze(note: Note, autoSave: Bool = true) {
        guard let context = note.managedObjectContext else { return }
        let content = note.content ?? ""
        let result = performAnalysis(on: content)
        context.performAndWait {
            note.noteKind = result.kind
            note.detectedSummary = result.summary
            note.updateActionItems(result.actionItems)
            note.detectedPeople = result.people.joined(separator: ", ")
            note.updateDetectedDates(result.dates)
            note.sentimentValue = result.sentiment
            note.wordCount = Int32(result.wordCount)
            note.lastAnalyzedAt = Date()
            if autoSave {
                do {
                    try context.save()
                } catch {
                    print("NoteAnalysisService save error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func performAnalysis(on content: String) -> AnalysisResult {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let wordCount = max(0, trimmed.split { $0.isWhitespace || $0.isNewline }.count)
        let summary = generateSummary(from: trimmed)
        let actionItems = extractActionItems(from: trimmed)
        let people = extractPeople(from: trimmed)
        let dates = extractDates(from: trimmed)
        let kind = determineKind(content: trimmed, actionItems: actionItems)
        let sentiment = estimateSentiment(from: trimmed)
        return AnalysisResult(
            kind: kind,
            summary: summary,
            actionItems: actionItems,
            people: people,
            dates: dates,
            sentiment: sentiment,
            wordCount: wordCount
        )
    }
    
    private func generateSummary(from content: String) -> String? {
        guard !content.isEmpty else { return nil }
        let sentences = content.components(separatedBy: .newlines)
            .flatMap { $0.components(separatedBy: ". ") }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !sentences.isEmpty else { return String(content.prefix(160)) }
        let firstSentences = sentences.prefix(3)
        return firstSentences.joined(separator: ". ")
    }
    
    private func extractActionItems(from content: String) -> [String] {
        let lines = content.components(separatedBy: .newlines)
        var items: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- [ ]") {
                items.append(trimmed.replacingOccurrences(of: "- [ ]", with: "").trimmingCharacters(in: .whitespaces))
            } else if trimmed.lowercased().hasPrefix("todo:") {
                items.append(trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces))
            } else if trimmed.lowercased().hasPrefix("action:") {
                items.append(trimmed.dropFirst(7).trimmingCharacters(in: .whitespaces))
            }
        }
        return items.filter { !$0.isEmpty }
    }
    
    private func extractPeople(from content: String) -> [String] {
        var people: Set<String> = []
        let attendeesKeywords = ["attendees:", "participants:", "with:"]
        let lines = content.lowercased().components(separatedBy: .newlines)
        for line in lines {
            for keyword in attendeesKeywords where line.contains(keyword) {
                let names = line.replacingOccurrences(of: keyword, with: "")
                    .components(separatedBy: [",", "-", "·"])
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                names.forEach { people.insert(capitalizeName($0)) }
            }
        }
        let mentions = content.components(separatedBy: CharacterSet.whitespacesAndNewlines)
            .filter { $0.hasPrefix("@") }
            .map { String($0.dropFirst()) }
            .map(capitalizeName(_:))
        mentions.forEach { people.insert($0) }
        return Array(people).sorted()
    }
    
    private func capitalizeName(_ name: String) -> String {
        name.split(separator: " ").map { part in
            part.prefix(1).uppercased() + part.dropFirst()
        }.joined(separator: " ")
    }
    
    private func extractDates(from content: String) -> [Date] {
        guard let detector = dateDetector else { return [] }
        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let matches = detector.matches(in: content, options: [], range: range)
        return matches.compactMap { $0.date }
    }
    
    private func determineKind(content: String, actionItems: [String]) -> Note.NoteKind {
        let lowered = content.lowercased()
        if lowered.contains("meeting") || lowered.contains("agenda") || lowered.contains("attendees:") {
            return .meeting
        }
        if lowered.contains("research") || lowered.contains("findings") || lowered.contains("analysis") {
            return .research
        }
        if lowered.contains("idea") || lowered.contains("brainstorm") {
            return .idea
        }
        if lowered.contains("journal") || lowered.contains("diary") || lowered.contains("today i") {
            return .journal
        }
        if lowered.contains("```") || lowered.contains("func ") || lowered.contains("class ") {
            return .code
        }
        if !actionItems.isEmpty || lowered.contains("todo:") || lowered.contains("action:") {
            return .checklist
        }
        if lowered.contains("summary") {
            return .summary
        }
        if lowered.contains("family") || lowered.contains("personal") {
            return .personal
        }
        return .general
    }
    
    private func estimateSentiment(from content: String) -> Note.NoteSentiment? {
        guard !content.isEmpty else { return nil }
        let lowered = content.lowercased()
        let positiveWords = ["great", "good", "excellent", "success", "happy", "excited"]
        let negativeWords = ["issue", "problem", "concern", "delay", "blocked", "difficult"]
        let positiveScore = positiveWords.reduce(0) { $0 + (lowered.contains($1) ? 1 : 0) }
        let negativeScore = negativeWords.reduce(0) { $0 + (lowered.contains($1) ? 1 : 0) }
        if positiveScore == 0 && negativeScore == 0 { return .neutral }
        if positiveScore > negativeScore { return .positive }
        if negativeScore > positiveScore { return .negative }
        return .neutral
    }
}
