//
//  RegisterView.swift
//  CalendarNotes
//
//  Registration form in white card matching exact design reference
//

import SwiftUI
import AuthenticationServices
#if os(iOS)
import UIKit
#endif

struct RegisterView: View {
	@EnvironmentObject private var authManager: AuthManager
	
	@State private var fullName: String = ""
	@State private var email: String = ""
	@State private var password: String = ""
	@State private var acceptTerms: Bool = false
	@State private var showingPassword: Bool = false
	@State private var errorMessage: String?
	@State private var shake: CGFloat = 0
	@FocusState private var focused: Field?
	
	let switchToLogin: () -> Void
	
	private enum Field { case fullName, email, password }
	
	var body: some View {
		GeometryReader { geometry in
			VStack(spacing: 0) {
				Spacer()
				
				// White Card Container
				VStack(alignment: .leading, spacing: 24) {
					// Welcome Message
					VStack(alignment: .leading, spacing: 8) {
						Text("Create Account")
							.font(.system(size: 32, weight: .bold))
							.foregroundColor(.black)
						
						Text("Start organizing your life")
							.font(.system(size: 17, weight: .regular))
							.foregroundColor(.gray)
					}
					.padding(.top, 48)
					
					// Full Name Input
					VStack(alignment: .leading, spacing: 10) {
						Text("Full Name")
							.font(.system(size: 15, weight: .medium))
							.foregroundColor(.black)
						
						TextField("Full Name", text: $fullName)
							.textContentType(.name)
							.submitLabel(.next)
							.focused($focused, equals: .fullName)
							.onSubmit { focused = .email }
							.font(.system(size: 17))
							.padding(.horizontal, 16)
							.padding(.vertical, 16)
							.frame(height: 50)
							.background(Color.gray.opacity(0.1))
							.clipShape(RoundedRectangle(cornerRadius: 12))
							.overlay(
								RoundedRectangle(cornerRadius: 12)
									.stroke(Color.gray.opacity(0.25), lineWidth: 1)
							)
					}
					
					// Email Input
					VStack(alignment: .leading, spacing: 10) {
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
							.submitLabel(.next)
							.focused($focused, equals: .email)
							.onSubmit { focused = .password }
							.font(.system(size: 17))
							.padding(.horizontal, 16)
							.padding(.vertical, 16)
							.frame(height: 50)
							.background(Color.gray.opacity(0.1))
							.clipShape(RoundedRectangle(cornerRadius: 12))
							.overlay(
								RoundedRectangle(cornerRadius: 12)
									.stroke(Color.gray.opacity(0.25), lineWidth: 1)
							)
					}
					
					// Password Input
					VStack(alignment: .leading, spacing: 10) {
						Text("Password")
							.font(.system(size: 15, weight: .medium))
							.foregroundColor(.black)
						
						HStack {
							if showingPassword {
								TextField("Password", text: $password)
									.font(.system(size: 17))
									.textContentType(.newPassword)
									.submitLabel(.done)
									.focused($focused, equals: .password)
							} else {
								SecureField("Password", text: $password)
									.font(.system(size: 17))
									.textContentType(.newPassword)
									.submitLabel(.done)
									.focused($focused, equals: .password)
							}
							
							Button {
								showingPassword.toggle()
							} label: {
								Image(systemName: showingPassword ? "eye.slash.fill" : "eye.fill")
									.font(.system(size: 18))
									.foregroundColor(.gray.opacity(0.7))
							}
						}
						.padding(.horizontal, 16)
						.padding(.vertical, 16)
						.frame(height: 50)
						.background(Color.gray.opacity(0.1))
						.clipShape(RoundedRectangle(cornerRadius: 12))
						.overlay(
							RoundedRectangle(cornerRadius: 12)
								.stroke(Color.gray.opacity(0.25), lineWidth: 1)
						)
					}
					
					// Terms and Privacy Policy Checkbox
					HStack(alignment: .top, spacing: 12) {
						Button {
							acceptTerms.toggle()
						} label: {
							Image(systemName: acceptTerms ? "checkmark.square.fill" : "square")
								.font(.system(size: 20))
								.foregroundColor(acceptTerms ? .blue : .gray)
						}
						.buttonStyle(.plain)
						
						HStack(spacing: 0) {
							Text("I agree to the ")
								.font(.system(size: 14))
								.foregroundColor(.black)
							Button("Terms") {
								// TODO: Open terms
							}
							.font(.system(size: 14))
							.foregroundColor(.blue)
							.buttonStyle(.plain)
							Text(" and ")
								.font(.system(size: 14))
								.foregroundColor(.black)
							Button("Privacy Policy") {
								// TODO: Open privacy policy
							}
							.font(.system(size: 14))
							.foregroundColor(.blue)
							.buttonStyle(.plain)
						}
					}
					.onTapGesture {
						acceptTerms.toggle()
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
					
					// Create Account Button with Purple Gradient
					Button {
						Task { await register() }
					} label: {
						HStack {
							if case .loading = authManager.authState {
								ProgressView()
									.tint(.white)
							}
							Text("Create Account")
								.font(.system(size: 18, weight: .semibold))
						}
						.frame(maxWidth: .infinity)
						.frame(height: 56)
						.background(
							LinearGradient(
								colors: [
									Color(red: 0.388, green: 0.404, blue: 0.945), // #6366F1
									Color(red: 0.545, green: 0.361, blue: 0.965)  // #8B5CF6
								],
								startPoint: .leading,
								endPoint: .trailing
							)
						)
						.foregroundColor(.white)
						.clipShape(RoundedRectangle(cornerRadius: 14))
					}
					.padding(.top, 8)
					.disabled(!canSubmit)
					
					// OR Separator
					HStack {
						Rectangle()
							.fill(Color.gray.opacity(0.25))
							.frame(height: 1)
						
						Text("OR")
							.font(.system(size: 15, weight: .medium))
							.foregroundColor(.gray)
							.padding(.horizontal, 16)
						
						Rectangle()
							.fill(Color.gray.opacity(0.25))
							.frame(height: 1)
					}
					.padding(.vertical, 16)
					
					// Additional login options
					// Sign in with Apple
					SignInWithAppleButton(.signUp, onRequest: { request in
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
					
					// Sign in prompt
					HStack(spacing: 4) {
						Text("Already have an account?")
							.font(.system(size: 15))
							.foregroundColor(.gray)
						Button("Log in") {
							switchToLogin()
						}
						.font(.system(size: 15, weight: .semibold))
						.foregroundColor(.blue)
					}
					.frame(maxWidth: .infinity, alignment: .center)
					.padding(.top, 20)
					.padding(.bottom, 48)
				}
				.padding(.horizontal, 24)
				.frame(maxWidth: .infinity)
				.background(Color.white)
				#if os(iOS)
				.cornerRadius(32, corners: [.topLeft, .topRight])
				#else
				.cornerRadius(32)
				#endif
			}
		}
	}
	
	private var canSubmit: Bool {
		let isLoading: Bool = {
			if case .loading = authManager.authState { return true }
			return false
		}()
		return !fullName.trimmingCharacters(in: .whitespaces).isEmpty &&
		Validation.isValidEmail(email) &&
		password.count >= 8 &&
		acceptTerms &&
		!isLoading
	}
	
	private func register() async {
		guard canSubmit else {
			errorMessage = "Please fill in all fields correctly and accept the terms."
			return
		}
		#if canImport(UIKit)
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
		#endif
		await authManager.register(email: email.trimmingCharacters(in: .whitespacesAndNewlines), password: password, fullName: fullName.trimmingCharacters(in: .whitespacesAndNewlines))
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
