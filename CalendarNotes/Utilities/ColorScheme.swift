//
//  ColorScheme.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import SwiftUI

extension Color {
    // MARK: - Primary Colors
    static let cnPrimary = Color("AppPrimary")
    static let cnSecondary = Color("AppSecondary")
    static let cnAccent = Color("AppAccent")
    
    // MARK: - Background Colors
    static let cnBackground = Color("AppBackground")
    static let cnSecondaryBackground = Color("AppSecondaryBackground")
    static let cnTertiaryBackground = Color("AppTertiaryBackground")
    
    // MARK: - Text Colors
    static let cnPrimaryText = Color("AppPrimaryText")
    static let cnSecondaryText = Color("AppSecondaryText")
    
    // MARK: - Category Colors
    static let cnCategoryWork = Color("CategoryWork")
    static let cnCategoryPersonal = Color("CategoryPersonal")
    static let cnCategoryHealth = Color("CategoryHealth")
    static let cnCategoryEducation = Color("CategoryEducation")
    static let cnCategoryOther = Color("CategoryOther")
    
    // MARK: - Status Colors
    static let cnStatusSuccess = Color("StatusSuccess")
    static let cnStatusWarning = Color("StatusWarning")
    static let cnStatusError = Color("StatusError")
    static let cnStatusInfo = Color("StatusInfo")
    
    // MARK: - Priority Colors
    static let cnPriorityLow = Color.green
    static let cnPriorityMedium = Color.yellow
    static let cnPriorityHigh = Color.orange
    static let cnPriorityUrgent = Color.red
    
    // MARK: - Accessibility Colors
    static let cnAccessibilityHighContrast = Color(red: 0, green: 0, blue: 0)
    static let cnAccessibilityHighContrastBackground = Color(red: 1, green: 1, blue: 1)
    static let cnAccessibilityHighContrastAccent = Color(red: 0, green: 0.5, blue: 1)
    
    // Color blind friendly colors
    static let cnColorBlindSafe1 = Color(red: 0.9, green: 0.1, blue: 0.1) // Red
    static let cnColorBlindSafe2 = Color(red: 0.1, green: 0.6, blue: 0.1) // Green
    static let cnColorBlindSafe3 = Color(red: 0.1, green: 0.1, blue: 0.9) // Blue
    static let cnColorBlindSafe4 = Color(red: 0.9, green: 0.6, blue: 0.1) // Orange
    static let cnColorBlindSafe5 = Color(red: 0.6, green: 0.1, blue: 0.9) // Purple
    static let cnColorBlindSafe6 = Color(red: 0.1, green: 0.9, blue: 0.9) // Cyan
}

// MARK: - Category Helper
enum EventCategory: String, CaseIterable {
    case work = "Work"
    case personal = "Personal"
    case health = "Health"
    case education = "Education"
    case other = "Other"
    
    var color: Color {
        switch self {
        case .work: return .cnCategoryWork
        case .personal: return .cnCategoryPersonal
        case .health: return .cnCategoryHealth
        case .education: return .cnCategoryEducation
        case .other: return .cnCategoryOther
        }
    }
    
    var icon: String {
        switch self {
        case .work: return "briefcase.fill"
        case .personal: return "person.fill"
        case .health: return "heart.fill"
        case .education: return "book.fill"
        case .other: return "square.grid.2x2.fill"
        }
    }
}
