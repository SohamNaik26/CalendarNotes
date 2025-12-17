//
//  CalendarIconView.swift
//  CalendarNotes
//
//  Custom calendar icon matching macOS style
//

import SwiftUI

struct CalendarIconView: View {
    var body: some View {
        VStack(spacing: 0) {
            // Red header section
            ZStack {
                Color.red
                Text("JUL")
                    .foregroundColor(.white)
                    .font(.system(size: 12, weight: .bold))
            }
            .frame(width: 80, height: 24)
            
            // White body section
            ZStack {
                Color.white
                Text("17")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.black)
            }
            .frame(width: 80, height: 56)
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    CalendarIconView()
        .padding()
        .background(Color.gray.opacity(0.1))
}
