//
//  EmptyStateView.swift
//  CalendarNotes
//
//  Reusable empty state component matching design specifications
//  Centered in parent view with large SF Symbol icon and message text
//

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct EmptyStateView: View {
    let icon: String
    let message: String
    
    private var grayColor: Color {
        #if os(macOS)
        return Color(NSColor.systemGray)
        #else
        return Color(UIColor.systemGray3)
        #endif
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Large SF Symbol icon (56pt size) - improved size
            Image(systemName: icon)
                .font(.system(size: 56, weight: .light))
                .foregroundColor(grayColor.opacity(0.7))
            
            // Text below icon (18pt, semibold) - improved styling
            Text(message)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Legacy Support (for existing code)

struct CalendarNotesEmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String?
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    
    private var grayColor: Color {
        #if os(macOS)
        return Color(NSColor.systemGray)
        #else
        return Color(UIColor.systemGray3)
        #endif
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Large gray icon
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(grayColor)
            
            // "No [items]" text
            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 15, weight: .regular))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(DesignSystem.accentGradient)
                        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.searchBarCornerRadius))
                }
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

#Preview {
    VStack(spacing: 40) {
        // New simple EmptyStateView
        EmptyStateView(icon: "calendar", message: "No events")
        EmptyStateView(icon: "note.text", message: "No notes")
        EmptyStateView(icon: "checkmark.circle", message: "No tasks")
        EmptyStateView(icon: "bookmark", message: "No Bookmarks")
    }
    .padding()
}
