//
//  ForgotPasswordView.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import SwiftUI

struct ForgotPasswordView: View {
	@State private var email: String = ""
	@State private var sent: Bool = false
	@State private var errorMessage: String?
	
	var body: some View {
		VStack(spacing: 0) {
			ScrollView {
				VStack(alignment: .leading, spacing: 12) {
					Text("Reset your password")
						.font(.title2).bold()
					
					TextField("Email", text: $email)
						.disableAutocorrection(true)
						.padding()
						.background(Color.cnSecondaryBackground)
						.clipShape(RoundedRectangle(cornerRadius: 12))
					
					if let errorMessage {
						Text(errorMessage)
							.foregroundColor(.red)
							.font(.footnote)
					}
					if sent {
						Text("If the email exists, a reset link will be sent.")
							.foregroundColor(.green)
							.font(.footnote)
					}
				}
				.padding()
				.padding(.bottom, 100) // Extra padding for button space
			}
			
			// Fixed button at bottom
			VStack(spacing: 0) {
				Divider()
				Button {
					Task { await submit() }
				} label: {
					Text("Send Reset Link")
						.bold()
						.frame(maxWidth: .infinity)
						.padding(.vertical, 16)
				}
				.buttonStyle(.borderedProminent)
				.controlSize(.large)
				.disabled(!Validation.isValidEmail(email))
				.padding(.horizontal)
				.padding(.top, 12)
				.padding(.bottom, 20)
				.background(Color.cnBackground)
			}
		}
	}
	
	private func submit() async {
		guard Validation.isValidEmail(email) else {
			errorMessage = "Enter a valid email"
			return
		}
		do {
			try await AuthService.shared.forgotPassword(email: email.trimmingCharacters(in: .whitespacesAndNewlines))
			sent = true
			errorMessage = nil
		} catch {
			errorMessage = error.localizedDescription
		}
	}
}


