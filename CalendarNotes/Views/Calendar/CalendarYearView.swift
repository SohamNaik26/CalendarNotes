//
//  CalendarYearView.swift
//  CalendarNotes
//
//  Year view showing 12 mini months
//

import SwiftUI

struct CalendarYearView: View {
    @Binding var currentYear: Date
    @Binding var selectedDate: Date
    @ObservedObject var viewModel: CalendarViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                yearNavigation
                
                yearGrid
            }
        }
    }
    
    private var yearNavigation: some View {
        HStack {
            Button(action: {
                withAnimation(.spring()) {
                    currentYear = Calendar.current.date(byAdding: .year, value: -1, to: currentYear) ?? currentYear
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
            
            Text(yearText)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.primary)
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring()) {
                    currentYear = Calendar.current.date(byAdding: .year, value: 1, to: currentYear) ?? currentYear
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
    
    private var yearText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: currentYear)
    }
    
    private var yearGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 20),
            GridItem(.flexible(), spacing: 20),
            GridItem(.flexible(), spacing: 20)
        ], spacing: 20) {
            ForEach(monthsInYear, id: \.self) { month in
                MiniMonthCard(month: month, selectedDate: selectedDate, viewModel: viewModel)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 20)
    }
    
    private var monthsInYear: [Date] {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: currentYear)
        var months: [Date] = []
        
        for month in 1...12 {
            if let date = calendar.date(from: DateComponents(year: year, month: month, day: 1)) {
                months.append(date)
            }
        }
        
        return months
    }
}

struct MiniMonthCard: View {
    let month: Date
    let selectedDate: Date
    @ObservedObject var viewModel: CalendarViewModel
    
    private var accentColor: Color {
        Color(red: 0.4, green: 0.49, blue: 0.92)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(monthName)
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.bottom, 4)
            
            miniCalendarGrid
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
    
    private var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: month)
    }
    
    private var miniCalendarGrid: some View {
        let calendar = Calendar.current
        guard let firstDayOfMonth = calendar.dateInterval(of: .month, for: month)?.start else {
            return AnyView(EmptyView())
        }
        
        let firstWeekday = calendar.component(.weekday, from: firstDayOfMonth)
        let daysToSubtract = (firstWeekday - calendar.firstWeekday + 7) % 7
        
        guard let startDate = calendar.date(byAdding: .day, value: -daysToSubtract, to: firstDayOfMonth) else {
            return AnyView(EmptyView())
        }
        
        // Weekday headers
        let weekdays = ["S", "M", "T", "W", "T", "F", "S"]
        
        return AnyView(
            VStack(spacing: 8) {
                // Weekday headers
                HStack(spacing: 4) {
                    ForEach(weekdays, id: \.self) { day in
                        Text(day)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Calendar grid - 6 weeks
                VStack(spacing: 4) {
                    ForEach(0..<6) { week in
                        HStack(spacing: 4) {
                            ForEach(0..<7) { dayOffset in
                                let totalDay = week * 7 + dayOffset
                                if let date = calendar.date(byAdding: .day, value: totalDay, to: startDate) {
                                    let day = calendar.component(.day, from: date)
                                    let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
                                    let isCurrentMonth = calendar.isDate(date, equalTo: month, toGranularity: .month)
                                    let isToday = calendar.isDateInToday(date)
                                    let hasEvents = hasEvents(on: date)
                                    
                                    ZStack {
                                        if isToday {
                                            Circle()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [accentColor, DesignSystem.accentColorDark],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 22, height: 22)
                                        } else if isSelected {
                                            Circle()
                                                .stroke(accentColor, lineWidth: 2)
                                                .frame(width: 22, height: 22)
                                        }
                                        
                                        Text("\(day)")
                                            .font(.system(size: 11, weight: (isSelected || isToday) ? .semibold : .regular))
                                            .foregroundColor(
                                                isToday ? .white :
                                                (isSelected ? accentColor :
                                                (isCurrentMonth ? .primary : .secondary.opacity(0.5)))
                                            )
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 22)
                                }
                            }
                        }
                    }
                }
            }
        )
    }
    
    private func hasEvents(on date: Date) -> Bool {
        let calendar = Calendar.current
        return viewModel.events.contains { event in
            guard let eventDate = event.startDate else { return false }
            return calendar.isDate(eventDate, inSameDayAs: date)
        }
    }
}

#Preview {
    CalendarYearView(
        currentYear: .constant(Date()),
        selectedDate: .constant(Date()),
        viewModel: CalendarViewModel()
    )
}
