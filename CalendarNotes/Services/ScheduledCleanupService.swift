//
//  ScheduledCleanupService.swift
//  CalendarNotes
//
//  Automated cleanup service that runs scheduled maintenance tasks
//

import Foundation
import CoreData
import Combine
import SwiftUI
import UserNotifications

#if os(iOS)
import BackgroundTasks
#endif

class ScheduledCleanupService: ObservableObject {
    
    // MARK: - Properties
    
    private let dataManager: DataManagementService
    private let coreDataManager: CoreDataManager
    private let notificationCenter = UNUserNotificationCenter.current()
    
    @Published var isScheduled = false
    @Published var nextCleanupDate: Date?
    @Published var lastCleanupDate: Date?
    
    // Cleanup intervals
    private let dailyCleanupInterval: TimeInterval = 24 * 60 * 60 // 24 hours
    private let weeklyCleanupInterval: TimeInterval = 7 * 24 * 60 * 60 // 7 days
    private let monthlyCleanupInterval: TimeInterval = 30 * 24 * 60 * 60 // 30 days
    
    // Background task identifiers
    private let dailyCleanupTaskID = "com.calendarnotes.daily.cleanup"
    private let weeklyCleanupTaskID = "com.calendarnotes.weekly.cleanup"
    private let monthlyCleanupTaskID = "com.calendarnotes.monthly.cleanup"
    
    // MARK: - Initialization
    
    init(dataManager: DataManagementService = DataManagementService(), 
         coreDataManager: CoreDataManager = .shared) {
        self.dataManager = dataManager
        self.coreDataManager = coreDataManager
        
        loadCleanupDates()
        setupBackgroundTasks()
        requestNotificationPermissions()
    }
    
    // MARK: - Background Task Setup
    
    private func setupBackgroundTasks() {
        #if os(iOS)
        // Register background task handlers
        BGTaskScheduler.shared.register(forTaskWithIdentifier: dailyCleanupTaskID, using: nil) { task in
            self.handleDailyCleanup(task: task as! BGAppRefreshTask)
        }
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: weeklyCleanupTaskID, using: nil) { task in
            self.handleWeeklyCleanup(task: task as! BGProcessingTask)
        }
        
        BGTaskScheduler.shared.register(forTaskWithIdentifier: monthlyCleanupTaskID, using: nil) { task in
            self.handleMonthlyCleanup(task: task as! BGProcessingTask)
        }
        
        scheduleBackgroundTasks()
        #else
        // On macOS or other platforms, use alternative scheduling
        scheduleAlternativeCleanup()
        #endif
    }
    
    private func scheduleBackgroundTasks() {
        #if os(iOS)
        // Schedule daily cleanup
        let dailyRequest = BGAppRefreshTaskRequest(identifier: dailyCleanupTaskID)
        dailyRequest.earliestBeginDate = Date(timeIntervalSinceNow: dailyCleanupInterval)
        
        do {
            try BGTaskScheduler.shared.submit(dailyRequest)
            print("✅ Daily cleanup task scheduled")
        } catch {
            print("❌ Failed to schedule daily cleanup: \(error)")
        }
        
        // Schedule weekly cleanup
        let weeklyRequest = BGProcessingTaskRequest(identifier: weeklyCleanupTaskID)
        weeklyRequest.earliestBeginDate = Date(timeIntervalSinceNow: weeklyCleanupInterval)
        weeklyRequest.requiresNetworkConnectivity = false
        weeklyRequest.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(weeklyRequest)
            print("✅ Weekly cleanup task scheduled")
        } catch {
            print("❌ Failed to schedule weekly cleanup: \(error)")
        }
        
        // Schedule monthly cleanup
        let monthlyRequest = BGProcessingTaskRequest(identifier: monthlyCleanupTaskID)
        monthlyRequest.earliestBeginDate = Date(timeIntervalSinceNow: monthlyCleanupInterval)
        monthlyRequest.requiresNetworkConnectivity = false
        monthlyRequest.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(monthlyRequest)
            print("✅ Monthly cleanup task scheduled")
        } catch {
            print("❌ Failed to schedule monthly cleanup: \(error)")
        }
        
        isScheduled = true
        #endif
    }
    
    private func scheduleAlternativeCleanup() {
        // Alternative cleanup scheduling for platforms without BackgroundTasks
        print("📅 Using alternative cleanup scheduling")
        isScheduled = true
    }
    
    // MARK: - Background Task Handlers
    
    #if os(iOS)
    private func handleDailyCleanup(task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            do {
                // Perform daily cleanup tasks
                try await performDailyCleanup()
                
                // Schedule next daily cleanup
                scheduleNextDailyCleanup()
                
                task.setTaskCompleted(success: true)
            } catch {
                print("❌ Daily cleanup failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    private func handleWeeklyCleanup(task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            do {
                // Perform weekly cleanup tasks
                try await performWeeklyCleanup()
                
                // Schedule next weekly cleanup
                scheduleNextWeeklyCleanup()
                
                task.setTaskCompleted(success: true)
            } catch {
                print("❌ Weekly cleanup failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    
    private func handleMonthlyCleanup(task: BGProcessingTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            do {
                // Perform monthly cleanup tasks
                try await performMonthlyCleanup()
                
                // Schedule next monthly cleanup
                scheduleNextMonthlyCleanup()
                
                task.setTaskCompleted(success: true)
            } catch {
                print("❌ Monthly cleanup failed: \(error)")
                task.setTaskCompleted(success: false)
            }
        }
    }
    #endif
    
    // MARK: - Cleanup Tasks
    
    private func performDailyCleanup() async throws {
        print("🧹 Starting daily cleanup...")
        
        // Clean up old completed tasks (30 days)
        try await cleanupOldCompletedTasks(days: 30)
        
        // Clear temporary cache files
        try await dataManager.clearCache()
        
        // Update storage info
        await dataManager.calculateStorageInfo()
        
        await MainActor.run {
            lastCleanupDate = Date()
            UserDefaults.standard.set(Date(), forKey: "lastCleanupDate")
        }
        
        print("✅ Daily cleanup completed")
    }
    
    private func performWeeklyCleanup() async throws {
        print("🧹 Starting weekly cleanup...")
        
        // Archive old notes (90 days)
        try await dataManager.archiveOldNotes(olderThanDays: 90)
        
        // Compress database
        try await dataManager.compressDatabase()
        
        // Clean up old archived notes (180 days)
        try await cleanupOldArchivedNotes(days: 180)
        
        print("✅ Weekly cleanup completed")
    }
    
    private func performMonthlyCleanup() async throws {
        print("🧹 Starting monthly cleanup...")
        
        // Delete very old events (1 year)
        try await dataManager.batchDeleteOldEvents(olderThanDays: 365)
        
        // Full database optimization
        try await dataManager.compressDatabase()
        
        // Send cleanup notification
        await sendCleanupNotification()
        
        print("✅ Monthly cleanup completed")
    }
    
    // MARK: - Cleanup Helper Methods
    
    private func cleanupOldCompletedTasks(days: Int) async throws {
        try await coreDataManager.performBackgroundTask { context in
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
            
            let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
            request.predicate = NSPredicate(format: "isCompleted == YES AND dueDate < %@", cutoffDate as NSDate)
            
            let todos = try context.fetch(request)
            for todo in todos {
                context.delete(todo)
            }
            
            try context.save()
        }
    }
    
    private func cleanupOldArchivedNotes(days: Int) async throws {
        try await coreDataManager.performBackgroundTask { context in
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date())!
            
            let request: NSFetchRequest<Note> = Note.fetchRequest()
            request.predicate = NSPredicate(format: "createdDate < %@", cutoffDate as NSDate)
            
            let notes = try context.fetch(request)
            for note in notes {
                context.delete(note)
            }
            
            try context.save()
        }
    }
    
    // MARK: - Next Task Scheduling
    
    private func scheduleNextDailyCleanup() {
        #if os(iOS)
        let request = BGAppRefreshTaskRequest(identifier: dailyCleanupTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: dailyCleanupInterval)
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Next daily cleanup scheduled")
        } catch {
            print("❌ Failed to schedule next daily cleanup: \(error)")
        }
        #endif
    }
    
    private func scheduleNextWeeklyCleanup() {
        #if os(iOS)
        let request = BGProcessingTaskRequest(identifier: weeklyCleanupTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: weeklyCleanupInterval)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Next weekly cleanup scheduled")
        } catch {
            print("❌ Failed to schedule next weekly cleanup: \(error)")
        }
        #endif
    }
    
    private func scheduleNextMonthlyCleanup() {
        #if os(iOS)
        let request = BGProcessingTaskRequest(identifier: monthlyCleanupTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: monthlyCleanupInterval)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower = false
        
        do {
            try BGTaskScheduler.shared.submit(request)
            print("✅ Next monthly cleanup scheduled")
        } catch {
            print("❌ Failed to schedule next monthly cleanup: \(error)")
        }
        #endif
    }
    
    // MARK: - Manual Cleanup Triggers
    
    func triggerImmediateCleanup() async throws {
        try await performDailyCleanup()
    }
    
    func triggerWeeklyCleanup() async throws {
        try await performWeeklyCleanup()
    }
    
    func triggerMonthlyCleanup() async throws {
        try await performMonthlyCleanup()
    }
    
    // MARK: - Notification Management
    
    private func requestNotificationPermissions() {
        notificationCenter.requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if granted {
                print("✅ Notification permissions granted")
            } else {
                print("❌ Notification permissions denied: \(error?.localizedDescription ?? "Unknown error")")
            }
        }
    }
    
    private func sendCleanupNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "CalendarNotes Cleanup"
        content.body = "Monthly cleanup completed. Your data has been optimized."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "cleanup-complete",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
            print("✅ Cleanup notification sent")
        } catch {
            print("❌ Failed to send cleanup notification: \(error)")
        }
    }
    
    // MARK: - Storage Monitoring
    
    func checkStorageAndWarn() async {
        await dataManager.calculateStorageInfo()
        
        if let storageInfo = dataManager.storageInfo, storageInfo.isLowStorage {
            await sendLowStorageNotification()
        }
    }
    
    private func sendLowStorageNotification() async {
        let content = UNMutableNotificationContent()
        content.title = "Low Storage Warning"
        content.body = "CalendarNotes is running low on storage space. Consider cleaning up old data."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "low-storage-warning",
            content: content,
            trigger: nil
        )
        
        do {
            try await notificationCenter.add(request)
            print("⚠️ Low storage notification sent")
        } catch {
            print("❌ Failed to send low storage notification: \(error)")
        }
    }
    
    // MARK: - Cleanup Status
    
    private func loadCleanupDates() {
        lastCleanupDate = UserDefaults.standard.object(forKey: "lastCleanupDate") as? Date
        nextCleanupDate = UserDefaults.standard.object(forKey: "nextCleanupDate") as? Date
    }
    
    func getCleanupStatus() -> CleanupStatus {
        let now = Date()
        
        if let lastCleanup = lastCleanupDate {
            let daysSinceLastCleanup = Calendar.current.dateComponents([.day], from: lastCleanup, to: now).day ?? 0
            
            if daysSinceLastCleanup < 1 {
                return .recent
            } else if daysSinceLastCleanup < 7 {
                return .dueSoon
            } else {
                return .overdue
            }
        } else {
            return .never
        }
    }
    
    // MARK: - Cleanup Statistics
    
    func getCleanupStatistics() async -> CleanupStatistics {
        do {
            let context = coreDataManager.viewContext
            
            // Count total items
            let eventsRequest: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
            let notesRequest: NSFetchRequest<Note> = Note.fetchRequest()
            let todosRequest: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
            
            let totalEvents = try context.count(for: eventsRequest)
            let totalNotes = try context.count(for: notesRequest)
            let totalTodos = try context.count(for: todosRequest)
            
            // Count completed todos
            let completedTodosRequest: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
            completedTodosRequest.predicate = NSPredicate(format: "isCompleted == YES")
            let completedTodos = try context.count(for: completedTodosRequest)
            
            // Count old notes (as a proxy for archived notes since we don't have isArchived)
            let cutoffDate = Calendar.current.date(byAdding: .day, value: -90, to: Date())!
            let archivedNotesRequest: NSFetchRequest<Note> = Note.fetchRequest()
            archivedNotesRequest.predicate = NSPredicate(format: "createdDate < %@", cutoffDate as NSDate)
            let archivedNotes = try context.count(for: archivedNotesRequest)
            
            return CleanupStatistics(
                totalEvents: totalEvents,
                totalNotes: totalNotes,
                totalTodos: totalTodos,
                completedTodos: completedTodos,
                archivedNotes: archivedNotes,
                lastCleanupDate: lastCleanupDate,
                nextCleanupDate: nextCleanupDate
            )
            
        } catch {
            print("❌ Failed to get cleanup statistics: \(error)")
            return CleanupStatistics(
                totalEvents: 0,
                totalNotes: 0,
                totalTodos: 0,
                completedTodos: 0,
                archivedNotes: 0,
                lastCleanupDate: lastCleanupDate,
                nextCleanupDate: nextCleanupDate
            )
        }
    }
}

// MARK: - Supporting Types

enum CleanupStatus {
    case recent
    case dueSoon
    case overdue
    case never
    
    var description: String {
        switch self {
        case .recent:
            return "Recently cleaned"
        case .dueSoon:
            return "Due for cleanup"
        case .overdue:
            return "Overdue for cleanup"
        case .never:
            return "Never cleaned"
        }
    }
    
    var color: SwiftUI.Color {
        switch self {
        case .recent:
            return .green
        case .dueSoon:
            return .orange
        case .overdue:
            return .red
        case .never:
            return .gray
        }
    }
}

struct CleanupStatistics {
    let totalEvents: Int
    let totalNotes: Int
    let totalTodos: Int
    let completedTodos: Int
    let archivedNotes: Int
    let lastCleanupDate: Date?
    let nextCleanupDate: Date?
    
    var cleanupEfficiency: Double {
        let totalItems = totalEvents + totalNotes + totalTodos
        let cleanableItems = completedTodos + archivedNotes
        return totalItems > 0 ? Double(cleanableItems) / Double(totalItems) : 0.0
    }
}
