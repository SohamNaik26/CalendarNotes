//
//  AuthService.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum AuthServiceError: Error, LocalizedError {
	case invalidURL
	case serverError(String)
	case decodingFailed
	case unauthorized
	case notAuthenticated
	case notImplemented
	
	var errorDescription: String? {
		switch self {
		case .invalidURL: return "Invalid URL"
		case .serverError(let msg): return msg
		case .decodingFailed: return "Failed to decode server response"
		case .unauthorized: return "Unauthorized"
		case .notAuthenticated: return "Not authenticated"
		case .notImplemented: return "Not implemented"
		}
	}
}

final class AuthService {
	static let shared = AuthService()
	private init() {}
	
	private let baseURLKey = "auth.api.baseURL"
	private var baseURL: URL {
		let defaultURL = URL(string: "http://localhost:3000")!
		if let s = UserDefaults.standard.string(forKey: baseURLKey), let u = URL(string: s) {
			return u
		}
		return defaultURL
	}
	
	private func endpoint(_ path: String) throws -> URL {
		guard let url = URL(string: path, relativeTo: baseURL) else { throw AuthServiceError.invalidURL }
		return url
	}
	
	private func request<T: Decodable>(_ method: String, path: String, body: Encodable? = nil, authorized: Bool = false, decode type: T.Type) async throws -> T {
		let url = try endpoint(path)
		var req = URLRequest(url: url)
		req.httpMethod = method
		req.setValue("application/json", forHTTPHeaderField: "Content-Type")
		if authorized {
			let token = try await TokenManager.shared.withValidAccessToken()
			req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		}
		if let body {
			req.httpBody = try JSONEncoder().encode(AnyEncodable(body))
		}
		
		let (data, resp) = try await URLSession.shared.data(for: req)
		if let http = resp as? HTTPURLResponse {
			if http.statusCode == 401, authorized {
				do {
					let token = try await TokenManager.shared.forceRefresh()
					var retryReq = req
					retryReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
					let (retryData, retryResp) = try await URLSession.shared.data(for: retryReq)
					guard let retryHttp = retryResp as? HTTPURLResponse, (200..<300).contains(retryHttp.statusCode) else {
						throw AuthServiceError.unauthorized
					}
					let decoder = JSONDecoder()
					decoder.dateDecodingStrategy = .iso8601
					return try decoder.decode(T.self, from: retryData)
				} catch {
					TokenManager.shared.clearTokens()
					AuthManager.shared.handleSessionExpired()
					throw AuthServiceError.unauthorized
				}
			}
			guard (200..<300).contains(http.statusCode) else {
				let msg = String(data: data, encoding: .utf8) ?? "HTTP \(http.statusCode)"
				throw AuthServiceError.serverError(msg)
			}
		}
		do {
			let decoder = JSONDecoder()
			decoder.dateDecodingStrategy = .custom { decoder in
				let container = try decoder.singleValueContainer()
				let value = try container.decode(String.self)
				// Try ISO8601 with fractional seconds first
				if let date = AuthService.iso8601WithFractional.date(from: value) {
					return date
				}
				// Fallback to plain ISO8601
				if let date = AuthService.iso8601Plain.date(from: value) {
					return date
				}
				throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format: \(value)")
			}
			return try decoder.decode(T.self, from: data)
		} catch {
			throw AuthServiceError.decodingFailed
		}
	}
	
	// MARK: - API
	
	func register(email: String, password: String, fullName: String?) async throws -> AuthResponse {
		struct RegisterReq: Encodable { let email: String; let password: String; let fullName: String? }
		let res: AuthResponse = try await request("POST", path: "/api/auth/register", body: RegisterReq(email: email, password: password, fullName: fullName), authorized: false, decode: AuthResponse.self)
		TokenManager.shared.setTokens(access: res.accessToken, refresh: res.refreshToken)
		return res
	}
	
	func login(credentials: AuthCredentials) async throws -> AuthResponse {
		struct LoginReq: Encodable { let email: String; let password: String }
		let res: AuthResponse = try await request("POST", path: "/api/auth/login", body: LoginReq(email: credentials.email, password: credentials.password), authorized: false, decode: AuthResponse.self)
		TokenManager.shared.setTokens(access: res.accessToken, refresh: res.refreshToken)
		return res
	}
	
	func logout() async throws {
		struct Empty: Decodable {}
		_ = try await request("POST", path: "/api/auth/logout", body: (nil as Encodable?), authorized: true, decode: Empty.self)
		TokenManager.shared.clearTokens()
	}
	
	func refreshToken() async throws -> String {
		return try await TokenManager.shared.forceRefresh()
	}
	
	func getCurrentUser() async throws -> User {
		struct MeResponse: Decodable { let user: User }
		let res: MeResponse = try await request("GET", path: "/api/auth/me", body: (nil as Encodable?), authorized: true, decode: MeResponse.self)
		return res.user
	}
	
	#if canImport(UIKit)
	func updateProfile(fullName: String?, profileImage: UIImage?) async throws -> User {
		// Placeholder: real API would accept multipart/form-data. Stub to notImplemented.
		throw AuthServiceError.notImplemented
	}
	#else
	func updateProfile(fullName: String?, profileImage: Any?) async throws -> User {
		throw AuthServiceError.notImplemented
	}
	#endif
	
	func changePassword(oldPassword: String, newPassword: String) async throws {
		// Placeholder: backend route not implemented
		throw AuthServiceError.notImplemented
	}
	
	func forgotPassword(email: String) async throws {
		struct Req: Encodable { let email: String }
		struct Res: Decodable { let success: Bool }
		_ = try await request("POST", path: "/api/auth/forgot-password", body: Req(email: email), authorized: false, decode: Res.self)
	}
	
	func resetPassword(token: String, newPassword: String) async throws {
		struct Req: Encodable { let token: String; let password: String }
		struct Res: Decodable { let success: Bool }
		_ = try await request("POST", path: "/api/auth/reset-password", body: Req(token: token, password: newPassword), authorized: false, decode: Res.self)
	}
	
	// MARK: - Social Authentication
	
	func signInWithApple(identityToken: String, authorizationCode: String, fullName: String?) async throws -> AuthResponse {
		struct AppleAuthReq: Encodable {
			let identityToken: String
			let authorizationCode: String
			let fullName: String?
		}
		let res: AuthResponse = try await request("POST", path: "/api/auth/apple", body: AppleAuthReq(identityToken: identityToken, authorizationCode: authorizationCode, fullName: fullName), authorized: false, decode: AuthResponse.self)
		TokenManager.shared.setTokens(access: res.accessToken, refresh: res.refreshToken)
		return res
	}
	
	func signInWithGoogle(idToken: String, accessToken: String?, fullName: String?) async throws -> AuthResponse {
		struct GoogleAuthReq: Encodable {
			let idToken: String
			let accessToken: String?
			let fullName: String?
		}
		let res: AuthResponse = try await request("POST", path: "/api/auth/google", body: GoogleAuthReq(idToken: idToken, accessToken: accessToken, fullName: fullName), authorized: false, decode: AuthResponse.self)
		TokenManager.shared.setTokens(access: res.accessToken, refresh: res.refreshToken)
		return res
	}
}

// Encode arbitrary Encodable to JSON
private struct AnyEncodable: Encodable {
	private let encodeFunc: (Encoder) throws -> Void
	init<T: Encodable>(_ wrapped: T) {
		self.encodeFunc = wrapped.encode
	}
	func encode(to encoder: Encoder) throws {
		try encodeFunc(encoder)
	}
}

private extension AuthService {
	static let iso8601WithFractional: ISO8601DateFormatter = {
		let f = ISO8601DateFormatter()
		f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
		return f
	}()
	static let iso8601Plain: ISO8601DateFormatter = {
		let f = ISO8601DateFormatter()
		f.formatOptions = [.withInternetDateTime]
		return f
	}()
}


