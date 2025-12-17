import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct ReadingAppearanceSettings: Equatable {
    enum FontFamily: String, CaseIterable, Identifiable {
        case serif
        case sansSerif
        case rounded
        case mono
        
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .serif: return "Serif"
            case .sansSerif: return "Sans"
            case .rounded: return "Rounded"
            case .mono: return "Mono"
            }
        }
        
        var fontDesign: Font.Design {
            switch self {
            case .serif: return .serif
            case .sansSerif: return .default
            case .rounded: return .rounded
            case .mono: return .monospaced
            }
        }
    }
    
    enum Theme: String, CaseIterable, Identifiable {
        case day
        case night
        case sepia
        case pitch
        
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .day: return "Daylight"
            case .night: return "Night"
            case .sepia: return "Sepia"
            case .pitch: return "Pitch"
            }
        }
        
        var backgroundColor: Color {
            #if canImport(UIKit)
            switch self {
            case .day: return Color(UIColor.systemBackground)
            case .night: return Color.black
            case .sepia: return Color(red: 0.96, green: 0.92, blue: 0.85)
            case .pitch: return Color(red: 0.07, green: 0.08, blue: 0.12)
            }
            #elseif canImport(AppKit)
            switch self {
            case .day: return Color(NSColor.windowBackgroundColor)
            case .night: return Color.black
            case .sepia: return Color(red: 0.96, green: 0.92, blue: 0.85)
            case .pitch: return Color(red: 0.07, green: 0.08, blue: 0.12)
            }
            #else
            return Color.white
            #endif
        }
        
        var foregroundColor: Color {
            #if canImport(UIKit)
            switch self {
            case .day: return Color(UIColor.label)
            case .night: return Color.white
            case .sepia: return Color(red: 0.25, green: 0.2, blue: 0.15)
            case .pitch: return Color(red: 0.82, green: 0.84, blue: 0.9)
            }
            #elseif canImport(AppKit)
            switch self {
            case .day: return Color(NSColor.labelColor)
            case .night: return Color.white
            case .sepia: return Color(red: 0.25, green: 0.2, blue: 0.15)
            case .pitch: return Color(red: 0.82, green: 0.84, blue: 0.9)
            }
            #else
            return Color.black
            #endif
        }
    }
    
    enum TextAlignmentOption: String, CaseIterable, Identifiable {
        case leading
        case justified
        case center
        
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .leading: return "Left"
            case .justified: return "Justified"
            case .center: return "Center"
            }
        }
        
        var textAlignment: TextAlignment {
            switch self {
            case .leading, .justified: return .leading
            case .center: return .center
            }
        }
        
        var multilineAlignment: HorizontalAlignment {
            switch self {
            case .leading, .justified: return .leading
            case .center: return .center
            }
        }
    }
    
    var fontFamily: FontFamily
    var fontSize: Double
    var lineHeight: Double
    var theme: Theme
    var margin: Double
    var alignment: TextAlignmentOption
    
    static var current: ReadingAppearanceSettings {
        ReadingAppearanceSettings(
            fontFamily: FontFamily(rawValue: BookmarkPreferenceStore.readingFontFamily.lowercased()) ?? .serif,
            fontSize: BookmarkPreferenceStore.readingFontSize,
            lineHeight: BookmarkPreferenceStore.readingLineHeight,
            theme: Theme(rawValue: BookmarkPreferenceStore.readingTheme) ?? .day,
            margin: BookmarkPreferenceStore.readingMarginWidth,
            alignment: TextAlignmentOption(rawValue: BookmarkPreferenceStore.readingAlignment) ?? .leading
        )
    }
    
    func persist() {
        BookmarkPreferenceStore.readingFontFamily = fontFamily.rawValue
        BookmarkPreferenceStore.readingFontSize = fontSize
        BookmarkPreferenceStore.readingLineHeight = lineHeight
        BookmarkPreferenceStore.readingTheme = theme.rawValue
        BookmarkPreferenceStore.readingMarginWidth = margin
        BookmarkPreferenceStore.readingAlignment = alignment.rawValue
    }
    
    func headingFont() -> Font {
        Font.system(size: fontSize + 6, weight: .semibold, design: fontFamily.fontDesign)
    }
    
    func bodyFont() -> Font {
        Font.system(size: fontSize, weight: .regular, design: fontFamily.fontDesign)
    }
    
    func captionFont() -> Font {
        Font.system(size: max(fontSize - 4, 12), weight: .regular, design: fontFamily.fontDesign)
    }
}
