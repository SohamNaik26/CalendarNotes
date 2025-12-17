//
//  AutomationRuleService.swift
//  CalendarNotes
//

import Foundation
import CoreData
import Combine

@MainActor
final class AutomationRuleService: ObservableObject {
    static let shared = AutomationRuleService()
    
    @Published var rules: [AutomationRule] = []
    @Published var executionLogs: [RuleExecutionLog] = []
    
    private let userDefaults = UserDefaults.standard
    private let rulesKey = "automationRules"
    private let logsKey = "automationRuleLogs"
    private let maxLogs = 1000
    
    private init() {
        loadRules()
        loadLogs()
    }
    
    // MARK: - Rule Management
    
    func addRule(_ rule: AutomationRule) {
        rules.append(rule)
        saveRules()
    }
    
    func updateRule(_ rule: AutomationRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
            saveRules()
        }
    }
    
    func deleteRule(_ rule: AutomationRule) {
        rules.removeAll { $0.id == rule.id }
        saveRules()
    }
    
    func toggleRule(_ rule: AutomationRule) {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index].isEnabled.toggle()
            saveRules()
        }
    }
    
    // MARK: - Rule Execution
    
    func executeRules(for bookmark: Bookmark, context: NSManagedObjectContext) {
        for rule in rules where rule.isEnabled {
            if evaluateTrigger(rule.trigger, for: bookmark) {
                executeActions(rule.actions, for: bookmark, rule: rule, context: context)
            }
        }
    }
    
    func testRule(_ rule: AutomationRule, on bookmarks: [Bookmark], context: NSManagedObjectContext) -> [RuleExecutionLog] {
        var logs: [RuleExecutionLog] = []
        for bookmark in bookmarks {
            if evaluateTrigger(rule.trigger, for: bookmark) {
                let log = executeActions(rule.actions, for: bookmark, rule: rule, context: context)
                logs.append(log)
            }
        }
        return logs
    }
    
    func batchApplyRule(_ rule: AutomationRule, to bookmarks: [Bookmark], context: NSManagedObjectContext) async {
        var successCount = 0
        var failureCount = 0
        
        for bookmark in bookmarks {
            if evaluateTrigger(rule.trigger, for: bookmark) {
                let log = executeActions(rule.actions, for: bookmark, rule: rule, context: context)
                if log.success {
                    successCount += 1
                } else {
                    failureCount += 1
                }
            }
        }
        
        // Update rule execution count
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index].executionCount += successCount
            rules[index].lastExecuted = Date()
            saveRules()
        }
    }
    
    // MARK: - Trigger Evaluation
    
    private func evaluateTrigger(_ trigger: Trigger, for bookmark: Bookmark) -> Bool {
        switch trigger {
        case .addedToCollection(let collectionName):
            return bookmark.collection?.name == collectionName
            
        case .taggedWith(let tagName):
            return bookmark.decodedTags.contains(tagName)
            
        case .fromDomain(let domain):
            guard let urlString = bookmark.url, let url = URL(string: urlString) else { return false }
            return url.host?.contains(domain) ?? false
            
        case .savedAtTime(let timeRange):
            return evaluateTimeRange(timeRange, for: bookmark.createdDate ?? Date())
            
        case .notOpenedInDays(let days):
            guard let lastOpened = bookmark.lastOpenedDate else { return false }
            let daysSince = Calendar.current.dateComponents([.day], from: lastOpened, to: Date()).day ?? 0
            return daysSince >= days
            
        case .matchesAll(let triggers):
            return triggers.allSatisfy { evaluateTrigger($0, for: bookmark) }
            
        case .matchesAny(let triggers):
            return triggers.contains { evaluateTrigger($0, for: bookmark) }
        }
    }
    
    private func evaluateTimeRange(_ range: Trigger.TimeRange, for date: Date) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute, .weekday], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let weekday = (components.weekday ?? 1) - 1 // Convert to 0-based (0 = Sunday)
        
        switch range {
        case .specificTime(let targetHour, let targetMinute):
            return hour == targetHour && minute == targetMinute
            
        case .timeRange(let startHour, let startMinute, let endHour, let endMinute):
            let startMinutes = startHour * 60 + startMinute
            let endMinutes = endHour * 60 + endMinute
            let currentMinutes = hour * 60 + minute
            return currentMinutes >= startMinutes && currentMinutes <= endMinutes
            
        case .weekdays(let allowedDays):
            return allowedDays.contains(weekday)
        }
    }
    
    // MARK: - Action Execution
    
    @discardableResult
    private func executeActions(_ actions: [Action], for bookmark: Bookmark, rule: AutomationRule, context: NSManagedObjectContext) -> RuleExecutionLog {
        var actionsPerformed: [String] = []
        var errorMessage: String?
        var success = true
        
        for action in actions {
            do {
                let description = try executeAction(action, for: bookmark, context: context)
                actionsPerformed.append(description)
            } catch {
                errorMessage = error.localizedDescription
                success = false
                break
            }
        }
        
        if success {
            try? context.save()
        }
        
        let log = RuleExecutionLog(
            ruleId: rule.id,
            ruleName: rule.name,
            bookmarkId: bookmark.id?.uuidString ?? "",
            bookmarkTitle: bookmark.title ?? bookmark.url ?? "Untitled",
            success: success,
            errorMessage: errorMessage,
            actionsPerformed: actionsPerformed
        )
        
        addLog(log)
        
        // Update rule execution count
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index].executionCount += 1
            rules[index].lastExecuted = Date()
            saveRules()
        }
        
        return log
    }
    
    private func executeAction(_ action: Action, for bookmark: Bookmark, context: NSManagedObjectContext) throws -> String {
        switch action {
        case .moveToCollection(let collectionName):
            let request: NSFetchRequest<Collection> = Collection.fetchRequest()
            request.predicate = NSPredicate(format: "name == %@", collectionName)
            if let collection = try context.fetch(request).first {
                bookmark.collection = collection
                return "Moved to collection: \(collectionName)"
            } else {
                throw AutomationError.collectionNotFound(collectionName)
            }
            
        case .addTags(let tagNames):
            var currentTags = Set(bookmark.decodedTags)
            for tagName in tagNames {
                currentTags.insert(tagName)
            }
            bookmark.decodedTags = Array(currentTags)
            return "Added tags: \(tagNames.joined(separator: ", "))"
            
        case .removeTags(let tagNames):
            var currentTags = Set(bookmark.decodedTags)
            for tagName in tagNames {
                currentTags.remove(tagName)
            }
            bookmark.decodedTags = Array(currentTags)
            return "Removed tags: \(tagNames.joined(separator: ", "))"
            
        case .markAsFavorite(let favorite):
            bookmark.isFavorite = favorite
            return favorite ? "Marked as favorite" : "Unmarked as favorite"
            
        case .archive(let archived):
            bookmark.isArchived = archived
            return archived ? "Archived" : "Unarchived"
            
        case .delete:
            context.delete(bookmark)
            return "Deleted"
            
        case .sendNotification(let message):
            // TODO: Implement notification sending
            return "Notification sent: \(message)"
            
        case .createTask(let title):
            let taskTitle = title ?? "Read: \(bookmark.title ?? bookmark.url ?? "Bookmark")"
            let task = TodoItem(context: context)
            task.id = UUID()
            task.title = taskTitle
            task.priority = "Medium"
            task.category = "Reading"
            task.isCompleted = false
            // TODO: Link bookmark to task if needed
            return "Created task: \(taskTitle)"
            
        case .createCalendarEvent(let title, let date):
            let eventTitle = title ?? bookmark.title ?? "Reading: \(bookmark.url ?? "Bookmark")"
            let eventDate = date ?? Date()
            // TODO: Create calendar event using CalendarEventService
            let formattedDate = eventDate.formatted(date: .abbreviated, time: .shortened)
            return "Created calendar event: \(eventTitle) · \(formattedDate)"
            
        case .addNote(let noteContent):
            let existingNotes = bookmark.notes ?? ""
            bookmark.notes = existingNotes.isEmpty ? noteContent : "\(existingNotes)\n\n\(noteContent)"
            return "Added note"
        }
    }
    
    // MARK: - Log Management
    
    func addLog(_ log: RuleExecutionLog) {
        executionLogs.insert(log, at: 0)
        if executionLogs.count > maxLogs {
            executionLogs = Array(executionLogs.prefix(maxLogs))
        }
        saveLogs()
    }
    
    func clearLogs() {
        executionLogs.removeAll()
        saveLogs()
    }
    
    func logsForRule(_ rule: AutomationRule) -> [RuleExecutionLog] {
        executionLogs.filter { $0.ruleId == rule.id }
    }
    
    // MARK: - Persistence
    
    private func saveRules() {
        if let encoded = try? JSONEncoder().encode(rules) {
            userDefaults.set(encoded, forKey: rulesKey)
        }
    }
    
    private func loadRules() {
        if let data = userDefaults.data(forKey: rulesKey),
           let decoded = try? JSONDecoder().decode([AutomationRule].self, from: data) {
            rules = decoded
        }
    }
    
    private func saveLogs() {
        if let encoded = try? JSONEncoder().encode(executionLogs) {
            userDefaults.set(encoded, forKey: logsKey)
        }
    }
    
    private func loadLogs() {
        if let data = userDefaults.data(forKey: logsKey),
           let decoded = try? JSONDecoder().decode([RuleExecutionLog].self, from: data) {
            executionLogs = decoded
        }
    }
}

// MARK: - Errors

enum AutomationError: LocalizedError {
    case collectionNotFound(String)
    case invalidTrigger
    case actionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .collectionNotFound(let name):
            return "Collection '\(name)' not found"
        case .invalidTrigger:
            return "Invalid trigger configuration"
        case .actionFailed(let message):
            return "Action failed: \(message)"
        }
    }
}


