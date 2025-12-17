//
//  WatchSettingsSection.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import SwiftUI

struct WatchSettingsSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "applewatch")
                    .foregroundColor(.accentColor)
                Text("Apple Watch")
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            VStack(alignment: .leading, spacing: 12) {
                WatchSettingsToggle()
                Text("Enable to sync recent bookmarks, unread counts, and quick actions with your Apple Watch.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
            .padding(20)
            .background(Color.cnSecondaryBackground)
            .cornerRadius(12)
        }
    }
}

#Preview {
    WatchSettingsSection()
        .padding()
}

