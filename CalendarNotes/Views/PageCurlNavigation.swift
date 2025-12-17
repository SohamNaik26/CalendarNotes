//
//  PageCurlNavigation.swift
//  CalendarNotes
//
//  Page curl effect for date navigation with smooth animations
//

import SwiftUI

// MARK: - Page Curl Navigation

struct PageCurlNavigation<Content: View>: View {
    let content: Content
    let onPrevious: () -> Void
    let onNext: () -> Void
    
    @State private var isTransitioning = false
    @State private var transitionDirection: Edge = .leading
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    init(
        @ViewBuilder content: () -> Content,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) {
        self.content = content()
        self.onPrevious = onPrevious
        self.onNext = onNext
    }
    
    var body: some View {
        ZStack {
            content
                .rotation3DEffect(
                    .degrees(isTransitioning ? (transitionDirection == .leading ? -90 : 90) : 0),
                    axis: (x: 0, y: 1, z: 0),
                    anchor: transitionDirection == .leading ? .leading : .trailing,
                    perspective: 0.5
                )
                .opacity(isTransitioning ? 0 : 1)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isTransitioning)
            
            // Navigation Gestures
            HStack(spacing: 0) {
                // Left side for previous
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.width > 0 {
                                    isDragging = true
                                    dragOffset = value.translation.width
                                }
                            }
                            .onEnded { value in
                                if value.translation.width > 100 {
                                    navigatePrevious()
                                } else {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        dragOffset = 0
                                        isDragging = false
                                    }
                                }
                            }
                    )
                    .onTapGesture {
                        navigatePrevious()
                    }
                
                // Right side for next
                Rectangle()
                    .fill(Color.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                if value.translation.width < 0 {
                                    isDragging = true
                                    dragOffset = value.translation.width
                                }
                            }
                            .onEnded { value in
                                if value.translation.width < -100 {
                                    navigateNext()
                                } else {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                        dragOffset = 0
                                        isDragging = false
                                    }
                                }
                            }
                    )
                    .onTapGesture {
                        navigateNext()
                    }
            }
            
            // Visual feedback for drag
            if isDragging {
                VStack {
                    Spacer()
                    
                    HStack {
                        if dragOffset > 0 {
                            Image(systemName: "chevron.left")
                                .font(.title)
                                .foregroundColor(.cnPrimary)
                                .opacity(min(dragOffset / 100.0, 1.0))
                        }
                        
                        Spacer()
                        
                        if dragOffset < 0 {
                            Image(systemName: "chevron.right")
                                .font(.title)
                                .foregroundColor(.cnPrimary)
                                .opacity(min(abs(dragOffset) / 100.0, 1.0))
                        }
                    }
                    .padding()
                }
            }
        }
        .offset(x: dragOffset * 0.1)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: dragOffset)
    }
    
    private func navigatePrevious() {
        guard !isTransitioning else { return }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isTransitioning = true
            transitionDirection = .leading
        }
        
        HapticFeedback.calendarNavigation()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onPrevious()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isTransitioning = false
                    dragOffset = 0
                    isDragging = false
                }
            }
        }
    }
    
    private func navigateNext() {
        guard !isTransitioning else { return }
        
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isTransitioning = true
            transitionDirection = .trailing
        }
        
        HapticFeedback.calendarNavigation()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onNext()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    isTransitioning = false
                    dragOffset = 0
                    isDragging = false
                }
            }
        }
    }
}

// MARK: - Calendar Page Curl View

struct CalendarPageCurlView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var currentDate = Date()
    
    var body: some View {
        PageCurlNavigation(
            content: {
                VStack(spacing: 0) {
                    // Date Header
                    HStack {
                        Button(action: {
                            navigateToPrevious()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.cnPrimary)
                        }
                        .buttonStyle(SpringButtonStyle())
                        
                        Spacer()
                        
                        Text(currentDate.formatted(date: .complete, time: .omitted))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentDate)
                        
                        Spacer()
                        
                        Button(action: {
                            navigateToNext()
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                                .foregroundColor(.cnPrimary)
                        }
                        .buttonStyle(SpringButtonStyle())
                    }
                    .padding()
                    .background(Color.cnBackground)
                    
                    // Calendar Content
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(viewModel.eventsForDate(currentDate), id: \.id) { event in
                                AnimatedEventCard(event: event)
                            }
                            
                            ForEach(viewModel.tasksForDate(currentDate), id: \.id) { task in
                                AnimatedTaskCard(task: task)
                            }
                        }
                        .padding()
                    }
                }
            },
            onPrevious: {
                navigateToPrevious()
            },
            onNext: {
                navigateToNext()
            }
        )
    }
    
    private func navigateToPrevious() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            currentDate = Calendar.current.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
        }
    }
    
    private func navigateToNext() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            currentDate = Calendar.current.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
    }
}

// MARK: - Month Page Curl View

struct MonthPageCurlView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var currentMonth = Date()
    
    var body: some View {
        PageCurlNavigation(
            content: {
                VStack(spacing: 0) {
                    // Month Header
                    HStack {
                        Button(action: {
                            navigateToPreviousMonth()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.cnPrimary)
                        }
                        .buttonStyle(SpringButtonStyle())
                        
                        Spacer()
                        
                        Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentMonth)
                        
                        Spacer()
                        
                        Button(action: {
                            navigateToNextMonth()
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                                .foregroundColor(.cnPrimary)
                        }
                        .buttonStyle(SpringButtonStyle())
                    }
                    .padding()
                    .background(Color.cnBackground)
                    
                    // Month Calendar Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 8) {
                        ForEach(daysInMonth(currentMonth), id: \.self) { date in
                            AnimatedCalendarDay(
                                date: date,
                                events: viewModel.eventsForDate(date),
                                tasks: viewModel.tasksForDate(date),
                                isToday: Calendar.current.isDateInToday(date),
                                isCurrentMonth: Calendar.current.isDate(date, equalTo: currentMonth, toGranularity: .month)
                            )
                        }
                    }
                    .padding()
                }
            },
            onPrevious: {
                navigateToPreviousMonth()
            },
            onNext: {
                navigateToNextMonth()
            }
        )
    }
    
    private func navigateToPreviousMonth() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }
    
    private func navigateToNextMonth() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
        }
    }
}

// MARK: - Week Page Curl View

struct WeekPageCurlView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var currentWeek = Date()
    
    var body: some View {
        PageCurlNavigation(
            content: {
                VStack(spacing: 0) {
                    // Week Header
                    HStack {
                        Button(action: {
                            navigateToPreviousWeek()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.title2)
                                .foregroundColor(.cnPrimary)
                        }
                        .buttonStyle(SpringButtonStyle())
                        
                        Spacer()
                        
                        Text("Week of \(currentWeek.formatted(date: .abbreviated, time: .omitted))")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentWeek)
                        
                        Spacer()
                        
                        Button(action: {
                            navigateToNextWeek()
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.title2)
                                .foregroundColor(.cnPrimary)
                        }
                        .buttonStyle(SpringButtonStyle())
                    }
                    .padding()
                    .background(Color.cnBackground)
                    
                    // Week Calendar
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(daysInWeek(currentWeek), id: \.self) { date in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(date.formatted(.dateTime.weekday(.wide)))
                                            .font(.headline)
                                            .foregroundColor(Calendar.current.isDateInToday(date) ? .cnPrimary : .primary)
                                        
                                        Spacer()
                                        
                                        Text(date.formatted(.dateTime.day()))
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    ForEach(viewModel.eventsForDate(date), id: \.id) { event in
                                        AnimatedEventCard(event: event)
                                    }
                                    
                                    ForEach(viewModel.tasksForDate(date), id: \.id) { task in
                                        AnimatedTaskCard(task: task)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.cnSecondaryBackground)
                                )
                            }
                        }
                        .padding()
                    }
                }
            },
            onPrevious: {
                navigateToPreviousWeek()
            },
            onNext: {
                navigateToNextWeek()
            }
        )
    }
    
    private func navigateToPreviousWeek() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            currentWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: currentWeek) ?? currentWeek
        }
    }
    
    private func navigateToNextWeek() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
            currentWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentWeek) ?? currentWeek
        }
    }
}

// MARK: - Local helpers and placeholder views

private func daysInMonth(_ month: Date) -> [Date] {
    let calendar = Calendar.current
    guard let range = calendar.range(of: .day, in: .month, for: month),
          let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
        return []
    }
    return range.compactMap { day -> Date? in
        calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth)
    }
}

private func daysInWeek(_ date: Date) -> [Date] {
    let calendar = Calendar.current
    guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
    var result: [Date] = []
    var cursor = weekInterval.start
    while cursor < weekInterval.end {
        result.append(cursor)
        guard let next = calendar.date(byAdding: .day, value: 1, to: cursor) else { break }
        cursor = next
        if result.count > 7 { break }
    }
    return result
}

private struct AnimatedEventCard: View {
    let event: CalendarEvent
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill((EventCategory(rawValue: event.category ?? "Other")?.color ?? .gray).opacity(0.2))
                .frame(width: 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "Untitled Event")
                    .font(.headline)
                if let start = event.startDate, let end = event.endDate {
                    Text("\(start.timeOnly(style: .short)) - \(end.timeOnly(style: .short))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                        Text(location)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cnSecondaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.cnPrimary.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct AnimatedTaskCard: View {
    let task: TodoItem
    @Environment(\.colorScheme) private var colorScheme
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundColor(task.isCompleted ? .green : .secondary)
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title ?? "Untitled Task")
                    .font(.headline)
                    .strikethrough(task.isCompleted)
                if let due = task.dueDate {
                    Text(due.formattedWithTime())
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cnSecondaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(colorScheme == .dark ? 0.2 : 0.1), lineWidth: 1)
        )
    }
}

private struct AnimatedCalendarDay: View {
    let date: Date
    let events: [CalendarEvent]
    let tasks: [TodoItem]
    let isToday: Bool
    let isCurrentMonth: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(date.day)")
                    .font(.subheadline)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundColor(isToday ? .white : (isCurrentMonth ? .primary : .secondary))
                    .frame(width: 24, height: 24)
                    .background(isToday ? Color.cnPrimary : Color.clear)
                    .clipShape(Circle())
                Spacer()
            }
            HStack(spacing: 4) {
                if !events.isEmpty { Circle().fill(Color.cnAccent).frame(width: 4, height: 4) }
                if !tasks.isEmpty { Circle().fill(Color.orange).frame(width: 4, height: 4) }
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.cnSecondaryBackground)
        )
    }
}

// MARK: - Date Extensions

extension Date {
    func formattedWithTime() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

#Preview {
    CalendarPageCurlView()
}
