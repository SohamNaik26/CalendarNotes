//
//  CalendarView.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import SwiftUI
import CoreData
#if os(iOS)
import UIKit
#else
import AppKit
#endif

// MARK: - Date Formatters

private let monthYearFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMMM yyyy"
    return formatter
}()

private let dayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "d"
    return formatter
}()

private let weekdayFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "EEEE"
    return formatter
}()

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter
}()

struct CalendarFilterOptions {
    var showScheduledReminders: Bool
    var showBirthdays: Bool
    var showHolidays: Bool
    var showSiriSuggestions: Bool
}

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @StateObject private var filterViewModel = FilterViewModel()
    @State private var showingAddEvent = false
    @State private var showingReadingList = false
    @State private var dragOffset: CGFloat = 0
    #if os(iOS)
    @State private var sidebarVisibility: NavigationSplitViewVisibility = .doubleColumn
    #endif
    
    private var controlBackgroundColor: Color {
        return Color.cnSecondaryBackground
    }
    
    private var textBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.textBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    var filteredEvents: [CalendarEvent] {
        filterViewModel.filterEvents(viewModel.events)
    }
    
    var filteredTasks: [TodoItem] {
        filterViewModel.filterTasks(viewModel.tasks)
    }
    
    private func holidayEventsForDate(_ date: Date) -> [HolidayEvent] {
        guard filterViewModel.calendarFilterOptions.showHolidays else { return [] }
        var holidayEvents: [HolidayEvent] = []
        
        // Add Indian holidays
        let indianHolidays = IndianHolidaysService.shared.getHolidaysForDate(date)
        holidayEvents.append(contentsOf: indianHolidays.map { holiday in
            HolidayEvent(
                title: holiday.name,
                date: holiday.date,
                category: "Indian Holiday"
            )
        })
        
        // Add international festivals
        let internationalFestivals = InternationalFestivalsService.shared.getFestivalsForDate(date)
        holidayEvents.append(contentsOf: internationalFestivals.map { festival in
            HolidayEvent(
                title: festival.name,
                date: festival.date,
                category: "Festival"
            )
        })
        
        return holidayEvents
    }
    
    private var backgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    var body: some View {
        ZStack {
            // Background
            backgroundColor
                .ignoresSafeArea(.keyboard, edges: .bottom)
            
            VStack(spacing: 0) {
                // Top Controls Bar - Always Visible
                HStack(spacing: 16) {
                    // View Mode Picker - Prominent and Always Visible
                    HStack(spacing: 4) {
                        ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.viewMode = mode
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: mode.icon)
                                        .font(.system(size: 14, weight: .medium))
                                    Text(mode.rawValue)
                                        .font(.system(size: 14, weight: .medium))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(viewModel.viewMode == mode ? Color.cnAccent : Color.cnSecondaryBackground)
                                )
                                .foregroundColor(viewModel.viewMode == mode ? .white : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                
                Spacer()
                
                // Filter and Add buttons - Compact
                HStack(spacing: 8) {
                    Button(action: {
                        withAnimation {
                            filterViewModel.showFilterPanel.toggle()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "line.3.horizontal.decrease.circle")
                                .font(.subheadline)
                            if filterViewModel.hasActiveFilters {
                                FilterBadge(count: filterViewModel.activeFilterCount)
                            }
                        }
                        .foregroundColor(.cnAccent)
                        .frame(width: 44, height: 44)
                        .background(
                            filterViewModel.hasActiveFilters 
                                ? Color.cnAccent.opacity(0.1) 
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button(action: {
                        showingAddEvent = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("Add")
                        }
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .frame(minHeight: 44)
                        .background(
                            LinearGradient(
                                colors: [Color.cnAccent, Color.cnAccent.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(Capsule())
                    }

                    Button(action: { showingReadingList = true }) {
                        Image(systemName: "book")
                            .font(.subheadline)
                            .foregroundColor(.cnAccent)
                            .frame(width: 44, height: 44)
                            .background(Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .background(controlBackgroundColor)
            
            // Quick Filter Chips
            if filterViewModel.hasActiveFilters {
                QuickFilterChips(viewModel: filterViewModel)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Main Content with Sidebar - Responsive Layout
            #if os(iOS)
            if #available(iOS 16.0, *) {
                // Use NavigationSplitView for iPhone (especially large devices) to show full layout like Mac
                NavigationSplitView(columnVisibility: $sidebarVisibility) {
                    // Sidebar
                    CalendarSidebar(
                        filterViewModel: filterViewModel,
                        onFilterChange: { }
                    )
                    .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 360)
                } detail: {
                    // Full Page Calendar Content
                    GeometryReader { geometry in
                        Group {
                            switch viewModel.viewMode {
                            case .month:
                                ScrollableMonthView(
                                    viewModel: viewModel,
                                    filteredEvents: filteredEvents,
                                    filteredTasks: filteredTasks,
                                    geometry: geometry,
                                    filterOptions: filterViewModel.calendarFilterOptions
                                )
                            case .week:
                                FullPageWeekView(
                                    viewModel: viewModel,
                                    filteredEvents: filteredEvents,
                                    filteredTasks: filteredTasks,
                                    geometry: geometry
                                )
                            case .day:
                                FullPageDayView(
                                    viewModel: viewModel,
                                    filteredEvents: filteredEvents,
                                    filteredTasks: filteredTasks,
                                    geometry: geometry
                                )
                            case .year:
                                FullPageYearView(
                                    viewModel: viewModel,
                                    filteredEvents: filteredEvents,
                                    filteredTasks: filteredTasks,
                                    geometry: geometry
                                )
                            }
                        }
                        .id(viewModel.viewMode) // Force view identity change for smooth transitions
                        .toolbar {
                            ToolbarItem(placement: .navigationBarLeading) {
                                Button {
                                    withAnimation {
                                        sidebarVisibility = sidebarVisibility == .doubleColumn ? .detailOnly : .doubleColumn
                                    }
                                } label: {
                                    Image(systemName: sidebarVisibility == .doubleColumn ? "sidebar.left" : "sidebar.right")
                                }
                            }
                        }
                    }
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                // Fallback for iOS < 16: Show sidebar only on large devices, hide on smaller ones
                HStack(spacing: 0) {
                    if ScreenSize.isLargeDevice || ScreenSize.isExtraLargeDevice {
                        // Sidebar - only show on large iPhones
                        CalendarSidebar(
                            filterViewModel: filterViewModel,
                            onFilterChange: { }
                        )
                        .frame(width: 280)
                    }
                    
                    // Full Page Calendar Content
                    GeometryReader { geometry in
                        Group {
                            switch viewModel.viewMode {
                            case .month:
                                ScrollableMonthView(
                                    viewModel: viewModel,
                                    filteredEvents: filteredEvents,
                                    filteredTasks: filteredTasks,
                                    geometry: geometry,
                                    filterOptions: filterViewModel.calendarFilterOptions
                                )
                            case .week:
                                FullPageWeekView(
                                    viewModel: viewModel,
                                    filteredEvents: filteredEvents,
                                    filteredTasks: filteredTasks,
                                    geometry: geometry
                                )
                            case .day:
                                FullPageDayView(
                                    viewModel: viewModel,
                                    filteredEvents: filteredEvents,
                                    filteredTasks: filteredTasks,
                                    geometry: geometry
                                )
                            case .year:
                                FullPageYearView(
                                    viewModel: viewModel,
                                    filteredEvents: filteredEvents,
                                    filteredTasks: filteredTasks,
                                    geometry: geometry
                                )
                            }
                        }
                        .id(viewModel.viewMode) // Force view identity change for smooth transitions
                    }
                }
            }
            #else
            // macOS: Keep original HStack layout
            HStack(spacing: 0) {
                // Sidebar
                CalendarSidebar(
                    filterViewModel: filterViewModel,
                    onFilterChange: { }
                )
                .frame(width: 340)
                
                // Full Page Calendar Content
                GeometryReader { geometry in
                    Group {
                        switch viewModel.viewMode {
                        case .month:
                            ScrollableMonthView(
                                viewModel: viewModel,
                                filteredEvents: filteredEvents,
                                filteredTasks: filteredTasks,
                                geometry: geometry,
                                filterOptions: filterViewModel.calendarFilterOptions
                            )
                        case .week:
                            FullPageWeekView(
                                viewModel: viewModel,
                                filteredEvents: filteredEvents,
                                filteredTasks: filteredTasks,
                                geometry: geometry
                            )
                        case .day:
                            FullPageDayView(
                                viewModel: viewModel,
                                filteredEvents: filteredEvents,
                                filteredTasks: filteredTasks,
                                geometry: geometry
                            )
                        case .year:
                            FullPageYearView(
                                viewModel: viewModel,
                                filteredEvents: filteredEvents,
                                filteredTasks: filteredTasks,
                                geometry: geometry
                            )
                        }
                    }
                    .id(viewModel.viewMode) // Force view identity change for smooth transitions
                }
            }
            #endif
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 0)
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(viewModel: viewModel)
                .presentationCornerRadius(20)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .overlay(alignment: .center) {
            if filterViewModel.showFilterPanel {
                FilterModalOverlay(viewModel: filterViewModel)
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showingReadingList) {
            ReadingListView()
                .presentationCornerRadius(20)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .onAppear {
            // Ensure sidebar is visible on large devices for full calendar view
            #if os(iOS)
            if ScreenSize.isLargeDevice || ScreenSize.isExtraLargeDevice {
                sidebarVisibility = .doubleColumn
            }
            // Ensure view mode is set to month by default
            if viewModel.viewMode != .month {
                viewModel.viewMode = .month
            }
            #endif
        }
        .task {
            // Ensure we start with the current date
            await MainActor.run {
                viewModel.currentDate = Date()
                viewModel.currentMonth = Date()
            }
            viewModel.loadAll()
        }
    }
}

// MARK: - Month View Content

struct MonthViewContent: View {
    @ObservedObject var viewModel: CalendarViewModel
    @ObservedObject var filterViewModel: FilterViewModel
    @Binding var dragOffset: CGFloat
    var filteredEvents: [CalendarEvent] = []
    var filteredTasks: [TodoItem] = []
    @State private var selectedTask: TodoItem?
    @State private var showingTaskDetail = false
    @State private var showingTaskEditor = false
    @State private var taskToEdit: TodoItem?
    @StateObject private var tasksViewModel = TasksViewModel()
    
    private func holidayEventsForDate(_ date: Date) -> [HolidayEvent] {
        guard filterViewModel.calendarFilterOptions.showHolidays else { return [] }
        var holidayEvents: [HolidayEvent] = []
        
        // Add Indian holidays
        let indianHolidays = IndianHolidaysService.shared.getHolidaysForDate(date)
        holidayEvents.append(contentsOf: indianHolidays.map { holiday in
            HolidayEvent(
                title: holiday.name,
                date: holiday.date,
                category: "Indian Holiday"
            )
        })
        
        // Add international festivals
        let internationalFestivals = InternationalFestivalsService.shared.getFestivalsForDate(date)
        holidayEvents.append(contentsOf: internationalFestivals.map { festival in
            HolidayEvent(
                title: festival.name,
                date: festival.date,
                category: "Festival"
            )
        })
        
        return holidayEvents
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Month Navigation Header
            MonthNavigationHeader(
                currentMonth: viewModel.currentMonth,
                onPrevious: { withAnimation(.spring()) { viewModel.changeMonth(by: -1) } },
                onNext: { withAnimation(.spring()) { viewModel.changeMonth(by: 1) } },
                onToday: { withAnimation(.spring()) { viewModel.goToToday() } }
            )
                
            // Calendar Grid
            CalendarGridView(
                currentMonth: viewModel.currentMonth,
                selectedDate: $viewModel.selectedDate,
                events: filteredEvents,
                tasks: filteredTasks,
                showHolidays: filterViewModel.calendarFilterOptions.showHolidays,
                onDateTap: { date in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.selectDate(date)
                    }
                }
            )
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let threshold: CGFloat = 50
                        if value.translation.width < -threshold {
                            withAnimation(.spring()) {
                                viewModel.changeMonth(by: 1)
                            }
                        } else if value.translation.width > threshold {
                            withAnimation(.spring()) {
                                viewModel.changeMonth(by: -1)
                            }
                        }
                        dragOffset = 0
                    }
            )
            
            Divider()
            
            // Events and Tasks List for Selected Date
            EventsListSection(
                selectedDate: viewModel.selectedDate,
                events: filteredEvents.filter { event in
                    guard let startDate = event.startDate else { return false }
                    return Calendar.current.isDate(startDate, inSameDayAs: viewModel.selectedDate)
                },
                tasks: filteredTasks.filter { task in
                    guard let dueDate = task.dueDate else { return false }
                    return Calendar.current.isDate(dueDate, inSameDayAs: viewModel.selectedDate)
                },
                holidayEvents: holidayEventsForDate(viewModel.selectedDate),
                onDelete: { event in
                    Task {
                        await viewModel.deleteEvent(event)
                    }
                },
                onTaskToggle: { task in
                    viewModel.toggleTaskCompletion(task)
                },
                onTaskTap: { task in
                    selectedTask = task
                    showingTaskDetail = true
                }
            )
        }
        .sheet(isPresented: $showingTaskDetail) {
            if let task = selectedTask {
                TaskDetailSheetView(
                    task: task,
                    onToggleComplete: {
                        viewModel.toggleTaskCompletion(task)
                    },
                    onConvertToEvent: {
                        Task {
                            await viewModel.convertTaskToEvent(task)
                        }
                    },
                    onEdit: {
                        taskToEdit = task
                        showingTaskEditor = true
                    },
                    onDelete: {
                        Task {
                            await viewModel.deleteTask(task)
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingTaskEditor) {
            EnhancedTaskEditorView(viewModel: tasksViewModel, task: taskToEdit)
        }
    }
}

// MARK: - Week View Content

struct WeekViewContent: View {
    @ObservedObject var viewModel: CalendarViewModel
    var filteredEvents: [CalendarEvent] = []
    var filteredTasks: [TodoItem] = []
    @State private var selectedEvent: CalendarEvent?
    @State private var showingEventDetail = false
    @State private var showingAddEvent = false
    @State private var newEventDate: Date?
    @State private var newEventHour: Int = 0
    
    // Time slots (0-23 hours)
    private let hours = Array(0..<24)
    private let hourHeight: CGFloat = 80
    private let columnWidth: CGFloat = 50
    
    var body: some View {
        VStack(spacing: 0) {
            // Week Navigation Header
            WeekNavigationHeader(
                currentWeek: viewModel.currentDate,
                onPrevious: {
                    withAnimation(.spring()) {
                        viewModel.changeWeek(by: -1)
                    }
                },
                onNext: {
                    withAnimation(.spring()) {
                        viewModel.changeWeek(by: 1)
                    }
                },
                onToday: {
                    withAnimation(.spring()) {
                        viewModel.goToToday()
                    }
                }
            )
            
            Divider()
            
            // All-Day Events Section
            if !allDayEvents.isEmpty {
                AllDayEventsSection(events: allDayEvents)
                Divider()
            }
            
            // Week View Grid
            WeekGridView(
                weekDates: viewModel.currentWeekDates,
                events: viewModel.eventsForWeek(viewModel.currentDate),
                hours: hours,
                hourHeight: hourHeight,
                columnWidth: columnWidth,
                onEventTap: { event in
                    selectedEvent = event
                    showingEventDetail = true
                    #if os(iOS)
                    generateHapticFeedback(style: .light)
                    #endif
                },
                onLongPress: { date, hour in
                    newEventDate = date
                    newEventHour = hour
                    showingAddEvent = true
                    #if os(iOS)
                    generateHapticFeedback(style: .medium)
                    #endif
                }
            )
        }
        .sheet(isPresented: $showingAddEvent) {
            Group {
                if let date = newEventDate {
                    AddEventView(
                        viewModel: viewModel,
                        preselectedDate: date,
                        preselectedHour: newEventHour
                    )
                } else {
                    AddEventView(viewModel: viewModel)
                }
            }
            .presentationCornerRadius(20)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingEventDetail) {
            if let event = selectedEvent {
                EventDetailView(event: event, viewModel: viewModel)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    private var allDayEvents: [CalendarEvent] {
        viewModel.eventsForWeek(viewModel.currentDate).filter { event in
            guard let start = event.startDate, let end = event.endDate else { return false }
            let calendar = Calendar.current
            return calendar.component(.hour, from: start) == 0 &&
                   calendar.component(.minute, from: start) == 0 &&
                   calendar.component(.hour, from: end) == 0 &&
                   calendar.component(.minute, from: end) == 0
        }
    }
    
    #if os(iOS)
    private func generateHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    #endif
}

// MARK: - Day View Content

struct DayViewContent: View {
    @ObservedObject var viewModel: CalendarViewModel
    var filteredEvents: [CalendarEvent] = []
    var filteredTasks: [TodoItem] = []
    @State private var selectedEvent: CalendarEvent?
    @State private var showingEventDetail = false
    @State private var showingAddEvent = false
    @State private var newEventHour: Int = 0
    @State private var dragOffset: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    
    // Time configuration
    private let hours = Array(0..<24)
    private let hourHeight: CGFloat = 120
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Day Navigation Header
                DayNavigationHeader(
                    currentDate: viewModel.selectedDate,
                    onPrevious: {
                        withAnimation(.spring()) {
                            viewModel.changeDay(by: -1)
                        }
                    },
                    onNext: {
                        withAnimation(.spring()) {
                            viewModel.changeDay(by: 1)
                        }
                    },
                    onToday: {
                        withAnimation(.spring()) {
                            viewModel.goToToday()
                        }
                    }
                )
                
                Divider()
                
                // Day Timeline View
                GeometryReader { geometry in
                DayTimelineView(
                    currentDate: viewModel.selectedDate,
                        events: filteredEvents,
                        tasks: filteredTasks,
                        geometry: geometry
                    )
                }
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            dragOffset = value.translation.width
                        }
                        .onEnded { value in
                            let threshold: CGFloat = 100
                            if value.translation.width < -threshold {
                                withAnimation(.spring()) {
                                    viewModel.changeDay(by: 1)
                                }
                            } else if value.translation.width > threshold {
                                withAnimation(.spring()) {
                                    viewModel.changeDay(by: -1)
                                }
                            }
                            dragOffset = 0
                        }
                )
            }
            
            // Floating Add Button
            FloatingAddButton {
                showingAddEvent = true
                #if os(iOS)
                generateHapticFeedback(style: .medium)
                #endif
            }
            .padding(.bottom, 20)
            .padding(.trailing, 20)
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(
                viewModel: viewModel,
                preselectedDate: viewModel.selectedDate,
                preselectedHour: newEventHour
            )
            .presentationCornerRadius(20)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingEventDetail) {
            if let event = selectedEvent {
                EventDetailView(event: event, viewModel: viewModel)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    #if os(iOS)
    private func generateHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    #endif
}

// MARK: - Day Navigation Header

struct DayNavigationHeader: View {
    let currentDate: Date
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Previous day button
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.cnPrimary)
                        .frame(width: 50, height: 50)
                }
                
                Spacer()
                
                // Date Display
                VStack(spacing: 4) {
                    Text(currentDate.weekdayName(style: .full))
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(currentDate.formatted(style: .long))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Next day button
                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.cnPrimary)
                        .frame(width: 50, height: 50)
                }
            }
            .padding(.horizontal)
            
            // Today button
            if !currentDate.isToday() {
                Button(action: onToday) {
                    HStack {
                        Image(systemName: "calendar.circle.fill")
                            .font(.title3)
                        Text("Today")
                            .font(.headline)
                    }
                    .foregroundColor(.cnPrimary)
                }
                .padding(.bottom, 8)
            }
        }
        .padding(.top, 8)
    }
}


// MARK: - Day Timeline Background

struct DayTimelineBackground: View {
    let hours: [Int]
    let hourHeight: CGFloat
    let showHalfHourMarks: Bool
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                VStack(spacing: 0) {
                    // Hour line
                    Divider()
                        .background(Color.gray.opacity(0.3))
                    
                    Spacer()
                        .frame(height: hourHeight / 2 - 0.5)
                    
                    // Half-hour mark
                    if showHalfHourMarks {
                        Divider()
                            .background(Color.gray.opacity(0.15))
                    }
                    
                    Spacer()
                        .frame(height: hourHeight / 2 - 0.5)
                }
                .frame(height: hourHeight)
                .id("hour_\(hour)")
            }
        }
        .padding(.leading, 60)
    }
}

// MARK: - Day Time Labels Column

struct DayTimeLabelsColumn: View {
    let hours: [Int]
    let hourHeight: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                Text(timeString(for: hour))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 60, height: hourHeight, alignment: .top)
                    .padding(.top, -8)
            }
        }
    }
    
    private func timeString(for hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

// MARK: - Day Events Layer

struct DayEventsLayer: View {
    let currentDate: Date
    let events: [CalendarEvent]
    let hourHeight: CGFloat
    let width: CGFloat
    let onEventTap: (CalendarEvent) -> Void
    let onLongPress: (Int) -> Void
    
    var body: some View {
        ZStack {
            // Hour gesture areas
            hourGestureAreas
            
            // Events overlay
            eventsOverlay
        }
    }
    
    private var hourGestureAreas: some View {
        VStack(spacing: 0) {
            ForEach(0..<24, id: \.self) { hour in
                Color.clear
                    .frame(width: width, height: hourHeight)
                    .contentShape(Rectangle())
                    .onLongPressGesture {
                        onLongPress(hour)
                    }
            }
                    }
            }
            
    private var eventsOverlay: some View {
        Group {
            if events.isEmpty {
                EmptyDayView()
                    .frame(width: width)
                    .position(x: 60 + width / 2, y: hourHeight * 6)
            } else {
                ForEach(events, id: \.id) { event in
                    eventView(for: event)
                }
            }
        }
    }
    
    @ViewBuilder
    private func eventView(for event: CalendarEvent) -> some View {
                    if let eventPosition = eventPosition(for: event) {
                        DayEventBlock(
                            event: event,
                hourHeight: hourHeight
                        )
                        .position(
                            x: 60 + (width - 20) / 2 + 10,
                            y: eventPosition.y + eventPosition.height / 2
                        )
                        .onTapGesture {
                            onEventTap(event)
            }
        }
    }
    
    private func eventPosition(for event: CalendarEvent) -> (y: CGFloat, height: CGFloat)? {
        guard let start = event.startDate, let end = event.endDate else { return nil }
        
        let calendar = Calendar.current
        
        // Check if all-day event
        let startHour = calendar.component(.hour, from: start)
        let startMinute = calendar.component(.minute, from: start)
        let endHour = calendar.component(.hour, from: end)
        let endMinute = calendar.component(.minute, from: end)
        
        if startHour == 0 && startMinute == 0 && endHour == 0 && endMinute == 0 {
            // All-day event at top
            return (y: 0, height: 60)
        }
        
        let startOffset = CGFloat(startHour) + CGFloat(startMinute) / 60.0
        let endOffset = CGFloat(endHour) + CGFloat(endMinute) / 60.0
        
        let y = startOffset * hourHeight
        let height = max((endOffset - startOffset) * hourHeight, 40)
        
        return (y, height)
    }
}


// MARK: - Current Day Time Indicator

struct CurrentDayTimeIndicator: View {
    let hourHeight: CGFloat
    let width: CGFloat
    
    @State private var currentTime = Date()
    @State private var timer: Timer?
    
    var body: some View {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: currentTime)
        let minute = calendar.component(.minute, from: currentTime)
        let offset = CGFloat(hour) + CGFloat(minute) / 60.0
        
        ZStack(alignment: .leading) {
            // Circle indicator
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .position(
                    x: 65,
                    y: offset * hourHeight
                )
            
            // Line
            Rectangle()
                .fill(Color.red)
                .frame(width: width - 70, height: 2)
                .position(
                    x: 60 + (width - 70) / 2,
                    y: offset * hourHeight
                )
        }
        .onAppear {
            // Update every minute
            timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                currentTime = Date()
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

// MARK: - Empty Day View

struct EmptyDayView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "sun.horizon.fill")
                .font(.system(size: 60))
                .foregroundColor(.cnPrimary.opacity(0.6))
            
            Text("No events today")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Text("Tap and hold on any time slot to add an event")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding()
    }
}

// MARK: - Floating Add Button

private struct CalendarFloatingAddButton: View {
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Spacer()
            
            Button(action: action) {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text("New Event")
                        .font(.headline)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [.cnPrimary, .cnAccent]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .shadow(color: Color.cnPrimary.opacity(0.4), radius: 8, x: 0, y: 4)
            }
        }
    }
}

// MARK: - Month Navigation Header

struct MonthNavigationHeader: View {
    let currentMonth: Date
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                // Previous month button
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.cnPrimary)
                        .frame(width: 50, height: 50)
                }
                
                Spacer()
                
                // Month and Year
                VStack(spacing: 4) {
                    Text(currentMonth.monthName())
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(String(currentMonth.year))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Next month button
                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.cnPrimary)
                        .frame(width: 50, height: 50)
                }
            }
            .padding(.horizontal)
            
            // Today button
            Button(action: onToday) {
                HStack {
                    Image(systemName: "calendar.circle.fill")
                        .font(.title3)
                    Text("Today")
                        .font(.headline)
                }
                .foregroundColor(.cnPrimary)
            }
            .padding(.bottom, 8)
        }
        .padding(.top)
    }
}

// MARK: - Calendar Grid View

struct CalendarGridView: View {
    let currentMonth: Date
    @Binding var selectedDate: Date
    let events: [CalendarEvent]
    var tasks: [TodoItem] = []
    let showHolidays: Bool
    let onDateTap: (Date) -> Void
    
    init(currentMonth: Date, selectedDate: Binding<Date>, events: [CalendarEvent], tasks: [TodoItem] = [], showHolidays: Bool = true, onDateTap: @escaping (Date) -> Void) {
        self.currentMonth = currentMonth
        self._selectedDate = selectedDate
        self.events = events
        self.tasks = tasks
        self.showHolidays = showHolidays
        self.onDateTap = onDateTap
    }
    
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: spacing), count: 7)
    }
    
    private var spacing: CGFloat {
        AdaptiveLayouts.calendarGridSpacing
    }
    
    private var weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: AppSpacing.small) {
                // Weekday headers
                HStack(spacing: AppSpacing.tiny) {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(AppFonts.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, AppSpacing.horizontalPadding)
                
                // Calendar days grid
                LazyVGrid(columns: columns, spacing: spacing) {
                    ForEach(Array(gridDates().enumerated()), id: \.offset) { index, date in
                        let isCurrentMonthDate = isInCurrentMonth(date)
                        
                        if ScreenSize.isSmallDevice {
                            CompactDayCell(
                                date: date,
                                eventCount: eventCount(for: date),
                                festivalCount: festivalCount(for: date),
                                isToday: date.isToday(),
                                isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                                isCurrentMonth: isCurrentMonthDate,
                                onTap: { onDateTap(date) }
                            )
                            .frame(height: cellHeight(availableWidth: geometry.size.width))
                            .opacity(isCurrentMonthDate ? 1.0 : 0.85) // Keep dates clearly visible even from other months
                        } else {
                            CalendarDayCell(
                                date: date,
                                isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                                isToday: date.isToday(),
                                isCurrentMonth: isCurrentMonthDate,
                                eventCount: eventCount(for: date),
                                taskCount: taskCount(for: date),
                                activeTaskCount: activeTaskCount(for: date),
                                festivalCount: festivalCount(for: date),
                                onTap: { onDateTap(date) }
                            )
                            .frame(height: cellHeight(availableWidth: geometry.size.width))
                            .opacity(isCurrentMonthDate ? 1.0 : 0.85) // Keep dates clearly visible even from other months
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.horizontalPadding)
            }
            .padding(.vertical, AppSpacing.verticalPadding)
        }
    }
    
    private func cellHeight(availableWidth: CGFloat) -> CGFloat {
        // Validate input
        guard availableWidth.isFinite && availableWidth > 0 else {
            return 50 // Safe default
        }
        
        let padding = AppSpacing.horizontalPadding * 2
        let adjustedWidth = max(availableWidth - padding, 200) // Ensure minimum width
        let calculatedHeight = AdaptiveLayouts.calendarCellHeight(availableWidth: adjustedWidth, spacing: spacing)
        
        // Final validation - ensure result is finite and in valid range
        guard calculatedHeight.isFinite && calculatedHeight > 0 else {
            return 50 // Safe default
        }
        
        return min(max(calculatedHeight, 40), 200) // Ensure valid range 40-200
    }
    
    private func gridDates() -> [Date] {
        // Use calendarGridDatesWithPadding to get ALL dates including from adjacent months
        currentMonth.calendarGridDatesWithPadding()
    }
    
    private func isInCurrentMonth(_ date: Date) -> Bool {
        Calendar.current.isDate(date, equalTo: currentMonth, toGranularity: .month)
    }
    
    private func eventCount(for date: Date) -> Int {
        events.filter { event in
            guard let eventStart = event.startDate else { return false }
            return Calendar.current.isDate(eventStart, inSameDayAs: date)
        }.count
    }
    
    private func taskCount(for date: Date) -> Int {
        tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDate(dueDate, inSameDayAs: date)
        }.count
    }
    
    private func activeTaskCount(for date: Date) -> Int {
        tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDate(dueDate, inSameDayAs: date) && !task.isCompleted
        }.count
    }
    
    private func festivalCount(for date: Date) -> Int {
        guard showHolidays else { return 0 }
        let indianHolidays = IndianHolidaysService.shared.getHolidaysForDate(date).count
        let internationalFestivals = InternationalFestivalsService.shared.getFestivalsForDate(date).count
        return indianHolidays + internationalFestivals
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let eventCount: Int
    var taskCount: Int = 0
    var activeTaskCount: Int = 0
    var festivalCount: Int = 0
    let onTap: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Date number - Top-left corner, simple and visible
            HStack {
                    Text("\(date.day)")
                        .font(.system(size: 14, weight: isToday ? .semibold : .medium))
                        .foregroundColor(textColor)
                    .padding(.leading, 4)
                    .padding(.top, 4)
                Spacer()
            }
            
            // Event indicators with colored bars and names
            VStack(alignment: .leading, spacing: 2) {
                // Festival indicator (orange bar with text)
                if festivalCount > 0 {
                    HStack(spacing: 3) {
                        Rectangle()
                            .fill(Color.orange)
                            .frame(width: 3, height: 12)
                            .cornerRadius(1.5)
                        
                        Text("\(festivalCount) festival\(festivalCount > 1 ? "s" : "")")
                            .font(.caption2)
                            .foregroundColor(isCurrentMonth ? Color.cnPrimaryText : Color.cnSecondaryText.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                
                // Event indicator (blue bar with text)
                if eventCount > 0 {
                    HStack(spacing: 3) {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 3, height: 12)
                            .cornerRadius(1.5)
                        
                        Text("\(eventCount) event\(eventCount > 1 ? "s" : "")")
                            .font(.caption2)
                            .foregroundColor(isCurrentMonth ? Color.cnPrimaryText : Color.cnSecondaryText.opacity(0.7))
                            .lineLimit(1)
                    }
                }
                
                // Task indicator (green bar with text)
                if taskCount > 0 {
                    HStack(spacing: 3) {
                        Rectangle()
                            .fill(Color.green)
                            .frame(width: 3, height: 12)
                            .cornerRadius(1.5)
                        
                        Text("\(taskCount) task\(taskCount > 1 ? "s" : "")")
                            .font(.caption2)
                            .foregroundColor(isCurrentMonth ? Color.cnPrimaryText : Color.cnSecondaryText.opacity(0.7))
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 4)
            .padding(.top, 2)
            .padding(.bottom, 2)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(backgroundColor)
        .cornerRadius(cornerRadius)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(borderColor, lineWidth: isToday ? borderWidth : 0)
        )
        .scaleEffect(isSelected ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .onTapGesture {
            onTap()
        }
    }
    
    private var dateFont: Font {
        return .system(size: 13, weight: isToday ? .semibold : .regular)
    }
    
    private var cornerRadius: CGFloat {
        ScreenSize.isSmallDevice ? 8 : 12
    }
    
    private var borderWidth: CGFloat {
        ScreenSize.isSmallDevice ? 1.5 : 2
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return Color.cnPrimaryText.opacity(0.85) // Much more visible for adjacent months
        } else if isToday {
            return .cnPrimary
        } else {
            // Use primary text color for maximum visibility on dark background
            return Color.cnPrimaryText
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return Color.cnAccent.opacity(0.1)
        } else if isToday {
            return Color.cnPrimary.opacity(0.1)
        } else {
            return Color.clear
        }
    }
    
    private var borderColor: Color {
        isToday ? .cnPrimary : .clear
    }
}

// MARK: - Event Count Indicator

struct EventCountIndicator: View {
    let count: Int
    let isSelected: Bool
    
    var body: some View {
        Group {
            if count <= 3 {
                // Show dots for 1-3 events
                HStack(spacing: 2) {
                    ForEach(0..<count, id: \.self) { _ in
                        Circle()
                            .fill(isSelected ? Color.white : Color.cnAccent)
                            .frame(width: 4, height: 4)
                    }
                }
            } else {
                // Show badge for 4+ events
                Text("\(count)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 16, height: 16)
                    .background(isSelected ? Color.white.opacity(0.3) : Color.cnAccent)
                    .clipShape(Circle())
            }
        }
        .frame(height: 8)
    }
}

// MARK: - Festival Indicator

struct FestivalIndicator: View {
    let count: Int
    let isSelected: Bool
    
    var body: some View {
        Group {
            if count <= 2 {
                // Show dots for 1-2 festivals
                HStack(spacing: 2) {
                    ForEach(0..<count, id: \.self) { _ in
                        Circle()
                            .fill(isSelected ? Color.white : Color.orange)
                            .frame(width: 5, height: 5)
                    }
                }
            } else {
                // Show badge for 3+ festivals
                Text("\(count)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 14, height: 14)
                    .background(isSelected ? Color.white.opacity(0.3) : Color.orange)
                    .clipShape(Circle())
            }
        }
        .frame(height: 6)
    }
}

// MARK: - Events List Section

struct EventsListSection: View {
    let selectedDate: Date
    let events: [CalendarEvent]
    var tasks: [TodoItem] = []
    var holidayEvents: [HolidayEvent] = []
    let onDelete: (CalendarEvent) -> Void
    var onTaskToggle: ((TodoItem) -> Void)?
    var onTaskTap: ((TodoItem) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedDate.relativeFormatted())
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Text(selectedDate.formatted(style: .long))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Count badges
                HStack(spacing: 8) {
                    if !tasks.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.square")
                                .font(.system(size: 10))
                            Text("\(tasks.count)")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cnPrimary)
                        .clipShape(Capsule())
                    }
                    
                    if !events.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 10))
                            Text("\(events.count)")
                                .font(.caption)
                                .fontWeight(.bold)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.cnAccent)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            // Combined list
            if events.isEmpty && tasks.isEmpty && holidayEvents.isEmpty {
                EmptyEventsView()
            } else {
                ScrollView {
                    // Use LazyVStack for better performance with long lists
                    LazyVStack(spacing: 12) {
                        // Festivals & Holidays Section
                        if !holidayEvents.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("FESTIVALS & HOLIDAYS")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                ForEach(holidayEvents.indices, id: \.self) { index in
                                    let holiday = holidayEvents[index]
                                    HolidayEventRow(holiday: holiday)
                                        .transition(.slide)
                                }
                            }
                            .padding(.horizontal)
                            
                            if !tasks.isEmpty || !events.isEmpty {
                                Divider()
                                    .padding(.horizontal)
                            }
                        }
                        
                        // Tasks Section
                        if !tasks.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("TASKS")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                ForEach(tasks, id: \.id) { task in
                                    TaskCalendarItem(
                                        task: task,
                                        onToggle: {
                                            onTaskToggle?(task)
                                        },
                                        onTap: {
                                            onTaskTap?(task)
                                        }
                                    )
                                    .transition(.slide)
                                }
                            }
                            .padding(.horizontal)
                            
                            if !events.isEmpty {
                                Divider()
                                    .padding(.horizontal)
                            }
                        }
                        
                        // Events Section
                        if !events.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("EVENTS")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.secondary)
                                
                                ForEach(events, id: \.id) { event in
                                    if ScreenSize.isSmallDevice {
                                        CompactEventRow(event: event)
                                            .transition(.slide)
                                    } else {
                                        EventRowCard(event: event)
                                            .transition(.slide)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom)
                }
            }
        }
    }
}

// MARK: - Event Row Card

struct EventRowCard: View {
    let event: CalendarEvent
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(categoryColor)
                .frame(width: 4)
                    .padding(.top, 4)
            
            VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: event.eventKind.icon)
                            .foregroundColor(categoryColor)
                Text(event.title ?? "Untitled Event")
                    .font(.headline)
                    .lineLimit(2)
                        if let sentiment = event.eventSentiment {
                            Image(systemName: sentimentIcon(sentiment))
                                .foregroundColor(sentimentColor(sentiment))
                                .font(.caption)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption2)
                            .foregroundColor(.secondary)
                    Text(timeString)
                        .font(.subheadline)
                .foregroundColor(.secondary)
                        if event.durationMinutes > 0 {
                            Text("· \(event.durationDescription)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let summary = event.detectedSummary, !summary.isEmpty {
                        Text(summary)
                            .font(.subheadline)
                    .foregroundColor(.secondary)
                            .lineLimit(3)
                    } else if let notes = event.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "location.fill")
                    .font(.caption)
                .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    metadataFooter
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(categoryColor.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.08), radius: 3, x: 0, y: 1)
    }
    
    private var categoryColor: Color {
        EventCategory(rawValue: event.category ?? "Other")?.color ?? .gray
    }
    
    private var timeString: String {
        guard let start = event.startDate, let end = event.endDate else {
            return "Time not set"
        }
        
        let startTime = start.timeOnly(style: .short)
        let endTime = end.timeOnly(style: .short)
        
        // Check if all-day event
        let calendar = Calendar.current
        if calendar.component(.hour, from: start) == 0 &&
           calendar.component(.minute, from: start) == 0 &&
           calendar.component(.hour, from: end) == 0 &&
           calendar.component(.minute, from: end) == 0 {
            return "All Day"
        }
        
        return "\(startTime) - \(endTime)"
    }
    
    private var attendees: [String] {
        event.attendees
    }
    
    private var recommendedBookmarks: [Bookmark] {
        guard let context = event.managedObjectContext else { return [] }
        return event.recommendedBookmarkObjectIDs.compactMap { uri in
            context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: uri)
        }.compactMap { try? context.existingObject(with: $0) as? Bookmark }
    }
    
    private var recommendedNotes: [Note] {
        guard let context = event.managedObjectContext else { return [] }
        return event.recommendedNoteObjectIDs.compactMap { uri in
            context.persistentStoreCoordinator?.managedObjectID(forURIRepresentation: uri)
        }.compactMap { try? context.existingObject(with: $0) as? Note }
    }
    
    private var metadataFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(event.category ?? "Other")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(categoryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor.opacity(0.15))
                    .cornerRadius(6)
                if !attendees.isEmpty {
                    Label("\(attendees.count)", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !event.preparationChecklist.isEmpty {
                    Label("Prep \(event.preparationChecklist.count)", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.cnAccent)
                }
                if !recommendedBookmarks.isEmpty {
                    Label("Bookmarks \(recommendedBookmarks.count)", systemImage: "bookmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if !recommendedNotes.isEmpty {
                    Label("Notes \(recommendedNotes.count)", systemImage: "doc.text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            if !attendees.isEmpty {
                Text(attendees.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
    
    private func sentimentIcon(_ sentiment: CalendarEvent.EventSentiment) -> String {
        switch sentiment {
        case .positive: return "face.smiling"
        case .neutral: return "face.dashed"
        case .negative: return "face.frown"
        }
    }
    
    private func sentimentColor(_ sentiment: CalendarEvent.EventSentiment) -> Color {
        switch sentiment {
        case .positive: return .green
        case .neutral: return .secondary
        case .negative: return .red
        }
    }
    
    private var cardBackground: Color {
        #if canImport(UIKit)
        if colorScheme == .dark {
            return Color(white: 0.18)
        }
        return Color(UIColor.secondarySystemBackground)
        #elseif canImport(AppKit)
        if colorScheme == .dark {
            return Color(white: 0.18)
        }
        return Color(NSColor.windowBackgroundColor)
        #else
        return Color.gray.opacity(0.1)
        #endif
    }
}

// MARK: - Empty Events View

struct EmptyEventsView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("No Events")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Tap + to add an event for this day")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Enhanced Event Creation/Editing Modal

struct AddEventView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: CalendarViewModel
    
    var preselectedDate: Date?
    var preselectedHour: Int?
    var editingEvent: CalendarEvent?
    
    private var controlBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    private var textBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.textBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    @State private var title = ""
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var category = EventCategory.personal.rawValue
    @State private var location = ""
    @State private var notes = ""
    @State private var isAllDay = false
    @State private var isRecurring = false
    @State private var recurrenceType = RecurrenceType.none
    @State private var recurrenceEndDate = Date().addingTimeInterval(30 * 24 * 60 * 60) // 30 days from now
    @State private var showingValidationError = false
    @State private var showingDeleteConfirmation = false
    @State private var showingRecurrenceOptions = false
    @State private var showingVoiceRecorder = false
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case title, location, notes
    }
    
    init(viewModel: CalendarViewModel, preselectedDate: Date? = nil, preselectedHour: Int? = nil, editingEvent: CalendarEvent? = nil) {
        self.viewModel = viewModel
        self.preselectedDate = preselectedDate
        self.preselectedHour = preselectedHour
        self.editingEvent = editingEvent
        
        // Calculate initial dates
        if let event = editingEvent {
            // Editing existing event
            _title = State(initialValue: event.title ?? "")
            _startDate = State(initialValue: event.startDate ?? Date())
            _endDate = State(initialValue: event.endDate ?? Date().addingTimeInterval(3600))
            _category = State(initialValue: event.category ?? EventCategory.personal.rawValue)
            _location = State(initialValue: event.location ?? "")
            _notes = State(initialValue: event.notes ?? "")
            _isAllDay = State(initialValue: isAllDayEvent(event))
        } else if let date = preselectedDate, let hour = preselectedHour {
            // New event with preselected time
            let calendar = Calendar.current
            var components = calendar.dateComponents([.year, .month, .day], from: date)
            components.hour = hour
            components.minute = 0
            
            if let calculatedStart = calendar.date(from: components) {
                _startDate = State(initialValue: calculatedStart)
                _endDate = State(initialValue: calculatedStart.addingTimeInterval(3600))
            } else {
                _startDate = State(initialValue: Date())
                _endDate = State(initialValue: Date().addingTimeInterval(3600))
            }
        } else {
            // New event with current time
            _startDate = State(initialValue: Date())
            _endDate = State(initialValue: Date().addingTimeInterval(3600))
        }
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text("Event Details")
                            .font(.system(size: 20, weight: .semibold))
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                
                Section(header: Text("EVENT TITLE")) {
                    TextField("Enter event title", text: $title)
                        .textFieldStyle(.plain)
                }
                
                Section {
                    Toggle("All Day Event", isOn: $isAllDay)
                        .onChange(of: isAllDay) { _, newValue in
                            if newValue {
                                let calendar = Calendar.current
                                startDate = calendar.startOfDay(for: startDate)
                                endDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate)
                            }
                        }
                }
                
                Section {
                    HStack {
                        Image(systemName: "calendar.badge.clock")
                            .foregroundColor(.blue)
                        Text("Schedule")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }
                
                Section(header: Text("START TIME")) {
                    DatePicker("", selection: $startDate, displayedComponents: isAllDay ? [.date] : [.date, .hourAndMinute])
                        .datePickerStyle(.compact)
                        .labelsHidden()
                }
                
                if !isAllDay {
                    Section(header: Text("END TIME")) {
                        DatePicker("", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                            .datePickerStyle(.compact)
                            .labelsHidden()
                    }
                }
                
                Section(header: Text("CATEGORY")) {
                    CategoryPicker(selectedCategory: $category)
                }
                
                Section(header: Text("LOCATION")) {
                    TextField("Enter location (optional)", text: $location)
                        .textFieldStyle(.plain)
                }
                
                Section(header: Text("NOTES")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }
                
                if editingEvent != nil {
                    Section {
                        Button(action: {
                            showingDeleteConfirmation = true
                        }) {
                            HStack {
                                Spacer()
                                Text("Delete Event")
                                    .foregroundColor(.red)
                                Spacer()
                            }
                        }
                    }
                }
            }
            #if os(iOS)
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            #else
            .background(Color(NSColor.controlBackgroundColor))
            #endif
            .navigationTitle("Event Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(editingEvent != nil ? "Save" : "Create") {
                        saveEvent()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty)
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(editingEvent != nil ? "Save" : "Create") {
                        saveEvent()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.isEmpty)
                }
                #endif
            }
            .alert("Invalid Date Range", isPresented: $showingValidationError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("The end time must be after the start time.")
            }
        }
        #if os(iOS)
        .navigationViewStyle(.stack)
        #endif
        .alert("Delete Event", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteEvent()
            }
        } message: {
            Text("Are you sure you want to delete this event? This action cannot be undone.")
        }
    }
    
    private func saveEvent() {
        if validateInput() {
            Task {
                if let event = editingEvent {
                    // Update existing event
                    await viewModel.updateEvent(
                        event,
                        title: title,
                        startDate: startDate,
                        endDate: endDate,
                        category: category,
                        location: location.isEmpty ? nil : location,
                        notes: notes.isEmpty ? nil : notes,
                        isRecurring: isRecurring,
                        recurrenceType: recurrenceType,
                        recurrenceEndDate: recurrenceEndDate
                    )
                } else {
                    // Create new event
                    await viewModel.createEvent(
                        title: title,
                        startDate: startDate,
                        endDate: endDate,
                        category: category,
                        location: location.isEmpty ? nil : location,
                        notes: notes.isEmpty ? nil : notes,
                        isRecurring: isRecurring,
                        recurrenceType: recurrenceType,
                        recurrenceEndDate: recurrenceEndDate
                    )
                }
                
                #if os(iOS)
                generateHapticFeedback(style: .medium)
                #endif
                dismiss()
            }
        } else {
            showingValidationError = true
        }
    }
    
    private func deleteEvent() {
        if let event = editingEvent {
            Task {
                await viewModel.deleteEvent(event)
                #if os(iOS)
                generateHapticFeedback(style: .heavy)
                #endif
                dismiss()
            }
        }
    }
    
    private func validateInput() -> Bool {
        !title.isEmpty && endDate > startDate
    }
    
    private func isAllDayEvent(_ event: CalendarEvent) -> Bool {
        guard let start = event.startDate, let end = event.endDate else { return false }
        let calendar = Calendar.current
        return calendar.component(.hour, from: start) == 0 &&
               calendar.component(.minute, from: start) == 0 &&
               calendar.component(.hour, from: end) == 0 &&
               calendar.component(.minute, from: end) == 0
    }
    
    private var durationString: String {
        let duration = endDate.timeIntervalSince(startDate)
        return duration.formattedDuration()
    }
    
    #if os(iOS)
    private func generateHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
    }
    #endif
}

// MARK: - Category Picker

struct CategoryPicker: View {
    @Binding var selectedCategory: String
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
            ForEach(EventCategory.allCases, id: \.rawValue) { category in
                CategoryOption(
                    category: category,
                    isSelected: selectedCategory == category.rawValue,
                    onTap: {
                        selectedCategory = category.rawValue
                    }
                )
            }
        }
    }
}

struct CategoryOption: View {
    let category: EventCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: category.icon)
                    .foregroundColor(isSelected ? .white : category.color)
                    .font(.title3)
                
                Text(category.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : .primary)
                
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? category.color : category.color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(category.color, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Recurrence Picker

struct RecurrencePicker: View {
    @Binding var selectedType: RecurrenceType
    
    var body: some View {
        Picker("Repeat", selection: $selectedType) {
            ForEach(RecurrenceType.allCases, id: \.self) { type in
                HStack {
                    Image(systemName: type.icon)
                    Text(type.displayName)
                }
                .tag(type)
            }
        }
        .pickerStyle(.menu)
    }
}

// MARK: - Recurrence Type

enum RecurrenceType: String, CaseIterable {
    case none = "none"
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case yearly = "yearly"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .none: return "None"
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .custom: return "Custom"
        }
    }
    
    var icon: String {
        switch self {
        case .none: return "xmark"
        case .daily: return "calendar"
        case .weekly: return "calendar.badge.clock"
        case .monthly: return "calendar.circle"
        case .yearly: return "calendar.badge.plus"
        case .custom: return "gear"
        }
    }
}

// MARK: - Preview

// MARK: - Holiday Event

struct HolidayEvent {
    let title: String
    let date: Date
    let category: String
}

// MARK: - Holiday Event Row

struct HolidayEventRow: View {
    let holiday: HolidayEvent
    
    var body: some View {
        HStack(spacing: 12) {
            // Festival icon
            Image(systemName: holidayCategoryIcon)
                .font(.title3)
                .foregroundColor(holidayCategoryColor)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(holiday.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(holiday.category)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Festival indicator
            Circle()
                .fill(holidayCategoryColor)
                .frame(width: 8, height: 8)
        }
        .padding(12)
        .background(holidayBackgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(holidayCategoryColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var holidayCategoryIcon: String {
        if holiday.category.contains("Indian") {
            return "flag.fill"
        } else if holiday.category == "Festival" {
            return "sparkles"
        } else {
            return "calendar.badge.clock"
        }
    }
    
    private var holidayCategoryColor: Color {
        if holiday.category.contains("Indian") {
            return .orange
        } else if holiday.category == "Festival" {
            return .purple
        } else {
            return .green
        }
    }
    
    private var holidayBackgroundColor: Color {
        holidayCategoryColor.opacity(0.1)
    }
}

// MARK: - Calendar Sidebar

struct CalendarSidebar: View {
    @ObservedObject var filterViewModel: FilterViewModel
    let onFilterChange: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Section - Account
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title)
                        .foregroundColor(.cnPrimary)
                    
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.cnPrimary)
                    }
                }
                
                // Account Info
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.callout)
                    
                    Text("naiksoham267@gmail.com")
                        .font(.callout)
                        .foregroundColor(.cnPrimaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.cnAccent.opacity(0.15))
                        .cornerRadius(6)
                }
                
                // Holidays in India
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.callout)
                    
                    Text("Holidays in India")
                        .font(.callout)
                        .foregroundColor(.cnPrimaryText)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)
            .padding(.bottom, 24)
            
            Divider()
                .background(Color.cnSecondaryText.opacity(0.3))
            
            // Other Filters Section
            VStack(alignment: .leading, spacing: 20) {
                Text("Other")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.cnPrimaryText)
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                
                VStack(spacing: 16) {
                    // Scheduled Reminders
                    FilterRow(
                        title: "Scheduled Reminders",
                        isEnabled: $filterViewModel.showScheduledReminders,
                        iconColor: .blue,
                        iconName: "checkmark.circle.fill"
                    )
                    .onChange(of: filterViewModel.showScheduledReminders) { _, _ in onFilterChange() }
                    
                    // Birthdays
                    FilterRow(
                        title: "Birthdays",
                        isEnabled: $filterViewModel.showBirthdays,
                        iconColor: .purple,
                        iconName: "checkmark.circle.fill"
                    )
                    .onChange(of: filterViewModel.showBirthdays) { _, _ in onFilterChange() }
                    
                    // India Holidays
                    FilterRow(
                        title: "India Holidays",
                        isEnabled: $filterViewModel.showHolidays,
                        iconColor: .pink,
                        iconName: "checkmark.circle.fill"
                    )
                    .onChange(of: filterViewModel.showHolidays) { _, _ in onFilterChange() }
                    
                    // Siri Suggestions
                    FilterRow(
                        title: "Siri Suggestions",
                        isEnabled: $filterViewModel.showSiriSuggestions,
                        iconColor: .gray,
                        iconName: "checkmark.circle.fill"
                    )
                    .onChange(of: filterViewModel.showSiriSuggestions) { _, _ in onFilterChange() }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.cnSecondaryBackground)
    }
}

struct FilterRow: View {
    let title: String
    @Binding var isEnabled: Bool
    let iconColor: Color
    let iconName: String
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
                .font(.callout)
            
            Text(title)
                .font(.callout)
                .foregroundColor(.cnPrimaryText)
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .cnAccent))
                .labelsHidden()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.cnBackground.opacity(0.5))
        .cornerRadius(10)
    }
}

// MARK: - Full Page Calendar Views

struct ScrollableMonthView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let filteredEvents: [CalendarEvent]
    let filteredTasks: [TodoItem]
    let geometry: GeometryProxy
    let filterOptions: CalendarFilterOptions
    
    @StateObject private var indianHolidaysService = IndianHolidaysService.shared
    @State private var scrollOffset: CGFloat = 0
    @State private var currentVisibleMonth: Date = Date()
    
    private let monthRange = 12 // Show 12 months before and after current month
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    ForEach(monthIndices, id: \.self) { index in
                        let monthDate = monthDate(for: index)
                        let monthEvents = eventsForMonth(monthDate)
                        let monthTasks = tasksForMonth(monthDate)
                        
                        MonthViewCard(
                            monthDate: monthDate,
                            events: monthEvents,
                            tasks: monthTasks,
                            isCurrentMonth: Calendar.current.isDate(monthDate, equalTo: viewModel.currentDate, toGranularity: .month),
                            onDateSelected: { date in
                                viewModel.selectedDate = date
                            },
                            onNewEvent: { date in
                                // Handle new event creation
                                viewModel.selectedDate = date
                                // You can add logic to show event creation sheet here
                            },
                            onNewReminder: { date in
                                // Handle new reminder creation
                                viewModel.selectedDate = date
                                // You can add logic to show reminder creation sheet here
                            },
                            filterOptions: filterOptions
                        )
                        .id(index)
                    }
                }
            }
            .onAppear {
                scrollToCurrentMonth(proxy: proxy)
            }
            .onChange(of: viewModel.currentDate) { _, newDate in
                scrollToCurrentMonth(proxy: proxy)
            }
        }
    }
    
    private var monthIndices: Range<Int> {
        return (0..<(monthRange * 2 + 1))
    }
    
    private func monthDate(for index: Int) -> Date {
        let calendar = Calendar.current
        let currentMonth = calendar.dateInterval(of: .month, for: viewModel.currentDate)?.start ?? viewModel.currentDate
        let monthsFromCurrent = index - monthRange
        return calendar.date(byAdding: .month, value: monthsFromCurrent, to: currentMonth) ?? currentMonth
    }
    
    private func eventsForMonth(_ monthDate: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        return filteredEvents.filter { event in
            guard let eventDate = event.startDate else { return false }
            return calendar.isDate(eventDate, equalTo: monthDate, toGranularity: .month)
        }
    }
    
    private func tasksForMonth(_ monthDate: Date) -> [TodoItem] {
        let calendar = Calendar.current
        return filteredTasks.filter { task in
            guard let taskDate = task.dueDate else { return false }
            return calendar.isDate(taskDate, equalTo: monthDate, toGranularity: .month)
        }
    }
    
    private func scrollToCurrentMonth(proxy: ScrollViewProxy) {
        withAnimation(.easeInOut(duration: 0.5)) {
            proxy.scrollTo(monthRange, anchor: .top)
        }
    }
}

struct MonthViewCard: View {
    let monthDate: Date
    let events: [CalendarEvent]
    let tasks: [TodoItem]
    let isCurrentMonth: Bool
    let onDateSelected: (Date) -> Void
    let onNewEvent: (Date) -> Void
    let onNewReminder: (Date) -> Void
    let filterOptions: CalendarFilterOptions
    
    private var controlBackgroundColor: Color {
        return Color.cnSecondaryBackground
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Month Header
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        // Navigate to previous month
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(AppFonts.title2)
                        .foregroundColor(.cnPrimary)
                        .frame(width: ScreenSize.isSmallDevice ? 44 : 50, height: ScreenSize.isSmallDevice ? 44 : 50)
                }
                
                Spacer()
                
                VStack(spacing: AppSpacing.tiny) {
                    Text(monthDate.formatted(.dateTime.month(.wide).year()))
                        .font(AppFonts.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.cnPrimaryText)
                    
                    Text(String(monthDate.year))
                        .font(AppFonts.subheadline)
                        .foregroundColor(.cnSecondaryText)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        // Navigate to next month
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(AppFonts.title2)
                        .foregroundColor(.cnPrimary)
                        .frame(width: ScreenSize.isSmallDevice ? 44 : 50, height: ScreenSize.isSmallDevice ? 44 : 50)
                }
            }
            .padding(.horizontal, AppSpacing.horizontalPadding)
            .padding(.vertical, AppSpacing.medium)
            .background(controlBackgroundColor)
            
            // Weekday Headers
            HStack(spacing: 0) {
                ForEach(weekdayHeaders, id: \.self) { day in
                    Text(day)
                        .font(AppFonts.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.cnSecondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, AppSpacing.horizontalPadding)
            .padding(.bottom, AppSpacing.small)
            
            // Calendar Grid - Fixed height to always show all 6 rows
            let spacing = AdaptiveLayouts.calendarGridSpacing
            let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: 7)
            
            // Use a fixed cell height that works for all window sizes
            // This ensures all 6 rows are always visible
            let cellHeight: CGFloat = 90.0 // Fixed height per cell - enough for date + event names
            
            // Total height for 6 rows: 6 cells × 90px + 5 spacings × spacing
            let totalGridHeight = (cellHeight * 6) + (spacing * 5)
            
            LazyVGrid(columns: columns, spacing: spacing) {
                ForEach(Array(gridDates().enumerated()), id: \.offset) { index, date in
                    let isCurrentMonth = Calendar.current.isDate(date, equalTo: monthDate, toGranularity: .month)
                    
                    ScrollableCalendarDayCell(
                        date: date,
                        isToday: Calendar.current.isDateInToday(date),
                        isSelected: Calendar.current.isDate(date, inSameDayAs: Date()),
                        isCurrentMonth: isCurrentMonth,
                        events: eventsForDate(date),
                        holidayEvents: holidayEventsForDate(date),
                        tasks: tasksForDate(date),
                        onDateSelected: {
                            onDateSelected(date)
                        },
                        onNewEvent: onNewEvent,
                        onNewReminder: onNewReminder
                    )
                    .frame(height: cellHeight)
                    .opacity(isCurrentMonth ? 1.0 : 0.85) // Keep dates clearly visible even from other months
                }
            }
            .padding(.horizontal, AppSpacing.horizontalPadding)
            .frame(height: totalGridHeight) // Fixed height ensures all 6 rows are always visible
            .padding(.bottom, AppSpacing.medium)
        }
        .background(Color.cnBackground)
    }
    
    private var weekdayHeaders: [String] {
        ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    }
    
    private func gridDates() -> [Date] {
        // Ensure ALL 30-31 days of the month are included with real-time festival data
        let calendar = Calendar.current
        let startOfMonth = monthDate.startOfMonth()
        let daysInMonth = monthDate.daysInMonth() // This returns 28, 29, 30, or 31
        
        // Verify we have the correct number of days
        guard daysInMonth > 0 else {
            return []
        }
        
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let leadingDays = firstWeekday - 1
        
        var dates: [Date] = []
        
        // Add leading days from previous month to align with weekday
        for i in (0..<leadingDays).reversed() {
            if let date = calendar.date(byAdding: .day, value: -(i + 1), to: startOfMonth) {
                dates.append(date)
            }
        }
        
        // Add ALL days of the current month (28, 29, 30, or 31 days)
        // This loop ensures every single day is included
        for day in 0..<daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day, to: startOfMonth) {
                dates.append(date)
            }
        }
        
        // Verify we added all days
        let currentMonthDates = dates.filter { calendar.isDate($0, equalTo: monthDate, toGranularity: .month) }
        assert(currentMonthDates.count == daysInMonth, "Expected \(daysInMonth) days but got \(currentMonthDates.count)")
        
        // Add trailing days from next month to complete 6-week grid (42 cells = 6 weeks × 7 days)
        let remainingCells = 42 - dates.count
        if let lastDate = dates.last, remainingCells > 0 {
            for i in 1...remainingCells {
                if let nextDate = calendar.date(byAdding: .day, value: i, to: lastDate) {
                    dates.append(nextDate)
                }
            }
        }
        
        // Final verification: should have exactly 42 cells
        assert(dates.count == 42, "Calendar grid should have 42 cells but has \(dates.count)")
        
        return dates
    }
    
    private func eventsForDate(_ date: Date) -> [CalendarEvent] {
        return events.filter { event in
            Calendar.current.isDate(event.startDate ?? Date(), inSameDayAs: date)
        }
    }
    
    private func holidayEventsForDate(_ date: Date) -> [HolidayEvent] {
        guard filterOptions.showHolidays else { return [] }
        var holidayEvents: [HolidayEvent] = []
        
        // Add Indian holidays
        let indianHolidays = IndianHolidaysService.shared.getHolidaysForDate(date)
        holidayEvents.append(contentsOf: indianHolidays.map { holiday in
            HolidayEvent(
                title: holiday.name,
                date: holiday.date,
                category: "Indian Holiday"
            )
        })
        
        // Add international festivals
        let internationalFestivals = InternationalFestivalsService.shared.getFestivalsForDate(date)
        holidayEvents.append(contentsOf: internationalFestivals.map { festival in
            HolidayEvent(
                title: festival.name,
                date: festival.date,
                category: "Festival"
            )
        })
        
        return holidayEvents
    }
    
    private func tasksForDate(_ date: Date) -> [TodoItem] {
        return tasks.filter { task in
            Calendar.current.isDate(task.dueDate ?? Date(), inSameDayAs: date)
        }
    }
}

struct ScrollableCalendarDayCell: View, Equatable {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    var isCurrentMonth: Bool = true
    let events: [CalendarEvent]
    let holidayEvents: [HolidayEvent]
    let tasks: [TodoItem]
    let onDateSelected: () -> Void
    let onNewEvent: (Date) -> Void
    let onNewReminder: (Date) -> Void
    
    static func == (lhs: ScrollableCalendarDayCell, rhs: ScrollableCalendarDayCell) -> Bool {
        lhs.date == rhs.date &&
        lhs.isToday == rhs.isToday &&
        lhs.isSelected == rhs.isSelected &&
        lhs.isCurrentMonth == rhs.isCurrentMonth &&
        lhs.events.count == rhs.events.count &&
        lhs.holidayEvents.count == rhs.holidayEvents.count &&
        lhs.tasks.count == rhs.tasks.count
    }
    
    var body: some View {
        Button(action: onDateSelected) {
            VStack(alignment: .leading, spacing: 2) {
                // Date number - Top-left corner, simple and visible
                HStack {
                    Text("\(Calendar.current.component(.day, from: date))")
                        .font(.system(size: 14, weight: isToday ? .semibold : .medium))
                        .foregroundColor(dateTextColor)
                        .padding(.leading, 4)
                        .padding(.top, 4)
                    Spacer()
                }
                
                // Event indicators with colored bars and names (Google Calendar style)
                VStack(alignment: .leading, spacing: 2) {
                    // Show holiday events first (purple/green bars with names)
                    ForEach(Array(holidayEvents.prefix(2).enumerated()), id: \.offset) { index, holiday in
                        HStack(spacing: 3) {
                            Rectangle()
                                .fill(index == 0 ? Color.purple : Color.green)
                                .frame(width: 3, height: 12)
                                .cornerRadius(1.5)
                            
                            Text(holiday.title)
                                .font(.caption2)
                                .foregroundColor(isCurrentMonth ? Color.cnPrimaryText : Color.cnSecondaryText.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    
                    // Show regular events (max 2) - use category colors with names
                    ForEach(Array(events.prefix(2).enumerated()), id: \.offset) { index, event in
                        HStack(spacing: 3) {
                            Rectangle()
                                .fill(eventCategoryColor(for: event.category))
                                .frame(width: 3, height: 12)
                                .cornerRadius(1.5)
                            
                            Text(event.title ?? "Untitled Event")
                                .font(.caption2)
                                .foregroundColor(isCurrentMonth ? Color.cnPrimaryText : Color.cnSecondaryText.opacity(0.7))
                                .lineLimit(1)
                        }
                    }
                    
                    // Show count if more events
                    let totalEvents = events.count + holidayEvents.count
                    if totalEvents > 4 {
                        Text("+\(totalEvents - 4) more")
                            .font(.caption2)
                            .foregroundColor(Color.cnSecondaryText)
                            .padding(.leading, 6)
                    }
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)
                .padding(.bottom, 2)
                
                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isSelected ? Color.cnAccent.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isToday ? Color.cnPrimary.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            AccessibilityHelpers.calendarDayHint(
                hasEvents: !events.isEmpty || !holidayEvents.isEmpty,
                hasTasks: !tasks.isEmpty,
                date: AccessibilityHelpers.dateValue(date)
            )
        )
        .contextMenu {
            Button(action: {
                onNewEvent(date)
            }) {
                Label("New Event", systemImage: "calendar.badge.plus")
            }
            
            Button(action: {
                onNewReminder(date)
            }) {
                Label("New Reminder", systemImage: "bell.badge.plus")
            }
        }
    }
    
    private var dateTextColor: Color {
        if !isCurrentMonth {
            return Color.cnPrimaryText.opacity(0.85) // Much more visible for adjacent months
        } else if isToday {
            return .cnPrimary
        } else {
            // Use primary text color for maximum visibility on dark background
            return Color.cnPrimaryText
        }
    }
    
    private func eventCategoryColor(for category: String?) -> Color {
        guard let category = category else { return .cnCategoryOther }
        
        switch category {
        case "Work": return .cnCategoryWork
        case "Personal": return .cnCategoryPersonal
        case "Health": return .cnCategoryHealth
        case "Education": return .cnCategoryEducation
        case "Holiday": return .green // Indian holidays in green
        default: return .cnCategoryOther
        }
    }
}

struct FullPageMonthView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let filteredEvents: [CalendarEvent]
    let filteredTasks: [TodoItem]
    let geometry: GeometryProxy
    
    private var controlBackgroundColor: Color {
        return Color.cnSecondaryBackground
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Month Header
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.previousMonth()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(AppFonts.title2)
                        .foregroundColor(.cnAccent)
                }
                
                Spacer()
                
                Text(viewModel.currentDate, formatter: monthYearFormatter)
                    .font(AppFonts.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.nextMonth()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(AppFonts.title2)
                        .foregroundColor(.cnAccent)
                }
            }
            .padding(.horizontal, AppSpacing.horizontalPadding)
            .padding(.vertical, AppSpacing.medium)
            
            // Days of Week Header
            HStack(spacing: 0) {
                ForEach(Calendar.current.shortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                        .font(AppFonts.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, AppSpacing.horizontalPadding)
            .padding(.bottom, AppSpacing.small)
            
            // Calendar Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(Array(gridDates().enumerated()), id: \.offset) { index, date in
                    if let date = date {
                        FullPageCalendarDayCell(
                            date: date,
                            isToday: Calendar.current.isDateInToday(date),
                            isSelected: Calendar.current.isDate(date, inSameDayAs: viewModel.selectedDate),
                            events: eventsForDate(date),
                            tasks: tasksForDate(date),
                            onDateSelected: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    viewModel.selectedDate = date
                                }
                            },
                            onNewEvent: { date in
                                // Handle new event creation
                                viewModel.selectedDate = date
                                // You can add logic to show event creation sheet here
                            },
                            onNewReminder: { date in
                                // Handle new reminder creation
                                viewModel.selectedDate = date
                                // You can add logic to show reminder creation sheet here
                            }
                        )
                    } else {
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: 60)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .background(controlBackgroundColor)
    }
    
    private func gridDates() -> [Date?] {
        return viewModel.currentDate.calendarGridDatesWithPadding().map { $0 }
    }
    
    private func eventsForDate(_ date: Date) -> [CalendarEvent] {
        return filteredEvents.filter { event in
            Calendar.current.isDate(event.startDate ?? Date(), inSameDayAs: date)
        }
    }
    
    private func tasksForDate(_ date: Date) -> [TodoItem] {
        return filteredTasks.filter { task in
            if let dueDate = task.dueDate {
                return Calendar.current.isDate(dueDate, inSameDayAs: date)
            }
            return false
        }
    }
}

// MARK: - Week Timeline View

struct WeekTimelineView: View {
    let weekDates: [Date]
    let events: [CalendarEvent]
    let tasks: [TodoItem]
    let geometry: GeometryProxy
    
    @StateObject private var indianHolidaysService = IndianHolidaysService.shared
    
    private let hours = Array(0...23)
    private let hourHeight: CGFloat = 60
    
    var body: some View {
            HStack(spacing: 0) {
            // Time column
            VStack(spacing: 0) {
                // All-day section
                HStack {
                    Text("all-day")
                        .font(.caption)
                        .foregroundColor(.cnSecondaryText)
                        .frame(width: 60, height: 40, alignment: .leading)
                    
                    // All-day events
                    HStack(spacing: 4) {
                ForEach(weekDates, id: \.self) { date in
                            VStack(spacing: 2) {
                                ForEach(allDayEventsForDate(date), id: \.id) { event in
                                    AllDayEventBar(event: event)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 40)
                }
                .background(Color.cnTertiaryBackground)
                
                // Hourly timeline
                HStack(spacing: 0) {
                    // Time labels
                    VStack(spacing: 0) {
                        ForEach(hours, id: \.self) { hour in
                            Text(timeString(for: hour))
                                .font(.caption)
                                .foregroundColor(.cnSecondaryText)
                                .frame(width: 60, height: hourHeight, alignment: .top)
                                .padding(.top, -8)
                        }
                    }
                    
                    // Week grid
                    HStack(spacing: 0) {
                        ForEach(weekDates, id: \.self) { date in
                            WeekDayColumn(
                                date: date,
                                events: eventsForDate(date),
                                tasks: tasksForDate(date),
                                hourHeight: hourHeight
                            )
                        }
                    }
                }
            }
        }
        .background(Color.cnBackground)
    }
    
    private func timeString(for hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
    
    private func allDayEventsForDate(_ date: Date) -> [CalendarEvent] {
        return events.filter { event in
            Calendar.current.isDate(event.startDate ?? Date(), inSameDayAs: date)
        }
    }
    
    private func eventsForDate(_ date: Date) -> [CalendarEvent] {
        return events.filter { event in
            Calendar.current.isDate(event.startDate ?? Date(), inSameDayAs: date)
        }
    }
    
    private func tasksForDate(_ date: Date) -> [TodoItem] {
        return tasks.filter { task in
            Calendar.current.isDate(task.dueDate ?? Date(), inSameDayAs: date)
        }
    }
}

struct WeekDayColumn: View {
    let date: Date
    let events: [CalendarEvent]
    let tasks: [TodoItem]
    let hourHeight: CGFloat
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Hour lines
            VStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    Rectangle()
                        .fill(Color.cnSecondaryText.opacity(0.1))
                        .frame(height: 1)
                        .frame(maxHeight: hourHeight)
                }
            }
            
            // Events
            ForEach(events, id: \.id) { event in
                WeekEventBlock(event: event, hourHeight: hourHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(
            Rectangle()
                .stroke(Color.cnSecondaryText.opacity(0.2), lineWidth: 0.5)
        )
    }
}

struct AllDayEventBar: View {
    let event: CalendarEvent
    
    var body: some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(eventCategoryColor(for: event.category))
                .frame(width: 4, height: 16)
                .cornerRadius(2)
            
            Text(event.title ?? "Untitled Event")
                                .font(.caption2)
                .foregroundColor(.cnPrimaryText)
                .lineLimit(1)
        }
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                .fill(eventCategoryColor(for: event.category).opacity(0.2))
        )
    }
    
    private func eventCategoryColor(for category: String?) -> Color {
        guard let category = category else { return .cnCategoryOther }
        
        switch category {
        case "Work": return .cnCategoryWork
        case "Personal": return .cnCategoryPersonal
        case "Health": return .cnCategoryHealth
        case "Education": return .cnCategoryEducation
        case "Holiday": return .green
        default: return .cnCategoryOther
        }
    }
}

struct WeekEventBlock: View {
    let event: CalendarEvent
    let hourHeight: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.title ?? "Untitled Event")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(2)
            
            if let startDate = event.startDate {
                Text(startDate.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(eventCategoryColor(for: event.category))
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .offset(y: eventStartOffset)
    }
    
    private var eventStartOffset: CGFloat {
        guard let startDate = event.startDate else { return 0 }
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: startDate)
        let minute = calendar.component(.minute, from: startDate)
        return CGFloat(hour) * hourHeight + CGFloat(minute) * (hourHeight / 60)
    }
    
    private func eventCategoryColor(for category: String?) -> Color {
        guard let category = category else { return .cnCategoryOther }
        
        switch category {
        case "Work": return .cnCategoryWork
        case "Personal": return .cnCategoryPersonal
        case "Health": return .cnCategoryHealth
        case "Education": return .cnCategoryEducation
        case "Holiday": return .green
        default: return .cnCategoryOther
        }
    }
}

struct FullPageWeekView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let filteredEvents: [CalendarEvent]
    let filteredTasks: [TodoItem]
    let geometry: GeometryProxy
    
    private var controlBackgroundColor: Color {
        return Color.cnSecondaryBackground
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Week Header
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.previousWeek()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.cnPrimary)
                }
            
            Spacer()
                
                Text(weekRangeText)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.cnPrimaryText)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.nextWeek()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.cnPrimary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        .background(controlBackgroundColor)
            
            // Week Timeline
            WeekTimelineView(
                weekDates: weekDates,
                events: filteredEvents,
                tasks: filteredTasks,
                geometry: geometry
            )
        }
        .background(Color.cnBackground)
    }
    
    private var weekDates: [Date] {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: viewModel.currentDate)?.start ?? viewModel.currentDate
        
        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)
        }
    }
    
    private var weekRangeText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        if let startOfWeek = weekDates.first, let endOfWeek = weekDates.last {
            if Calendar.current.isDate(startOfWeek, equalTo: endOfWeek, toGranularity: .month) {
                return "\(formatter.string(from: startOfWeek)) - \(Calendar.current.component(.day, from: endOfWeek))"
            } else {
                return "\(formatter.string(from: startOfWeek)) - \(formatter.string(from: endOfWeek))"
            }
        }
        return ""
    }
    
    private func eventsForDate(_ date: Date) -> [CalendarEvent] {
        return filteredEvents.filter { event in
            Calendar.current.isDate(event.startDate ?? Date(), inSameDayAs: date)
        }
    }
    
    private func tasksForDate(_ date: Date) -> [TodoItem] {
        return filteredTasks.filter { task in
            if let dueDate = task.dueDate {
                return Calendar.current.isDate(dueDate, inSameDayAs: date)
            }
            return false
        }
    }
}

// MARK: - Day Timeline View

struct DayTimelineView: View {
    let currentDate: Date
    let events: [CalendarEvent]
    let tasks: [TodoItem]
    let geometry: GeometryProxy
    
    @StateObject private var indianHolidaysService = IndianHolidaysService.shared
    
    private let hours = Array(0...23)
    private let hourHeight: CGFloat = 60
    
    var body: some View {
        HStack(spacing: 0) {
            // Time column
            VStack(spacing: 0) {
                // All-day section
                HStack {
                    Text("all-day")
                        .font(.caption)
                        .foregroundColor(.cnSecondaryText)
                        .frame(width: 60, height: 40, alignment: .leading)
                    
                    // All-day events
                    VStack(spacing: 2) {
                        ForEach(allDayEvents, id: \.id) { event in
                            AllDayEventBar(event: event)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: 40)
                }
                .background(Color.cnTertiaryBackground)
                
                // Hourly timeline
                HStack(spacing: 0) {
                    // Time labels
                    VStack(spacing: 0) {
                        ForEach(hours, id: \.self) { hour in
                            Text(timeString(for: hour))
                                .font(.caption)
                                .foregroundColor(.cnSecondaryText)
                                .frame(width: 60, height: hourHeight, alignment: .top)
                                .padding(.top, -8)
                        }
                    }
                    
                    // Day column
                    DayColumn(
                        date: currentDate,
                        events: events,
                        tasks: tasks,
                        hourHeight: hourHeight
                    )
                }
            }
        }
        .background(Color.cnBackground)
    }
    
    private func timeString(for hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
    
    private var allDayEvents: [CalendarEvent] {
        return events.filter { event in
            Calendar.current.isDate(event.startDate ?? Date(), inSameDayAs: currentDate)
        }
    }
}

struct DayColumn: View {
    let date: Date
    let events: [CalendarEvent]
    let tasks: [TodoItem]
    let hourHeight: CGFloat
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Hour lines
            VStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    Rectangle()
                        .fill(Color.cnSecondaryText.opacity(0.1))
                        .frame(height: 1)
                        .frame(maxHeight: hourHeight)
                }
            }
            
            // Current time indicator
            DayCurrentTimeIndicator(hourHeight: hourHeight)
            
            // Events
            ForEach(events, id: \.id) { event in
                DayEventBlock(event: event, hourHeight: hourHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .overlay(
            Rectangle()
                .stroke(Color.cnSecondaryText.opacity(0.2), lineWidth: 0.5)
        )
    }
}

struct DayCurrentTimeIndicator: View {
    let hourHeight: CGFloat
    
    var body: some View {
        let calendar = Calendar.current
        let now = Date()
        let hour = calendar.component(.hour, from: now)
        let minute = calendar.component(.minute, from: now)
        let offset = CGFloat(hour) * hourHeight + CGFloat(minute) * (hourHeight / 60)
        
        HStack(spacing: 0) {
            // Time label
            Text(now.formatted(.dateTime.hour().minute()))
                .font(.caption)
                .foregroundColor(.red)
                .frame(width: 60, alignment: .trailing)
                .padding(.trailing, 8)
            
            // Red line
            Rectangle()
                .fill(Color.red)
                .frame(height: 2)
                .frame(maxWidth: .infinity)
        }
        .offset(y: offset)
    }
}

struct DayEventBlock: View {
    let event: CalendarEvent
    let hourHeight: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.title ?? "Untitled Event")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .lineLimit(2)
            
            if let startDate = event.startDate, let endDate = event.endDate {
                HStack {
                    Text(startDate.formatted(.dateTime.hour().minute()))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("-")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text(endDate.formatted(.dateTime.hour().minute()))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            
            if let location = event.location, !location.isEmpty {
                HStack {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(location)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(eventCategoryColor(for: event.category))
        )
        .frame(maxWidth: .infinity, alignment: .leading)
        .offset(y: eventStartOffset)
        .frame(height: eventHeight)
    }
    
    private var eventStartOffset: CGFloat {
        guard let startDate = event.startDate else { return 0 }
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: startDate)
        let minute = calendar.component(.minute, from: startDate)
        return CGFloat(hour) * hourHeight + CGFloat(minute) * (hourHeight / 60)
    }
    
    private var eventHeight: CGFloat {
        guard let startDate = event.startDate, let endDate = event.endDate else { return hourHeight }
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: startDate)
        let startMinute = calendar.component(.minute, from: startDate)
        let endHour = calendar.component(.hour, from: endDate)
        let endMinute = calendar.component(.minute, from: endDate)
        
        let startOffset = CGFloat(startHour) * hourHeight + CGFloat(startMinute) * (hourHeight / 60)
        let endOffset = CGFloat(endHour) * hourHeight + CGFloat(endMinute) * (hourHeight / 60)
        
        return max(endOffset - startOffset, hourHeight * 0.5)
    }
    
    private func eventCategoryColor(for category: String?) -> Color {
        guard let category = category else { return .cnCategoryOther }
        
        switch category {
        case "Work": return .cnCategoryWork
        case "Personal": return .cnCategoryPersonal
        case "Health": return .cnCategoryHealth
        case "Education": return .cnCategoryEducation
        case "Holiday": return .green
        default: return .cnCategoryOther
        }
    }
}

struct FullPageDayView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let filteredEvents: [CalendarEvent]
    let filteredTasks: [TodoItem]
    let geometry: GeometryProxy
    @State private var showingAddEvent = false
    
    private var controlBackgroundColor: Color {
        return Color.cnSecondaryBackground
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Day Header
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.previousDay()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.cnAccent)
                }
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text(viewModel.selectedDate, formatter: dayFormatter)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(viewModel.selectedDate, formatter: weekdayFormatter)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.nextDay()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.cnAccent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Day Content
            ScrollView {
                LazyVStack(spacing: 12) {
                    // Events Section
                    if !eventsForSelectedDate.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Events")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("\(eventsForSelectedDate.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.gray.opacity(0.2))
                                    )
                            }
                            
                            ForEach(eventsForSelectedDate, id: \.id) { event in
                                FullPageEventDetailCard(event: event)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Tasks Section
                    if !tasksForSelectedDate.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Tasks")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text("\(tasksForSelectedDate.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.gray.opacity(0.2))
                                    )
                            }
                            
                            ForEach(tasksForSelectedDate, id: \.id) { task in
                                FullPageTaskDetailCard(task: task)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    // Empty State
                    if eventsForSelectedDate.isEmpty && tasksForSelectedDate.isEmpty {
                        CalendarEmptyState {
                            showingAddEvent = true
                        }
                    }
                }
                .padding(.vertical, 20)
            }
        }
        .background(controlBackgroundColor)
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(viewModel: viewModel)
                .presentationCornerRadius(20)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
    
    private var eventsForSelectedDate: [CalendarEvent] {
        return filteredEvents.filter { event in
            Calendar.current.isDate(event.startDate ?? Date(), inSameDayAs: viewModel.selectedDate)
        }
    }
    
    private var tasksForSelectedDate: [TodoItem] {
        return filteredTasks.filter { task in
            if let dueDate = task.dueDate {
                return Calendar.current.isDate(dueDate, inSameDayAs: viewModel.selectedDate)
            }
            return false
        }
    }
}

// MARK: - Full Page Calendar Components

struct FullPageCalendarDayCell: View, Equatable {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let events: [CalendarEvent]
    let tasks: [TodoItem]
    let onDateSelected: () -> Void
    let onNewEvent: (Date) -> Void
    let onNewReminder: (Date) -> Void
    
    static func == (lhs: FullPageCalendarDayCell, rhs: FullPageCalendarDayCell) -> Bool {
        lhs.date == rhs.date &&
        lhs.isToday == rhs.isToday &&
        lhs.isSelected == rhs.isSelected &&
        lhs.events.count == rhs.events.count &&
        lhs.tasks.count == rhs.tasks.count
    }
    
    var body: some View {
        Button(action: onDateSelected) {
            VStack(alignment: .leading, spacing: 2) {
                // Date number
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 16, weight: isToday ? .bold : .medium))
                    .foregroundColor(isToday ? .white : (isSelected ? .cnAccent : Color.cnPrimaryText))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(isToday ? Color.cnAccent : (isSelected ? Color.cnAccent.opacity(0.2) : Color.clear))
                    )
                
                // Event indicators with colored circles
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(Array(events.prefix(3).enumerated()), id: \.offset) { index, event in
                        HStack(spacing: 4) {
                        Circle()
                                .fill(eventCategoryColor(for: event.category))
                                .frame(width: 6, height: 6)
                            
                            Text(event.title ?? "Untitled Event")
                                .font(.caption2)
                                .foregroundColor(Color.cnPrimaryText)
                                .lineLimit(1)
                        }
                    }
                    
                    if events.count > 3 {
                        Text("+\(events.count - 3) more")
                            .font(.caption2)
                            .foregroundColor(Color.cnSecondaryText)
                    }
                }
            }
            .frame(height: 80)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.cnAccent.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .contextMenu {
            Button(action: {
                onNewEvent(date)
            }) {
                Label("New Event", systemImage: "calendar.badge.plus")
            }
            
            Button(action: {
                onNewReminder(date)
            }) {
                Label("New Reminder", systemImage: "bell.badge.plus")
            }
        }
    }
    
    private func eventCategoryColor(for category: String?) -> Color {
        guard let category = category else { return .cnCategoryOther }
        
        switch category {
        case "Work": return .cnCategoryWork
        case "Personal": return .cnCategoryPersonal
        case "Health": return .cnCategoryHealth
        case "Education": return .cnCategoryEducation
        default: return .cnCategoryOther
        }
    }
}

struct FullPageEventItem: View {
    let event: CalendarEvent
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.blue)
                .frame(width: 6, height: 6)
            
            Text(event.title ?? "Untitled Event")
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.blue.opacity(0.1))
        )
    }
}

struct FullPageTaskItem: View {
    let task: TodoItem
    
    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(task.isCompleted ? Color.green : Color.orange)
                .frame(width: 6, height: 6)
            
            Text(task.title ?? "Untitled Task")
                .font(.caption)
                .foregroundColor(task.isCompleted ? .secondary : .primary)
                .strikethrough(task.isCompleted)
                .lineLimit(1)
            
            Spacer()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill((task.isCompleted ? Color.green : Color.orange).opacity(0.1))
        )
    }
}

struct FullPageEventDetailCard: View {
    let event: CalendarEvent
    
    private var controlBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "Untitled Event")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 8) {
                    Text(event.startDate ?? Date(), formatter: timeFormatter)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if event.endDate != event.startDate {
                        Text(" - \(event.endDate ?? Date(), formatter: timeFormatter)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            Circle()
                .fill(Color.blue)
                .frame(width: 12, height: 12)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(controlBackgroundColor)
        )
    }
}

struct FullPageTaskDetailCard: View {
    let task: TodoItem
    
    private var controlBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title ?? "Untitled Task")
                    .font(.headline)
                    .foregroundColor(.primary)
                    .strikethrough(task.isCompleted)
                
                if let dueDate = task.dueDate {
                    Text(dueDate, formatter: timeFormatter)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
            }
            
            Spacer()
            
            Circle()
                .fill(task.isCompleted ? Color.green : Color.orange)
                .frame(width: 12, height: 12)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(controlBackgroundColor)
        )
    }
}

// MARK: - Full Page Year View

struct FullPageYearView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let filteredEvents: [CalendarEvent]
    let filteredTasks: [TodoItem]
    let geometry: GeometryProxy
    
    private var controlBackgroundColor: Color {
        return Color.cnSecondaryBackground
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Year Header
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.previousYear()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title2)
                        .foregroundColor(.cnPrimary)
                }
                
                Spacer()
                
                Text(yearText)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.cnPrimaryText)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.nextYear()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.cnPrimary)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(controlBackgroundColor)
            
            // Year Grid
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 16), count: 3), spacing: 16) {
                    ForEach(monthsInYear, id: \.self) { month in
                        YearMonthCard(
                            month: month,
                            events: eventsForMonth(month),
                            tasks: tasksForMonth(month),
                            currentDate: viewModel.currentDate,
                            onDateTap: { date in
                                viewModel.selectedDate = date
                                viewModel.viewMode = .day
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .background(Color.cnBackground)
    }
    
    private var yearText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: viewModel.currentDate)
    }
    
    private var monthsInYear: [Date] {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: viewModel.currentDate)
        
        return (1...12).compactMap { month in
            calendar.date(from: DateComponents(year: year, month: month, day: 1))
        }
    }
    
    private func eventsForMonth(_ month: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: month)?.start ?? month
        let endOfMonth = calendar.dateInterval(of: .month, for: month)?.end ?? month
        
        return filteredEvents.filter { event in
            guard let eventStart = event.startDate else { return false }
            return eventStart >= startOfMonth && eventStart < endOfMonth
        }
    }
    
    private func tasksForMonth(_ month: Date) -> [TodoItem] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: month)?.start ?? month
        let endOfMonth = calendar.dateInterval(of: .month, for: month)?.end ?? month
        
        return filteredTasks.filter { task in
            guard let taskDate = task.dueDate else { return false }
            return taskDate >= startOfMonth && taskDate < endOfMonth
        }
    }
}

// MARK: - Year Month Card

struct YearMonthCard: View {
    let month: Date
    let events: [CalendarEvent]
    let tasks: [TodoItem]
    let currentDate: Date
    let onDateTap: (Date) -> Void
    
    private let calendar = Calendar.current
    
    var body: some View {
        VStack(spacing: 8) {
            // Month Header
            Text(monthName)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.cnAccent)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // Weekday Headers
            HStack(spacing: 0) {
                ForEach(weekdayHeaders, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundColor(.cnSecondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 2) {
                ForEach(calendarDays, id: \.self) { date in
                    YearDayCell(
                        date: date,
                        isCurrentMonth: calendar.isDate(date, equalTo: month, toGranularity: .month),
                        isToday: calendar.isDateInToday(date),
                        events: eventsForDate(date),
                        tasks: tasksForDate(date),
                        onTap: { onDateTap(date) }
                    )
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cnSecondaryBackground)
        )
    }
    
    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: month)
    }
    
    private var weekdayHeaders: [String] {
        ["S", "M", "T", "W", "T", "F", "S"]
    }
    
    private var calendarDays: [Date] {
        let startOfMonth = calendar.dateInterval(of: .month, for: month)?.start ?? month
        
        // Get the first day of the week for the start of the month
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let startDate = calendar.date(byAdding: .day, value: -(firstWeekday - 1), to: startOfMonth) ?? startOfMonth
        
        // Generate 42 days (6 weeks)
        return (0..<42).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startDate)
        }
    }
    
    private func eventsForDate(_ date: Date) -> [CalendarEvent] {
        return events.filter { event in
            calendar.isDate(event.startDate ?? Date(), inSameDayAs: date)
        }
    }
    
    private func tasksForDate(_ date: Date) -> [TodoItem] {
        return tasks.filter { task in
            calendar.isDate(task.dueDate ?? Date(), inSameDayAs: date)
        }
    }
}

// MARK: - Year Day Cell

struct YearDayCell: View, Equatable {
    let date: Date
    let isCurrentMonth: Bool
    let isToday: Bool
    let events: [CalendarEvent]
    let tasks: [TodoItem]
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
    static func == (lhs: YearDayCell, rhs: YearDayCell) -> Bool {
        lhs.date == rhs.date &&
        lhs.isCurrentMonth == rhs.isCurrentMonth &&
        lhs.isToday == rhs.isToday &&
        lhs.events.count == rhs.events.count &&
        lhs.tasks.count == rhs.tasks.count
    }
    
    var body: some View {
        VStack(spacing: 2) {
            // Date Number
            Text(dayNumber)
                .font(.caption)
                .fontWeight(isToday ? .bold : .medium)
                .foregroundColor(textColor)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(isToday ? Color.red : Color.clear)
                )
            
            // Event Indicators
            HStack(spacing: 1) {
                ForEach(events.prefix(3), id: \.id) { event in
                    Circle()
                        .fill(eventCategoryColor(for: event.category))
                        .frame(width: 4, height: 4)
                }
                
                if events.count > 3 {
                    Text("+\(events.count - 3)")
                        .font(.caption2)
                        .foregroundColor(.cnSecondaryText)
                }
            }
        }
        .frame(height: 32)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private var textColor: Color {
        if isToday {
            return .white
        } else if isCurrentMonth {
            return .cnPrimaryText
        } else {
            return .cnSecondaryText
        }
    }
    
    private func eventCategoryColor(for category: String?) -> Color {
        guard let category = category else { return .cnCategoryOther }
        
        switch category {
        case "Work": return .cnCategoryWork
        case "Personal": return .cnCategoryPersonal
        case "Health": return .cnCategoryHealth
        case "Education": return .cnCategoryEducation
        case "Holiday": return .green
        default: return .cnCategoryOther
        }
    }
}

#Preview {
    CalendarView()
}


