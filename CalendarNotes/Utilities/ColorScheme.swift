//
//  ColorScheme.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import SwiftUI

extension Color {
    // MARK: - Safe Named Color Helper
    private static func namedColor(_ name: String, fallback: Color) -> Color {
        #if os(macOS)
        if let resolved = NSColor(named: NSColor.Name(name)) {
            return Color(resolved)
        }
        return fallback
        #else
        if let resolved = UIColor(named: name) {
            return Color(resolved)
        }
        return fallback
        #endif
    }
    
    // MARK: - Primary Colors (Purple Gradient Scheme)
    // Primary Purple: #667eea
    static let cnPrimary = namedColor("AppPrimary", fallback: Color(hex: "#667eea"))
    // Accent Purple: #764ba2
    static let cnAccent = namedColor("AppAccent", fallback: Color(hex: "#764ba2"))
    // Lighter Purple for accents
    static let cnAccentLight = namedColor("AppAccentLight", fallback: Color(hex: "#A594F9"))
    static let cnSecondary = namedColor("AppSecondary", fallback: .gray)
    
    // MARK: - Purple Gradient
    static var cnGradient: LinearGradient {
        LinearGradient(
            colors: [cnPrimary, cnAccent],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Background Colors
    #if os(macOS)
    static let cnBackground = namedColor("AppBackground", fallback: Color(NSColor.windowBackgroundColor))
    static let cnSecondaryBackground = namedColor("AppSecondaryBackground", fallback: Color(NSColor.underPageBackgroundColor))
    static let cnTertiaryBackground = namedColor("AppTertiaryBackground", fallback: Color(NSColor.textBackgroundColor))
    #else
    static let cnBackground = namedColor("AppBackground", fallback: Color(UIColor.systemBackground))
    static let cnSecondaryBackground = namedColor("AppSecondaryBackground", fallback: Color(UIColor.secondarySystemBackground))
    static let cnTertiaryBackground = namedColor("AppTertiaryBackground", fallback: Color(UIColor.tertiarySystemBackground))
    #endif
    
    // MARK: - Text Colors
    #if os(macOS)
    static let cnPrimaryText = namedColor("AppPrimaryText", fallback: Color(NSColor.labelColor))
    static let cnSecondaryText = namedColor("AppSecondaryText", fallback: Color(hex: "#8E8E93"))
    static let cnTertiaryText = namedColor("AppTertiaryText", fallback: Color(NSColor.tertiaryLabelColor))
    #else
    static let cnPrimaryText = namedColor("AppPrimaryText", fallback: Color(UIColor.label))
    // Secondary text: #8E8E93
    static let cnSecondaryText = namedColor("AppSecondaryText", fallback: Color(hex: "#8E8E93"))
    static let cnTertiaryText = namedColor("AppTertiaryText", fallback: Color(UIColor.tertiaryLabel))
    #endif
    
    // MARK: - Category Colors
    static let cnCategoryWork = Color("CategoryWork")
    static let cnCategoryPersonal = Color("CategoryPersonal")
    static let cnCategoryHealth = Color("CategoryHealth")
    static let cnCategoryEducation = Color("CategoryEducation")
    static let cnCategoryOther = Color("CategoryOther")
    
    // MARK: - Status Colors
    static let cnStatusSuccess = namedColor("StatusSuccess", fallback: .green)
    static let cnStatusWarning = namedColor("StatusWarning", fallback: .yellow)
    static let cnStatusError = namedColor("StatusError", fallback: .red)
    static let cnStatusInfo = namedColor("StatusInfo", fallback: .blue)
    
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
    
    // MARK: - Hex Color Initializer
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    // MARK: - Hex Color Helper (for optional usage)
    static func hex(_ hex: String) -> Color? {
        let trimmed = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard !trimmed.isEmpty else { return nil }
        // Use the initializer directly
        return Color(hex: hex)
    }
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
