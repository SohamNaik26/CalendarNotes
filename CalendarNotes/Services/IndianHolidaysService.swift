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
    case secular = "Secular"
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
        // Calculate variable dates (using approximations for lunar calendar dates)
        // Note: Actual lunar dates vary each year - these are approximations
        let holiDate = calculateHoli(year: year)
        let ramNavamiDate = calculateRamNavami(year: year)
        let goodFridayDate = calculateGoodFriday(year: year)
        let buddhaPurnimaDate = calculateBuddhaPurnima(year: year)
        let rakshaBandhanDate = calculateRakshaBandhan(year: year)
        let janmashtamiDate = calculateJanmashtami(year: year)
        let ganeshChaturthiDate = calculateGaneshChaturthi(year: year)
        let onamDate = calculateOnam(year: year)
        let dussehraDate = calculateDussehra(year: year)
        let karvaChauthDate = calculateKarvaChauth(year: year)
        let diwaliDate = calculateDiwali(year: year)
        let govardhanPujaDate = calculateGovardhanPuja(year: year)
        let bhaiDoojDate = calculateBhaiDooj(year: year)
        let chhathPujaDate = calculateChhathPuja(year: year)
        let guruNanakJayantiDate = calculateGuruNanakJayanti(year: year)
        
        return [
            // January
            IndianHoliday(name: "New Year's Day", date: createDate(year: year, month: 1, day: 1), type: .national, color: "green"),
            IndianHoliday(name: "Makar Sankranti", date: createDate(year: year, month: 1, day: 14), type: .religious, color: "orange"),
            IndianHoliday(name: "Pongal", date: createDate(year: year, month: 1, day: 15), type: .regional, color: "orange"),
            IndianHoliday(name: "Lohri", date: createDate(year: year, month: 1, day: 13), type: .regional, color: "orange"),
            IndianHoliday(name: "Republic Day", date: createDate(year: year, month: 1, day: 26), type: .national, color: "green"),
            IndianHoliday(name: "Basant Panchami", date: calculateBasantPanchami(year: year), type: .religious, color: "yellow"),
            
            // February
            IndianHoliday(name: "Maha Shivaratri", date: calculateMahaShivaratri(year: year), type: .religious, color: "purple"),
            IndianHoliday(name: "Vasant Panchami", date: calculateBasantPanchami(year: year), type: .religious, color: "yellow"),
            
            // March
            IndianHoliday(name: "Holi", date: holiDate, type: .religious, color: "rainbow"),
            IndianHoliday(name: "Holi Dhuleti", date: holiDate.addingTimeInterval(24 * 3600), type: .religious, color: "rainbow"),
            IndianHoliday(name: "Ugadi", date: calculateUgadi(year: year), type: .regional, color: "yellow"),
            IndianHoliday(name: "Gudi Padwa", date: calculateUgadi(year: year), type: .regional, color: "yellow"),
            IndianHoliday(name: "Ram Navami", date: ramNavamiDate, type: .religious, color: "blue"),
            
            // April
            IndianHoliday(name: "Good Friday", date: goodFridayDate, type: .religious, color: "red"),
            IndianHoliday(name: "Easter", date: goodFridayDate.addingTimeInterval(3 * 24 * 3600), type: .religious, color: "green"),
            IndianHoliday(name: "Ambedkar Jayanti", date: createDate(year: year, month: 4, day: 14), type: .national, color: "blue"),
            IndianHoliday(name: "Baisakhi", date: createDate(year: year, month: 4, day: 13), type: .religious, color: "orange"),
            IndianHoliday(name: "Vaisakhi", date: createDate(year: year, month: 4, day: 13), type: .religious, color: "orange"),
            IndianHoliday(name: "Pohela Boishakh", date: createDate(year: year, month: 4, day: 14), type: .regional, color: "green"),
            
            // May
            IndianHoliday(name: "Labour Day", date: createDate(year: year, month: 5, day: 1), type: .national, color: "red"),
            IndianHoliday(name: "Buddha Purnima", date: buddhaPurnimaDate, type: .religious, color: "yellow"),
            IndianHoliday(name: "Akshaya Tritiya", date: calculateAkshayaTritiya(year: year), type: .religious, color: "gold"),
            
            // June
            IndianHoliday(name: "Eid al-Fitr", date: calculateEidFitr(year: year), type: .religious, color: "green"),
            
            // July
            IndianHoliday(name: "Rath Yatra", date: calculateRathYatra(year: year), type: .religious, color: "orange"),
            IndianHoliday(name: "Guru Purnima", date: calculateGuruPurnima(year: year), type: .religious, color: "orange"),
            
            // August
            IndianHoliday(name: "Independence Day", date: createDate(year: year, month: 8, day: 15), type: .national, color: "green"),
            IndianHoliday(name: "Raksha Bandhan", date: rakshaBandhanDate, type: .religious, color: "pink"),
            IndianHoliday(name: "Janmashtami", date: janmashtamiDate, type: .religious, color: "blue"),
            IndianHoliday(name: "Onam", date: onamDate, type: .religious, color: "rainbow"),
            
            // September
            IndianHoliday(name: "Ganesh Chaturthi", date: ganeshChaturthiDate, type: .religious, color: "orange"),
            IndianHoliday(name: "Eid al-Adha", date: calculateEidAdha(year: year), type: .religious, color: "green"),
            IndianHoliday(name: "Muharram", date: calculateMuharram(year: year), type: .religious, color: "black"),
            
            // October
            IndianHoliday(name: "Dussehra", date: dussehraDate, type: .religious, color: "orange"),
            IndianHoliday(name: "Mahatma Gandhi Jayanti", date: createDate(year: year, month: 10, day: 2), type: .national, color: "green"),
            IndianHoliday(name: "Karva Chauth", date: karvaChauthDate, type: .religious, color: "red"),
            IndianHoliday(name: "Diwali", date: diwaliDate, type: .religious, color: "gold"),
            IndianHoliday(name: "Govardhan Puja", date: govardhanPujaDate, type: .religious, color: "green"),
            IndianHoliday(name: "Bhai Dooj", date: bhaiDoojDate, type: .religious, color: "orange"),
            IndianHoliday(name: "Chhath Puja", date: chhathPujaDate, type: .religious, color: "orange"),
            
            // November
            IndianHoliday(name: "Guru Nanak Jayanti", date: guruNanakJayantiDate, type: .religious, color: "orange"),
            IndianHoliday(name: "Dev Diwali", date: calculateDevDiwali(year: year), type: .religious, color: "gold"),
            IndianHoliday(name: "Kartik Purnima", date: calculateKartikPurnima(year: year), type: .religious, color: "orange"),
            
            // December
            IndianHoliday(name: "Christmas", date: createDate(year: year, month: 12, day: 25), type: .religious, color: "green"),
            IndianHoliday(name: "New Year's Eve", date: createDate(year: year, month: 12, day: 31), type: .secular, color: "blue")
        ]
    }
    
    // MARK: - Lunar Calendar Date Calculations (Approximations)
    
    // Note: These are simplified approximations. For accurate dates, use proper lunar calendar calculations
    
    private func calculateMahaShivaratri(year: Int) -> Date {
        // Typically February/March
        let dates: [Int: (Int, Int)] = [
            2024: (3, 8),
            2025: (2, 26),
            2026: (2, 15)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 2, day: 28)
    }
    
    private func calculateHoli(year: Int) -> Date {
        // Typically March
        let dates: [Int: (Int, Int)] = [
            2024: (3, 25),
            2025: (3, 14),
            2026: (3, 3)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 3, day: 8)
    }
    
    private func calculateRamNavami(year: Int) -> Date {
        // Typically March/April
        let dates: [Int: (Int, Int)] = [
            2024: (4, 17),
            2025: (4, 6),
            2026: (3, 27)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 3, day: 26)
    }
    
    private func calculateGoodFriday(year: Int) -> Date {
        // Good Friday is 2 days before Easter
        let easter = calculateEaster(year: year)
        return easter.addingTimeInterval(-2 * 24 * 3600)
    }
    
    private func calculateEaster(year: Int) -> Date {
        // Simplified Easter calculation
        let a = year % 19
        let b = year / 100
        let c = year % 100
        let d = b / 4
        let e = b % 4
        let f = (b + 8) / 25
        let g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30
        let i = c / 4
        let k = c % 4
        let l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31
        let day = ((h + l - 7 * m + 114) % 31) + 1
        return createDate(year: year, month: month, day: day)
    }
    
    private func calculateBuddhaPurnima(year: Int) -> Date {
        // Typically May
        let dates: [Int: (Int, Int)] = [
            2024: (5, 23),
            2025: (5, 12),
            2026: (5, 1)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 5, day: 23)
    }
    
    private func calculateRakshaBandhan(year: Int) -> Date {
        // Typically August
        let dates: [Int: (Int, Int)] = [
            2024: (8, 19),
            2025: (8, 9),
            2026: (7, 30)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 8, day: 19)
    }
    
    private func calculateJanmashtami(year: Int) -> Date {
        // Typically August/September
        let dates: [Int: (Int, Int)] = [
            2024: (8, 26),
            2025: (8, 15),
            2026: (9, 3)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 8, day: 26)
    }
    
    private func calculateGaneshChaturthi(year: Int) -> Date {
        // Typically August/September
        let dates: [Int: (Int, Int)] = [
            2024: (9, 7),
            2025: (8, 27),
            2026: (9, 14)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 9, day: 7)
    }
    
    private func calculateOnam(year: Int) -> Date {
        // Typically August/September
        let dates: [Int: (Int, Int)] = [
            2024: (9, 5),
            2025: (8, 25),
            2026: (9, 12)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 9, day: 15)
    }
    
    private func calculateDussehra(year: Int) -> Date {
        // Typically October
        let dates: [Int: (Int, Int)] = [
            2024: (10, 12),
            2025: (10, 1),
            2026: (9, 20)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 10, day: 1)
    }
    
    private func calculateKarvaChauth(year: Int) -> Date {
        // Typically October/November
        let dates: [Int: (Int, Int)] = [
            2024: (11, 1),
            2025: (10, 21),
            2026: (10, 10)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 10, day: 9)
    }
    
    private func calculateDiwali(year: Int) -> Date {
        // Typically October/November
        let dates: [Int: (Int, Int)] = [
            2024: (11, 1),
            2025: (10, 20),
            2026: (10, 8)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 10, day: 19)
    }
    
    private func calculateGovardhanPuja(year: Int) -> Date {
        // Day after Diwali
        return calculateDiwali(year: year).addingTimeInterval(24 * 3600)
    }
    
    private func calculateBhaiDooj(year: Int) -> Date {
        // 2 days after Diwali
        return calculateDiwali(year: year).addingTimeInterval(2 * 24 * 3600)
    }
    
    private func calculateChhathPuja(year: Int) -> Date {
        // 6 days after Diwali
        return calculateDiwali(year: year).addingTimeInterval(6 * 24 * 3600)
    }
    
    private func calculateGuruNanakJayanti(year: Int) -> Date {
        // Typically November
        let dates: [Int: (Int, Int)] = [
            2024: (11, 15),
            2025: (11, 4),
            2026: (10, 23)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 11, day: 4)
    }
    
    private func calculateBasantPanchami(year: Int) -> Date {
        // Typically January/February
        let dates: [Int: (Int, Int)] = [
            2024: (2, 14),
            2025: (2, 2),
            2026: (1, 22)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 1, day: 28)
    }
    
    private func calculateUgadi(year: Int) -> Date {
        // Typically March/April
        let dates: [Int: (Int, Int)] = [
            2024: (4, 9),
            2025: (3, 30),
            2026: (3, 19)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 3, day: 26)
    }
    
    private func calculateAkshayaTritiya(year: Int) -> Date {
        // Typically April/May
        let dates: [Int: (Int, Int)] = [
            2024: (5, 10),
            2025: (4, 29),
            2026: (4, 18)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 4, day: 28)
    }
    
    private func calculateEidFitr(year: Int) -> Date {
        // Typically June/July (approximation)
        let dates: [Int: (Int, Int)] = [
            2024: (6, 16),
            2025: (3, 31),
            2026: (3, 21)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 6, day: 15)
    }
    
    private func calculateEidAdha(year: Int) -> Date {
        // Typically July/August (approximation)
        let dates: [Int: (Int, Int)] = [
            2024: (6, 16),
            2025: (6, 6),
            2026: (5, 27)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 7, day: 10)
    }
    
    private func calculateMuharram(year: Int) -> Date {
        // Typically August/September (approximation)
        let dates: [Int: (Int, Int)] = [
            2024: (7, 17),
            2025: (7, 7),
            2026: (6, 26)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 8, day: 1)
    }
    
    private func calculateRathYatra(year: Int) -> Date {
        // Typically July
        let dates: [Int: (Int, Int)] = [
            2024: (7, 7),
            2025: (6, 26),
            2026: (7, 15)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 7, day: 7)
    }
    
    private func calculateGuruPurnima(year: Int) -> Date {
        // Typically July
        let dates: [Int: (Int, Int)] = [
            2024: (7, 21),
            2025: (7, 10),
            2026: (7, 30)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 7, day: 21)
    }
    
    private func calculateDevDiwali(year: Int) -> Date {
        // Typically November (15 days after Diwali)
        return calculateDiwali(year: year).addingTimeInterval(15 * 24 * 3600)
    }
    
    private func calculateKartikPurnima(year: Int) -> Date {
        // Typically November
        let dates: [Int: (Int, Int)] = [
            2024: (11, 15),
            2025: (11, 4),
            2026: (10, 24)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 11, day: 15)
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
