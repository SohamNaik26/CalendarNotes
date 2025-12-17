//
//  LaunchScreenContainer.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 25/10/25.
//

import SwiftUI
import CoreData

/// Lightweight splash container that keeps showing the launch view while auth/initialization runs.
struct LaunchScreenContainer: View {
    @ObservedObject private var authManager = AuthManager.shared
    @Environment(\.managedObjectContext) private var managedObjectContext
    @State private var hasMarkedFirstFrame = false
    
    var body: some View {
        #if os(macOS)
        LaunchScreenMacFallback()
        #else
        LaunchScreeniOS()
        #endif
    }
    
    #if os(macOS)
    private func LaunchScreenMacFallback() -> some View {
        MacRootSplitView()
            .environment(\.managedObjectContext, managedObjectContext)
            .withTheme()
            .onAppear { markFirstFrameIfNeeded(for: authManager.authState) }
            .onChange(of: authManager.authState) { _, state in
                markFirstFrameIfNeeded(for: state)
            }
    }
    #else
    private func LaunchScreeniOS() -> some View {
        LaunchScreenView()
            .overlay(alignment: .bottom) {
                if case .loading = authManager.authState {
                    VStack(spacing: 12) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .tint(.white)
                        Text("Preparing your data…")
                            .font(.footnote)
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .background(Color.black.opacity(0.35), in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.opacity)
                }
            }
            .onAppear { markFirstFrameIfNeeded(for: authManager.authState) }
            .onChange(of: authManager.authState) { _, state in
                markFirstFrameIfNeeded(for: state)
            }
    }
    #endif
    
    private func markFirstFrameIfNeeded(for state: AuthState) {
        guard !hasMarkedFirstFrame else { return }
        switch state {
        case .idle, .loading:
            return
        default:
            hasMarkedFirstFrame = true
            Task { @MainActor in AppLaunchMetrics.shared.markFirstFrameRendered() }
        }
    }
}
