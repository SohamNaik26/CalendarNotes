//
//  CalendarViewModel.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import Foundation
import CoreData
import Combine
import SwiftUI

// MARK: - Calendar View Mode

enum CalendarViewMode: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
    case year = "Year"
    
    var icon: String {
        switch self {
        case .day: return "calendar.day.timeline.leading"
        case .week: return "calendar"
        case .month: return "calendar.circle"
        case .year: return "calendar.badge.clock"
        }
    }
}

// MARK: - Calendar View Model

class CalendarViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var events: [CalendarEvent] = []
    @Published var tasks: [TodoItem] = []
    @Published var selectedDate: Date = Date()
    @Published var currentDate: Date = Date()
    @Published var currentMonth: Date = Date()
    @Published var viewMode: CalendarViewMode = .month
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var selectedCategories: Set<String> = Set(EventCategory.allCases.map { $0.rawValue })
    @Published var showTasksOnCalendar: Bool = true
    
    // MARK: - Private Properties
    
    private let manager = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    private let calendar = Calendar.current
    
    // MARK: - Computed Properties
    
    var filteredEvents: [CalendarEvent] {
        events.filter { event in
            guard let category = event.category else { return true }
            return selectedCategories.contains(category)
        }
    }
    
    var upcomingEvents: [CalendarEvent] {
        let now = Date()
        return events.filter { event in
            guard let startDate = event.startDate else { return false }
            return startDate >= now
        }.sorted { event1, event2 in
            guard let date1 = event1.startDate, let date2 = event2.startDate else { return false }
            return date1 < date2
        }
    }
    
    var eventsForSelectedDate: [CalendarEvent] {
        eventsForDate(selectedDate)
    }
    
    var eventsGroupedByDate: [Date: [CalendarEvent]] {
        Dictionary(grouping: filteredEvents) { event in
            calendar.startOfDay(for: event.startDate ?? Date())
        }
    }
    
    var tasksGroupedByDate: [Date: [TodoItem]] {
        Dictionary(grouping: tasks) { task in
            guard let dueDate = task.dueDate else { return Date.distantPast }
            return calendar.startOfDay(for: dueDate)
        }.filter { $0.key != Date.distantPast }
    }
    
    var tasksForSelectedDate: [TodoItem] {
        tasksForDate(selectedDate)
    }
    
    func tasksForDate(_ date: Date) -> [TodoItem] {
        let startOfDay = calendar.startOfDay(for: date)
        return tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return calendar.isDate(dueDate, inSameDayAs: startOfDay)
        }.sorted { task1, task2 in
            // Sort by priority then by completion status
            if task1.isCompleted != task2.isCompleted {
                return !task1.isCompleted
            }
            let priority1 = priorityValue(task1.priority ?? "Medium")
            let priority2 = priorityValue(task2.priority ?? "Medium")
            return priority1 > priority2
        }
    }
    
    func taskCount(for date: Date) -> Int {
        tasksForDate(date).count
    }
    
    func activeTaskCount(for date: Date) -> Int {
        tasksForDate(date).filter { !$0.isCompleted }.count
    }
    
    private func priorityValue(_ priority: String) -> Int {
        switch priority {
        case "Urgent": return 4
        case "High": return 3
        case "Medium": return 2
        case "Low": return 1
        default: return 2
        }
    }
    
    // Week view helpers
    var currentWeekDates: [Date] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: currentDate) else {
            return []
        }
        var dates: [Date] = []
        var date = weekInterval.start
        while date < weekInterval.end {
            dates.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        return dates
    }
    
    // MARK: - Initialization
    
    init() {
        setupObservers()
        loadAll()
    }
    
    // MARK: - Setup
    
    private func setupObservers() {
        // Reload events when view mode changes
        $viewMode
            .sink { [weak self] _ in
                self?.loadAll()
            }
            .store(in: &cancellables)
        
        // Reload events when current date changes
        $currentDate
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.loadAll()
            }
            .store(in: &cancellables)
        
        // Reload when selected categories change
        $selectedCategories
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Data Loading
    
    func loadEvents() {
        isLoading = true
        errorMessage = nil
        
        Task { @MainActor in
            do {
                let (startDate, endDate) = getDateRange()
                events = try await manager.fetchAsync(createFetchRequest(from: startDate, to: endDate))
                isLoading = false
            } catch {
                errorMessage = "Failed to load events: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    func loadTasks() {
        Task { @MainActor in
            let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \TodoItem.dueDate, ascending: true)]
            
            do {
                tasks = try await manager.fetchAsync(request)
            } catch {
                print("Failed to load tasks: \(error.localizedDescription)")
            }
        }
    }
    
    func loadAll() {
        loadEvents()
        loadTasks()
    }
    
    private func getDateRange() -> (start: Date, end: Date) {
        switch viewMode {
        case .day:
            let start = calendar.startOfDay(for: currentDate)
            let end = calendar.date(byAdding: .day, value: 1, to: start)!
            return (start, end)
            
        case .week:
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: currentDate) else {
                return (currentDate.startOfDay(), currentDate.endOfDay())
            }
            return (weekInterval.start, weekInterval.end)
            
        case .month:
            let start = currentMonth.startOfMonth()
            let end = currentMonth.endOfMonth()
            return (start, end)
            
        case .year:
            let startOfYear = calendar.dateInterval(of: .year, for: currentDate)?.start ?? currentDate
            let endOfYear = calendar.date(byAdding: .year, value: 1, to: startOfYear)!
            return (startOfYear, endOfYear)
        }
    }
    
    private func createFetchRequest(from startDate: Date, to endDate: Date) -> NSFetchRequest<CalendarEvent> {
        let request: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()
        request.predicate = NSPredicate(
            format: "startDate >= %@ AND startDate <= %@",
            startDate as NSDate,
            endDate as NSDate
        )
        request.sortDescriptors = [NSSortDescriptor(keyPath: \CalendarEvent.startDate, ascending: true)]
        return request
    }
    
    // MARK: - Event Queries
    
    func eventsForDate(_ date: Date) -> [CalendarEvent] {
        let startOfDay = calendar.startOfDay(for: date)
        return filteredEvents.filter { event in
            guard let eventStart = event.startDate else { return false }
            return calendar.isDate(eventStart, inSameDayAs: startOfDay)
        }
    }
    
    func eventsForWeek(_ date: Date) -> [CalendarEvent] {
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else {
            return []
        }
        return filteredEvents.filter { event in
            guard let eventStart = event.startDate else { return false }
            return eventStart >= weekInterval.start && eventStart < weekInterval.end
        }
    }
    
    func hasEvents(on date: Date) -> Bool {
        !eventsForDate(date).isEmpty
    }
    
    // MARK: - Year Navigation Methods
    
    func nextYear() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentDate = calendar.date(byAdding: .year, value: 1, to: currentDate) ?? currentDate
        }
    }
    
    func previousYear() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentDate = calendar.date(byAdding: .year, value: -1, to: currentDate) ?? currentDate
        }
    }
    
    // MARK: - CRUD Operations
    
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        category: String,
        location: String? = nil,
        notes: String? = nil,
        isRecurring: Bool = false,
        recurrenceType: RecurrenceType = .none,
        recurrenceEndDate: Date? = nil
    ) async {
        do {
            let recurrenceRule = isRecurring ? generateRecurrenceRule(type: recurrenceType, endDate: recurrenceEndDate) : nil
            
            _ = try manager.createEvent(
                title: title,
                startDate: startDate,
                endDate: endDate,
                category: category,
                location: location,
                notes: notes,
                isRecurring: isRecurring,
                recurrenceRule: recurrenceRule
            )
            await MainActor.run {
                loadEvents()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to create event: \(error.localizedDescription)"
            }
        }
    }
    
    func updateEvent(
        _ event: CalendarEvent,
        title: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        category: String? = nil,
        location: String? = nil,
        notes: String? = nil,
        isRecurring: Bool? = nil,
        recurrenceType: RecurrenceType? = nil,
        recurrenceEndDate: Date? = nil
    ) async {
        do {
            try manager.update(event) { event in
                if let title = title { event.title = title }
                if let startDate = startDate { event.startDate = startDate }
                if let endDate = endDate { event.endDate = endDate }
                if let category = category { event.category = category }
                if let location = location { event.location = location }
                if let notes = notes { event.notes = notes }
                if let isRecurring = isRecurring { event.isRecurring = isRecurring }
                
                if let recurrenceType = recurrenceType, let isRecurring = isRecurring {
                    if isRecurring {
                        event.recurrenceRule = generateRecurrenceRule(type: recurrenceType, endDate: recurrenceEndDate)
                    } else {
                        event.recurrenceRule = nil
                    }
                }
            }
            await MainActor.run {
                loadEvents()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to update event: \(error.localizedDescription)"
            }
        }
    }
    
    func deleteEvent(_ event: CalendarEvent) async {
        do {
            try manager.delete(event)
            await MainActor.run {
                events.removeAll { $0.id == event.id }
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete event: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func generateRecurrenceRule(type: RecurrenceType, endDate: Date?) -> String? {
        switch type {
        case .none:
            return nil
        case .daily:
            return "FREQ=DAILY"
        case .weekly:
            return "FREQ=WEEKLY"
        case .monthly:
            return "FREQ=MONTHLY"
        case .yearly:
            return "FREQ=YEARLY"
        case .custom:
            return "FREQ=WEEKLY" // Default for custom
        }
    }
    
    func deleteEvents(_ events: [CalendarEvent]) async {
        do {
            try manager.delete(events)
            await MainActor.run {
                loadEvents()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete events: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Navigation
    
    func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: currentMonth) {
            currentMonth = newMonth
            loadEvents()
        }
    }
    
    func changeWeek(by value: Int) {
        if let newDate = calendar.date(byAdding: .weekOfYear, value: value, to: currentDate) {
            currentDate = newDate
        }
    }
    
    func changeDay(by value: Int) {
        if let newDate = calendar.date(byAdding: .day, value: value, to: currentDate) {
            currentDate = newDate
            selectedDate = newDate
        }
    }
    
    func goToToday() {
        currentDate = Date()
        selectedDate = Date()
        currentMonth = Date()
    }
    
    func selectDate(_ date: Date) {
        selectedDate = date
        currentDate = date
    }
    
    // MARK: - Category Management
    
    func toggleCategory(_ category: String) {
        if selectedCategories.contains(category) {
            selectedCategories.remove(category)
        } else {
            selectedCategories.insert(category)
        }
    }
    
    func selectAllCategories() {
        selectedCategories = Set(EventCategory.allCases.map { $0.rawValue })
    }
    
    func deselectAllCategories() {
        selectedCategories.removeAll()
    }
    
    func isCategorySelected(_ category: String) -> Bool {
        selectedCategories.contains(category)
    }
    
    // MARK: - Statistics
    
    var eventCountForSelectedDate: Int {
        eventsForSelectedDate.count
    }
    
    var totalEventsThisMonth: Int {
        let start = currentMonth.startOfMonth()
        let end = currentMonth.endOfMonth()
        return events.filter { event in
            guard let eventStart = event.startDate else { return false }
            return eventStart >= start && eventStart <= end
        }.count
    }
    
    func eventCountByCategory() -> [String: Int] {
        Dictionary(grouping: filteredEvents) { $0.category ?? "Other" }
            .mapValues { $0.count }
    }
    
    // MARK: - Task-Event Conversion
    
    /// Convert a task to a calendar event
    func convertTaskToEvent(_ task: TodoItem) async {
        guard let dueDate = task.dueDate else {
            await MainActor.run {
                errorMessage = "Task must have a due date to convert to event"
            }
            return
        }
        
        let startDate = dueDate
        let endDate = calendar.date(byAdding: .hour, value: 1, to: startDate) ?? startDate
        
        await createEvent(
            title: task.title ?? "Untitled Event",
            startDate: startDate,
            endDate: endDate,
            category: task.category ?? "Personal",
            location: nil,
            notes: "Converted from task",
            isRecurring: task.isRecurring,
            recurrenceType: .none,
            recurrenceEndDate: nil
        )
        
        // Delete the original task
        do {
            try manager.delete(task)
            await MainActor.run {
                loadTasks()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete task after conversion: \(error.localizedDescription)"
            }
        }
    }
    
    /// Convert a calendar event to a task
    func convertEventToTask(_ event: CalendarEvent) async {
        guard let startDate = event.startDate else { return }
        
        do {
            _ = try manager.createTodoItem(
                title: event.title ?? "Untitled Task",
                priority: "Medium",
                category: event.category ?? "Personal",
                dueDate: startDate,
                isCompleted: false,
                isRecurring: event.isRecurring
            )
            
            // Delete the original event
            try manager.delete(event)
            
            await MainActor.run {
                loadEvents()
                loadTasks()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to convert event to task: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Task Operations
    
    func toggleTaskCompletion(_ task: TodoItem) {
        task.isCompleted.toggle()
        
        do {
            try manager.save()
            // Trigger UI update
            objectWillChange.send()
        } catch {
            errorMessage = "Failed to toggle task: \(error.localizedDescription)"
        }
    }
    
    func deleteTask(_ task: TodoItem) async {
        do {
            try manager.delete(task)
            await MainActor.run {
                loadTasks()
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to delete task: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Validation
    
    func validateEventDates(start: Date, end: Date) -> Bool {
        end > start
    }
    
    func hasConflict(startDate: Date, endDate: Date, excluding eventId: UUID? = nil) -> Bool {
        events.contains { event in
            guard event.id != eventId,
                  let eventStart = event.startDate,
                  let eventEnd = event.endDate else {
                return false
            }
            
            // Check if events overlap
            return (startDate < eventEnd && endDate > eventStart)
        }
    }
    
    // MARK: - Navigation Methods
    
    func previousMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentDate = calendar.date(byAdding: .month, value: -1, to: currentDate) ?? currentDate
            currentMonth = currentDate
        }
    }
    
    func nextMonth() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
            currentMonth = currentDate
        }
    }
    
    func previousWeek() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentDate = calendar.date(byAdding: .weekOfYear, value: -1, to: currentDate) ?? currentDate
        }
    }
    
    func nextWeek() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
        }
    }
    
    func previousDay() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            selectedDate = currentDate
        }
    }
    
    func nextDay() {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
            selectedDate = currentDate
        }
    }
}
