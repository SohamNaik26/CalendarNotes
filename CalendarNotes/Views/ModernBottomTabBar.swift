//
//  ModernBottomTabBar.swift
//  CalendarNotes
//
//  Modern bottom navigation bar matching reference design
//

import SwiftUI

struct TabBarItem: Identifiable {
    let id: Int
    let icon: String
    let title: String
    let iconSelected: String?
    
    init(id: Int, icon: String, title: String, iconSelected: String? = nil) {
        self.id = id
        self.icon = icon
        self.title = title
        self.iconSelected = iconSelected
    }
}

struct ModernBottomTabBar: View {
    @Binding var selectedTab: Int
    let items: [TabBarItem]
    @Environment(\.colorScheme) var colorScheme
    @State private var showCreateMenu = false
    
    private var backgroundColor: Color {
        colorScheme == .dark ? Color(red: 0.1, green: 0.1, blue: 0.1) : Color(red: 0.98, green: 0.98, blue: 0.98)
    }
    
    private var accentColor: Color {
        Color.cnAccent
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab bar background
            HStack(spacing: 0) {
                // Left side tabs (Home, Calendar)
                ForEach(items.filter { $0.id < 2 }) { item in
                    tabButton(for: item)
                }
                
                // Spacer for center button
                Spacer()
                    .frame(width: 56) // Space for floating button
                
                // Right side tabs (Bookmarks, Profile)
                ForEach(items.filter { $0.id > 2 }) { item in
                    tabButton(for: item)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
            .padding(.bottom, 8)
            .background(
                backgroundColor
                    .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: -2)
            )
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 0.5),
                alignment: .top
            )
            
            // Floating center button
            Button(action: {
                showCreateMenu = true
                // Trigger the sheet via notification or binding
                NotificationCenter.default.post(name: .init("ShowCreateMenu"), object: nil)
            }) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        LinearGradient(
                            colors: [accentColor, accentColor.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Circle())
                    .shadow(color: accentColor.opacity(0.4), radius: 8, y: 4)
            }
            .offset(y: -30)
        }
    }
    
    private func tabButton(for item: TabBarItem) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedTab = item.id
            }
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    // Background circle for selected state
                    if selectedTab == item.id {
                        Circle()
                            .fill(accentColor.opacity(0.15))
                            .frame(width: 44, height: 44)
                            .transition(.scale.combined(with: .opacity))
                    }
                    
                    Image(systemName: selectedTab == item.id ? (item.iconSelected ?? item.icon) : item.icon)
                        .font(.system(size: 22, weight: selectedTab == item.id ? .semibold : .regular))
                        .foregroundColor(selectedTab == item.id ? accentColor : .secondary)
                }
                .frame(height: 44)
                
                Text(item.title)
                    .font(.system(size: 10, weight: selectedTab == item.id ? .semibold : .regular))
                    .foregroundColor(selectedTab == item.id ? accentColor : .secondary)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        Spacer()
        ModernBottomTabBar(
            selectedTab: .constant(0),
            items: [
                TabBarItem(id: 0, icon: "house.fill", title: "Home"),
                TabBarItem(id: 1, icon: "calendar", title: "Calendar", iconSelected: "calendar.fill"),
                TabBarItem(id: 2, icon: "plus.circle.fill", title: ""),
                TabBarItem(id: 3, icon: "bookmark", title: "Bookmarks", iconSelected: "bookmark.fill"),
                TabBarItem(id: 4, icon: "person.circle", title: "Profile", iconSelected: "person.circle.fill")
            ]
        )
    }
    .background(Color.black)
}

