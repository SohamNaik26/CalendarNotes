//
//  RootView.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import SwiftUI
import Foundation

struct RootView: View {
	@EnvironmentObject private var syncManager: SyncManager
	@StateObject private var authManager = AuthManager.shared
	@AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false
	
	private var backgroundColor: Color {
		#if os(macOS)
		return Color(NSColor.windowBackgroundColor)
		#else
		return Color(UIColor.systemBackground)
		#endif
	}
	
	var body: some View {
		Group {
			switch authManager.authState {
			case .idle, .loading:
				LaunchScreenContainer()
			case .unauthenticated, .error:
				AuthenticationView()
					.environmentObject(authManager)
					.ignoresSafeArea(.all)
			case .authenticated(let user):
				if !hasCompletedOnboarding {
					OnboardingView(user: user) {
						hasCompletedOnboarding = true
					}
				} else {
					#if os(macOS)
					MacRootSplitView()
						.environmentObject(authManager)
						.environmentObject(syncManager)
					#else
					MainTabBarView()
						.environmentObject(authManager)
						.environmentObject(syncManager)
					#endif
				}
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
		.background(
			Group {
				switch authManager.authState {
				case .idle, .loading:
					// LaunchScreenContainer has its own gradient background - use gradient start color as fallback
					DesignSystem.accentGradient
				case .unauthenticated, .error:
					// AuthenticationView has its own gradient background - use gradient start color as fallback
					DesignSystem.accentGradient
				case .authenticated:
					// Main app views need system background
					backgroundColor
				}
			}
			.ignoresSafeArea(.all)
		)
		.ignoresSafeArea(.all)
		.onAppear {
			// Immediate check on appear: if no tokens exist, skip auth check and go straight to login
			let hasAccessToken = KeychainManager.shared.getString(.accessToken) != nil
			let hasRefreshToken = KeychainManager.shared.getString(.refreshToken) != nil
			
			if !hasAccessToken && !hasRefreshToken {
				// No tokens, go directly to authentication view immediately
				authManager.authState = .unauthenticated
			}
		}
		.task {
			// Only run auth check if we have tokens
			let hasAccessToken = KeychainManager.shared.getString(.accessToken) != nil
			let hasRefreshToken = KeychainManager.shared.getString(.refreshToken) != nil
			
			guard hasAccessToken || hasRefreshToken else {
				// Already handled in onAppear, skip
				return
			}
			
			// Add a timeout fallback to prevent indefinite hanging
			await withTaskGroup(of: Void.self) { group in
				group.addTask {
					await authManager.appLaunched()
				}
				
				// Fallback: if appLaunched takes more than 3 seconds, force unauthenticated
				group.addTask {
					try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
					await MainActor.run {
						if case .loading = authManager.authState {
							authManager.authState = .unauthenticated
						}
					}
				}
				
				await group.next()
				group.cancelAll()
			}
		}
		.animation(.easeInOut(duration: 0.3), value: authManager.authState)
	}
}


