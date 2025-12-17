//
//  SearchBarView.swift
//  CalendarNotes
//
//  Reusable search bar component
//  Light gray background, rounded corners, magnifying glass icon
//

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// MARK: - Search Bar Component

struct SearchBar: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    
    private var systemGray: Color {
        #if os(macOS)
        return Color(NSColor.systemGray)
        #else
        return Color(UIColor.systemGray)
        #endif
    }
    
    private var systemGray6: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemGray6)
        #endif
    }
    
    private var borderColor: Color {
        #if os(macOS)
        return Color(red: 0.7, green: 0.7, blue: 0.7) // Medium gray for macOS
        #else
        return Color(white: 0.8) // Light gray for iOS
        #endif
    }
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(systemGray)
            
            ZStack(alignment: .leading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(.system(size: 16))
                        .foregroundColor(systemGray.opacity(0.6))
                }
                TextField("", text: $text)
                    .font(.system(size: 16))
                    .foregroundColor(.primary)
            }
        }
        .padding(14)
        .background(systemGray6)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(borderColor, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Legacy SearchBarView (for backward compatibility)

struct SearchBarView: View {
    @Binding var text: String
    var placeholder: String = "Search..."
    
    var body: some View {
        HStack(spacing: 12) {
            // Magnifying glass icon
            Image(systemName: "magnifyingglass")
                .font(.system(size: 18))
                .foregroundColor(DesignSystem.secondaryGray)
            
            TextField(placeholder, text: $text)
                .font(DesignSystem.bodyText)
                .foregroundColor(.primary)
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(DesignSystem.secondaryGray)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .background(DesignSystem.searchBarBackground)
        .clipShape(RoundedRectangle(cornerRadius: DesignSystem.searchBarCornerRadius))
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var text = ""
        
        var body: some View {
            VStack(spacing: 20) {
                SearchBar(text: $text, placeholder: "Search notes...")
                SearchBar(text: .constant("Sample text"), placeholder: "Search bookmarks...")
                SearchBar(text: .constant(""), placeholder: "Q Search bookmarks...")
            }
            .padding()
        }
    }
    
    return PreviewWrapper()
}
