//
//  AuthRegisterView.swift
//  CalendarNotes
//
//  Register view with purple gradient background
//

import SwiftUI

#if os(macOS)
import AppKit
#endif

struct AuthRegisterView: View {
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var agreeToTerms = false
    @EnvironmentObject private var authManager: AuthManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let switchToLogin: () -> Void
    
    // Text colors for macOS compatibility - explicitly dark for visibility
    private var whiteTextColor: Color {
        #if os(macOS)
        return Color(NSColor.white)
        #else
        return Color.white
        #endif
    }
    
    private var labelTextColor: Color {
        // Explicitly dark for visibility on white backgrounds
        #if os(macOS)
        return Color(red: 0.0, green: 0.0, blue: 0.0) // Pure black
        #else
        return Color.black
        #endif
    }
    
    private var secondaryLabelTextColor: Color {
        // Dark gray for secondary text
        #if os(macOS)
        return Color(red: 0.4, green: 0.4, blue: 0.4) // Dark gray
        #else
        return Color.gray
        #endif
    }
    
    private var redTextColor: Color {
        #if os(macOS)
        return Color(NSColor.systemRed)
        #else
        return Color.red
        #endif
    }
    
    private var blueTextColor: Color {
        #if os(macOS)
        return Color(NSColor.systemBlue)
        #else
        return Color.blue
        #endif
    }
    
    // Border colors for input fields
    private var inputFieldBorderColor: Color {
        // Visible border for input fields
        #if os(macOS)
        return Color(red: 0.7, green: 0.7, blue: 0.7) // Medium gray border
        #else
        return Color(white: 0.8) // Light gray border
        #endif
    }
    
    var body: some View {
        ZStack {
            // Always show gradient background (works on both iOS and macOS)
            DesignSystem.accentGradient
                .ignoresSafeArea(.all)
            
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: 100)
                        
                        // Calendar Icon
                        CalendarIconView()
                        
                        // App Title - explicit macOS colors
                        Text("CalendarNotes")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(whiteTextColor)
                            .shadow(color: Color.black.opacity(0.6), radius: 4, x: 0, y: 2)
                            .padding(.top, 24)
                        
                        // Tagline - explicit macOS colors
                        Text("Your life, organized")
                            .font(.system(size: 16, weight: .regular))
                            .foregroundColor(whiteTextColor)
                            .shadow(color: Color.black.opacity(0.5), radius: 3, x: 0, y: 1)
                            .padding(.top, 8)
                        
                        Spacer()
                            .frame(height: 50)
                        
                        // White Auth Card
                        VStack(alignment: .leading, spacing: 20) {
                            // Title - explicit macOS colors
                            VStack(alignment: .leading, spacing: 6) {
                            Text("Create Account")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(labelTextColor)
                            
                            Text("Start organizing your life")
                                .font(.system(size: 14))
                                .foregroundColor(secondaryLabelTextColor)
                            }
                            .padding(.bottom, 8)
                            
                            // Full Name Field - explicit macOS colors
                            VStack(alignment: .leading, spacing: 10) {
                            Text("Full Name")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(labelTextColor)
                            
                            TextField("Soham Naik", text: $fullName)
                                .font(.system(size: 16))
                                .foregroundColor(labelTextColor)
                                .nameTextFieldModifiers()
                                .padding()
                                .background(Color(white: 0.96))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(inputFieldBorderColor, lineWidth: 1.5)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .textFieldStyle(.plain)
                            }
                            
                            // Email Field - explicit macOS colors
                            VStack(alignment: .leading, spacing: 10) {
                            Text("Email")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(labelTextColor)
                            
                            ZStack(alignment: .leading) {
                                if email.isEmpty {
                                    Text("you@example.com")
                                        .font(.system(size: 16))
                                        .foregroundColor(secondaryLabelTextColor)
                                        .padding(.horizontal, 16)
                                }
                                TextField("", text: $email)
                                    .font(.system(size: 16))
                                    .foregroundColor(labelTextColor)
                                    .emailTextFieldModifiers()
                            }
                            .padding()
                            .background(Color(white: 0.96))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(inputFieldBorderColor, lineWidth: 1.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            // Password Field - explicit macOS colors
                            VStack(alignment: .leading, spacing: 10) {
                            Text("Password")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(labelTextColor)
                            
                            SecureField("••••••••", text: $password)
                                .font(.system(size: 16))
                                .foregroundColor(labelTextColor)
                                .padding()
                                .background(Color(white: 0.96))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(inputFieldBorderColor, lineWidth: 1.5)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            // Terms Checkbox
                            HStack(spacing: 12) {
                            Button(action: {
                                agreeToTerms.toggle()
                            }) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6)
                                        .strokeBorder(Color(white: 0.8), lineWidth: 2)
                                        .frame(width: 20, height: 20)
                                    
                                    if agreeToTerms {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(whiteTextColor)
                                            .frame(width: 20, height: 20)
                                            .background(DesignSystem.accentColor)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    }
                                }
                                .buttonStyle(.plain)
                                
                                Text("I agree to the")
                                    .font(.system(size: 13))
                                    .foregroundColor(secondaryLabelTextColor)
                                
                                Button(action: {}) {
                                    Text("Terms")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(DesignSystem.accentColor)
                                }
                                
                                Text("and")
                                    .font(.system(size: 13))
                                    .foregroundColor(secondaryLabelTextColor)
                                
                                Button(action: {}) {
                                    Text("Privacy Policy")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(DesignSystem.accentColor)
                                }
                            }
                            .padding(.top, 4)
                            
                            // Error Message - explicit macOS colors
                            if let errorMessage = errorMessage {
                                Text(errorMessage)
                                    .font(.system(size: 13))
                                    .foregroundColor(redTextColor)
                                    .padding(.top, 4)
                            }
                            
                            // Create Account Button
                            GradientButton(title: "Create Account", action: {
                                Task {
                                    await register()
                                }
                            })
                            .disabled(isLoading || !agreeToTerms)
                            .opacity((isLoading || !agreeToTerms) ? 0.6 : 1.0)
                            
                            // Divider
                            HStack {
                                Rectangle()
                                    .fill(Color(white: 0.9))
                                    .frame(height: 1)
                                
                                Text("OR")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(secondaryLabelTextColor)
                                    .padding(.horizontal, 16)
                                
                                Rectangle()
                                    .fill(Color(white: 0.9))
                                    .frame(height: 1)
                            }
                            .padding(.vertical, 8)
                            
                            // Social Buttons
                            VStack(spacing: 12) {
                            // "Sign up with Google" button (white, border, blue icon)
                            Button(action: {
                                Task {
                                    await googleSignUp()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(blueTextColor)
                                    
                                    Text("Sign up with Google")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(labelTextColor)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color.white)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(white: 0.9), lineWidth: 2)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                                
                                // "Sign up with Apple" button (black background, white text, apple icon)
                                Button(action: {
                                    Task {
                                        await appleSignUp()
                                    }
                                }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "applelogo")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundColor(whiteTextColor)
                                        
                                        Text("Sign up with Apple")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(whiteTextColor)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.black)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            }
                            
                            // Footer
                            HStack {
                                Text("Already have an account?")
                                    .font(.system(size: 14))
                                    .foregroundColor(secondaryLabelTextColor)
                                
                                Button(action: switchToLogin) {
                                    Text("Sign In")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(DesignSystem.accentColor)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                        }
                    .padding(24)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 8)
                    .padding(.horizontal, 24)
                    
                    // Bottom spacing with safe area consideration
                    Spacer()
                        .frame(height: max(40, geometry.safeAreaInsets.bottom + 20))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(.all)
    }
    
    private func register() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // TODO: Implement actual registration logic
            try await Task.sleep(nanoseconds: 1_000_000_000)
            // await authManager.register(name: fullName, email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func googleSignUp() async {
        isLoading = true
        // TODO: Implement Google Sign Up
        isLoading = false
    }
    
    private func appleSignUp() async {
        isLoading = true
        // TODO: Implement Apple Sign Up
        isLoading = false
    }
}

#Preview {
    AuthRegisterView(switchToLogin: {})
        .environmentObject(AuthManager.shared)
}
