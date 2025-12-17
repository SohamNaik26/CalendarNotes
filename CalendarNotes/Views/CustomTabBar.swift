//
//  CustomTabBar.swift
//  CalendarNotes
//
//  Custom tab bar matching design specifications
//  Height: 83pt total, 4 tabs + floating center button
//

import SwiftUI

struct CustomTabBar: View {
    @Binding var selectedTab: Tab
    @Binding var showAddSheet: Bool
    
    private var bottomSafeArea: CGFloat {
        ScreenSize.homeIndicatorHeight
    }
    
    var body: some View {
        HStack(spacing: 0) {
            TabButton(icon: "calendar", title: "Calendar", tab: .calendar, selectedTab: $selectedTab)
            TabButton(icon: "note.text", title: "Notes", tab: .notes, selectedTab: $selectedTab)
            
            // Spacer for floating button
            Color.clear
                .frame(width: 80)
            
            TabButton(icon: "checkmark.circle", title: "Tasks", tab: .tasks, selectedTab: $selectedTab)
            TabButton(icon: "bookmark", title: "Bookmarks", tab: .bookmarks, selectedTab: $selectedTab)
            TabButton(icon: "gearshape.fill", title: "Settings", tab: .settings, selectedTab: $selectedTab)
        }
        .frame(height: 50)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(Color(white: 0.9))
                .frame(height: 1),
            alignment: .top
        )
        .overlay(
            FloatingAddButton(action: {
                #if os(iOS)
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                #endif
                showAddSheet = true
            })
            .offset(y: -28)
        )
        .frame(height: 83 + bottomSafeArea)
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let icon: String
    let title: String
    let tab: Tab
    @Binding var selectedTab: Tab
    
    private var accentColor: Color {
        Color(red: 0.4, green: 0.49, blue: 0.92) // #667eea
    }
    
    var body: some View {
        Button(action: {
            #if os(iOS)
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
            #endif
            
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = tab
            }
        }) {
            VStack(spacing: 4) {
                // Icon size: 24pt
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(selectedTab == tab ? accentColor : .gray)
                
                // Label size: 10pt, medium weight
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(selectedTab == tab ? accentColor : .gray)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Floating Add Button

struct FloatingAddButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.4, green: 0.49, blue: 0.92), // #667eea
                            Color(red: 0.46, green: 0.29, blue: 0.64)  // #764ba2
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(Circle())
                .shadow(color: Color.purple.opacity(0.4), radius: 12, y: 6)
        }
    }
}

#Preview {
    CustomTabBar(
        selectedTab: .constant(.calendar),
        showAddSheet: .constant(false)
    )
}

