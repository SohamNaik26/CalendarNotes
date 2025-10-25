//
//  WeekCalendarView.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Week Calendar View

struct WeekCalendarView: View {
    @StateObject private var viewModel = CalendarViewModel()
    @State private var scrollProxy: ScrollViewProxy?
    @State private var selectedEvent: CalendarEvent?
    @State private var showingEventDetail = false
    @State private var showingAddEvent = false
    @State private var newEventDate: Date?
    @State private var newEventHour: Int = 0
    @State private var currentTimeOffset: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    
    // Time slots (0-23 hours)
    private let hours = Array(0..<24)
    private let hourHeight: CGFloat = 80
    private let columnWidth: CGFloat = 50
    
    var body: some View {
        NavigationView {
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
            .navigationTitle("Week View")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        showingAddEvent = true
                        #if os(iOS)
                        generateHapticFeedback(style: .light)
                        #endif
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
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
        .task {
            viewModel.loadEvents()
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

// MARK: - Week Navigation Header

struct WeekNavigationHeader: View {
    let currentWeek: Date
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.cnPrimary)
                        .frame(width: 44, height: 44)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Text(weekRangeText)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(currentWeek.monthName())
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onNext) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.cnPrimary)
                        .frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal)
            
            Button(action: onToday) {
                HStack {
                    Image(systemName: "calendar.circle.fill")
                    Text("Today")
                }
                .font(.subheadline)
                .foregroundColor(.cnPrimary)
            }
            .padding(.bottom, 8)
        }
        .padding(.top)
    }
    
    private var weekRangeText: String {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: currentWeek) else {
            return ""
        }
        
        let start = weekInterval.start
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

// MARK: - All-Day Events Section

struct AllDayEventsSection: View {
    let events: [CalendarEvent]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("All-Day Events")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal)
                .padding(.top, 8)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(events, id: \.id) { event in
                        AllDayEventCard(event: event)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom, 8)
        }
        #if os(iOS)
        .background(Color(.secondarySystemBackground))
        #else
        .background(Color(white: 0.95))
        #endif
    }
}

// MARK: - All-Day Event Card

struct AllDayEventCard: View {
    let event: CalendarEvent
    
    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2)
                .fill(categoryColor)
                .frame(width: 3)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "Untitled")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let location = event.location, !location.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                        Text(location)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            .padding(.trailing, 8)
        }
        .padding(.vertical, 6)
        .padding(.leading, 4)
        .background(categoryColor.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(categoryColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var categoryColor: Color {
        EventCategory(rawValue: event.category ?? "Other")?.color ?? .gray
    }
}

// MARK: - Week Grid View

struct WeekGridView: View {
    let weekDates: [Date]
    let events: [CalendarEvent]
    let hours: [Int]
    let hourHeight: CGFloat
    let columnWidth: CGFloat
    let onEventTap: (CalendarEvent) -> Void
    let onLongPress: (Date, Int) -> Void
    
    @State private var scrollOffset: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        GeometryReader { geometry in
            ScrollViewReader { proxy in
                ScrollView([.horizontal, .vertical], showsIndicators: true) {
                    ZStack(alignment: .topLeading) {
                        // Background Grid
                        WeekGridBackground(
                            weekDates: weekDates,
                            hours: hours,
                            hourHeight: hourHeight,
                            columnWidth: columnWidth
                        )
                        
                        // Time Labels (Left Side)
                        TimeLabelsColumn(
                            hours: hours,
                            hourHeight: hourHeight
                        )
                        
                        // Day Headers (Top)
                        DayHeadersRow(
                            weekDates: weekDates,
                            columnWidth: columnWidth
                        )
                        
                        // Events
                        WeekEventsLayer(
                            weekDates: weekDates,
                            events: timeBasedEvents,
                            hourHeight: hourHeight,
                            columnWidth: columnWidth,
                            onEventTap: onEventTap,
                            onLongPress: onLongPress
                        )
                        
                        // Current Time Indicator
                        if shouldShowCurrentTimeIndicator {
                            CurrentTimeIndicator(
                                weekDates: weekDates,
                                columnWidth: columnWidth,
                                hourHeight: hourHeight
                            )
                        }
                    }
                    .frame(
                        width: columnWidth + CGFloat(weekDates.count) * columnWidth,
                        height: 60 + CGFloat(hours.count) * hourHeight
                    )
                }
                .onAppear {
                    // Auto-scroll to current time
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        scrollToCurrentTime(proxy: proxy)
                    }
                }
            }
        }
    }
    
    private var timeBasedEvents: [CalendarEvent] {
        events.filter { event in
            guard let start = event.startDate, let end = event.endDate else { return false }
            let calendar = Calendar.current
            // Filter out all-day events
            return !(calendar.component(.hour, from: start) == 0 &&
                    calendar.component(.minute, from: start) == 0 &&
                    calendar.component(.hour, from: end) == 0 &&
                    calendar.component(.minute, from: end) == 0)
        }
    }
    
    private var shouldShowCurrentTimeIndicator: Bool {
        let now = Date()
        return weekDates.contains { Calendar.current.isDate($0, inSameDayAs: now) }
    }
    
    private func scrollToCurrentTime(proxy: ScrollViewProxy) {
        let currentHour = Calendar.current.component(.hour, from: Date())
        let targetHour = max(0, currentHour - 2) // Show 2 hours before current time
        withAnimation(.easeInOut(duration: 0.5)) {
            proxy.scrollTo("hour_\(targetHour)", anchor: .top)
        }
    }
}

// MARK: - Week Grid Background

struct WeekGridBackground: View {
    let weekDates: [Date]
    let hours: [Int]
    let hourHeight: CGFloat
    let columnWidth: CGFloat
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 0) {
            // Header spacer
            Color.clear
                .frame(height: 60)
            
            // Grid
            ForEach(hours, id: \.self) { hour in
                HStack(spacing: 0) {
                    // Time column spacer
                    Color.clear
                        .frame(width: columnWidth)
                    
                    // Day columns
                    ForEach(weekDates, id: \.self) { date in
                        Rectangle()
                            .fill(isToday(date) ? Color.cnPrimary.opacity(0.03) : Color.clear)
                            .frame(width: columnWidth, height: hourHeight)
                            .overlay(
                                Rectangle()
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )
                    }
                }
                .id("hour_\(hour)")
            }
        }
    }
    
    private func isToday(_ date: Date) -> Bool {
        Calendar.current.isDate(date, inSameDayAs: Date())
    }
}

// MARK: - Time Labels Column

struct TimeLabelsColumn: View {
    let hours: [Int]
    let hourHeight: CGFloat
    
    var body: some View {
        VStack(spacing: 0) {
            // Header spacer
            Color.clear
                .frame(height: 60)
            
            // Time labels
            ForEach(hours, id: \.self) { hour in
                Text(timeString(for: hour))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 50, height: hourHeight, alignment: .top)
                    .padding(.top, 4)
            }
        }
        #if os(iOS)
        .background(Color(.systemBackground))
        #else
        .background(Color(nsColor: .windowBackgroundColor))
        #endif
    }
    
    private func timeString(for hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

// MARK: - Day Headers Row

struct DayHeadersRow: View {
    let weekDates: [Date]
    let columnWidth: CGFloat
    
    var body: some View {
        HStack(spacing: 0) {
            // Time column spacer
            Color.clear
                .frame(width: 50)
            
            // Day headers
            ForEach(weekDates, id: \.self) { date in
                DayHeaderCell(date: date, columnWidth: columnWidth)
            }
        }
        .frame(height: 60)
        #if os(iOS)
        .background(Color(.systemBackground))
        #else
        .background(Color(nsColor: .windowBackgroundColor))
        #endif
    }
}

// MARK: - Day Header Cell

struct DayHeaderCell: View {
    let date: Date
    let columnWidth: CGFloat
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 4) {
            Text(date.weekdayName(style: .short))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(date.day)")
                .font(.system(size: 18, weight: isToday ? .bold : .medium))
                .foregroundColor(isToday ? .white : .primary)
                .frame(width: 32, height: 32)
                .background(isToday ? Color.cnPrimary : Color.clear)
                .clipShape(Circle())
        }
        .frame(width: columnWidth)
    }
    
    private var isToday: Bool {
        Calendar.current.isDate(date, inSameDayAs: Date())
    }
}

// MARK: - Week Events Layer

struct WeekEventsLayer: View {
    let weekDates: [Date]
    let events: [CalendarEvent]
    let hourHeight: CGFloat
    let columnWidth: CGFloat
    let onEventTap: (CalendarEvent) -> Void
    let onLongPress: (Date, Int) -> Void
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            // Long press gesture areas
            ForEach(Array(weekDates.enumerated()), id: \.element) { dayIndex, date in
                ForEach(0..<24) { hour in
                    Color.clear
                        .frame(width: columnWidth, height: hourHeight)
                        .position(
                            x: 50 + CGFloat(dayIndex) * columnWidth + columnWidth / 2,
                            y: 60 + CGFloat(hour) * hourHeight + hourHeight / 2
                        )
                        .onLongPressGesture {
                            onLongPress(date, hour)
                        }
                }
            }
            
            // Event blocks
            ForEach(events, id: \.id) { event in
                if let dayIndex = dayIndex(for: event),
                   let eventPosition = eventPosition(for: event) {
                    EventBlock(
                        event: event,
                        height: eventPosition.height,
                        width: columnWidth - 4
                    )
                    .position(
                        x: 50 + CGFloat(dayIndex) * columnWidth + columnWidth / 2,
                        y: 60 + eventPosition.y + eventPosition.height / 2
                    )
                    .onTapGesture {
                        onEventTap(event)
                    }
                }
            }
        }
    }
    
    private func dayIndex(for event: CalendarEvent) -> Int? {
        guard let startDate = event.startDate else { return nil }
        return weekDates.firstIndex { Calendar.current.isDate($0, inSameDayAs: startDate) }
    }
    
    private func eventPosition(for event: CalendarEvent) -> (y: CGFloat, height: CGFloat)? {
        guard let start = event.startDate, let end = event.endDate else { return nil }
        
        let calendar = Calendar.current
        let startHour = calendar.component(.hour, from: start)
        let startMinute = calendar.component(.minute, from: start)
        let endHour = calendar.component(.hour, from: end)
        let endMinute = calendar.component(.minute, from: end)
        
        let startOffset = CGFloat(startHour) + CGFloat(startMinute) / 60.0
        let endOffset = CGFloat(endHour) + CGFloat(endMinute) / 60.0
        
        let y = startOffset * hourHeight
        let height = max((endOffset - startOffset) * hourHeight, 20)
        
        return (y, height)
    }
}

// MARK: - Event Block

struct EventBlock: View {
    let event: CalendarEvent
    let height: CGFloat
    let width: CGFloat
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 6)
                .fill(categoryColor.opacity(0.9))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Untitled")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(height > 40 ? 2 : 1)
                
                if height > 40 {
                    Text(timeString)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.9))
                    
                    if let location = event.location, !location.isEmpty, height > 60 {
                        HStack(spacing: 2) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 8))
                            Text(location)
                                .font(.system(size: 9))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                    }
                }
            }
            .padding(4)
        }
        .frame(width: width, height: height)
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.2), radius: 2, x: 0, y: 1)
    }
    
    private var categoryColor: Color {
        EventCategory(rawValue: event.category ?? "Other")?.color ?? .gray
    }
    
    private var timeString: String {
        guard let start = event.startDate, let end = event.endDate else { return "" }
        return "\(start.timeOnly(style: .short)) - \(end.timeOnly(style: .short))"
    }
}

// MARK: - Current Time Indicator

struct CurrentTimeIndicator: View {
    let weekDates: [Date]
    let columnWidth: CGFloat
    let hourHeight: CGFloat
    
    @State private var currentTime = Date()
    
    var body: some View {
        if let _ = weekDates.firstIndex(where: { Calendar.current.isDate($0, inSameDayAs: currentTime) }) {
            let calendar = Calendar.current
            let hour = calendar.component(.hour, from: currentTime)
            let minute = calendar.component(.minute, from: currentTime)
            let offset = CGFloat(hour) + CGFloat(minute) / 60.0
            
            ZStack(alignment: .leading) {
                // Circle indicator
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .position(
                        x: 50 + 4,
                        y: 60 + offset * hourHeight
                    )
                
                // Line
                Rectangle()
                    .fill(Color.red)
                    .frame(width: columnWidth * CGFloat(weekDates.count), height: 1)
                    .position(
                        x: 50 + (columnWidth * CGFloat(weekDates.count)) / 2,
                        y: 60 + offset * hourHeight
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
}

// MARK: - Event Detail View

struct EventDetailView: View {
    let event: CalendarEvent
    @ObservedObject var viewModel: CalendarViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var showingEditEvent = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Image(systemName: categoryIcon)
                            .foregroundColor(categoryColor)
                            .font(.title2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.title ?? "Untitled Event")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Text(event.category ?? "Other")
                                .font(.subheadline)
                                .foregroundColor(categoryColor)
                        }
                    }
                    .padding(.vertical, 8)
                }
                
                Section("Time") {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.cnAccent)
                        if let start = event.startDate, let end = event.endDate {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(start.formattedWithTime())
                                Text("to")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(end.formattedWithTime())
                            }
                        }
                    }
                }
                
                if let location = event.location, !location.isEmpty {
                    Section("Location") {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(.cnAccent)
                            Text(location)
                        }
                    }
                }
                
                if let notes = event.notes, !notes.isEmpty {
                    Section("Notes") {
                        Text(notes)
                            .font(.body)
                    }
                }
                
                Section {
                    Button(action: {
                        showingEditEvent = true
                    }) {
                        HStack {
                            Image(systemName: "pencil")
                            Text("Edit Event")
                        }
                    }
                    
                    Button(role: .destructive, action: {
                        showingDeleteConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete Event")
                        }
                    }
                }
            }
            .navigationTitle("Event Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .frame(maxWidth: 450, maxHeight: 500)
            .alert("Delete Event", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        await viewModel.deleteEvent(event)
                        dismiss()
                    }
                }
            } message: {
                Text("Are you sure you want to delete this event?")
            }
            .sheet(isPresented: $showingEditEvent) {
                AddEventView(viewModel: viewModel, editingEvent: event)
            }
        }
    }
    
    private var categoryColor: Color {
        EventCategory(rawValue: event.category ?? "Other")?.color ?? .gray
    }
    
    private var categoryIcon: String {
        EventCategory(rawValue: event.category ?? "Other")?.icon ?? "square.grid.2x2.fill"
    }
}

// MARK: - Preview

#Preview {
    WeekCalendarView()
}

