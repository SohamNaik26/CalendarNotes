//
//  AuthManager.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import Combine
import LocalAuthentication

enum AuthState: Equatable {
	case idle
	case loading
	case authenticated(User)
	case unauthenticated
	case error(Error)

	static func == (lhs: AuthState, rhs: AuthState) -> Bool {
		switch (lhs, rhs) {
		case (.idle, .idle),
			 (.loading, .loading),
			 (.unauthenticated, .unauthenticated):
			return true
		case (.authenticated(let lUser), .authenticated(let rUser)):
			return lUser.id == rUser.id
		case (.error(let lError), .error(let rError)):
			return lError.localizedDescription == rError.localizedDescription
		default:
			return false
		}
	}
}

@MainActor
final class AuthManager: ObservableObject {
	static let shared = AuthManager()
	private init() {}
	
	@Published var currentUser: User?
	@Published var authState: AuthState = .idle
	@Published var sessionExpired: Bool = false
	
	var isAuthenticated: Bool {
		if case .authenticated = authState { return true }
		return false
	}
	
	private let biometricPrefKey = "cn.auth.biometric.enabled"
	
	func setBiometricEnabled(_ enabled: Bool) {
		UserDefaults.standard.set(enabled, forKey: biometricPrefKey)
	}
	
	func isBiometricEnabled() -> Bool {
		UserDefaults.standard.bool(forKey: biometricPrefKey)
	}
	
	func appLaunched() async {
		// Set loading state immediately to show progress
		authState = .loading
		
		// Check for tokens first (this is fast, no network call)
		let hasAccessToken = KeychainManager.shared.getString(.accessToken) != nil
		let hasRefreshToken = KeychainManager.shared.getString(.refreshToken) != nil
		
		if hasAccessToken || hasRefreshToken {
			// Has tokens, try to reload session (with timeout)
			await reloadSession()
		} else {
			// No tokens found, go directly to unauthenticated
			authState = .unauthenticated
		}
	}
	
	func reloadSession() async {
		authState = .loading
		do {
			// Add shorter timeout to prevent indefinite hanging (2 seconds each)
			_ = try await withTimeout(seconds: 2) {
				try await AuthService.shared.refreshToken()
			}
			let user = try await withTimeout(seconds: 2) {
				try await AuthService.shared.getCurrentUser()
			}
			currentUser = user
			authState = .authenticated(user)
		} catch {
			// On any error (timeout, network, etc.), go to unauthenticated
			currentUser = nil
			authState = .unauthenticated
		}
	}
	
	// Helper function to add timeout to async operations
	private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
		try await withThrowingTaskGroup(of: T.self) { group in
			group.addTask {
				try await operation()
			}
			
			group.addTask {
				try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
				throw TimeoutError()
			}
			
			guard let result = try await group.next() else {
				throw TimeoutError()
			}
			
			group.cancelAll()
			return result
		}
	}
	
	private struct TimeoutError: Error {
		let localizedDescription = "Request timed out"
	}
	
	func login(email: String, password: String) async {
		authState = .loading
		do {
			let res = try await AuthService.shared.login(credentials: AuthCredentials(email: email, password: password))
			currentUser = res.user
			authState = .authenticated(res.user)
		} catch {
			authState = .error(error)
		}
	}
	
	func register(email: String, password: String, fullName: String?) async {
		authState = .loading
		do {
			let res = try await AuthService.shared.register(email: email, password: password, fullName: fullName)
			currentUser = res.user
			authState = .authenticated(res.user)
		} catch {
			authState = .error(error)
		}
	}
	
	func logout() async {
		authState = .loading
		do {
			try await AuthService.shared.logout()
			try? CoreDataManager.shared.resetDatabase()
			currentUser = nil
			authState = .unauthenticated
		} catch {
			authState = .error(error)
		}
	}
	
	func handleSessionExpired() {
		sessionExpired = true
		currentUser = nil
		authState = .unauthenticated
	}
	
	func quickLoginWithBiometrics(reason: String = "Authenticate to access your account") async {
		guard isBiometricEnabled() else {
			await reloadSession()
			return
		}
		let context = LAContext()
		var error: NSError?
		if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
			let success = (try? await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)) ?? false
			if success {
				await reloadSession()
			} else {
				authState = .unauthenticated
			}
		} else {
			await reloadSession()
		}
	}
	
	// MARK: - Social Authentication
	
	func signInWithApple(identityToken: String, authorizationCode: String, fullName: String?) async {
		authState = .loading
		do {
			let res = try await AuthService.shared.signInWithApple(identityToken: identityToken, authorizationCode: authorizationCode, fullName: fullName)
			currentUser = res.user
			authState = .authenticated(res.user)
		} catch {
			authState = .error(error)
		}
	}
	
	func signInWithGoogle(idToken: String, accessToken: String?, fullName: String?) async {
		authState = .loading
		do {
			let res = try await AuthService.shared.signInWithGoogle(idToken: idToken, accessToken: accessToken, fullName: fullName)
			currentUser = res.user
			authState = .authenticated(res.user)
		} catch {
			authState = .error(error)
		}
	}
}


