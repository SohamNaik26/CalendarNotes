//
//  HapticFeedback.swift
//  CalendarNotes
//
//  Haptic feedback utilities for iOS
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Haptic Feedback Manager

enum HapticFeedback {
    case light
    case medium
    case heavy
    case soft
    case rigid
    case success
    case warning
    case error
    case selection
    
    #if os(iOS)
    func trigger() {
        switch self {
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        case .heavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        case .soft:
            let generator = UIImpactFeedbackGenerator(style: .soft)
            generator.impactOccurred()
        case .rigid:
            let generator = UIImpactFeedbackGenerator(style: .rigid)
            generator.impactOccurred()
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }
    #else
    func trigger() {
        // No-op on macOS
    }
    #endif
}

// MARK: - View Extension for Haptic Feedback

extension View {
    /// Trigger haptic feedback
    func haptic(_ feedback: HapticFeedback) -> some View {
        #if os(iOS)
        feedback.trigger()
        #endif
        return self
    }
    
    /// Add haptic feedback on tap
    func hapticOnTap(_ feedback: HapticFeedback = .light) -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded { _ in
                feedback.trigger()
            }
        )
    }
}

// MARK: - Global Haptic Helper

#if os(iOS)
func generateHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.impactOccurred()
}

func generateNotificationFeedback(type: UINotificationFeedbackGenerator.FeedbackType) {
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(type)
}

func generateSelectionFeedback() {
    let generator = UISelectionFeedbackGenerator()
    generator.selectionChanged()
}
#endif

