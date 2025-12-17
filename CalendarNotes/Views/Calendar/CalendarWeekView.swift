//
//  CalendarWeekView.swift
//  CalendarNotes
//
//  Week view showing 7 days vertically
//

import SwiftUI

struct CalendarWeekView: View {
    @Binding var selectedDate: Date
    @ObservedObject var viewModel: CalendarViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                weekNavigation
                
                weekContent
            }
        }
    }
    
    private var weekNavigation: some View {
        HStack {
            Button(action: {
                withAnimation(.spring()) {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -7, to: selectedDate) ?? selectedDate
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
            
            Text(weekText)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring()) {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 7, to: selectedDate) ?? selectedDate
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
        .padding(.vertical, 16)
    }
    
    private var weekText: String {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
            return ""
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let start = weekInterval.start
        let end = calendar.date(byAdding: .day, value: 6, to: start) ?? start
        
        // Format: "Dec 7 - Dec 13" with proper spacing
        let startString = formatter.string(from: start)
        let endString = formatter.string(from: end)
        return "\(startString) - \(endString)"
    }
    
    private var weekContent: some View {
        VStack(spacing: 12) {
            let calendar = Calendar.current
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
                return AnyView(EmptyView())
            }
            
            let startDate = weekInterval.start
            var days: [Date] = []
            for i in 0..<7 {
                if let date = calendar.date(byAdding: .day, value: i, to: startDate) {
                    days.append(date)
                }
            }
            
            return AnyView(
                ForEach(days, id: \.self) { date in
                    WeekDayCard(date: date, events: eventsForDate(date))
                }
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }
    
    private func eventsForDate(_ date: Date) -> [CalendarEvent] {
        let calendar = Calendar.current
        return viewModel.events.filter { event in
            guard let eventDate = event.startDate else { return false }
            return calendar.isDate(eventDate, inSameDayAs: date)
        }
    }
}

struct WeekDayCard: View {
    let date: Date
    let events: [CalendarEvent]
    
    private var accentColor: Color {
        Color(red: 0.4, green: 0.49, blue: 0.92)
    }
    
    private var accentColorDark: Color {
        Color(red: 0.46, green: 0.29, blue: 0.64)
    }
    
    var body: some View {
        HStack(spacing: 16) {
            WeekDateSection(date: date)
            
            VStack(alignment: .leading, spacing: 8) {
                if events.isEmpty {
                    Text("No events")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .padding(.vertical, 12)
                } else {
                    ForEach(events, id: \.id) { event in
                        WeekEventPill(event: event)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(Color.white)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(white: 0.9), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}

struct WeekDateSection: View {
    let date: Date
    let isToday: Bool
    
    private var accentColor: Color {
        Color(red: 0.4, green: 0.49, blue: 0.92)
    }
    
    init(date: Date) {
        self.date = date
        self.isToday = Calendar.current.isDate(date, inSameDayAs: Date())
    }
    
    var body: some View {
        VStack(spacing: 4) {
            Text(dayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isToday ? .white : .secondary)
            
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(isToday ? .white : .primary)
        }
        .frame(minWidth: 56)
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(
            Group {
                if isToday {
                    LinearGradient(
                        colors: [accentColor, DesignSystem.accentColorDark],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                } else {
                    Color.clear
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var dayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date).uppercased()
    }
}

struct WeekEventPill: View {
    let event: CalendarEvent
    
    private var accentColor: Color {
        Color(red: 0.4, green: 0.49, blue: 0.92)
    }
    
    private var accentColorDark: Color {
        Color(red: 0.46, green: 0.29, blue: 0.64)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.title ?? "Untitled Event")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
            
            if let start = event.startDate, let end = event.endDate {
                Text(timeString(from: start, to: end))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.9))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(8)
        .background(
            LinearGradient(
                colors: [accentColor, accentColorDark],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func timeString(from start: Date, to end: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
    }
}

#Preview {
    CalendarWeekView(
        selectedDate: .constant(Date()),
        viewModel: CalendarViewModel()
    )
}
