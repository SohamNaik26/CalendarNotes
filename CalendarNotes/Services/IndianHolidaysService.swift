//
//  IndianHolidaysService.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import Foundation
import Combine

struct IndianHoliday {
    let name: String
    let date: Date
    let type: HolidayType
    let color: String
}

enum HolidayType: String, CaseIterable {
    case national = "National"
    case religious = "Religious"
    case regional = "Regional"
    case bank = "Bank"
}

class IndianHolidaysService: ObservableObject {
    static let shared = IndianHolidaysService()
    
    @Published var holidays: [IndianHoliday] = []
    
    private init() {
        loadHolidays()
    }
    
    private func loadHolidays() {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        var allHolidays: [IndianHoliday] = []
        
        // Add holidays for current year and next year
        for year in [currentYear, currentYear + 1] {
            allHolidays.append(contentsOf: getHolidaysForYear(year))
        }
        
        self.holidays = allHolidays
    }
    
    private func getHolidaysForYear(_ year: Int) -> [IndianHoliday] {
        return [
            // January
            IndianHoliday(name: "New Year's Day", date: createDate(year: year, month: 1, day: 1), type: .national, color: "green"),
            IndianHoliday(name: "Makar Sankranti", date: createDate(year: year, month: 1, day: 14), type: .religious, color: "green"),
            IndianHoliday(name: "Republic Day", date: createDate(year: year, month: 1, day: 26), type: .national, color: "green"),
            
            // February
            IndianHoliday(name: "Maha Shivaratri", date: createDate(year: year, month: 2, day: 18), type: .religious, color: "green"),
            
            // March
            IndianHoliday(name: "Holi", date: createDate(year: year, month: 3, day: 8), type: .religious, color: "green"),
            IndianHoliday(name: "Ram Navami", date: createDate(year: year, month: 3, day: 26), type: .religious, color: "green"),
            
            // April
            IndianHoliday(name: "Good Friday", date: createDate(year: year, month: 4, day: 18), type: .religious, color: "green"),
            IndianHoliday(name: "Ambedkar Jayanti", date: createDate(year: year, month: 4, day: 14), type: .national, color: "green"),
            
            // May
            IndianHoliday(name: "Labour Day", date: createDate(year: year, month: 5, day: 1), type: .national, color: "green"),
            IndianHoliday(name: "Buddha Purnima", date: createDate(year: year, month: 5, day: 23), type: .religious, color: "green"),
            
            // August
            IndianHoliday(name: "Independence Day", date: createDate(year: year, month: 8, day: 15), type: .national, color: "green"),
            IndianHoliday(name: "Raksha Bandhan", date: createDate(year: year, month: 8, day: 19), type: .religious, color: "green"),
            IndianHoliday(name: "Janmashtami", date: createDate(year: year, month: 8, day: 26), type: .religious, color: "green"),
            
            // September
            IndianHoliday(name: "Ganesh Chaturthi", date: createDate(year: year, month: 9, day: 7), type: .religious, color: "green"),
            IndianHoliday(name: "Onam", date: createDate(year: year, month: 9, day: 15), type: .religious, color: "green"),
            
            // October
            IndianHoliday(name: "Dussehra", date: createDate(year: year, month: 10, day: 1), type: .religious, color: "purple"),
            IndianHoliday(name: "Mahatma Gandhi Jayanti", date: createDate(year: year, month: 10, day: 2), type: .national, color: "green"),
            IndianHoliday(name: "Karva Chauth", date: createDate(year: year, month: 10, day: 9), type: .religious, color: "purple"),
            IndianHoliday(name: "Diwali", date: createDate(year: year, month: 10, day: 19), type: .religious, color: "purple"),
            IndianHoliday(name: "Govardhan Puja", date: createDate(year: year, month: 10, day: 21), type: .religious, color: "green"),
            IndianHoliday(name: "Bhai Dooj", date: createDate(year: year, month: 10, day: 22), type: .religious, color: "green"),
            IndianHoliday(name: "Chhath Puja", date: createDate(year: year, month: 10, day: 26), type: .religious, color: "purple"),
            
            // November
            IndianHoliday(name: "Guru Nanak Jayanti", date: createDate(year: year, month: 11, day: 4), type: .religious, color: "purple"),
            
            // December
            IndianHoliday(name: "Christmas", date: createDate(year: year, month: 12, day: 25), type: .religious, color: "green")
        ]
    }
    
    private func createDate(year: Int, month: Int, day: Int) -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components) ?? Date()
    }
    
    func getHolidaysForMonth(_ date: Date) -> [IndianHoliday] {
        let calendar = Calendar.current
        return holidays.filter { holiday in
            calendar.isDate(holiday.date, equalTo: date, toGranularity: .month)
        }
    }
    
    func getHolidaysForDate(_ date: Date) -> [IndianHoliday] {
        let calendar = Calendar.current
        return holidays.filter { holiday in
            calendar.isDate(holiday.date, inSameDayAs: date)
        }
    }
}
