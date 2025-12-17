//
//  AuthLoginView.swift
//  CalendarNotes
//
//  Login view with purple gradient background
//

import SwiftUI

#if os(macOS)
import AppKit
#endif

#if os(iOS)
extension View {
    func emailTextFieldModifiers() -> some View {
        self.keyboardType(.emailAddress)
            .autocapitalization(.none)
    }
    
    func nameTextFieldModifiers() -> some View {
        self.autocapitalization(.words)
    }
    
    func underlineOnMacOS() -> some View {
        self
    }
}
#else
extension View {
    func emailTextFieldModifiers() -> some View {
        self
    }
    
    func nameTextFieldModifiers() -> some View {
        self
    }
    
    func underlineOnMacOS() -> some View {
        self.underline()
    }
}
#endif

struct AuthLoginView: View {
    @State private var email = ""
    @State private var password = ""
    @EnvironmentObject private var authManager: AuthManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    let switchToRegister: () -> Void
    
    private var emailFieldBorderColor: Color {
        // Visible border for input fields
        #if os(macOS)
        return Color(red: 0.7, green: 0.7, blue: 0.7) // Medium gray border
        #else
        return Color(white: 0.8) // Light gray border
        #endif
    }
    
    private var passwordFieldBorderColor: Color {
        // Visible border for password fields
        #if os(macOS)
        return Color(red: 0.7, green: 0.7, blue: 0.7) // Medium gray border
        #else
        return Color(white: 0.8) // Light gray border
        #endif
    }
    
    private var cardBorderColor: Color {
        #if os(macOS)
        return Color.gray.opacity(0.2)
        #else
        return Color.clear
        #endif
    }
    
    private var shadowOpacity: Double {
        #if os(macOS)
        return 0.15
        #else
        return 0.2
        #endif
    }
    
    // Text colors for macOS compatibility
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
    
    private var grayTextColor: Color {
        // Dark gray for subtitles
        #if os(macOS)
        return Color(red: 0.5, green: 0.5, blue: 0.5) // Medium gray
        #else
        return Color.gray
        #endif
    }
    
    private var blackTextColor: Color {
        // Pure black for headings
        #if os(macOS)
        return Color(red: 0.0, green: 0.0, blue: 0.0) // Pure black
        #else
        return Color.black
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
    
    var body: some View {
        ZStack {
            // Always show gradient background (works on both iOS and macOS)
            DesignSystem.accentGradient
                .ignoresSafeArea(.all)
            
            GeometryReader { geometry in
                ScrollView {
                    VStack(spacing: 0) {
                        // Top spacing with safe area consideration
                        Spacer()
                            .frame(height: max(60, geometry.safeAreaInsets.top + 20))
                        
                        // Calendar Icon (80x80pt)
                        CalendarIconView()
                        
                        // App Title (28pt, bold, white) - explicit color for macOS
                        Text("CalendarNotes")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(whiteTextColor)
                            .shadow(color: Color.black.opacity(0.6), radius: 4, x: 0, y: 2)
                            .padding(.top, 24)
                        
                        // Tagline (14pt, white) - explicit color for macOS
                        Text("Your life, organized")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundColor(whiteTextColor)
                            .shadow(color: Color.black.opacity(0.5), radius: 3, x: 0, y: 1)
                            .padding(.top, 8)
                        
                        Spacer()
                            .frame(height: 50)
                        
                        // White rounded card (cornerRadius: 24pt)
                        VStack(alignment: .leading, spacing: 20) {
                        // "Welcome Back" heading (24pt, bold, black) - explicit macOS colors
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Welcome Back")
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(blackTextColor)
                            
                            // "Sign in to continue" subtitle (14pt, gray) - explicit macOS colors
                            Text("Sign in to continue")
                                .font(.system(size: 14, weight: .regular))
                                .foregroundColor(grayTextColor)
                        }
                        .padding(.bottom, 8)
                        
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
                                    .strokeBorder(emailFieldBorderColor, lineWidth: 1.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Password Field
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Password")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(labelTextColor)
                                
                                Spacer()
                                
                                Button(action: {}) {
                                    Text("Forgot Password?")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(DesignSystem.accentColor)
                                        .underlineOnMacOS()
                                }
                                .buttonStyle(.plain)
                            }
                            
                            SecureField("••••••••", text: $password)
                                .font(.system(size: 16))
                                .foregroundColor(labelTextColor)
                                .padding()
                                .background(Color(white: 0.96))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(passwordFieldBorderColor, lineWidth: 1.5)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        
                        // Error Message - explicit macOS colors
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 13))
                                .foregroundColor(redTextColor)
                                .padding(.top, 4)
                        }
                        
                        // "Sign In" button (full width, purple gradient, 16pt padding)
                        VStack(spacing: 8) {
                            Button(action: {
                                Task {
                                    await signIn()
                                }
                            }) {
                                Text("Sign In")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(DesignSystem.accentGradient)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(isLoading)
                            .opacity(isLoading ? 0.6 : 1.0)
                            .buttonStyle(.plain)
                            
                            // Loading Indicator
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .scaleEffect(0.8)
                                    .tint(DesignSystem.accentColor)
                            }
                        }
                        
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
                            // "Continue with Google" button (white, border, blue icon)
                            Button(action: {
                                Task {
                                    await googleSignIn()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "globe")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.blue)
                                    
                                    Text("Continue with Google")
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
                            
                            // "Continue with Apple" button (black background, white text, apple icon)
                            Button(action: {
                                Task {
                                    await appleSignIn()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "applelogo")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Text("Continue with Apple")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundColor(.white)
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
                            Text("Don't have an account?")
                                .font(.system(size: 14))
                                .foregroundColor(secondaryLabelTextColor)
                            
                            Button(action: switchToRegister) {
                                Text("Sign Up")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(DesignSystem.accentColor)
                                    .underlineOnMacOS()
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                        }
                        .padding(24)
                        .background(DesignSystem.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                        .shadow(
                            color: Color.black.opacity(shadowOpacity),
                            radius: 20,
                            x: 0,
                            y: 8
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(cardBorderColor, lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        
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
    
    private func signIn() async {
        isLoading = true
        errorMessage = nil
        
        // Validate input
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "Please enter both email and password"
            isLoading = false
            return
        }
        
        guard email.contains("@") else {
            errorMessage = "Please enter a valid email address"
            isLoading = false
            return
        }
        
        guard password.count >= 8 else {
            errorMessage = "Password must be at least 8 characters"
            isLoading = false
            return
        }
        
        do {
            await authManager.login(email: email, password: password)
            
            // Check if login was successful
            if case .error(let error) = authManager.authState {
                // Provide user-friendly error messages
                let errorDesc = error.localizedDescription
                if errorDesc.contains("Could not connect") || errorDesc.contains("network") || errorDesc.contains("timed out") {
                    errorMessage = "Cannot connect to server. Please check that Docker is running and the server is accessible at http://localhost:3000"
                } else if errorDesc.contains("401") || errorDesc.contains("Invalid credentials") || errorDesc.contains("Unauthorized") {
                    errorMessage = "Invalid email or password. Please try again."
                } else if errorDesc.contains("400") || errorDesc.contains("validation") {
                    errorMessage = "Invalid input. Please check your email and password."
                } else {
                    errorMessage = errorDesc
                }
            } else if case .authenticated = authManager.authState {
                // Login successful - navigation will be handled by the parent view
                errorMessage = nil
            }
        } catch {
            let errorDesc = error.localizedDescription
            if errorDesc.contains("Could not connect") || errorDesc.contains("network") || errorDesc.contains("timed out") {
                errorMessage = "Cannot connect to server. Please check that Docker is running and the server is accessible at http://localhost:3000"
            } else {
                errorMessage = errorDesc
            }
        }
        
        isLoading = false
    }
    
    private func googleSignIn() async {
        isLoading = true
        // TODO: Implement Google Sign In
        isLoading = false
    }
    
    private func appleSignIn() async {
        isLoading = true
        // TODO: Implement Apple Sign In
        isLoading = false
    }
}


#Preview {
    AuthLoginView(switchToRegister: {})
        .environmentObject(AuthManager.shared)
}
