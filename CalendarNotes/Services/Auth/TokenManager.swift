//
//  TokenManager.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import LocalAuthentication

@MainActor
final class TokenManager {
	static let shared = TokenManager()
	private init() {}
	
	private let expiryKey = "cn.auth.accessToken.exp"
	private let baseURLKey = "auth.api.baseURL"
	private var isRefreshing = false
	private var waiters: [CheckedContinuation<String, Error>] = []
	
	func setTokens(access: String, refresh: String, userId: String? = nil) {
		let requireBiometric = UserDefaults.standard.bool(forKey: KeychainManager.Key.biometricEnabled.rawValue)
		_ = KeychainManager.shared.setString(access, for: .accessToken, requireBiometric: requireBiometric)
		_ = KeychainManager.shared.setString(refresh, for: .refreshToken, requireBiometric: requireBiometric)
		if let userId {
			_ = KeychainManager.shared.setString(userId, for: .userId, requireBiometric: requireBiometric)
		}
		if let exp = decodeJWTExpiration(access) {
			UserDefaults.standard.set(exp.timeIntervalSince1970, forKey: expiryKey)
		}
	}
	
	func clearTokens() {
		KeychainManager.shared.remove(.accessToken)
		KeychainManager.shared.remove(.refreshToken)
		KeychainManager.shared.remove(.userId)
		UserDefaults.standard.removeObject(forKey: expiryKey)
	}
	
	func accessToken(requireBiometric: Bool = false) -> String? {
		let context = requireBiometric ? LAContext() : nil
		return KeychainManager.shared.getString(.accessToken, context: context)
	}
	
	func refreshToken() -> String? {
		return KeychainManager.shared.getString(.refreshToken)
	}
	
	func withValidAccessToken() async throws -> String {
		if let token = accessToken(), !isExpiringSoon() {
			return token
		}
		return try await refreshAccessTokenQueued()
	}
	
	func forceRefresh() async throws -> String {
		try await refreshAccessTokenQueued(force: true)
	}
	
	private func refreshAccessTokenQueued(force: Bool = false) async throws -> String {
		if isRefreshing {
			return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
				waiters.append(cont)
			}
		}
		isRefreshing = true
		defer { isRefreshing = false }
		do {
			let token = try await performRefreshIfNeeded(force: force)
			for waiter in waiters { waiter.resume(returning: token) }
			waiters.removeAll()
			return token
		} catch {
			for waiter in waiters { waiter.resume(throwing: error) }
			waiters.removeAll()
			throw error
		}
	}
	
	private func performRefreshIfNeeded(force: Bool) async throws -> String {
		if !force, let token = accessToken(), !isExpiringSoon() {
			return token
		}
		guard let refresh = refreshToken() else { throw AuthServiceError.notAuthenticated }
		struct RefreshReq: Encodable { let refreshToken: String }
		struct RefreshRes: Decodable { let token: String }
		let url = try endpoint("/api/auth/refresh-token")
		var req = URLRequest(url: url)
		req.httpMethod = "POST"
		req.setValue("application/json", forHTTPHeaderField: "Content-Type")
		req.httpBody = try JSONEncoder().encode(RefreshReq(refreshToken: refresh))
		let (data, resp) = try await URLSession.shared.data(for: req)
		guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
			clearTokens()
			throw AuthServiceError.unauthorized
		}
		let decoder = JSONDecoder()
		if let res = try? decoder.decode(RefreshRes.self, from: data) {
			setTokens(access: res.token, refresh: refresh)
			return res.token
		} else {
			throw AuthServiceError.decodingFailed
		}
	}
	
	private func endpoint(_ path: String) throws -> URL {
		let defaultURL = URL(string: "http://localhost:3000")!
		let base: URL
		if let s = UserDefaults.standard.string(forKey: baseURLKey), let u = URL(string: s) {
			base = u
		} else {
			base = defaultURL
		}
		guard let url = URL(string: path, relativeTo: base) else { throw AuthServiceError.invalidURL }
		return url
	}
	
	private func isExpiringSoon(threshold: TimeInterval = 3600) -> Bool {
		let ts = UserDefaults.standard.double(forKey: expiryKey)
		guard ts > 0 else { return false }
		let exp = Date(timeIntervalSince1970: ts)
		return exp.timeIntervalSinceNow < threshold
	}
}

// MARK: - JWT Helpers
fileprivate func decodeJWTExpiration(_ jwt: String) -> Date? {
	let parts = jwt.split(separator: ".")
	guard parts.count >= 2 else { return nil }
	let payload = parts[1]
	var base64 = String(payload).replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
	while base64.count % 4 != 0 { base64.append("=") }
	guard let data = Data(base64Encoded: base64),
		  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
		  let exp = obj["exp"] as? Double else { return nil }
	return Date(timeIntervalSince1970: exp)
}


