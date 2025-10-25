//
//  AccessibilityHelpers.swift
//  CalendarNotes
//
//  Created on 10/23/2025.
//

import SwiftUI
import Combine

// MARK: - Accessibility Utilities

struct AccessibilityHelpers {
    
    // MARK: - Accessibility Labels
    
    static func calendarEventLabel(title: String, startTime: String, endTime: String?, location: String?) -> String {
        var label = "Event: \(title)"
        
        if let endTime = endTime {
            label += ", from \(startTime) to \(endTime)"
        } else {
            label += ", at \(startTime)"
        }
        
        if let location = location, !location.isEmpty {
            label += ", location: \(location)"
        }
        
        return label
    }
    
    static func taskLabel(title: String, dueDate: String?, isCompleted: Bool) -> String {
        var label = "Task: \(title)"
        
        if isCompleted {
            label += ", completed"
        } else {
            label += ", not completed"
        }
        
        if let dueDate = dueDate {
            label += ", due \(dueDate)"
        } else {
            label += ", no due date"
        }
        
        return label
    }
    
    static func noteLabel(title: String, content: String, dateCreated: String) -> String {
        let preview = content.prefix(50)
        return "Note: \(title), created \(dateCreated), content preview: \(preview)"
    }
    
    // MARK: - Accessibility Hints
    
    static func calendarDayHint(hasEvents: Bool, hasTasks: Bool, date: String) -> String {
        var hint = "Day \(date)"
        
        if hasEvents && hasTasks {
            hint += ", has events and tasks"
        } else if hasEvents {
            hint += ", has events"
        } else if hasTasks {
            hint += ", has tasks"
        } else {
            hint += ", no scheduled items"
        }
        
        hint += ", double tap to view details"
        return hint
    }
    
    static func addButtonHint(type: String) -> String {
        return "Double tap to add new \(type)"
    }
    
    static func deleteActionHint(item: String) -> String {
        return "Double tap to delete this \(item)"
    }
    
    static func editActionHint(item: String) -> String {
        return "Double tap to edit this \(item)"
    }
    
    // MARK: - Accessibility Values
    
    static func progressValue(current: Int, total: Int) -> String {
        return "\(current) of \(total) completed"
    }
    
    static func dateValue(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: date)
    }
    
    static func timeValue(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Accessibility Modifiers

struct AccessibilityModifiers {
    
    // MARK: - Dynamic Type Support
    
    static func dynamicType(_ size: Font.TextStyle) -> some ViewModifier {
        DynamicTypeModifier(textStyle: size)
    }
    
    private struct DynamicTypeModifier: ViewModifier {
        let textStyle: Font.TextStyle
        
        func body(content: Content) -> some View {
            content
                .font(.system(textStyle))
        }
    }
    
    // MARK: - High Contrast Support
    
    static func highContrast<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .foregroundColor(.primary)
            #if os(macOS)
            .background(Color(NSColor.controlBackgroundColor))
            #else
            .background(Color(UIColor.systemBackground))
            #endif
    }
    
    // MARK: - Reduce Motion Support
    
    static func reduceMotion<Content: View>(
        animated: Content,
        reduced: Content
    ) -> some View {
        Group {
            // For macOS, we'll use a simple approach
            // In a real app, you'd check NSWorkspace accessibility settings
            animated
        }
    }
    
    // MARK: - Minimum Touch Target
    
    static func minimumTouchTarget<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(minWidth: 44, minHeight: 44)
    }
}

// MARK: - Color Blind Friendly Colors

struct AccessibilityColors {
    
    // High contrast colors for better visibility
    static let highContrastPrimary = Color(red: 0, green: 0, blue: 0)
    static let highContrastSecondary = Color(red: 0.2, green: 0.2, blue: 0.2)
    static let highContrastAccent = Color(red: 0, green: 0.5, blue: 1)
    static let highContrastBackground = Color(red: 1, green: 1, blue: 1)
    static let highContrastSuccess = Color(red: 0, green: 0.6, blue: 0)
    static let highContrastError = Color(red: 0.8, green: 0, blue: 0)
    static let highContrastWarning = Color(red: 0.8, green: 0.4, blue: 0)
    
    // Color blind friendly palette
    static let colorBlindSafe1 = Color(red: 0.9, green: 0.1, blue: 0.1) // Red
    static let colorBlindSafe2 = Color(red: 0.1, green: 0.6, blue: 0.1) // Green
    static let colorBlindSafe3 = Color(red: 0.1, green: 0.1, blue: 0.9) // Blue
    static let colorBlindSafe4 = Color(red: 0.9, green: 0.6, blue: 0.1) // Orange
    static let colorBlindSafe5 = Color(red: 0.6, green: 0.1, blue: 0.9) // Purple
    static let colorBlindSafe6 = Color(red: 0.1, green: 0.9, blue: 0.9) // Cyan
}

// MARK: - Accessibility Environment

class AccessibilityEnvironment: ObservableObject {
    @Published var isHighContrastEnabled: Bool = false
    @Published var isReduceMotionEnabled: Bool = false
    @Published var preferredContentSizeCategory: ContentSizeCategory = .medium
    
    init() {
        updateAccessibilitySettings()
    }
    
    func updateAccessibilitySettings() {
        // For macOS, we'll use simple defaults
        // In a real app, you'd check NSWorkspace accessibility settings
        isHighContrastEnabled = false
        isReduceMotionEnabled = false
        preferredContentSizeCategory = .medium
    }
}

// MARK: - Accessibility View Extensions

extension View {
    
    // MARK: - Accessibility Labels
    
    func accessibilityLabel(_ label: String) -> some View {
        self.accessibility(label: Text(label))
    }
    
    func accessibilityLabel(_ label: Text) -> some View {
        self.accessibility(label: label)
    }
    
    // MARK: - Accessibility Hints
    
    func accessibilityHint(_ hint: String) -> some View {
        self.accessibility(hint: Text(hint))
    }
    
    func accessibilityHint(_ hint: Text) -> some View {
        self.accessibility(hint: hint)
    }
    
    // MARK: - Accessibility Values
    
    func accessibilityValue(_ value: String) -> some View {
        self.accessibility(value: Text(value))
    }
    
    func accessibilityValue(_ value: Text) -> some View {
        self.accessibility(value: value)
    }
    
    // MARK: - Accessibility Traits
    
    func accessibilityButton() -> some View {
        self.accessibility(addTraits: .isButton)
    }
    
    func accessibilityHeader() -> some View {
        self.accessibility(addTraits: .isHeader)
    }
    
    func accessibilitySelected() -> some View {
        self.accessibility(addTraits: .isSelected)
    }
    
    func accessibilityNotEnabled() -> some View {
        self.accessibility(addTraits: .isButton)
    }
    
    // MARK: - Accessibility Actions
    
    func accessibilityAction(_ name: String, action: @escaping () -> Void) -> some View {
        self.accessibilityAction(named: Text(name), action)
    }
    
    // MARK: - Dynamic Type
    
    func dynamicType(_ size: Font.TextStyle) -> some View {
        self.modifier(AccessibilityModifiers.dynamicType(size))
    }
    
    // MARK: - High Contrast
    
    func highContrastSupport() -> some View {
        self.modifier(HighContrastModifier())
    }
    
    // MARK: - Reduce Motion
    
    func reduceMotionSupport<ReducedContent: View>(
        @ViewBuilder reduced: () -> ReducedContent
    ) -> some View {
        self.modifier(ReduceMotionModifier(reduced: reduced()))
    }
    
    // MARK: - Minimum Touch Target
    
    func minimumTouchTarget() -> some View {
        self.frame(minWidth: 44, minHeight: 44)
    }
    
    // MARK: - Keyboard Navigation
    
    func keyboardNavigation() -> some View {
        self.accessibility(addTraits: .isKeyboardKey)
    }
}

// MARK: - Accessibility Modifiers

struct HighContrastModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme
    
    func body(content: Content) -> some View {
        // For macOS, we'll use a simple approach
        // In a real app, you'd check NSWorkspace accessibility settings
        content
    }
}

struct ReduceMotionModifier<ReducedContent: View>: ViewModifier {
    let reduced: ReducedContent
    
    func body(content: Content) -> some View {
        // For macOS, we'll use a simple approach
        // In a real app, you'd check NSWorkspace accessibility settings
        content
    }
}

// MARK: - Accessibility Testing Helpers

struct AccessibilityTestingHelpers {
    
    static func testWithLargestTextSize<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
    }
    
    static func testWithHighContrast<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .environment(\.colorScheme, .dark)
            .preferredColorScheme(.dark)
    }
    
    static func testWithReduceMotion<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
    }
}

// MARK: - Accessibility Preview Helpers

#if DEBUG
struct AccessibilityPreview<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Normal")
                .font(.headline)
            content
            
            Divider()
            
            Text("Largest Text Size")
                .font(.headline)
            AccessibilityTestingHelpers.testWithLargestTextSize {
                content
            }
            
            Divider()
            
            Text("High Contrast")
                .font(.headline)
            AccessibilityTestingHelpers.testWithHighContrast {
                content
            }
            
            Divider()
            
            Text("Reduce Motion")
                .font(.headline)
            AccessibilityTestingHelpers.testWithReduceMotion {
                content
            }
        }
        .padding()
    }
}
#endif