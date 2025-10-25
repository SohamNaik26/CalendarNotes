//
//  EventKitManager.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 22/10/25.
//

import Foundation
import EventKit
import CoreData
import Combine

// MARK: - EventKit Errors

enum EventKitError: Error, LocalizedError {
    case permissionDenied
    case permissionRestricted
    case permissionNotDetermined
    case syncFailed(String)
    case eventNotFound
    case conflictDetected
    case calendarNotFound
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Calendar access permission denied. Please enable access in System Settings."
        case .permissionRestricted:
            return "Calendar access is restricted on this device."
        case .permissionNotDetermined:
            return "Calendar access permission has not been requested yet."
        case .syncFailed(let message):
            return "Sync failed: \(message)"
        case .eventNotFound:
            return "Event not found in calendar."
        case .conflictDetected:
            return "A sync conflict was detected."
        case .calendarNotFound:
            return "Calendar not found."
        }
    }
}

// MARK: - Sync Conflict Resolution Strategy

enum SyncConflictResolution {
    case localWins        // Local changes take priority
    case remoteWins       // EventKit changes take priority
    case newerWins        // Use modification date to determine winner
    case manual           // Ask user to resolve (not implemented in this version)
}

// MARK: - Sync Statistics

struct SyncStatistics {
    var eventsCreated: Int = 0
    var eventsUpdated: Int = 0
    var eventsDeleted: Int = 0
    var conflictsResolved: Int = 0
    var errors: [String] = []
    
    var totalChanges: Int {
        eventsCreated + eventsUpdated + eventsDeleted
    }
}

// MARK: - EventKit Manager

@MainActor
class EventKitManager: ObservableObject {
    
    // MARK: - Singleton
    
    static let shared = EventKitManager()
    
    // MARK: - Properties
    
    private let eventStore = EKEventStore()
    private let coreDataManager = CoreDataManager.shared
    
    @Published var authorizationStatus: EKAuthorizationStatus = .notDetermined
    @Published var isSyncing: Bool = false
    @Published var lastSyncDate: Date?
    @Published var syncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(syncEnabled, forKey: "eventKitSyncEnabled")
        }
    }
    
    private var conflictResolutionStrategy: SyncConflictResolution = .newerWins
    private var syncStatistics = SyncStatistics()
    
    // MARK: - Initialization
    
    private init() {
        syncEnabled = UserDefaults.standard.bool(forKey: "eventKitSyncEnabled")
        lastSyncDate = UserDefaults.standard.object(forKey: "lastEventKitSyncDate") as? Date
        checkAuthorizationStatus()
    }
    
    // MARK: - Authorization
    
    func checkAuthorizationStatus() {
        if #available(macOS 14.0, iOS 17.0, *) {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        } else {
            authorizationStatus = EKEventStore.authorizationStatus(for: .event)
        }
    }
    
    func requestAccess() async throws -> Bool {
        if #available(macOS 14.0, iOS 17.0, *) {
            do {
                let granted = try await eventStore.requestFullAccessToEvents()
                authorizationStatus = granted ? .fullAccess : .denied
                return granted
            } catch {
                throw EventKitError.syncFailed("Failed to request access: \(error.localizedDescription)")
            }
        } else {
            return try await withCheckedThrowingContinuation { continuation in
                eventStore.requestAccess(to: .event) { granted, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                    } else {
                        Task { @MainActor in
                            self.authorizationStatus = granted ? .authorized : .denied
                        }
                        continuation.resume(returning: granted)
                    }
                }
            }
        }
    }
    
    func ensureAuthorized() async throws {
        checkAuthorizationStatus()
        
        switch authorizationStatus {
        case .authorized, .fullAccess:
            return
        case .notDetermined:
            let granted = try await requestAccess()
            if !granted {
                throw EventKitError.permissionDenied
            }
        case .denied:
            throw EventKitError.permissionDenied
        case .restricted:
            throw EventKitError.permissionRestricted
        case .writeOnly:
            // Write-only access is sufficient for basic sync
            return
        @unknown default:
            throw EventKitError.permissionNotDetermined
        }
    }
    
    // MARK: - Main Sync Functions
    
    /// Performs a full two-way sync between CalendarNotes and iOS Calendar
    func performFullSync() async throws -> SyncStatistics {
        try await ensureAuthorized()
        
        guard syncEnabled else {
            throw EventKitError.syncFailed("Sync is disabled")
        }
        
        isSyncing = true
        defer { isSyncing = false }
        
        syncStatistics = SyncStatistics()
        
        do {
            // Step 1: Sync local events to EventKit
            try await syncLocalToEventKit()
            
            // Step 2: Import events from EventKit
            try await syncEventKitToLocal()
            
            // Step 3: Handle deletions
            try await handleDeletedEvents()
            
            // Update last sync date
            lastSyncDate = Date()
            UserDefaults.standard.set(lastSyncDate, forKey: "lastEventKitSyncDate")
            
            print("✅ Sync completed: \(syncStatistics.totalChanges) changes")
            return syncStatistics
            
        } catch {
            syncStatistics.errors.append(error.localizedDescription)
            throw EventKitError.syncFailed(error.localizedDescription)
        }
    }
    
    /// Syncs local CalendarNotes events to iOS Calendar
    private func syncLocalToEventKit() async throws {
        let context = coreDataManager.viewContext
        let fetchRequest: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
        
        let localEvents = try coreDataManager.fetch(fetchRequest, context: context)
        
        for localEvent in localEvents {
            do {
                try await syncSingleEventToEventKit(localEvent, context: context)
            } catch {
                syncStatistics.errors.append("Failed to sync '\(localEvent.title ?? "")': \(error.localizedDescription)")
            }
        }
    }
    
    /// Syncs a single local event to EventKit
    private func syncSingleEventToEventKit(_ localEvent: CalendarEvent, context: NSManagedObjectContext) async throws {
        // Check if event already exists in EventKit
        if let eventKitId = localEvent.eventKitId, !eventKitId.isEmpty {
            // Event exists, check for updates
            if let ekEvent = eventStore.event(withIdentifier: eventKitId) {
                // Check for conflicts
                if try await hasConflict(localEvent: localEvent, ekEvent: ekEvent) {
                    try await resolveConflict(localEvent: localEvent, ekEvent: ekEvent, context: context)
                    syncStatistics.conflictsResolved += 1
                } else {
                    // Update EventKit event with local changes
                    updateEKEvent(ekEvent, from: localEvent)
                    try eventStore.save(ekEvent, span: .thisEvent)
                    syncStatistics.eventsUpdated += 1
                }
            } else {
                // EventKit event was deleted, create new one
                let newEKEvent = try createEKEvent(from: localEvent)
                localEvent.eventKitId = newEKEvent.eventIdentifier
                localEvent.lastSyncDate = Date()
                try coreDataManager.save(context: context)
                syncStatistics.eventsCreated += 1
            }
        } else {
            // New event, create in EventKit
            let newEKEvent = try createEKEvent(from: localEvent)
            localEvent.eventKitId = newEKEvent.eventIdentifier
            localEvent.lastSyncDate = Date()
            try coreDataManager.save(context: context)
            syncStatistics.eventsCreated += 1
        }
    }
    
    /// Syncs EventKit events to local CalendarNotes
    private func syncEventKitToLocal() async throws {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .year, value: -1, to: Date()) ?? Date()
        let endDate = calendar.date(byAdding: .year, value: 1, to: Date()) ?? Date()
        
        let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
        let ekEvents = eventStore.events(matching: predicate)
        
        let context = coreDataManager.viewContext
        
        for ekEvent in ekEvents {
            do {
                try await importEKEvent(ekEvent, context: context)
            } catch {
                syncStatistics.errors.append("Failed to import '\(ekEvent.title ?? "Untitled")': \(error.localizedDescription)")
            }
        }
    }
    
    /// Imports a single EventKit event to local storage
    private func importEKEvent(_ ekEvent: EKEvent, context: NSManagedObjectContext) async throws {
        // Check if event already exists locally
        let fetchRequest: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventKitId == %@", ekEvent.eventIdentifier)
        
        let existingEvents = try coreDataManager.fetch(fetchRequest, context: context)
        
        if let existingEvent = existingEvents.first {
            // Event exists, check for updates
            if try await hasConflict(localEvent: existingEvent, ekEvent: ekEvent) {
                try await resolveConflict(localEvent: existingEvent, ekEvent: ekEvent, context: context)
                syncStatistics.conflictsResolved += 1
            } else {
                // Update local event with EventKit changes
                updateLocalEvent(existingEvent, from: ekEvent)
                existingEvent.lastSyncDate = Date()
                try coreDataManager.save(context: context)
                syncStatistics.eventsUpdated += 1
            }
        } else {
            // New event from EventKit, create locally
            createLocalEvent(from: ekEvent, context: context)
            try coreDataManager.save(context: context)
            syncStatistics.eventsCreated += 1
        }
    }
    
    /// Handles events deleted in one system but still present in the other
    private func handleDeletedEvents() async throws {
        let context = coreDataManager.viewContext
        let fetchRequest: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "eventKitId != nil AND eventKitId != ''")
        
        let localEvents = try coreDataManager.fetch(fetchRequest, context: context)
        
        for localEvent in localEvents {
            guard let eventKitId = localEvent.eventKitId else { continue }
            
            // Check if EventKit event still exists
            if eventStore.event(withIdentifier: eventKitId) == nil {
                // EventKit event was deleted, delete local event
                try coreDataManager.delete(localEvent, context: context)
                syncStatistics.eventsDeleted += 1
            }
        }
    }
    
    // MARK: - Conflict Resolution
    
    private func hasConflict(localEvent: CalendarEvent, ekEvent: EKEvent) async throws -> Bool {
        guard let lastSyncDate = localEvent.lastSyncDate else {
            return false // No previous sync, no conflict
        }
        
        // Check if both events were modified since last sync
        let localModified = localEvent.modifiedDate ?? localEvent.createdDate ?? Date()
        let ekModified = ekEvent.lastModifiedDate ?? ekEvent.creationDate ?? Date()
        
        return localModified > lastSyncDate && ekModified > lastSyncDate
    }
    
    private func resolveConflict(localEvent: CalendarEvent, ekEvent: EKEvent, context: NSManagedObjectContext) async throws {
        switch conflictResolutionStrategy {
        case .localWins:
            updateEKEvent(ekEvent, from: localEvent)
            try eventStore.save(ekEvent, span: .thisEvent)
            
        case .remoteWins:
            updateLocalEvent(localEvent, from: ekEvent)
            try coreDataManager.save(context: context)
            
        case .newerWins:
            let localModified = localEvent.modifiedDate ?? localEvent.createdDate ?? Date()
            let ekModified = ekEvent.lastModifiedDate ?? ekEvent.creationDate ?? Date()
            
            if localModified > ekModified {
                updateEKEvent(ekEvent, from: localEvent)
                try eventStore.save(ekEvent, span: .thisEvent)
            } else {
                updateLocalEvent(localEvent, from: ekEvent)
                try coreDataManager.save(context: context)
            }
            
        case .manual:
            // For now, default to newerWins
            // In a future version, this could present a UI for user resolution
            try await resolveConflict(localEvent: localEvent, ekEvent: ekEvent, context: context)
        }
        
        localEvent.lastSyncDate = Date()
    }
    
    // MARK: - Event Creation and Updates
    
    private func createEKEvent(from localEvent: CalendarEvent) throws -> EKEvent {
        let ekEvent = EKEvent(eventStore: eventStore)
        updateEKEvent(ekEvent, from: localEvent)
        
        // Set calendar
        if let defaultCalendar = eventStore.defaultCalendarForNewEvents {
            ekEvent.calendar = defaultCalendar
        } else {
            throw EventKitError.calendarNotFound
        }
        
        // Handle recurring events
        if localEvent.isRecurring, let recurrenceRule = localEvent.recurrenceRule {
            ekEvent.recurrenceRules = parseRecurrenceRule(recurrenceRule)
        }
        
        try eventStore.save(ekEvent, span: .thisEvent)
        return ekEvent
    }
    
    private func updateEKEvent(_ ekEvent: EKEvent, from localEvent: CalendarEvent) {
        ekEvent.title = localEvent.title ?? ""
        ekEvent.startDate = localEvent.startDate ?? Date()
        ekEvent.endDate = localEvent.endDate ?? Date()
        ekEvent.location = localEvent.location
        ekEvent.notes = localEvent.notes
        
        // Map category to calendar with appropriate color
        if let category = localEvent.category {
            if let calendar = EventKitAvailabilityHelper.getOrCreateCalendar(for: category, in: eventStore) {
                ekEvent.calendar = calendar
            } else {
                ekEvent.calendar = eventStore.defaultCalendarForNewEvents
            }
        }
    }
    
    private func createLocalEvent(from ekEvent: EKEvent, context: NSManagedObjectContext) {
        let localEvent = CalendarEvent(context: context)
        updateLocalEvent(localEvent, from: ekEvent)
        localEvent.eventKitId = ekEvent.eventIdentifier
        localEvent.lastSyncDate = Date()
        localEvent.createdDate = Date()
    }
    
    private func updateLocalEvent(_ localEvent: CalendarEvent, from ekEvent: EKEvent) {
        localEvent.title = ekEvent.title
        localEvent.startDate = ekEvent.startDate
        localEvent.endDate = ekEvent.endDate
        localEvent.location = ekEvent.location
        localEvent.notes = ekEvent.notes
        localEvent.category = ekEvent.calendar.title
        
        // Handle recurring events
        if let recurrenceRules = ekEvent.recurrenceRules, !recurrenceRules.isEmpty {
            localEvent.isRecurring = true
            localEvent.recurrenceRule = formatRecurrenceRule(recurrenceRules.first)
        } else {
            localEvent.isRecurring = false
            localEvent.recurrenceRule = nil
        }
        
        localEvent.modifiedDate = Date()
    }
    
    // MARK: - Calendar Management
    
    /// Finds or creates a calendar for a specific category with appropriate color
    private func findOrCreateCalendar(for category: String) -> EKCalendar? {
        return EventKitAvailabilityHelper.getOrCreateCalendar(for: category, in: eventStore)
    }
    
    // MARK: - Recurrence Rule Parsing
    
    private func parseRecurrenceRule(_ ruleString: String) -> [EKRecurrenceRule] {
        // Simple parsing for common recurrence patterns
        // Format: "DAILY", "WEEKLY", "MONTHLY", "YEARLY"
        var frequency: EKRecurrenceFrequency
        
        switch ruleString.uppercased() {
        case "DAILY":
            frequency = .daily
        case "WEEKLY":
            frequency = .weekly
        case "MONTHLY":
            frequency = .monthly
        case "YEARLY":
            frequency = .yearly
        default:
            frequency = .daily
        }
        
        let rule = EKRecurrenceRule(
            recurrenceWith: frequency,
            interval: 1,
            end: nil
        )
        
        return [rule]
    }
    
    private func formatRecurrenceRule(_ rule: EKRecurrenceRule?) -> String? {
        guard let rule = rule else { return nil }
        
        switch rule.frequency {
        case .daily:
            return "DAILY"
        case .weekly:
            return "WEEKLY"
        case .monthly:
            return "MONTHLY"
        case .yearly:
            return "YEARLY"
        @unknown default:
            return nil
        }
    }
    
    // MARK: - Public Helper Methods
    
    /// Syncs a single event immediately
    func syncEvent(_ event: CalendarEvent) async throws {
        try await ensureAuthorized()
        guard syncEnabled else { return }
        
        let context = coreDataManager.viewContext
        try await syncSingleEventToEventKit(event, context: context)
    }
    
    /// Deletes an event from both local and EventKit
    func deleteEvent(_ event: CalendarEvent) async throws {
        let context = coreDataManager.viewContext
        
        // Delete from EventKit if it exists there
        if let eventKitId = event.eventKitId,
           let ekEvent = eventStore.event(withIdentifier: eventKitId) {
            try eventStore.remove(ekEvent, span: .thisEvent)
        }
        
        // Delete from local storage
        try coreDataManager.delete(event, context: context)
    }
    
    /// Sets the conflict resolution strategy
    func setConflictResolution(_ strategy: SyncConflictResolution) {
        conflictResolutionStrategy = strategy
    }
    
    /// Gets the current sync statistics
    func getSyncStatistics() -> SyncStatistics {
        return syncStatistics
    }
    
    /// Resets sync metadata for an event (useful for troubleshooting)
    func resetSyncMetadata(for event: CalendarEvent) throws {
        event.eventKitId = nil
        event.lastSyncDate = nil
        try coreDataManager.save()
    }
}

