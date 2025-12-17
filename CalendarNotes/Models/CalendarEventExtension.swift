//
//  CalendarEventExtension.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import Foundation
import CoreData
import Combine

extension CalendarEvent {
    enum EventKind: String, CaseIterable {
        case meeting
        case focus
        case travel
        case personal
        case celebration
        case appointment
        case workshop
        case call
        case other
        
        var displayName: String {
            switch self {
            case .meeting: return "Meeting"
            case .focus: return "Focus"
            case .travel: return "Travel"
            case .personal: return "Personal"
            case .celebration: return "Celebration"
            case .appointment: return "Appointment"
            case .workshop: return "Workshop"
            case .call: return "Call"
            case .other: return "Other"
            }
        }
        
        var icon: String {
            switch self {
            case .meeting: return "person.2.fill"
            case .focus: return "bolt.fill"
            case .travel: return "airplane"
            case .personal: return "heart.fill"
            case .celebration: return "party.popper"
            case .appointment: return "stethoscope"
            case .workshop: return "hammer"
            case .call: return "phone"
            case .other: return "calendar"
            }
        }
    }
    
    enum EventSentiment: String {
        case positive
        case neutral
        case negative
    }
    
    convenience init(context: NSManagedObjectContext, title: String, startDate: Date, endDate: Date, category: String, location: String? = nil, notes: String? = nil, isRecurring: Bool = false, recurrenceRule: String? = nil) {
        self.init(context: context)
        self.id = UUID()
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.category = category
        self.location = location
        self.notes = notes
        self.isRecurring = isRecurring
        self.recurrenceRule = recurrenceRule
    }

    var linkedBookmarks: [Bookmark] {
        let set = (self.value(forKey: "bookmarkLinks") as? Set<BookmarkLink>) ?? []
        return set.compactMap { $0.bookmark }
    }
    
    var eventKind: EventKind {
        get { EventKind(rawValue: eventType ?? EventKind.other.rawValue) ?? .other }
        set { eventType = newValue.rawValue }
    }
    
    var eventSentiment: EventSentiment? {
        get { sentiment.flatMap(EventSentiment.init(rawValue:)) }
        set { sentiment = newValue?.rawValue }
    }
    
    var agendaItems: [String] {
        decodeStringArray(from: detectedAgendaJSON)
    }
    
    var preparationChecklist: [String] {
        decodeStringArray(from: prepChecklistJSON)
    }
    
    var recommendedBookmarkObjectIDs: [URL] {
        decodeStringArray(from: recommendedBookmarkIDs).compactMap(URL.init(string:))
    }
    
    var recommendedNoteObjectIDs: [URL] {
        decodeStringArray(from: recommendedNoteIDs).compactMap(URL.init(string:))
    }
    
    var attendees: [String] {
        guard let detectedPeople, !detectedPeople.isEmpty else { return [] }
        return detectedPeople
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    var duration: TimeInterval {
        guard let startDate, let endDate else { return 0 }
        return endDate.timeIntervalSince(startDate)
    }
    
    var durationDescription: String {
        guard duration > 0 else { return "--" }
        let componentsFormatter = DateComponentsFormatter()
        componentsFormatter.allowedUnits = duration >= 3600 ? [.hour, .minute] : [.minute]
        componentsFormatter.unitsStyle = .abbreviated
        return componentsFormatter.string(from: duration) ?? "--"
    }
    
    func updateAgendaItems(_ items: [String]) {
        detectedAgendaJSON = encodeStringArray(items)
    }
    
    func updatePreparationChecklist(_ items: [String]) {
        prepChecklistJSON = encodeStringArray(items)
    }
    
    func updateRecommendedBookmarks(_ uris: [URL]) {
        let strings = uris.map { $0.absoluteString }
        recommendedBookmarkIDs = encodeStringArray(strings)
    }
    
    func updateRecommendedNotes(_ uris: [URL]) {
        let strings = uris.map { $0.absoluteString }
        recommendedNoteIDs = encodeStringArray(strings)
    }
    
    private func decodeStringArray(from string: String?) -> [String] {
        guard let dataString = string, let data = dataString.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }
    
    private func encodeStringArray(_ items: [String]) -> String? {
        guard let data = try? JSONEncoder().encode(items) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

