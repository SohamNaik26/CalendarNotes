//
//  NotesViewModel.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import Foundation
import CoreData
import Combine
#if os(iOS)
import UIKit
#endif

class NotesViewModel: ObservableObject {
    @Published var notesState: LoadingState<[Note]> = .idle
    @Published var notes: [Note] = []
    @Published var selectedDate: Date?
    @Published var searchText: String = ""
    @Published var sortOption: NoteSortOption = .dateCreated
    @Published var activeKind: Note.NoteKind? = nil
    
    private let coreDataService: CoreDataService
    private var cancellables = Set<AnyCancellable>()
    
    init(coreDataService: CoreDataService = CoreDataService()) {
        self.coreDataService = coreDataService
        loadNotes()
    }
    
    func loadNotes() {
        notesState = .loading
        Task { @MainActor in
            do {
                let fetched = try await NetworkTimeoutHandler.shared.withTimeout(timeout: 10.0) {
                    self.coreDataService.fetchNotes(linkedToDate: self.selectedDate)
                }
                notes = fetched
                notesState = .loaded(fetched)
                if let activeKind, !notes.contains(where: { $0.noteKind == activeKind }) {
                    self.activeKind = nil
                }
            } catch {
                let cachedNotes = notesState.value ?? []
                notesState = .error(error)
                if !cachedNotes.isEmpty {
                    notes = cachedNotes
                }
            }
        }
    }
    
    @MainActor
    func refresh() async {
        loadNotes()
        // Wait for loading to complete
        while notesState.isLoading {
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
    }
    
    var filteredNotes: [Note] {
        var filtered = notes
        
        // Apply search filter
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            filtered = filtered.filter { note in
                let contentMatch = note.content?.lowercased().contains(query) ?? false
                let summaryMatch = note.summaryText?.lowercased().contains(query) ?? false
                let tagMatch = note.tags?.lowercased().contains(query) ?? false
                let peopleMatch = note.detectedPeopleList.contains { $0.lowercased().contains(query) }
                let actionMatch = note.actionItems.contains { $0.lowercased().contains(query) }
                return contentMatch || summaryMatch || tagMatch || peopleMatch || actionMatch
            }
        }
        
        if let activeKind {
            filtered = filtered.filter { $0.noteKind == activeKind }
        }
        
        // Apply sorting
        return sortNotes(filtered)
    }
    
    var groupedNotes: [NoteGroup] {
        let sortedNotes = filteredNotes
        return groupNotesByDate(sortedNotes)
    }
    
    private func sortNotes(_ notes: [Note]) -> [Note] {
        switch sortOption {
        case .dateCreated:
            return notes.sorted { ($0.createdDate ?? Date.distantPast) > ($1.createdDate ?? Date.distantPast) }
        case .dateModified:
            return notes.sorted { ($0.createdDate ?? Date.distantPast) > ($1.createdDate ?? Date.distantPast) }
        case .linkedDate:
            return notes.sorted { ($0.linkedDate ?? Date.distantPast) > ($1.linkedDate ?? Date.distantPast) }
        case .alphabetical:
            return notes.sorted { ($0.content ?? "") < ($1.content ?? "") }
        }
    }
    
    private func groupNotesByDate(_ notes: [Note]) -> [NoteGroup] {
        let calendar = Calendar.current
        let now = Date()
        
        var groups: [NoteGroup] = []
        
        // Today
        let todayNotes = notes.filter { note in
            guard let date = note.createdDate else { return false }
            return calendar.isDate(date, inSameDayAs: now)
        }
        if !todayNotes.isEmpty {
            groups.append(NoteGroup(title: "Today", notes: todayNotes))
        }
        
        // Yesterday
        let yesterday = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let yesterdayNotes = notes.filter { note in
            guard let date = note.createdDate else { return false }
            return calendar.isDate(date, inSameDayAs: yesterday)
        }
        if !yesterdayNotes.isEmpty {
            groups.append(NoteGroup(title: "Yesterday", notes: yesterdayNotes))
        }
        
        // This Week
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: now)?.start ?? now
        let thisWeekNotes = notes.filter { note in
            guard let date = note.createdDate else { return false }
            return date >= weekStart && !calendar.isDate(date, inSameDayAs: now) && !calendar.isDate(date, inSameDayAs: yesterday)
        }
        if !thisWeekNotes.isEmpty {
            groups.append(NoteGroup(title: "This Week", notes: thisWeekNotes))
        }
        
        // This Month
        let monthStart = calendar.dateInterval(of: .month, for: now)?.start ?? now
        let thisMonthNotes = notes.filter { note in
            guard let date = note.createdDate else { return false }
            return date >= monthStart && date < weekStart
        }
        if !thisMonthNotes.isEmpty {
            groups.append(NoteGroup(title: "This Month", notes: thisMonthNotes))
        }
        
        // Older
        let olderNotes = notes.filter { note in
            guard let date = note.createdDate else { return false }
            return date < monthStart
        }
        if !olderNotes.isEmpty {
            groups.append(NoteGroup(title: "Older", notes: olderNotes))
        }
        
        return groups
    }
    
    func addNote(content: String, linkedDate: Date? = nil, tags: String? = nil) {
        do {
            try coreDataService.createNote(content: content, linkedDate: linkedDate, tags: tags)
            loadNotes()
        } catch {
            print("Error creating note: \(error)")
        }
    }
    
    var availableKinds: [Note.NoteKind] {
        let kinds = notes.map { $0.noteKind }
        let unique = Set(kinds)
        return Note.NoteKind.allCases.filter { unique.contains($0) }
    }
    
    func setKindFilter(_ kind: Note.NoteKind) {
        if activeKind == kind {
            activeKind = nil
        } else {
            activeKind = kind
        }
    }
    
    func clearKindFilter() {
        activeKind = nil
    }
    
    func deleteNote(_ note: Note) {
        do {
            try coreDataService.deleteNote(note)
            loadNotes()
        } catch {
            print("Error deleting note: \(error)")
        }
    }
    
    func filterByDate(_ date: Date?) {
        selectedDate = date
        loadNotes()
    }
    
    func shareNote(_ note: Note) {
        #if os(iOS)
        let activityViewController = UIActivityViewController(
            activityItems: [note.content ?? ""],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            window.rootViewController?.present(activityViewController, animated: true)
        }
        #else
        // macOS sharing implementation would go here
        // For now, we'll just print the content
        print("Sharing note: \(note.content ?? "")")
        #endif
    }
}

// MARK: - Note Sort Option

enum NoteSortOption: String, CaseIterable {
    case dateCreated = "dateCreated"
    case dateModified = "dateModified"
    case linkedDate = "linkedDate"
    case alphabetical = "alphabetical"
    
    var title: String {
        switch self {
        case .dateCreated: return "Date Created"
        case .dateModified: return "Date Modified"
        case .linkedDate: return "Linked Date"
        case .alphabetical: return "Alphabetical"
        }
    }
    
    var description: String {
        switch self {
        case .dateCreated: return "Newest notes first"
        case .dateModified: return "Recently modified first"
        case .linkedDate: return "By linked date"
        case .alphabetical: return "A to Z"
        }
    }
    
    var icon: String {
        switch self {
        case .dateCreated: return "calendar.badge.plus"
        case .dateModified: return "pencil"
        case .linkedDate: return "calendar"
        case .alphabetical: return "textformat.abc"
        }
    }
}

// MARK: - Note Group

struct NoteGroup {
    let title: String
    let notes: [Note]
}

