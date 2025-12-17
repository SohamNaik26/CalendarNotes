//
//  GradientButton.swift
//  CalendarNotes
//
//  Reusable gradient button component
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct GradientButton: View {
    let title: String
    let action: () -> Void
    var isFullWidth: Bool = true
    
    @State private var isPressed = false
    
    private var accentColor: Color {
        DesignSystem.accentColor
    }
    
    private var accentColorDark: Color {
        DesignSystem.accentColorDark
    }
    
    var body: some View {
        Button(action: {
            #if os(iOS)
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            #endif
            action()
        }) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .padding(.vertical, 16)
                .padding(.horizontal, isFullWidth ? 0 : 24)
                .background(DesignSystem.accentGradient)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .scaleEffect(isPressed ? 0.95 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

#Preview {
    VStack(spacing: 20) {
        GradientButton(title: "Sign In", action: {})
        GradientButton(title: "Create Account", action: {}, isFullWidth: false)
    }
    .padding()
}
