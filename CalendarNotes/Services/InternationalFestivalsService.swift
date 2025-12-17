//
//  InternationalFestivalsService.swift
//  CalendarNotes
//
//  Service for international festivals and holidays
//

import Foundation
import Combine

struct InternationalFestival {
    let name: String
    let date: Date
    let type: FestivalType
    let country: String
    let color: String
}

enum FestivalType: String, CaseIterable {
    case religious = "Religious"
    case cultural = "Cultural"
    case national = "National"
    case international = "International"
    case secular = "Secular"
}

class InternationalFestivalsService: ObservableObject {
    static let shared = InternationalFestivalsService()
    
    @Published var festivals: [InternationalFestival] = []
    
    private init() {
        loadFestivals()
    }
    
    private func loadFestivals() {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        
        var allFestivals: [InternationalFestival] = []
        
        // Add festivals for current year and next year
        for year in [currentYear, currentYear + 1] {
            allFestivals.append(contentsOf: getFestivalsForYear(year))
        }
        
        self.festivals = allFestivals
    }
    
    private func getFestivalsForYear(_ year: Int) -> [InternationalFestival] {
        // Calculate variable dates first
        let easterDate = calculateEaster(year: year)
        let chineseNY = chineseNewYear(year: year)
        let passoverDate = passover(year: year)
        let roshHashana = roshHashanah(year: year)
        let yomKippurDate = yomKippur(year: year)
        let hanukkahDate = hanukkah(year: year)
        let mothersDayDate = mothersDay(year: year)
        let fathersDayDate = fathersDay(year: year)
        let memorialDayDate = memorialDay(year: year)
        let laborDayDate = laborDay(year: year)
        let columbusDayDate = columbusDay(year: year)
        let thanksgivingUSADate = thanksgivingUSA(year: year)
        let thanksgivingCanadaDate = thanksgivingCanada(year: year)
        
        return [
            // January - International
            InternationalFestival(name: "New Year's Day", date: createDate(year: year, month: 1, day: 1), type: .international, country: "Global", color: "blue"),
            InternationalFestival(name: "Epiphany", date: createDate(year: year, month: 1, day: 6), type: .religious, country: "Christian", color: "purple"),
            InternationalFestival(name: "Orthodox Christmas", date: createDate(year: year, month: 1, day: 7), type: .religious, country: "Eastern Orthodox", color: "blue"),
            InternationalFestival(name: "Australia Day", date: createDate(year: year, month: 1, day: 26), type: .national, country: "Australia", color: "blue"),
            
            // February - International
            InternationalFestival(name: "Groundhog Day", date: createDate(year: year, month: 2, day: 2), type: .cultural, country: "USA/Canada", color: "brown"),
            InternationalFestival(name: "Valentine's Day", date: createDate(year: year, month: 2, day: 14), type: .secular, country: "Global", color: "red"),
            InternationalFestival(name: "Mardi Gras", date: easterDate.addingTimeInterval(-47 * 24 * 3600), type: .cultural, country: "Global", color: "purple"),
            InternationalFestival(name: "Chinese New Year", date: chineseNY, type: .cultural, country: "China/East Asia", color: "red"),
            
            // March - International
            InternationalFestival(name: "St. Patrick's Day", date: createDate(year: year, month: 3, day: 17), type: .cultural, country: "Ireland/Global", color: "green"),
            InternationalFestival(name: "Spring Equinox", date: createDate(year: year, month: 3, day: 20), type: .cultural, country: "Global", color: "green"),
            InternationalFestival(name: "Nowruz", date: createDate(year: year, month: 3, day: 21), type: .cultural, country: "Persian/Iranian", color: "green"),
            
            // April - International
            InternationalFestival(name: "April Fool's Day", date: createDate(year: year, month: 4, day: 1), type: .secular, country: "Global", color: "yellow"),
            InternationalFestival(name: "Easter Sunday", date: easterDate, type: .religious, country: "Christian", color: "purple"),
            InternationalFestival(name: "Easter Monday", date: easterDate.addingTimeInterval(24 * 3600), type: .religious, country: "Christian", color: "purple"),
            InternationalFestival(name: "Earth Day", date: createDate(year: year, month: 4, day: 22), type: .international, country: "Global", color: "green"),
            InternationalFestival(name: "Passover", date: passoverDate, type: .religious, country: "Jewish", color: "blue"),
            
            // May - International
            InternationalFestival(name: "Labour Day", date: createDate(year: year, month: 5, day: 1), type: .international, country: "Global", color: "red"),
            InternationalFestival(name: "Cinco de Mayo", date: createDate(year: year, month: 5, day: 5), type: .cultural, country: "Mexico", color: "green"),
            InternationalFestival(name: "Mother's Day", date: mothersDayDate, type: .secular, country: "USA/Global", color: "pink"),
            InternationalFestival(name: "Ascension Day", date: easterDate.addingTimeInterval(39 * 24 * 3600), type: .religious, country: "Christian", color: "purple"),
            InternationalFestival(name: "Pentecost", date: easterDate.addingTimeInterval(49 * 24 * 3600), type: .religious, country: "Christian", color: "red"),
            InternationalFestival(name: "Memorial Day", date: memorialDayDate, type: .national, country: "USA", color: "blue"),
            InternationalFestival(name: "Whit Monday", date: easterDate.addingTimeInterval(50 * 24 * 3600), type: .religious, country: "Christian", color: "purple"),
            
            // June - International
            InternationalFestival(name: "D-Day", date: createDate(year: year, month: 6, day: 6), type: .national, country: "Allied Nations", color: "blue"),
            InternationalFestival(name: "Flag Day", date: createDate(year: year, month: 6, day: 14), type: .national, country: "USA", color: "red"),
            InternationalFestival(name: "Father's Day", date: fathersDayDate, type: .secular, country: "USA/Global", color: "blue"),
            InternationalFestival(name: "Summer Solstice", date: createDate(year: year, month: 6, day: 21), type: .cultural, country: "Global", color: "yellow"),
            InternationalFestival(name: "Pride Month", date: createDate(year: year, month: 6, day: 1), type: .cultural, country: "Global", color: "rainbow"),
            
            // July - International
            InternationalFestival(name: "Canada Day", date: createDate(year: year, month: 7, day: 1), type: .national, country: "Canada", color: "red"),
            InternationalFestival(name: "Independence Day", date: createDate(year: year, month: 7, day: 4), type: .national, country: "USA", color: "red"),
            InternationalFestival(name: "Bastille Day", date: createDate(year: year, month: 7, day: 14), type: .national, country: "France", color: "blue"),
            
            // August - International
            InternationalFestival(name: "Lammas", date: createDate(year: year, month: 8, day: 1), type: .cultural, country: "Celtic", color: "yellow"),
            InternationalFestival(name: "Hiroshima Day", date: createDate(year: year, month: 8, day: 6), type: .international, country: "Global", color: "white"),
            InternationalFestival(name: "International Youth Day", date: createDate(year: year, month: 8, day: 12), type: .international, country: "Global", color: "blue"),
            InternationalFestival(name: "Assumption of Mary", date: createDate(year: year, month: 8, day: 15), type: .religious, country: "Catholic", color: "blue"),
            
            // September - International
            InternationalFestival(name: "Labor Day", date: laborDayDate, type: .national, country: "USA", color: "blue"),
            InternationalFestival(name: "Rosh Hashanah", date: roshHashana, type: .religious, country: "Jewish", color: "blue"),
            InternationalFestival(name: "Yom Kippur", date: yomKippurDate, type: .religious, country: "Jewish", color: "blue"),
            InternationalFestival(name: "Autumn Equinox", date: createDate(year: year, month: 9, day: 22), type: .cultural, country: "Global", color: "orange"),
            
            // October - International
            InternationalFestival(name: "World Vegetarian Day", date: createDate(year: year, month: 10, day: 1), type: .secular, country: "Global", color: "green"),
            InternationalFestival(name: "Columbus Day", date: columbusDayDate, type: .national, country: "USA", color: "blue"),
            InternationalFestival(name: "Thanksgiving (Canada)", date: thanksgivingCanadaDate, type: .cultural, country: "Canada", color: "orange"),
            InternationalFestival(name: "Halloween", date: createDate(year: year, month: 10, day: 31), type: .cultural, country: "Global", color: "orange"),
            
            // November - International
            InternationalFestival(name: "All Saints' Day", date: createDate(year: year, month: 11, day: 1), type: .religious, country: "Catholic", color: "white"),
            InternationalFestival(name: "All Souls' Day", date: createDate(year: year, month: 11, day: 2), type: .religious, country: "Catholic", color: "purple"),
            InternationalFestival(name: "Veterans Day", date: createDate(year: year, month: 11, day: 11), type: .national, country: "USA", color: "blue"),
            InternationalFestival(name: "Remembrance Day", date: createDate(year: year, month: 11, day: 11), type: .national, country: "Commonwealth", color: "red"),
            InternationalFestival(name: "Thanksgiving (USA)", date: thanksgivingUSADate, type: .cultural, country: "USA", color: "orange"),
            InternationalFestival(name: "Hanukkah", date: hanukkahDate, type: .religious, country: "Jewish", color: "blue"),
            InternationalFestival(name: "Black Friday", date: thanksgivingUSADate.addingTimeInterval(24 * 3600), type: .secular, country: "USA/Global", color: "red"),
            
            // December - International
            InternationalFestival(name: "St. Nicholas Day", date: createDate(year: year, month: 12, day: 6), type: .cultural, country: "Europe", color: "red"),
            InternationalFestival(name: "Winter Solstice", date: createDate(year: year, month: 12, day: 21), type: .cultural, country: "Global", color: "white"),
            InternationalFestival(name: "Christmas Eve", date: createDate(year: year, month: 12, day: 24), type: .religious, country: "Christian", color: "green"),
            InternationalFestival(name: "Christmas Day", date: createDate(year: year, month: 12, day: 25), type: .religious, country: "Christian", color: "green"),
            InternationalFestival(name: "Boxing Day", date: createDate(year: year, month: 12, day: 26), type: .cultural, country: "UK/Commonwealth", color: "blue"),
            InternationalFestival(name: "New Year's Eve", date: createDate(year: year, month: 12, day: 31), type: .secular, country: "Global", color: "blue")
        ]
    }
    
    // MARK: - Helper Functions for Variable Dates
    
    private func calculateEaster(year: Int) -> Date {
        // Simplified Easter calculation (Meeus/Jones/Butcher algorithm)
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
    
    private func chineseNewYear(year: Int) -> Date {
        // Simplified - Chinese New Year typically falls between Jan 21 - Feb 20
        // For accuracy, you'd need proper lunar calendar calculations
        // This is an approximation
        let chineseNewYearDates: [Int: Int] = [
            2024: 10,  // Feb 10, 2024
            2025: 29   // Jan 29, 2025
        ]
        if let day = chineseNewYearDates[year] {
            return year < 2025 ? createDate(year: year, month: 2, day: day) : createDate(year: year, month: 1, day: day)
        }
        // Default approximation
        return createDate(year: year, month: 2, day: 10)
    }
    
    private func passover(year: Int) -> Date {
        // Simplified - Passover typically in March/April
        // Actual calculation requires Hebrew calendar
        let passoverDates: [Int: (Int, Int)] = [
            2024: (4, 22),
            2025: (4, 13),
            2026: (4, 2)
        ]
        if let (month, day) = passoverDates[year] {
            return createDate(year: year, month: month, day: day)
        }
        // Fallback approximation
        let easter = calculateEaster(year: year)
        return easter.addingTimeInterval(-14 * 24 * 3600)
    }
    
    private func roshHashanah(year: Int) -> Date {
        // Simplified - Rosh Hashanah typically in September/October
        let dates: [Int: (Int, Int)] = [
            2024: (10, 2),
            2025: (9, 22),
            2026: (9, 11)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 9, day: 25) // Fallback
    }
    
    private func yomKippur(year: Int) -> Date {
        // Yom Kippur is 10 days after Rosh Hashanah
        let roshHashana = roshHashanah(year: year)
        return roshHashana.addingTimeInterval(10 * 24 * 3600)
    }
    
    private func hanukkah(year: Int) -> Date {
        // Simplified - Hanukkah typically in November/December
        let dates: [Int: (Int, Int)] = [
            2024: (12, 25),
            2025: (12, 14),
            2026: (12, 4)
        ]
        if let (month, day) = dates[year] {
            return createDate(year: year, month: month, day: day)
        }
        return createDate(year: year, month: 12, day: 18) // Fallback
    }
    
    private func mothersDay(year: Int) -> Date {
        // Second Sunday in May (USA)
        let date = createDate(year: year, month: 5, day: 1)
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let daysToAdd = (8 - weekday) % 7 // Days to first Sunday
        return calendar.date(byAdding: .day, value: daysToAdd + 7, to: date) ?? date // Second Sunday
    }
    
    private func fathersDay(year: Int) -> Date {
        // Third Sunday in June (USA)
        let date = createDate(year: year, month: 6, day: 1)
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let daysToAdd = (8 - weekday) % 7 // Days to first Sunday
        return calendar.date(byAdding: .day, value: daysToAdd + 14, to: date) ?? date // Third Sunday
    }
    
    private func memorialDay(year: Int) -> Date {
        // Last Monday in May (USA)
        let date = createDate(year: year, month: 5, day: 31)
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let daysToSubtract = (weekday + 5) % 7 // Days to go back to Monday
        return calendar.date(byAdding: .day, value: -daysToSubtract, to: date) ?? date
    }
    
    private func laborDay(year: Int) -> Date {
        // First Monday in September (USA)
        let date = createDate(year: year, month: 9, day: 1)
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let daysToAdd = (8 - weekday) % 7 // Days to first Monday
        return calendar.date(byAdding: .day, value: daysToAdd, to: date) ?? date
    }
    
    private func columbusDay(year: Int) -> Date {
        // Second Monday in October (USA)
        let date = createDate(year: year, month: 10, day: 1)
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let daysToAdd = (8 - weekday) % 7 // Days to first Monday
        return calendar.date(byAdding: .day, value: daysToAdd + 7, to: date) ?? date // Second Monday
    }
    
    private func thanksgivingUSA(year: Int) -> Date {
        // Fourth Thursday in November (USA)
        let date = createDate(year: year, month: 11, day: 1)
        let calendar = Calendar.current
        let weekday = calendar.component(.weekday, from: date)
        let daysToAdd = (12 - weekday) % 7 // Days to first Thursday
        return calendar.date(byAdding: .day, value: daysToAdd + 21, to: date) ?? date // Fourth Thursday
    }
    
    private func thanksgivingCanada(year: Int) -> Date {
        // Second Monday in October (Canada)
        return columbusDay(year: year) // Same date as Columbus Day
    }
    
    private func createDate(year: Int, month: Int, day: Int) -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return calendar.date(from: components) ?? Date()
    }
    
    func getFestivalsForMonth(_ date: Date) -> [InternationalFestival] {
        let calendar = Calendar.current
        return festivals.filter { festival in
            calendar.isDate(festival.date, equalTo: date, toGranularity: .month)
        }
    }
    
    func getFestivalsForDate(_ date: Date) -> [InternationalFestival] {
        let calendar = Calendar.current
        return festivals.filter { festival in
            calendar.isDate(festival.date, inSameDayAs: date)
        }
    }
}

