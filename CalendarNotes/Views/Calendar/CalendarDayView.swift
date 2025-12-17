//
//  CalendarDayView.swift
//  CalendarNotes
//
//  Day view with hourly timeline
//

import SwiftUI

struct CalendarDayView: View {
    @Binding var selectedDate: Date
    @ObservedObject var viewModel: CalendarViewModel
    
    private let hours = Array(6..<24) // 6 AM to 11 PM
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                dayNavigation
                
                dayTimeline
            }
        }
    }
    
    private var dayNavigation: some View {
        HStack {
            Button(action: {
                withAnimation(.spring()) {
                    selectedDate = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate) ?? selectedDate
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
            
            Text(dayText)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring()) {
                    selectedDate = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) ?? selectedDate
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
    
    private var dayText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: selectedDate)
    }
    
    private var dayTimeline: some View {
        VStack(spacing: 0) {
            ForEach(hours, id: \.self) { hour in
                DayTimeSlot(
                    hour: hour,
                    events: eventsForHour(hour)
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }
    
    private func eventsForHour(_ hour: Int) -> [CalendarEvent] {
        let calendar = Calendar.current
        return viewModel.events.filter { event in
            guard let eventDate = event.startDate else { return false }
            return calendar.isDate(eventDate, inSameDayAs: selectedDate) &&
                   calendar.component(.hour, from: eventDate) == hour
        }
    }
}

struct DayTimeSlot: View {
    let hour: Int
    let events: [CalendarEvent]
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(hourText)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
            
            VStack(alignment: .leading, spacing: 8) {
                if events.isEmpty {
                    Text("")
                        .font(.system(size: 14))
                        .foregroundColor(.clear)
                        .frame(height: 20)
                } else {
                    ForEach(events, id: \.id) { event in
                        CalendarDayViewEventBlock(event: event)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 70)
        .padding(.vertical, 8)
        .overlay(
            Rectangle()
                .fill(Color(white: 0.92))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private var hourText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h a"
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}

struct CalendarDayViewEventBlock: View {
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
    CalendarDayView(
        selectedDate: .constant(Date()),
        viewModel: CalendarViewModel()
    )
}
