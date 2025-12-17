//
//  ConflictNotificationBanner.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import SwiftUI

struct ConflictNotificationBanner: View {
    @EnvironmentObject private var conflictStore: ConflictStore
    
    var body: some View {
        if conflictStore.unresolvedCount > 0 {
            HStack(spacing: 12) {
                ZStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.orange)
                        .clipShape(Circle())
                    if conflictStore.unresolvedCount > 0 {
                        Text("\(conflictStore.unresolvedCount)")
                            .font(.caption2)
                            .foregroundColor(.white)
                            .padding(2)
                            .background(Color.red)
                            .clipShape(Capsule())
                            .offset(x: 14, y: -14)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Sync Conflicts")
                        .fontWeight(.semibold)
                    Text("\(conflictStore.unresolvedCount) unresolved")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                NavigationLink {
                    ConflictResolutionView()
                        .environmentObject(conflictStore)
                } label: {
                    Text("Review")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(12)
            .background(Color.cnSecondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}


