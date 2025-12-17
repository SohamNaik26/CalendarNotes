//
//  WatchSettingsToggle.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import SwiftUI

struct WatchSettingsToggle: View {
    @ObservedObject private var connectivity = WatchConnectivityService.shared

    var body: some View {
        Toggle(isOn: $connectivity.syncEnabled) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sync with Apple Watch")
                    .font(.body)
                if connectivity.isSupported {
                    HStack(spacing: 6) {
                        statusDot(color: connectivity.isPaired ? .green : .yellow)
                        Text(connectivity.isPaired ? "Watch paired" : "Watch not paired")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        if connectivity.isPaired {
                            Text(connectivity.isWatchAppInstalled ? "App installed" : "Install Watch app")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    Text("Apple Watch not detected on this device")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .disabled(!connectivity.isSupported)
        .onAppear { Task { await connectivity.refreshState() } }
    }

    private func statusDot(color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
    }
}

#Preview {
    WatchSettingsToggle()
}
