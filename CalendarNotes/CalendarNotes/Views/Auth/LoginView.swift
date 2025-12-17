//
//  LoginView.swift
//  CalendarNotes
//
//  Login form in white card matching exact design reference
//

import SwiftUI
import AuthenticationServices
#if os(iOS)
import UIKit
#endif

struct LoginView: View {
	@EnvironmentObject private var authManager: AuthManager
	
	@State private var email: String = ""
	@State private var password: String = ""
	@State private var showingPassword: Bool = false
	@State private var errorMessage: String?
	@State private var shake: CGFloat = 0
	@FocusState private var focusedField: Field?
	
	let switchToRegister: () -> Void
	
	private enum Field { case email, password }
	
	var body: some View {
		GeometryReader { geometry in
			VStack(spacing: 0) {
				Spacer()
				
				// White Card Container
				VStack(alignment: .leading, spacing: 16) {
					// Header
					Text("Welcome Back")
						.font(.system(size: 32, weight: .bold))
						.foregroundColor(.black)
					
					Text("Sign in to continue")
						.font(.system(size: 16))
						.foregroundColor(.gray)
						.padding(.bottom, 8)
					
					// Email Field
					VStack(alignment: .leading, spacing: 8) {
						Text("Email")
							.font(.system(size: 15, weight: .medium))
							.foregroundColor(.black)
						
						TextField("you@example.com", text: $email)
							#if canImport(UIKit)
							.keyboardType(.emailAddress)
							.textInputAutocapitalization(.never)
							.textContentType(.emailAddress)
							#endif
							.disableAutocorrection(true)
							.focused($focusedField, equals: .email)
							.submitLabel(.next)
							.onSubmit { focusedField = .password }
							.font(.system(size: 16))
							.foregroundColor(email.isEmpty ? .primary : .blue)
							.padding()
							.frame(height: 50)
							.background(Color(red: 0.95, green: 0.95, blue: 0.97))
							.cornerRadius(12)
					}
					
					// Password Field
					VStack(alignment: .leading, spacing: 8) {
						HStack {
							Text("Password")
								.font(.system(size: 15, weight: .medium))
								.foregroundColor(.black)
							
							Spacer()
							
							Button(action: {}) {
								Text("Forgot Password?")
									.font(.system(size: 14))
									.foregroundColor(.blue)
							}
						}
						
						HStack {
							if showingPassword {
								TextField("••••••••", text: $password)
									.font(.system(size: 16))
									.foregroundColor(password.isEmpty ? .primary : .blue)
									.focused($focusedField, equals: .password)
									.submitLabel(.done)
							} else {
								SecureField("••••••••", text: $password)
									.font(.system(size: 16))
									.foregroundColor(password.isEmpty ? .primary : .blue)
									.focused($focusedField, equals: .password)
									.submitLabel(.done)
							}
							
							Button {
								showingPassword.toggle()
							} label: {
								Image(systemName: showingPassword ? "eye.slash.fill" : "eye.fill")
									.font(.system(size: 18))
									.foregroundColor(.gray.opacity(0.7))
							}
						}
						.padding()
						.frame(height: 50)
						.background(Color(red: 0.95, green: 0.95, blue: 0.97))
						.cornerRadius(12)
					}
					
					// Error messages
					if case .error(let err) = authManager.authState {
						Text(err.localizedDescription)
							.foregroundColor(.red)
							.font(.system(size: 14))
							.modifier(ShakeEffect(animatableData: shake))
							.onAppear { withAnimation(.easeInOut(duration: 0.4)) { shake += 1 } }
					}
					if let errorMessage {
						Text(errorMessage)
							.foregroundColor(.red)
							.font(.system(size: 14))
							.modifier(ShakeEffect(animatableData: shake))
							.onAppear { withAnimation(.easeInOut(duration: 0.4)) { shake += 1 } }
					}
					
					// Sign In Button
					Button(action: {
						Task { await login() }
					}) {
						HStack {
							if case .loading = authManager.authState {
								ProgressView()
									.tint(.white)
							}
							Text("Sign In")
								.font(.system(size: 18, weight: .bold))
								.foregroundColor(.white)
						}
						.frame(maxWidth: .infinity)
						.frame(height: 54)
						.background(
							LinearGradient(
								gradient: Gradient(colors: [
									Color(red: 0.54, green: 0.50, blue: 0.91),
									Color(red: 0.42, green: 0.37, blue: 0.82)
								]),
								startPoint: .leading,
								endPoint: .trailing
							)
						)
						.cornerRadius(12)
					}
					.padding(.top, 8)
					.disabled(!canSubmit)
					
					// OR Divider
					Text("OR")
						.font(.system(size: 14))
						.foregroundColor(.gray)
						.frame(maxWidth: .infinity, alignment: .center)
						.padding(.top, 12)
						.padding(.bottom, 8)
					
					// Additional login options
					// Sign in with Apple
					SignInWithAppleButton(.signIn, onRequest: { request in
						request.requestedScopes = [.fullName, .email]
					}, onCompletion: { result in
						Task {
							switch result {
							case .success(let authorization):
								guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
									  let identityTokenData = appleIDCredential.identityToken,
									  let identityToken = String(data: identityTokenData, encoding: .utf8),
									  let authorizationCodeData = appleIDCredential.authorizationCode,
									  let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
									errorMessage = "Failed to get Apple authentication tokens"
									return
								}
								
								let fullName: String?
								if let fullNameData = appleIDCredential.fullName {
									let formatter = PersonNameComponentsFormatter()
									fullName = formatter.string(from: fullNameData)
								} else {
									fullName = nil
								}
								
								await authManager.signInWithApple(identityToken: identityToken, authorizationCode: authorizationCode, fullName: fullName)
							case .failure(let error):
								errorMessage = error.localizedDescription
							}
						}
					})
					.signInWithAppleButtonStyle(.black)
					.frame(maxWidth: .infinity)
					.frame(height: 56)
					.clipShape(RoundedRectangle(cornerRadius: 14))
					
					// Continue with Google
					Button {
						Task { await signInWithGoogle() }
					} label: {
						HStack {
							Image(systemName: "g.circle.fill")
								.font(.system(size: 22))
							Text("Continue with Google")
								.font(.system(size: 16, weight: .semibold))
						}
						.frame(maxWidth: .infinity)
						.frame(height: 56)
						.background(Color.white)
						.foregroundColor(.black)
						.clipShape(RoundedRectangle(cornerRadius: 14))
						.overlay(
							RoundedRectangle(cornerRadius: 14)
								.stroke(Color.gray.opacity(0.25), lineWidth: 1)
						)
					}
					.padding(.top, 8)
					
					// Additional login options
					// Sign in with Apple
					SignInWithAppleButton(.signIn, onRequest: { request in
						request.requestedScopes = [.fullName, .email]
					}, onCompletion: { result in
						Task {
							switch result {
							case .success(let authorization):
								guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
									  let identityTokenData = appleIDCredential.identityToken,
									  let identityToken = String(data: identityTokenData, encoding: .utf8),
									  let authorizationCodeData = appleIDCredential.authorizationCode,
									  let authorizationCode = String(data: authorizationCodeData, encoding: .utf8) else {
									errorMessage = "Failed to get Apple authentication tokens"
									return
								}
								
								let fullName: String?
								if let fullNameData = appleIDCredential.fullName {
									let formatter = PersonNameComponentsFormatter()
									fullName = formatter.string(from: fullNameData)
								} else {
									fullName = nil
								}
								
								await authManager.signInWithApple(identityToken: identityToken, authorizationCode: authorizationCode, fullName: fullName)
							case .failure(let error):
								errorMessage = error.localizedDescription
							}
						}
					})
					.signInWithAppleButtonStyle(.black)
					.frame(maxWidth: .infinity)
					.frame(height: 56)
					.clipShape(RoundedRectangle(cornerRadius: 14))
					
					// Continue with Google
					Button {
						Task { await signInWithGoogle() }
					} label: {
						HStack {
							Image(systemName: "g.circle.fill")
								.font(.system(size: 22))
							Text("Continue with Google")
								.font(.system(size: 16, weight: .semibold))
						}
						.frame(maxWidth: .infinity)
						.frame(height: 56)
						.background(Color.white)
						.foregroundColor(.black)
						.clipShape(RoundedRectangle(cornerRadius: 14))
						.overlay(
							RoundedRectangle(cornerRadius: 14)
								.stroke(Color.gray.opacity(0.25), lineWidth: 1)
						)
					}
					.padding(.top, 8)
					
					// Sign up prompt
					HStack(spacing: 4) {
						Text("Don't have an account?")
							.font(.system(size: 15))
							.foregroundColor(.gray)
						Button("Sign up") {
							switchToRegister()
						}
						.font(.system(size: 15, weight: .semibold))
						.foregroundColor(.blue)
					}
					.frame(maxWidth: .infinity, alignment: .center)
					.padding(.top, 20)
				}
				.padding(32)
				.background(Color.white)
				.cornerRadius(24)
				.shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
				.padding(.horizontal, 24)
			}
		}
	}
	
	private var canSubmit: Bool {
		let isLoading: Bool = {
			if case .loading = authManager.authState { return true }
			return false
		}()
		return Validation.isValidEmail(email) && password.count >= 8 && !isLoading
	}
	
	private func login() async {
		guard canSubmit else {
			errorMessage = "Please enter a valid email and password (8+ chars)"
			return
		}
		#if canImport(UIKit)
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
		#endif
		await authManager.login(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password)
	}
	
	private func signInWithGoogle() async {
		do {
			let result = try await GoogleSignInService.shared.signIn()
			await authManager.signInWithGoogle(
				idToken: result.idToken,
				accessToken: result.accessToken,
				fullName: result.fullName
			)
		} catch {
			if let googleError = error as? GoogleSignInError,
			   case .userCanceled = googleError {
				return
			}
			errorMessage = error.localizedDescription
		}
	}
}
