//
//  LazyCalendarService.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 23/10/25.
//

import Foundation
import CoreData
import Combine

// MARK: - Lazy Calendar Events Service

class LazyCalendarService: ObservableObject {
    @Published var events: [CalendarEvent] = []
    @Published var isLoading = false
    @Published var isLoadingMore = false
    @Published var hasMoreEvents = true
    @Published var error: Error?
    
    private let coreDataService: OptimizedCoreDataService
    private var cancellables = Set<AnyCancellable>()
    
    // Date range management
    private var currentStartDate: Date
    private var currentEndDate: Date
    private var loadRange: DateInterval
    
    // Pagination
    private var currentPage = 0
    private let pageSize = 30
    
    // Cache for loaded months
    private var loadedMonths: Set<String> = []
    private let monthCacheQueue = DispatchQueue(label: "com.calendarnotes.calendar.cache", attributes: .concurrent)
    
    init(coreDataService: OptimizedCoreDataService = OptimizedCoreDataService()) {
        self.coreDataService = coreDataService
        
        // Initialize with current month
        let calendar = Calendar.current
        let now = Date()
        let monthInterval = calendar.dateInterval(of: .month, for: now)!
        
        self.currentStartDate = monthInterval.start
        self.currentEndDate = monthInterval.end
        self.loadRange = monthInterval
        
        loadInitialEvents()
    }
    
    // MARK: - Date Range Loading
    
    func loadEventsForMonth(_ date: Date) {
        let calendar = Calendar.current
        let monthInterval = calendar.dateInterval(of: .month, for: date)!
        
        let monthKey = monthKey(for: date)
        
        // Check if already loaded
        if monthCacheQueue.sync(execute: { loadedMonths.contains(monthKey) }) {
            return
        }
        
        loadEvents(from: monthInterval.start, to: monthInterval.end)
        
        // Mark as loaded
        monthCacheQueue.async(flags: .barrier) {
            self.loadedMonths.insert(monthKey)
        }
    }
    
    func loadEventsForWeek(_ date: Date) {
        let calendar = Calendar.current
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date)!
        
        loadEvents(from: weekInterval.start, to: weekInterval.end)
    }
    
    func loadEventsForDay(_ date: Date) {
        let calendar = Calendar.current
        let dayInterval = calendar.dateInterval(of: .day, for: date)!
        
        loadEvents(from: dayInterval.start, to: dayInterval.end)
    }
    
    private func loadEvents(from startDate: Date, to endDate: Date) {
        isLoading = true
        error = nil
        currentPage = 0
        hasMoreEvents = true
        
        coreDataService.fetchEventsAsync(from: startDate, to: endDate, page: currentPage, pageSize: pageSize)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoading = false
                    if case .failure(let error) = completion {
                        self?.error = error
                    }
                },
                receiveValue: { [weak self] newEvents in
                    self?.handleNewEvents(newEvents)
                }
            )
            .store(in: &cancellables)
    }
    
    private func loadInitialEvents() {
        loadEvents(from: currentStartDate, to: currentEndDate)
    }
    
    // MARK: - Pagination
    
    func loadMoreEvents() {
        guard !isLoadingMore && hasMoreEvents && !isLoading else { return }
        
        isLoadingMore = true
        currentPage += 1
        
        coreDataService.fetchEventsAsync(from: currentStartDate, to: currentEndDate, page: currentPage, pageSize: pageSize)
            .sink(
                receiveCompletion: { [weak self] completion in
                    self?.isLoadingMore = false
                    if case .failure(let error) = completion {
                        self?.error = error
                        self?.currentPage -= 1 // Revert page increment on error
                    }
                },
                receiveValue: { [weak self] newEvents in
                    self?.handleNewEvents(newEvents, append: true)
                }
            )
            .store(in: &cancellables)
    }
    
    private func handleNewEvents(_ newEvents: [CalendarEvent], append: Bool = false) {
        if append {
            events.append(contentsOf: newEvents)
        } else {
            events = newEvents
        }
        
        // Update pagination state
        hasMoreEvents = newEvents.count >= pageSize
        
        // Sort events by start date
        events.sort { ($0.startDate ?? Date.distantPast) < ($1.startDate ?? Date.distantPast) }
    }
    
    // MARK: - Event Filtering
    
    func eventsForDate(_ date: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        return events.filter { event in
            guard let startDate = event.startDate else { return false }
            return calendar.isDate(startDate, inSameDayAs: date)
        }
    }
    
    func eventsForDateRange(_ startDate: Date, _ endDate: Date) -> [CalendarEvent] {
        return events.filter { event in
            guard let eventStart = event.startDate, let eventEnd = event.endDate else { return false }
            
            // Check if event overlaps with the date range
            return (eventStart <= endDate) && (eventEnd >= startDate)
        }
    }
    
    // MARK: - Cache Management
    
    private func monthKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
    
    func clearCache() {
        monthCacheQueue.async(flags: .barrier) {
            self.loadedMonths.removeAll()
        }
        events = []
        coreDataService.clearAllCache()
    }
    
    func preloadAdjacentMonths() {
        let calendar = Calendar.current
        
        // Preload previous month
        if let previousMonth = calendar.date(byAdding: .month, value: -1, to: currentStartDate) {
            loadEventsForMonth(previousMonth)
        }
        
        // Preload next month
        if let nextMonth = calendar.date(byAdding: .month, value: 1, to: currentStartDate) {
            loadEventsForMonth(nextMonth)
        }
    }
    
    // MARK: - Performance Helpers
    
    func getLoadedMonths() -> [String] {
        return monthCacheQueue.sync {
            Array(loadedMonths).sorted()
        }
    }
    
    func getCacheStatistics() -> (loadedMonths: Int, eventsCount: Int, hasMore: Bool) {
        return (
            loadedMonths: loadedMonths.count,
            eventsCount: events.count,
            hasMore: hasMoreEvents
        )
    }
}

// MARK: - Lazy Calendar View Model

class LazyCalendarViewModel: ObservableObject {
    @Published var selectedDate: Date = Date()
    @Published var eventsForSelectedDate: [CalendarEvent] = []
    @Published var isLoadingEvents = false
    
    private let lazyCalendarService: LazyCalendarService
    private var cancellables = Set<AnyCancellable>()
    
    init(lazyCalendarService: LazyCalendarService = LazyCalendarService()) {
        self.lazyCalendarService = lazyCalendarService
        setupBindings()
    }
    
    private func setupBindings() {
        // Load events when selected date changes
        $selectedDate
            .sink { [weak self] date in
                self?.loadEventsForSelectedDate()
            }
            .store(in: &cancellables)
        
        // Update events for selected date when events change
        lazyCalendarService.$events
            .sink { [weak self] _ in
                self?.updateEventsForSelectedDate()
            }
            .store(in: &cancellables)
    }
    
    private func loadEventsForSelectedDate() {
        isLoadingEvents = true
        
        // Load events for the month containing the selected date
        lazyCalendarService.loadEventsForMonth(selectedDate)
        
        // Also load events for the specific day
        lazyCalendarService.loadEventsForDay(selectedDate)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isLoadingEvents = false
        }
    }
    
    private func updateEventsForSelectedDate() {
        eventsForSelectedDate = lazyCalendarService.eventsForDate(selectedDate)
    }
    
    func selectDate(_ date: Date) {
        selectedDate = date
    }
    
    func loadMoreEvents() {
        lazyCalendarService.loadMoreEvents()
    }
    
    func preloadAdjacentMonths() {
        lazyCalendarService.preloadAdjacentMonths()
    }
}

