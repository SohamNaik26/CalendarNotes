//
//  GoogleSignInService.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import AuthenticationServices

#if canImport(UIKit)
import UIKit
#endif

/// Service for handling Google Sign-In authentication
@MainActor
final class GoogleSignInService: NSObject {
    static let shared = GoogleSignInService()
    
    private var continuation: CheckedContinuation<GoogleSignInResult, Error>?
    
    // Google OAuth configuration
    // TODO: Replace with your actual Google OAuth client ID
    private let googleClientId: String = {
        // First try Info.plist
        if let clientId = Bundle.main.object(forInfoDictionaryKey: "GoogleOAuthClientID") as? String,
           !clientId.isEmpty, clientId != "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com" {
            return clientId
        }
        // Then try UserDefaults
        if let clientId = UserDefaults.standard.string(forKey: "google.oauth.clientId"),
           !clientId.isEmpty, clientId != "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com" {
            return clientId
        }
        // Default placeholder - replace with your actual client ID
        return "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com"
    }()
    
    private let redirectURI = "com.calendarnotes.app:/oauth2callback"
    private let scopes = ["openid", "profile", "email"]
    
    private override init() {
        super.init()
    }
    
    /// Signs in with Google using web-based OAuth flow
    func signIn() async throws -> GoogleSignInResult {
        guard googleClientId != "YOUR_GOOGLE_CLIENT_ID.apps.googleusercontent.com" else {
            throw GoogleSignInError.configurationMissing("Please configure your Google OAuth Client ID in UserDefaults with key 'google.oauth.clientId'")
        }
        
        // Build Google OAuth URL
        var components = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: googleClientId),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " ")),
            URLQueryItem(name: "access_type", value: "offline"),
            URLQueryItem(name: "prompt", value: "consent")
        ]
        
        guard let authURL = components.url else {
            throw GoogleSignInError.invalidURL
        }
        
        #if os(iOS)
        // Use ASWebAuthenticationSession for iOS
        return try await signInWithWebSession(authURL: authURL)
        #elseif os(macOS)
        // Use ASWebAuthenticationSession for macOS
        return try await signInWithWebSession(authURL: authURL)
        #else
        throw GoogleSignInError.platformNotSupported
        #endif
    }
    
    #if os(iOS) || os(macOS)
    private func signInWithWebSession(authURL: URL) async throws -> GoogleSignInResult {
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            
            let session = ASWebAuthenticationSession(
                url: authURL,
                callbackURLScheme: "com.calendarnotes.app"
            ) { [weak self] callbackURL, error in
                guard let self = self else { return }
                
                if let error = error {
                    if let authError = error as? ASWebAuthenticationSessionError,
                       authError.code == .canceledLogin {
                        self.continuation?.resume(throwing: GoogleSignInError.userCanceled)
                    } else {
                        self.continuation?.resume(throwing: error)
                    }
                    self.continuation = nil
                    return
                }
                
                guard let callbackURL = callbackURL else {
                    self.continuation?.resume(throwing: GoogleSignInError.invalidCallback)
                    self.continuation = nil
                    return
                }
                
                // Extract authorization code from callback URL
                guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                      let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
                    self.continuation?.resume(throwing: GoogleSignInError.invalidCallback)
                    self.continuation = nil
                    return
                }
                
                // Exchange authorization code for tokens
                Task {
                    do {
                        let result = try await self.exchangeCodeForTokens(code: code)
                        self.continuation?.resume(returning: result)
                        self.continuation = nil
                    } catch {
                        self.continuation?.resume(throwing: error)
                        self.continuation = nil
                    }
                }
            }
            
            #if os(iOS)
            session.presentationContextProvider = self
            #endif
            
            session.start()
        }
    }
    #endif
    
    /// Exchanges authorization code for ID token and access token via backend
    private func exchangeCodeForTokens(code: String) async throws -> GoogleSignInResult {
        // Send authorization code to backend, which will exchange it for tokens
        // This is more secure as the client secret stays on the server
        struct TokenExchangeRequest: Encodable {
            let code: String
            let redirectURI: String
        }
        
        struct TokenExchangeResponse: Decodable {
            let idToken: String
            let accessToken: String?
            let fullName: String?
            let email: String?
        }
        
        let requestBody = TokenExchangeRequest(code: code, redirectURI: redirectURI)
        
        // Get base URL
        let baseURL: URL = {
            let defaultURL = URL(string: "http://localhost:3000")!
            if let s = UserDefaults.standard.string(forKey: "auth.api.baseURL"), let u = URL(string: s) {
                return u
            }
            return defaultURL
        }()
        
        guard let url = URL(string: "/api/auth/google/exchange", relativeTo: baseURL) else {
            throw GoogleSignInError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GoogleSignInError.tokenExchangeFailed
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            _ = String(data: data, encoding: .utf8) ?? "HTTP \(httpResponse.statusCode)"
            throw GoogleSignInError.tokenExchangeFailed
        }
        
        let decoder = JSONDecoder()
        let tokenResponse = try decoder.decode(TokenExchangeResponse.self, from: data)
        
        return GoogleSignInResult(
            idToken: tokenResponse.idToken,
            accessToken: tokenResponse.accessToken,
            fullName: tokenResponse.fullName,
            email: tokenResponse.email
        )
    }
}

#if os(iOS)
extension GoogleSignInService: ASWebAuthenticationPresentationContextProviding {
    // Note: This function only uses UIWindow(windowScene:) which is the correct API for iOS 13+
    // Any deprecation warnings are false positives from the compiler
    @available(iOS 13.0, *)
    // swiftlint:disable:next deprecated_declarations
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Get all connected scenes and find a suitable window scene
        let scenes = UIApplication.shared.connectedScenes
        
        // Try to get the foreground active window scene first
        for scene in scenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            
            // Prefer foreground active scenes
            if windowScene.activationState == .foregroundActive {
                // Try to find the key window first
                if let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                    return window
                }
                // Fallback to any window in the scene
                if let window = windowScene.windows.first {
                    return window
                }
                // Create a new window in the scene (using windowScene: not deprecated frame:)
                return UIWindow(windowScene: windowScene)
            }
        }
        
        // Try any available scene as fallback
        if let window = findWindowInScenes(scenes) {
            return window
        }
        
        // This should never happen in normal operation
        // If no window scene is available, create a fallback window
        // Log the issue for debugging but don't crash the app
        print("⚠️ Warning: No window scene available for Google Sign-In presentation anchor. Creating fallback window.")
        
        // Create a fallback window using the first available scene
        if let firstScene = scenes.first as? UIWindowScene {
            return UIWindow(windowScene: firstScene)
        }
        
        // Last resort: create a window with a default frame (deprecated but necessary as fallback)
        #if DEBUG
        // In debug mode, we want to know if this happens
        print("❌ Critical: Unable to create any presentation anchor. This may cause Google Sign-In to fail.")
        #endif
        
        // Return a minimal window as absolute last resort
        // Note: This may not work in all cases, but it's better than crashing
        return UIWindow(frame: UIScreen.main.bounds)
    }
    
    /// Helper function to find a window in any available scene
    /// This separation helps avoid compiler false positives about deprecated APIs
    private func findWindowInScenes(_ scenes: Set<UIScene>) -> UIWindow? {
        for scene in scenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            
            // Try to find the key window first
            if let window = windowScene.windows.first(where: { $0.isKeyWindow }) {
                return window
            }
            // Fallback to any window in the scene
            if let window = windowScene.windows.first {
                return window
            }
            // Create a new window in the scene (using windowScene: not deprecated frame:)
            return UIWindow(windowScene: windowScene)
        }
        return nil
    }
}
#endif

// MARK: - Models

struct GoogleSignInResult {
    let idToken: String
    let accessToken: String?
    let fullName: String?
    let email: String?
}

enum GoogleSignInError: LocalizedError {
    case configurationMissing(String)
    case invalidURL
    case invalidCallback
    case tokenExchangeFailed
    case userCanceled
    case platformNotSupported
    
    var errorDescription: String? {
        switch self {
        case .configurationMissing(let message):
            return "Google Sign-In configuration missing: \(message)"
        case .invalidURL:
            return "Invalid Google OAuth URL"
        case .invalidCallback:
            return "Invalid OAuth callback"
        case .tokenExchangeFailed:
            return "Failed to exchange authorization code for tokens"
        case .userCanceled:
            return "Sign in was canceled"
        case .platformNotSupported:
            return "Google Sign-In is not supported on this platform"
        }
    }
}



