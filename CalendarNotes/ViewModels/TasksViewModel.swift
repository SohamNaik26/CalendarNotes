//
//  TasksViewModel.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import Foundation
import CoreData
import Combine
#if os(macOS)
import AppKit
#endif

enum TaskFilter: String, CaseIterable {
    case all = "All"
    case active = "Active"
    case completed = "Completed"
}

enum TaskSortOption: String, CaseIterable {
    case dueDate = "Due Date"
    case priority = "Priority"
    case creationDate = "Created"
    
    var systemImage: String {
        switch self {
        case .dueDate: return "calendar"
        case .priority: return "flag.fill"
        case .creationDate: return "clock"
        }
    }
}

class TasksViewModel: ObservableObject {
    @Published var tasks: [TodoItem] = []
    @Published var filter: TaskFilter = .active
    @Published var sortOption: TaskSortOption = .dueDate
    @Published var selectedTask: TodoItem?
    @Published var showingTaskEditor = false
    
    let coreDataService: CoreDataService
    private var cancellables = Set<AnyCancellable>()
    private var archiveTimer: Timer?
    
    init(coreDataService: CoreDataService = CoreDataService()) {
        self.coreDataService = coreDataService
        loadTasks()
        setupArchiveTimer()
    }
    
    // MARK: - Load Tasks
    func loadTasks() {
        tasks = coreDataService.fetchAllTodoItems()
    }
    
    // MARK: - Filtered and Sorted Tasks
    var filteredTasks: [TodoItem] {
        let filtered: [TodoItem]
        switch filter {
        case .all:
            filtered = tasks
        case .active:
            filtered = tasks.filter { !$0.isCompleted }
        case .completed:
            filtered = tasks.filter { $0.isCompleted }
        }
        
        return sortTasks(filtered)
    }
    
    private func sortTasks(_ tasks: [TodoItem]) -> [TodoItem] {
        switch sortOption {
        case .dueDate:
            return tasks.sorted { task1, task2 in
                guard let date1 = task1.dueDate else { return false }
                guard let date2 = task2.dueDate else { return true }
                return date1 < date2
            }
        case .priority:
            return tasks.sorted { task1, task2 in
                let priority1 = task1.priorityEnum
                let priority2 = task2.priorityEnum
                return priorityValue(priority1) > priorityValue(priority2)
            }
        case .creationDate:
            return tasks.sorted { task1, task2 in
                guard let date1 = task1.id?.uuidString else { return false }
                guard let date2 = task2.id?.uuidString else { return true }
                return date1 > date2
            }
        }
    }
    
    private func priorityValue(_ priority: TodoItem.Priority) -> Int {
        switch priority {
        case .urgent: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
    
    // MARK: - Sectioned Tasks
    var overdueTasks: [TodoItem] {
        filteredTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return !task.isCompleted && dueDate < Calendar.current.startOfDay(for: Date())
        }
    }
    
    var todayTasks: [TodoItem] {
        filteredTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            let today = Calendar.current.startOfDay(for: Date())
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!
            return !task.isCompleted && dueDate >= today && dueDate < tomorrow
        }
    }
    
    var upcomingTasks: [TodoItem] {
        filteredTasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: Date()))!
            return !task.isCompleted && dueDate >= tomorrow
        }
    }
    
    var noDueDateTasks: [TodoItem] {
        filteredTasks.filter { $0.dueDate == nil && !$0.isCompleted }
    }
    
    var completedTasks: [TodoItem] {
        filteredTasks.filter { $0.isCompleted }
    }
    
    // MARK: - Task Counts
    var overdueCount: Int { overdueTasks.count }
    var todayCount: Int { todayTasks.count }
    var upcomingCount: Int { upcomingTasks.count }
    var completedCount: Int { completedTasks.count }
    
    var hasTasks: Bool {
        !overdueTasks.isEmpty || !todayTasks.isEmpty || !upcomingTasks.isEmpty || !noDueDateTasks.isEmpty || !completedTasks.isEmpty
    }
    var activeCount: Int { tasks.filter { !$0.isCompleted }.count }
    
    // MARK: - Task Operations
    func addTask(title: String, priority: String, category: String, dueDate: Date? = nil) {
        do {
            try coreDataService.createTodoItem(title: title, priority: priority, category: category, dueDate: dueDate)
            loadTasks()
        } catch {
            print("Error creating task: \(error)")
        }
    }
    
    func toggleTaskCompletion(_ task: TodoItem) {
        do {
            try coreDataService.toggleTodoCompletion(task)
            loadTasks()
        } catch {
            print("Error toggling task: \(error)")
        }
    }
    
    func deleteTask(_ task: TodoItem) {
        do {
            try coreDataService.deleteTodoItem(task)
            loadTasks()
        } catch {
            print("Error deleting task: \(error)")
        }
    }
    
    func editTask(_ task: TodoItem) {
        selectedTask = task
        showingTaskEditor = true
    }
    
    // MARK: - Auto-Archive
    private func setupArchiveTimer() {
        // Check for tasks to archive every hour
        archiveTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { [weak self] _ in
            self?.archiveOldCompletedTasks()
        }
        // Also run on init
        archiveOldCompletedTasks()
    }
    
    func archiveOldCompletedTasks() {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        
        let tasksToArchive = completedTasks.filter { task in
            // If task was completed more than 7 days ago, archive it
            // For now, we'll delete it (could implement an archive flag in future)
            guard let dueDate = task.dueDate else { return false }
            return dueDate < sevenDaysAgo
        }
        
        for task in tasksToArchive {
            do {
                try coreDataService.deleteTodoItem(task)
            } catch {
                print("Error archiving task: \(error)")
            }
        }
        
        if !tasksToArchive.isEmpty {
            loadTasks()
        }
    }
    
    // MARK: - Share Task
    func shareTask(_ task: TodoItem) {
        #if os(macOS)
        let shareText = "Task: \(task.title ?? "Untitled")\nPriority: \(task.priority ?? "Medium")\nCategory: \(task.category ?? "Other")"
        
        if let dueDate = task.dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            let dateString = formatter.string(from: dueDate)
            let fullText = "\(shareText)\nDue Date: \(dateString)"
            
            let sharingService = NSSharingService(named: .composeEmail)
            sharingService?.perform(withItems: [fullText])
        } else {
            let sharingService = NSSharingService(named: .composeEmail)
            sharingService?.perform(withItems: [shareText])
        }
        #else
        // iOS implementation would go here
        print("Share task: \(task.title ?? "Untitled")")
        #endif
    }
    
    deinit {
        archiveTimer?.invalidate()
    }
}


