//
//  DateExtensions.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import Foundation

extension Date {
    
    // MARK: - Day Boundaries
    
    func startOfDay() -> Date {
        Calendar.current.startOfDay(for: self)
    }
    
    func endOfDay() -> Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay()) ?? self
    }
    
    // MARK: - Week Boundaries
    
    func startOfWeek(weekStartsOn: Int = 1) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        components.weekday = weekStartsOn
        return calendar.date(from: components) ?? self
    }
    
    func endOfWeek(weekStartsOn: Int = 1) -> Date {
        let startOfWeek = self.startOfWeek(weekStartsOn: weekStartsOn)
        return Calendar.current.date(byAdding: .day, value: 7, to: startOfWeek)?.addingTimeInterval(-1) ?? self
    }
    
    func daysInWeek(weekStartsOn: Int = 1) -> [Date] {
        let calendar = Calendar.current
        let startOfWeek = self.startOfWeek(weekStartsOn: weekStartsOn)
        var dates: [Date] = []
        
        for day in 0..<7 {
            if let date = calendar.date(byAdding: .day, value: day, to: startOfWeek) {
                dates.append(date)
            }
        }
        
        return dates
    }
    
    // MARK: - Month Boundaries
    
    func startOfMonth() -> Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components) ?? self
    }
    
    func endOfMonth() -> Date {
        var components = DateComponents()
        components.month = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfMonth()) ?? self
    }
    
    func daysInMonth() -> Int {
        let calendar = Calendar.current
        let range = calendar.range(of: .day, in: .month, for: self)
        return range?.count ?? 0
    }
    
    func allDatesInMonth() -> [Date] {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .month, for: self)!
        let days = daysInMonth()
        
        var dates: [Date] = []
        for day in 0..<days {
            if let date = calendar.date(byAdding: .day, value: day, to: interval.start) {
                dates.append(date)
            }
        }
        
        return dates
    }
    
    // MARK: - Year Boundaries
    
    func startOfYear() -> Date {
        let components = Calendar.current.dateComponents([.year], from: self)
        return Calendar.current.date(from: components) ?? self
    }
    
    func endOfYear() -> Date {
        var components = DateComponents()
        components.year = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfYear()) ?? self
    }
    
    // MARK: - Date Comparisons
    
    func isSameDay(as date: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: date)
    }
    
    func isToday() -> Bool {
        isSameDay(as: Date())
    }
    
    func isTomorrow() -> Bool {
        guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) else {
            return false
        }
        return isSameDay(as: tomorrow)
    }
    
    func isYesterday() -> Bool {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else {
            return false
        }
        return isSameDay(as: yesterday)
    }
    
    func isInCurrentWeek() -> Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    func isInCurrentMonth() -> Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }
    
    func isInCurrentYear() -> Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .year)
    }
    
    func isWeekend() -> Bool {
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: self)
        return weekday == 1 || weekday == 7 // Sunday or Saturday
    }
    
    func isWeekday() -> Bool {
        !isWeekend()
    }
    
    func isPast() -> Bool {
        self < Date()
    }
    
    func isFuture() -> Bool {
        self > Date()
    }
    
    // MARK: - Date Calculations
    
    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
    
    func adding(weeks: Int) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: self) ?? self
    }
    
    func adding(months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }
    
    func adding(years: Int) -> Date {
        Calendar.current.date(byAdding: .year, value: years, to: self) ?? self
    }
    
    func daysBetween(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: self.startOfDay(), to: date.startOfDay())
        return abs(components.day ?? 0)
    }
    
    func weeksBetween(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.weekOfYear], from: self, to: date)
        return abs(components.weekOfYear ?? 0)
    }
    
    func monthsBetween(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: self, to: date)
        return abs(components.month ?? 0)
    }
    
    // MARK: - Date Components
    
    func weekdayName(style: DateFormatter.Style = .full) -> String {
        let formatter = DateFormatter()
        switch style {
        case .short:
            formatter.dateFormat = "E"
        case .medium:
            formatter.dateFormat = "EEE"
        default:
            formatter.dateFormat = "EEEE"
        }
        return formatter.string(from: self)
    }
    
    func monthName(style: DateFormatter.Style = .full) -> String {
        let formatter = DateFormatter()
        switch style {
        case .short:
            formatter.dateFormat = "MMM"
        default:
            formatter.dateFormat = "MMMM"
        }
        return formatter.string(from: self)
    }
    
    var year: Int {
        Calendar.current.component(.year, from: self)
    }
    
    var month: Int {
        Calendar.current.component(.month, from: self)
    }
    
    var day: Int {
        Calendar.current.component(.day, from: self)
    }
    
    var hour: Int {
        Calendar.current.component(.hour, from: self)
    }
    
    var minute: Int {
        Calendar.current.component(.minute, from: self)
    }
    
    var weekday: Int {
        Calendar.current.component(.weekday, from: self)
    }
    
    // MARK: - Formatting
    
    func formatted(style: DateFormatter.Style = .medium) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }
    
    func formattedWithTime(dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter.string(from: self)
    }
    
    func timeOnly(style: DateFormatter.Style = .short) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = style
        return formatter.string(from: self)
    }
    
    func relativeFormatted() -> String {
        if isToday() {
            return "Today"
        } else if isTomorrow() {
            return "Tomorrow"
        } else if isYesterday() {
            return "Yesterday"
        } else if isInCurrentWeek() {
            return weekdayName(style: .full)
        } else {
            return formatted(style: .medium)
        }
    }
    
    func customFormatted(_ format: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        return formatter.string(from: self)
    }
    
    // MARK: - Calendar Grid Helpers
    
    /// Returns dates for calendar grid including padding days from previous/next month
    func calendarGridDates() -> [Date?] {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .month, for: self)!
        let days = daysInMonth()
        
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leadingEmptyDays = firstWeekday - 1
        
        var dates: [Date?] = Array(repeating: nil, count: leadingEmptyDays)
        dates += (0..<days).compactMap { day in
            calendar.date(byAdding: .day, value: day, to: interval.start)
        }
        
        // Pad the end to complete the grid (42 cells = 6 weeks)
        while dates.count < 42 {
            dates.append(nil)
        }
        
        return dates
    }
    
    /// Returns dates for calendar grid with actual dates from adjacent months
    func calendarGridDatesWithPadding() -> [Date] {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .month, for: self)!
        let firstWeekday = calendar.component(.weekday, from: interval.start)
        let leadingDays = firstWeekday - 1
        
        var dates: [Date] = []
        
        // Add leading days from previous month
        for i in (0..<leadingDays).reversed() {
            if let date = calendar.date(byAdding: .day, value: -(i + 1), to: interval.start) {
                dates.append(date)
            }
        }
        
        // Add current month days
        let days = daysInMonth()
        for day in 0..<days {
            if let date = calendar.date(byAdding: .day, value: day, to: interval.start) {
                dates.append(date)
            }
        }
        
        // Add trailing days from next month to complete grid
        while dates.count < 42 {
            if let lastDate = dates.last,
               let nextDate = calendar.date(byAdding: .day, value: 1, to: lastDate) {
                dates.append(nextDate)
            }
        }
        
        return dates
    }
    
    /// Returns dates for calendar grid with day 1 of month appearing first
    func calendarGridDatesWithDay1First() -> [Date] {
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .month, for: self)!
        let days = daysInMonth()
        
        var dates: [Date] = []
        
        // Start with day 1 of the current month
        for day in 0..<days {
            if let date = calendar.date(byAdding: .day, value: day, to: interval.start) {
                dates.append(date)
            }
        }
        
        // Add trailing days from next month to complete grid (42 cells = 6 weeks)
        while dates.count < 42 {
            if let lastDate = dates.last,
               let nextDate = calendar.date(byAdding: .day, value: 1, to: lastDate) {
                dates.append(nextDate)
            }
        }
        
        return dates
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    var hours: Int {
        Int(self) / 3600
    }
    
    var minutes: Int {
        (Int(self) % 3600) / 60
    }
    
    var seconds: Int {
        Int(self) % 60
    }
    
    func formattedDuration() -> String {
        let hours = self.hours
        let minutes = self.minutes
        
        if hours > 0 && minutes > 0 {
            return "\(hours)h \(minutes)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "< 1m"
        }
    }
}

