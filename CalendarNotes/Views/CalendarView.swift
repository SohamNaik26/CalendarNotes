//
//  CalendarView.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import SwiftUI
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

struct CalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @StateObject private var filterViewModel = FilterViewModel()
    @State private var showingAddEvent = false
    @State private var dragOffset: CGFloat = 0
    
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
    
    var body: some View {
        VStack(spacing: 0) {
            // Top Controls Bar - Compact
            HStack {
                // View Mode Picker - Compact
                HStack(spacing: 2) {
                    ForEach(CalendarViewMode.allCases, id: \.self) { mode in
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.viewMode = mode
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: mode.icon)
                                    .font(.subheadline)
                                Text(mode.rawValue)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(viewModel.viewMode == mode ? Color.cnAccent : Color.clear)
                            )
                            .foregroundColor(viewModel.viewMode == mode ? .white : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
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
                    }
                    
                    Button(action: {
                        showingAddEvent = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.subheadline)
                            Text("Add")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.cnAccent)
                        )
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(controlBackgroundColor)
            
            // Quick Filter Chips
            if filterViewModel.hasActiveFilters {
                QuickFilterChips(viewModel: filterViewModel)
                    .padding(.horizontal, 16)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            
            // Main Content with Sidebar
            HStack(spacing: 0) {
                // Sidebar
                CalendarSidebar(
                    filterViewModel: filterViewModel,
                    onFilterChange: { }
                )
                .frame(width: 280)
                
                // Full Page Calendar Content
            GeometryReader { geometry in
                switch viewModel.viewMode {
                case .month:
                        ScrollableMonthView(
                        viewModel: viewModel,
                        filteredEvents: filteredEvents,
                        filteredTasks: filteredTasks,
                        geometry: geometry
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
            }
        }
        .sheet(isPresented: $showingAddEvent) {
            AddEventView(viewModel: viewModel)
        }
        .sheet(isPresented: $filterViewModel.showFilterPanel) {
            FilterPanel(viewModel: filterViewModel)
                #if os(iOS)
                .presentationDetents([.medium, .large])
                #endif
        }
        .task {
            // Ensure we start with the current date
            viewModel.currentDate = Date()
            viewModel.currentMonth = Date()
            viewModel.loadAll()
        }
    }
}

// MARK: - Month View Content

struct MonthViewContent: View {
    @ObservedObject var viewModel: CalendarViewModel
    @Binding var dragOffset: CGFloat
    var filteredEvents: [CalendarEvent] = []
    var filteredTasks: [TodoItem] = []
    @State private var selectedTask: TodoItem?
    @State private var showingTaskDetail = false
    @State private var showingTaskEditor = false
    @State private var taskToEdit: TodoItem?
    @StateObject private var tasksViewModel = TasksViewModel()
    
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
        .sheet(isPresented: $showingEventDetail) {
            if let event = selectedEvent {
                EventDetailView(event: event, viewModel: viewModel)
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
        }
        .sheet(isPresented: $showingEventDetail) {
            if let event = selectedEvent {
                EventDetailView(event: event, viewModel: viewModel)
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
            Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
                currentTime = Date()
            }
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

private struct FloatingAddButton: View {
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
    let onDateTap: (Date) -> Void
    
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)
    private let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    
    var body: some View {
        VStack(spacing: 8) {
            // Weekday headers
            HStack(spacing: 4) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal)
            
            // Calendar days grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Array(gridDates().enumerated()), id: \.offset) { index, date in
                    if let date = date {
                        CalendarDayCell(
                            date: date,
                            isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                            isToday: date.isToday(),
                            isCurrentMonth: isInCurrentMonth(date),
                            eventCount: eventCount(for: date),
                            taskCount: taskCount(for: date),
                            activeTaskCount: activeTaskCount(for: date),
                            onTap: { onDateTap(date) }
                        )
                    } else {
                        Color.clear
                            .frame(height: 60)
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical)
    }
    
    private func gridDates() -> [Date?] {
        currentMonth.calendarGridDates()
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
    let onTap: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 2) {
            // Date number
            Text("\(date.day)")
                .font(.system(size: 16, weight: isToday ? .bold : .regular))
                .foregroundColor(textColor)
            
            // Indicators
            VStack(spacing: 2) {
                // Event indicator
                if eventCount > 0 {
                    EventCountIndicator(count: eventCount, isSelected: isSelected)
                }
                
                // Task indicator
                if taskCount > 0 {
                    TaskCountBadge(count: taskCount, activeCount: activeTaskCount)
                }
            }
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity)
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(borderColor, lineWidth: isToday ? 2 : 0)
        )
        .scaleEffect(isSelected ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
        .onTapGesture {
            onTap()
        }
    }
    
    private var textColor: Color {
        if !isCurrentMonth {
            return Color.cnSecondaryText.opacity(0.5)
        } else if isSelected {
            return .white
        } else if isToday {
            return .cnPrimary
        } else {
            return Color.cnPrimaryText
        }
    }
    
    private var backgroundColor: Color {
        if isSelected {
            return .cnPrimary
        } else if isToday {
            return .cnPrimary.opacity(0.2)
        } else {
            return Color.cnTertiaryBackground
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

// MARK: - Events List Section

struct EventsListSection: View {
    let selectedDate: Date
    let events: [CalendarEvent]
    var tasks: [TodoItem] = []
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
            if events.isEmpty && tasks.isEmpty {
                EmptyEventsView()
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
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
                                    EventRowCard(event: event)
                                        .transition(.slide)
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
        HStack(spacing: 12) {
            // Category color bar
            RoundedRectangle(cornerRadius: 4)
                .fill(categoryColor)
                .frame(width: 4)
            
            VStack(alignment: .leading, spacing: 6) {
                // Title
                Text(event.title ?? "Untitled Event")
                    .font(.headline)
                    .lineLimit(2)
                
                // Time
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    
                    Text(timeString)
                        .font(.subheadline)
                }
                .foregroundColor(.secondary)
                
                // Location
                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        
                        Text(location)
                            .font(.subheadline)
                            .lineLimit(1)
                    }
                    .foregroundColor(.secondary)
                }
                
                // Category tag
                Text(event.category ?? "Other")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(categoryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor.opacity(0.15))
                    .cornerRadius(6)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(colorScheme == .dark ? Color(white: 0.2) : Color(.sRGB, white: 0.95, opacity: 1))
        )
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.3 : 0.1), radius: 4, x: 0, y: 2)
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
        VStack(spacing: 0) {
            // Enhanced Header with Gradient
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        dismiss()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                        Text("Cancel")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("Event Details")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if editingEvent != nil {
                        Text("Edit existing event")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Create a new event")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        saveEvent()
                        dismiss()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: editingEvent != nil ? "checkmark" : "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text(editingEvent != nil ? "Save" : "Create")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: title.isEmpty ? [.gray, .gray] : [.cnPrimary, .cnAccent]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .scaleEffect(title.isEmpty ? 0.95 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(title.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [controlBackgroundColor, controlBackgroundColor.opacity(0.8)]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 0.5),
                alignment: .bottom
            )
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Event Details
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.cnPrimary)
                                .font(.title3)
                            Text("Event Details")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Event Title")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                TextField("Enter event title", text: $title)
                                    .textFieldStyle(.plain)
                                    .focused($focusedField, equals: .title)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .location
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(textBackgroundColor)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(title.isEmpty ? Color.gray.opacity(0.3) : Color.cnPrimary.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                            }
                            
                            Toggle("All Day Event", isOn: $isAllDay)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .onChange(of: isAllDay) { _, newValue in
                                    if newValue {
                                        let calendar = Calendar.current
                                        startDate = calendar.startOfDay(for: startDate)
                                        endDate = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate)
                                    }
                                }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(controlBackgroundColor)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                    )
                    
                    // MARK: - Schedule
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.cnPrimary)
                                .font(.title3)
                            Text("Schedule")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            if isAllDay {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Date")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    DatePicker("Select Date", selection: $startDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(textBackgroundColor)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(Color.cnPrimary.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Start Time")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    DatePicker("Start", selection: $startDate)
                                        .datePickerStyle(.compact)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(textBackgroundColor)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(Color.cnPrimary.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("End Time")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    DatePicker("End", selection: $endDate)
                                        .datePickerStyle(.compact)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(textBackgroundColor)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(Color.cnPrimary.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(controlBackgroundColor)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                    )
                    
                    // MARK: - Category
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "tag.fill")
                                .foregroundColor(.cnPrimary)
                                .font(.title3)
                            Text("Category")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        CategoryPicker(selectedCategory: $category)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(controlBackgroundColor)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                    )
                    
                    // MARK: - Location
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.cnPrimary)
                                .font(.title3)
                            Text("Location")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Event Location")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.cnAccent)
                                    .frame(width: 20)
                                
                                TextField("Enter location (optional)", text: $location)
                                    .textFieldStyle(.plain)
                                    .focused($focusedField, equals: .location)
                                    .submitLabel(.next)
                                    .onSubmit {
                                        focusedField = .notes
                                    }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(textBackgroundColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(controlBackgroundColor)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                    )
                    
                    // MARK: - Description
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.cnPrimary)
                                .font(.title3)
                            Text("Description")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Additional Notes")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            
                            ZStack(alignment: .topLeading) {
                                TextEditor(text: $notes)
                                    .frame(minHeight: 80)
                                    .focused($focusedField, equals: .notes)
                                    .background(Color.clear)
                                
                                if notes.isEmpty {
                                    Text("Add notes about this event...")
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .allowsHitTesting(false)
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(textBackgroundColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(controlBackgroundColor)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                    )
                    
                    // MARK: - Recurrence
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "repeat")
                                .foregroundColor(.cnPrimary)
                                .font(.title3)
                            Text("Recurrence")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle("Repeat Event", isOn: $isRecurring)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .onChange(of: isRecurring) { _, newValue in
                                    if newValue {
                                        recurrenceType = .daily
                                    } else {
                                        recurrenceType = .none
                                    }
                                }
                            
                            if isRecurring {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Repeat Frequency")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    RecurrencePicker(selectedType: $recurrenceType)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(textBackgroundColor)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(Color.cnPrimary.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                }
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("End Date")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    DatePicker("End Repeat", selection: $recurrenceEndDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(textBackgroundColor)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(Color.cnPrimary.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(controlBackgroundColor)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                    )
                    
                    // MARK: - Duration Info
                    if !isAllDay {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "clock")
                                    .foregroundColor(.cnPrimary)
                                    .font(.title3)
                                Text("Duration")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                            
                            HStack {
                                Text("Event Duration")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Text(durationString)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.cnAccent)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(textBackgroundColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.cnPrimary.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(controlBackgroundColor)
                                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                        )
                    }
                    
                    // MARK: - Delete Event (only when editing)
                    if editingEvent != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                    .font(.title3)
                                Text("Delete Event")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                            
                            Button(action: {
                                showingDeleteConfirmation = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                        .foregroundColor(.white)
                                    Text("Delete Event")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.red)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(controlBackgroundColor)
                                .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: 600, maxHeight: 700)
        .alert("Invalid Date Range", isPresented: $showingValidationError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("The end time must be after the start time.")
        }
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

// MARK: - Calendar Sidebar

struct CalendarSidebar: View {
    @ObservedObject var filterViewModel: FilterViewModel
    let onFilterChange: () -> Void
    
    @StateObject private var indianHolidaysService = IndianHolidaysService.shared
    @State private var indianHolidaysEnabled = true
    @State private var birthdaysEnabled = true
    @State private var scheduledRemindersEnabled = true
    @State private var siriSuggestionsEnabled = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top Section - Account
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "person.circle.fill")
                        .font(.title2)
                        .foregroundColor(.cnPrimary)
                    
                    Button(action: {}) {
                        Image(systemName: "plus")
                            .font(.title3)
                            .foregroundColor(.cnPrimary)
                    }
                }
                
                // Account Info
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text("naiksoham267@gmail.com")
                        .font(.caption)
                        .foregroundColor(.cnPrimaryText)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red)
                        .cornerRadius(4)
                }
                
                // Holidays in India
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text("Holidays in India")
                        .font(.caption)
                        .foregroundColor(.cnPrimaryText)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 20)
            
            Divider()
                .background(Color.cnSecondaryText.opacity(0.3))
            
            // Other Filters Section
            VStack(alignment: .leading, spacing: 16) {
                Text("Other")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.cnPrimaryText)
                    .padding(.horizontal, 16)
                    .padding(.top, 20)
                
                VStack(spacing: 12) {
                    // Scheduled Reminders
                    FilterRow(
                        title: "Scheduled Reminders",
                        isEnabled: $scheduledRemindersEnabled,
                        iconColor: .blue,
                        iconName: "checkmark.circle.fill"
                    )
                    
                    // Birthdays
                    FilterRow(
                        title: "Birthdays",
                        isEnabled: $birthdaysEnabled,
                        iconColor: .purple,
                        iconName: "checkmark.circle.fill"
                    )
                    
                    // India Holidays
                    FilterRow(
                        title: "India Holidays",
                        isEnabled: $indianHolidaysEnabled,
                        iconColor: .pink,
                        iconName: "checkmark.circle.fill"
                    )
                    
                    // Siri Suggestions
                    FilterRow(
                        title: "Siri Suggestions",
                        isEnabled: $siriSuggestionsEnabled,
                        iconColor: .gray,
                        iconName: "checkmark.circle.fill"
                    )
                }
                .padding(.horizontal, 16)
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
                .font(.caption)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.cnPrimaryText)
            
            Spacer()
            
            Toggle("", isOn: $isEnabled)
                .toggleStyle(SwitchToggleStyle(tint: .cnAccent))
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

// MARK: - Full Page Calendar Views

struct ScrollableMonthView: View {
    @ObservedObject var viewModel: CalendarViewModel
    let filteredEvents: [CalendarEvent]
    let filteredTasks: [TodoItem]
    let geometry: GeometryProxy
    
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
                            }
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
                        .font(.title2)
                        .foregroundColor(.cnPrimary)
                        .frame(width: 50, height: 50)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text(monthDate.formatted(.dateTime.month(.wide).year()))
                    .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.cnPrimaryText)
                    
                    Text(String(monthDate.year))
                        .font(.subheadline)
                        .foregroundColor(.cnSecondaryText)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        // Navigate to next month
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.cnPrimary)
                        .frame(width: 50, height: 50)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(controlBackgroundColor)
            
            // Weekday Headers
            HStack(spacing: 0) {
                ForEach(weekdayHeaders, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.cnSecondaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            
            // Calendar Grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(Array(gridDates().enumerated()), id: \.offset) { index, date in
                    if let date = date {
                        ScrollableCalendarDayCell(
                            date: date,
                            isToday: Calendar.current.isDateInToday(date),
                            isSelected: Calendar.current.isDate(date, inSameDayAs: Date()),
                            events: eventsForDate(date),
                            holidayEvents: holidayEventsForDate(date),
                            tasks: tasksForDate(date),
                            onDateSelected: {
                                onDateSelected(date)
                            },
                            onNewEvent: onNewEvent,
                            onNewReminder: onNewReminder
                        )
                    } else {
                        Color.clear
                            .frame(height: 60)
                    }
                }
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .background(Color.cnBackground)
    }
    
    private var weekdayHeaders: [String] {
        ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    }
    
    private func gridDates() -> [Date?] {
        return monthDate.calendarGridDatesWithPadding().map { $0 }
    }
    
    private func eventsForDate(_ date: Date) -> [CalendarEvent] {
        return events.filter { event in
            Calendar.current.isDate(event.startDate ?? Date(), inSameDayAs: date)
        }
    }
    
    private func holidayEventsForDate(_ date: Date) -> [HolidayEvent] {
        let holidays = IndianHolidaysService.shared.getHolidaysForDate(date)
        return holidays.map { holiday in
            HolidayEvent(
                title: holiday.name,
                date: holiday.date,
                category: "Holiday"
            )
        }
    }
    
    private func tasksForDate(_ date: Date) -> [TodoItem] {
        return tasks.filter { task in
            Calendar.current.isDate(task.dueDate ?? Date(), inSameDayAs: date)
        }
    }
}

struct ScrollableCalendarDayCell: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let events: [CalendarEvent]
    let holidayEvents: [HolidayEvent]
    let tasks: [TodoItem]
    let onDateSelected: () -> Void
    let onNewEvent: (Date) -> Void
    let onNewReminder: (Date) -> Void
    
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
                
                // Event indicators with colored bars
                VStack(alignment: .leading, spacing: 1) {
                    // Show regular events
                    ForEach(Array(events.prefix(2).enumerated()), id: \.offset) { index, event in
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(eventCategoryColor(for: event.category))
                                .frame(width: 4, height: 12)
                                .cornerRadius(2)
                            
                            Text(event.title ?? "Untitled Event")
                                .font(.caption2)
                                .foregroundColor(Color.cnPrimaryText)
                                .lineLimit(1)
                        }
                    }
                    
                    // Show holiday events
                    ForEach(Array(holidayEvents.prefix(1).enumerated()), id: \.offset) { index, holiday in
                        HStack(spacing: 4) {
                            Rectangle()
                                .fill(.green)
                                .frame(width: 4, height: 12)
                                .cornerRadius(2)
                            
                            Text(holiday.title)
                                .font(.caption2)
                                .foregroundColor(Color.cnPrimaryText)
                                .lineLimit(1)
                        }
                    }
                    
                    let totalEvents = events.count + holidayEvents.count
                    if totalEvents > 3 {
                        Text("+\(totalEvents - 3) more")
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
                        .font(.title2)
                        .foregroundColor(.cnAccent)
                }
                
                Spacer()
                
                Text(viewModel.currentDate, formatter: monthYearFormatter)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        viewModel.nextMonth()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title2)
                        .foregroundColor(.cnAccent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            
            // Days of Week Header
            HStack(spacing: 0) {
                ForEach(Calendar.current.shortWeekdaySymbols, id: \.self) { day in
                    Text(day)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            
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

struct FullPageCalendarDayCell: View {
    let date: Date
    let isToday: Bool
    let isSelected: Bool
    let events: [CalendarEvent]
    let tasks: [TodoItem]
    let onDateSelected: () -> Void
    let onNewEvent: (Date) -> Void
    let onNewReminder: (Date) -> Void
    
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

struct YearDayCell: View {
    let date: Date
    let isCurrentMonth: Bool
    let isToday: Bool
    let events: [CalendarEvent]
    let tasks: [TodoItem]
    let onTap: () -> Void
    
    private let calendar = Calendar.current
    
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


