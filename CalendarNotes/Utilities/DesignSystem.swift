//
//  DesignSystem.swift
//  CalendarNotes
//
//  Design system constants matching specifications
//

import SwiftUI

struct DesignSystem {
    // MARK: - Colors
    
    /// Primary purple accent color (#667eea)
    static let accentColor = Color(red: 0.4, green: 0.49, blue: 0.92)
    
    /// Dark purple for gradients (#764ba2)
    static let accentColorDark = Color(red: 0.46, green: 0.29, blue: 0.64)
    
    /// Purple gradient
    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accentColor, accentColorDark],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Light gray for search bar background
    static var searchBarBackground: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemGray6)
        #endif
    }
    
    /// System gray for secondary elements
    static var secondaryGray: Color {
        #if os(macOS)
        return Color(NSColor.secondaryLabelColor)
        #else
        return Color(UIColor.secondaryLabel)
        #endif
    }
    
    /// White background for cards
    static let cardBackground = Color.white
    
    /// Grouped background color
    static var groupedBackground: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemGroupedBackground)
        #endif
    }
    
    // MARK: - Typography
    
    /// SF Pro Display font family
    static func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .default)
    }
    
    /// Large bold title (34pt)
    static let largeTitle = font(size: 34, weight: .bold)
    
    /// Header title (24pt)
    static let headerTitle = font(size: 24, weight: .bold)
    
    /// Body text (16pt)
    static let bodyText = font(size: 16, weight: .regular)
    
    /// Caption text (13pt)
    static let captionText = font(size: 13, weight: .regular)
    
    // MARK: - Spacing
    
    static let cornerRadius: CGFloat = 16
    static let searchBarCornerRadius: CGFloat = 12
    static let cardCornerRadius: CGFloat = 16
    
    // MARK: - Shadows
    
    static let cardShadow = Shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
    static let subtleShadow = Shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    static let floatingButtonShadow = Shadow(color: accentColor.opacity(0.4), radius: 12, x: 0, y: 6)
    
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    
    // MARK: - Tab Bar
    
    static let tabBarHeight: CGFloat = 83
    static let floatingButtonSize: CGFloat = 56
    static let tabBarBlurMaterial: Material = .ultraThinMaterial
}

// MARK: - View Extensions

extension View {
    /// Apply card styling (white background, 16pt corner radius, subtle shadow)
    func cardStyle() -> some View {
        self
            .background(DesignSystem.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius))
            .shadow(
                color: DesignSystem.cardShadow.color,
                radius: DesignSystem.cardShadow.radius,
                x: DesignSystem.cardShadow.x,
                y: DesignSystem.cardShadow.y
            )
    }
    
    /// Apply subtle card styling
    func subtleCardStyle() -> some View {
        self
            .background(DesignSystem.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DesignSystem.cardCornerRadius))
            .shadow(
                color: DesignSystem.subtleShadow.color,
                radius: DesignSystem.subtleShadow.radius,
                x: DesignSystem.subtleShadow.x,
                y: DesignSystem.subtleShadow.y
            )
    }
}

