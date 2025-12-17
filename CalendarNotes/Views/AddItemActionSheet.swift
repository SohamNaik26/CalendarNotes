//
//  AddItemActionSheet.swift
//  CalendarNotes
//
//  Action sheet for the center plus button
//

import SwiftUI

enum CreateOption {
    case event
    case note
    case task
    case bookmark
}

struct AddItemActionSheet: View {
    @Environment(\.dismiss) var dismiss
    var onSelect: (CreateOption) -> Void
    
    var body: some View {
        CreateMenuView { option in
            onSelect(option)
            dismiss()
        }
    }
}

struct CreateMenuView: View {
    @Environment(\.dismiss) var dismiss
    var onSelect: (CreateOption) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Spacer()
                    Text("Create New")
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Button(action: { dismiss() }) {
                        Text("Done")
                            .fontWeight(.medium)
                    }
                }
                .padding()
                #if os(iOS)
                .background(Color(.systemBackground))
                #else
                .background(Color(NSColor.windowBackgroundColor))
                #endif
                
                Divider()
                
                // Options
                VStack(spacing: 0) {
                    CreateOptionRow(
                        icon: "calendar.badge.plus",
                        iconColor: .blue,
                        title: "New Event"
                    ) {
                        onSelect(.event)
                    }
                    
                    Divider().padding(.leading, 68)
                    
                    CreateOptionRow(
                        icon: "note.text.badge.plus",
                        iconColor: .purple,
                        title: "New Note"
                    ) {
                        onSelect(.note)
                    }
                    
                    Divider().padding(.leading, 68)
                    
                    CreateOptionRow(
                        icon: "checkmark.circle",
                        iconColor: .orange,
                        title: "New Task"
                    ) {
                        onSelect(.task)
                    }
                    
                    Divider().padding(.leading, 68)
                    
                    CreateOptionRow(
                        icon: "bookmark.fill",
                        iconColor: .pink,
                        title: "Add Bookmark"
                    ) {
                        onSelect(.bookmark)
                    }
                }
                #if os(iOS)
                .background(Color(.systemBackground))
                #else
                .background(Color(NSColor.windowBackgroundColor))
                #endif
            }
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.2), radius: 20, y: -5)
        }
        .background(Color.black.opacity(0.001))
        .onTapGesture {
            dismiss()
        }
    }
}

struct CreateOptionRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(iconColor)
                    .clipShape(Circle())
                
                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    AddItemActionSheet(onSelect: { _ in })
}

