//
//  TagPillView.swift
//  CalendarNotes
//
//  Tag pill component
//

import SwiftUI

struct TagPillView: View {
    let text: String
    var color: Color? = nil
    var showHash: Bool = true
    var action: (() -> Void)? = nil
    
    private var tagColor: Color {
        color ?? Color(red: 0.4, green: 0.49, blue: 0.92)
    }
    
    var body: some View {
        Button(action: {
            action?()
        }) {
            Text(showHash ? "#\(text)" : text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(tagColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color(white: 0.94))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    HStack(spacing: 8) {
        TagPillView(text: "work")
        TagPillView(text: "personal", color: .blue)
        TagPillView(text: "ideas", showHash: false)
    }
    .padding()
}
