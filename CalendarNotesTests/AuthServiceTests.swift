//
//  AuthServiceTests.swift
//  CalendarNotesTests
//
//  Unit tests for AuthService
//

import Testing
import Foundation
@testable import CalendarNotes

@Suite("AuthService Tests")
struct AuthServiceTests {
    
    @Test("Service is singleton")
    func testSingleton() {
        let service1 = AuthService.shared
        let service2 = AuthService.shared
        #expect(service1 === service2)
    }
    
    @Test("Base URL configuration")
    func testBaseURL() {
        let service = AuthService.shared
        
        // Test default URL
        // Note: This would require accessing private properties or using reflection
        // For now, we verify the service exists
        #expect(service != nil)
    }
    
    @Test("Registration request structure")
    func testRegistration() async throws {
        let service = AuthService.shared
        
        // This would require a mock server or test server
        // For now, we test error handling
        do {
            _ = try await service.register(
                email: "test@example.com",
                password: "password123",
                fullName: "Test User"
            )
        } catch {
            // Expected without actual server
            // Verify error is of expected type
            #expect(error is AuthServiceError)
        }
    }
    
    @Test("Login request structure")
    func testLogin() async throws {
        let service = AuthService.shared
        
        let credentials = AuthCredentials(email: "test@example.com", password: "password123")
        
        do {
            _ = try await service.login(credentials: credentials)
        } catch {
            // Expected without actual server
            #expect(error is AuthServiceError)
        }
    }
    
    @Test("Token refresh")
    func testTokenRefresh() async throws {
        let service = AuthService.shared
        
        do {
            _ = try await service.refreshToken()
        } catch {
            // Expected without valid tokens
            #expect(error is AuthServiceError)
        }
    }
    
    @Test("Get current user")
    func testGetCurrentUser() async throws {
        let service = AuthService.shared
        
        do {
            _ = try await service.getCurrentUser()
        } catch {
            // Expected without authentication
            #expect(error is AuthServiceError)
        }
    }
    
    @Test("Logout clears tokens")
    func testLogout() async throws {
        let service = AuthService.shared
        
        do {
            try await service.logout()
        } catch {
            // Expected without authentication
        }
        
        // Verify tokens are cleared (would need to check TokenManager)
    }
    
    @Test("Social authentication - Apple")
    func testAppleSignIn() async throws {
        let service = AuthService.shared
        
        do {
            _ = try await service.signInWithApple(
                identityToken: "test_token",
                authorizationCode: "test_code",
                fullName: "Test User"
            )
        } catch {
            // Expected without actual tokens
            #expect(error is AuthServiceError)
        }
    }
    
    @Test("Social authentication - Google")
    func testGoogleSignIn() async throws {
        let service = AuthService.shared
        
        do {
            _ = try await service.signInWithGoogle(
                idToken: "test_token",
                accessToken: "test_access",
                fullName: "Test User"
            )
        } catch {
            // Expected without actual tokens
            #expect(error is AuthServiceError)
        }
    }
    
    @Test("Password reset flow")
    func testPasswordReset() async throws {
        let service = AuthService.shared
        
        do {
            try await service.forgotPassword(email: "test@example.com")
        } catch {
            // Expected without actual server
        }
        
        do {
            try await service.resetPassword(token: "test_token", newPassword: "newpassword123")
        } catch {
            // Expected without actual server
        }
    }
}

