//
//  CalendarMonthView.swift
//  CalendarNotes
//
//  Month view with grid layout
//

import SwiftUI

struct CalendarMonthView: View {
    @Binding var currentMonth: Date
    @Binding var selectedDate: Date
    @ObservedObject var viewModel: CalendarViewModel
    
    private let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
    
    var body: some View {
        VStack(spacing: 0) {
            // Month Navigation Header
            monthNavigation
            
            // Day Headers (S M T W T F S)
            dayHeaders
            
            // Calendar Grid
            calendarGrid
                .padding(.bottom, 16)
            
            // Events Section or Empty State
            eventsSection
        }
        .padding(.vertical, 8)
    }
    
    private var monthNavigation: some View {
        // Month navigation: "< December 2025 >" with chevron buttons - improved styling
        HStack {
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    currentMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
                }
            }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignSystem.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color(white: 0.95))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            Text(monthYearString(from: currentMonth))
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    currentMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
                }
            }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(DesignSystem.accentColor)
                    .frame(width: 36, height: 36)
                    .background(Color(white: 0.95))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
    }
    
    private var dayHeaders: some View {
        HStack(spacing: 0) {
            ForEach(weekdays, id: \.self) { day in
                Text(day)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color.gray)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
    
    private var calendarGrid: some View {
        // LazyVGrid with 7 columns, improved spacing
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
            ForEach(getDaysInMonth(), id: \.self) { date in
                DayCell(
                    date: date,
                    isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                    isToday: Calendar.current.isDateInToday(date),
                    hasEvents: hasEvents(on: date),
                    isCurrentMonth: Calendar.current.isDate(date, equalTo: currentMonth, toGranularity: .month)
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3)) {
                        selectedDate = date
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
    
    private var eventsSection: some View {
        Group {
            let events = eventsForDate(selectedDate)
            
            if events.isEmpty {
                CalendarMonthEmptyEventsView()
                    .padding(.vertical, 40)
            } else {
                VStack(spacing: 12) {
                    ForEach(events, id: \.id) { event in
                        CalendarMonthEventCard(event: event)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 20)
            }
        }
    }
    
    // Get 42 days (6 rows) to show complete month using extension
    private func getDaysInMonth() -> [Date] {
        Calendar.current.getDaysInMonth(for: currentMonth)
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func hasEvents(on date: Date) -> Bool {
        let calendar = Calendar.current
        return viewModel.events.contains { event in
            guard let eventDate = event.startDate else { return false }
            return calendar.isDate(eventDate, inSameDayAs: date)
        }
    }
    
    private func eventsForDate(_ date: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        return viewModel.events.filter { event in
            guard let eventDate = event.startDate else { return false }
            return calendar.isDate(eventDate, inSameDayAs: date)
        }
    }
}

// MARK: - Day Cell Component

struct DayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasEvents: Bool
    let isCurrentMonth: Bool
    
    private var accentColor: Color {
        DesignSystem.accentColor
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                // Today: purple gradient circle background, white text
                if isToday {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [accentColor, DesignSystem.accentColorDark],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                }
                
                // Selected date (not today): show border
                if isSelected && !isToday {
                    Circle()
                        .stroke(accentColor, lineWidth: 2.5)
                        .frame(width: 40, height: 40)
                }
                
                // Date number
                Text(dayNumber)
                    .font(.system(size: 17, weight: isToday ? .semibold : (isSelected ? .semibold : .regular)))
                    .foregroundColor(textColor)
            }
            
            // Has events: small dot indicator below number
            if hasEvents {
                Circle()
                    .fill(isToday ? .white : (isSelected ? accentColor : accentColor))
                    .frame(width: 5, height: 5)
            } else {
                // Spacer to maintain consistent height
                Circle()
                    .fill(Color.clear)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(height: 56)
        .contentShape(Rectangle()) // Make entire cell tappable
    }
    
    private var textColor: Color {
        if isToday { return .white } // Today: white text
        if !isCurrentMonth { return .gray.opacity(0.4) } // Other month dates: light gray
        return .black // Regular dates: black text
    }
    
    private var backgroundColor: Color {
        if isToday { return accentColor }
        return .clear
    }
}

// MARK: - Calendar Month Empty Events View

struct CalendarMonthEmptyEventsView: View {
    var body: some View {
        // Empty state: calendar icon + "No events" text
        VStack(spacing: 16) {
            Image(systemName: "calendar")
                .font(.system(size: 48))
                .foregroundColor(DesignSystem.secondaryGray.opacity(0.6))
            
            Text("No events")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Calendar Month Event Card

struct CalendarMonthEventCard: View {
    let event: CalendarEvent
    
    private var accentColor: Color {
        DesignSystem.accentColor
    }
    
    private var accentColorDark: Color {
        DesignSystem.accentColorDark
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let start = event.startDate, let end = event.endDate {
                Text(timeString(from: start, to: end))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.9))
            }
            
            Text(event.title ?? "Untitled Event")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                colors: [accentColor, accentColorDark],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: accentColor.opacity(0.3), radius: 12, x: 0, y: 4)
    }
    
    private func timeString(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

#Preview {
    CalendarMonthView(
        currentMonth: .constant(Date()),
        selectedDate: .constant(Date()),
        viewModel: CalendarViewModel()
    )
}
