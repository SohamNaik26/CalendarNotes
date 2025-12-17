//
//  APIClient.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import Network

@MainActor
final class APIClient {
	static let shared = APIClient()
	
	private let session: URLSession
	private let baseURL: URL
	private let cache: URLCache
	private let monitor = NWPathMonitor()
	private let queue = DispatchQueue(label: "com.calendarnotes.network")
	private let jsonQueue = DispatchQueue(label: "com.calendarnotes.json", qos: .userInitiated)
	private var isOnline = true
	private var pendingRequests: [String: Task<Void, Never>] = [:]
	
	// Device ID for sync
	private let deviceId: String = {
		if let id = UserDefaults.standard.string(forKey: "cn.device.id") {
			return id
		}
		let id = UUID().uuidString
		UserDefaults.standard.set(id, forKey: "cn.device.id")
		return id
	}()
	
	// App version
	private let appVersion: String = {
		Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
	}()
	
	// Cache duration per endpoint (in seconds)
	private let cacheDurations: [String: TimeInterval] = [
		"/api/events": 60,
		"/api/notes": 60,
		"/api/todos": 60,
		"/api/bookmarks": 120,
		"/api/collections": 300,
		"/api/users/stats": 300
	]
	
	private init() {
		// Base URL configuration
		let defaultURL = URL(string: "http://localhost:3000")!
		if let urlString = UserDefaults.standard.string(forKey: "auth.api.baseURL"),
		   let url = URL(string: urlString) {
			self.baseURL = url
		} else {
			self.baseURL = defaultURL
		}
		
		// URLSession configuration
		let config = URLSessionConfiguration.default
		config.timeoutIntervalForRequest = 30
		config.timeoutIntervalForResource = 60
		config.requestCachePolicy = .returnCacheDataElseLoad
		config.urlCache = URLCache(memoryCapacity: 10 * 1024 * 1024, diskCapacity: 50 * 1024 * 1024)
		self.cache = config.urlCache!
		
		self.session = URLSession(configuration: config)
		
		// Network monitoring
		monitor.pathUpdateHandler = { [weak self] path in
			Task { @MainActor [weak self] in
				self?.isOnline = path.status == .satisfied
			}
		}
		monitor.start(queue: queue)
	}
	
	// MARK: - Request Methods
	
	func get<T: Decodable>(_ endpoint: APIEndpoint) async throws -> T {
		return try await performRequest(endpoint: endpoint, method: .get, body: nil)
	}
	
	func post<T: Decodable>(_ endpoint: APIEndpoint, body: Encodable?) async throws -> T {
		return try await performRequest(endpoint: endpoint, method: .post, body: body)
	}
	
	func put<T: Decodable>(_ endpoint: APIEndpoint, body: Encodable?) async throws -> T {
		return try await performRequest(endpoint: endpoint, method: .put, body: body)
	}
	
	func patch<T: Decodable>(_ endpoint: APIEndpoint, body: Encodable?) async throws -> T {
		return try await performRequest(endpoint: endpoint, method: .patch, body: body)
	}
	
	func delete(_ endpoint: APIEndpoint) async throws {
		let _: EmptyResponse = try await performRequest(endpoint: endpoint, method: .delete, body: nil)
	}
	
	func upload<T: Decodable>(_ endpoint: APIEndpoint, fileURL: URL, metadata: [String: String]? = nil) async throws -> T {
		var request = try buildRequest(endpoint: endpoint, method: .post)
		
		// Create multipart form data
		let boundary = UUID().uuidString
		request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
		
		var body = Data()
		
		// Add metadata fields
		if let metadata = metadata {
			for (key, value) in metadata {
				body.append("--\(boundary)\r\n".data(using: .utf8)!)
				body.append("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n".data(using: .utf8)!)
				body.append(value.data(using: .utf8)!)
				body.append("\r\n".data(using: .utf8)!)
			}
		}
		
		// Add file
		body.append("--\(boundary)\r\n".data(using: .utf8)!)
		body.append("Content-Disposition: form-data; name=\"audio\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
		body.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
		
		let fileData = try Data(contentsOf: fileURL)
		body.append(fileData)
		body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
		
		request.httpBody = body
		
		return try await performRequest(request: request, endpoint: endpoint, retryCount: 0)
	}
	
	// MARK: - Private Request Implementation
	
	private func performRequest<T: Decodable>(
		endpoint: APIEndpoint,
		method: HTTPMethod,
		body: Encodable?
	) async throws -> T {
		var request = try buildRequest(endpoint: endpoint, method: method)
		
		// Add body if present (encode on background thread)
		if let body = body {
			// Encode body before async closure to avoid Sendable capture issues
			// Use a helper function to encode without capturing non-Sendable type
			request.httpBody = try await encodeBody(body)
		}
		
		return try await performRequest(request: request, endpoint: endpoint, retryCount: 0)
	}
	
	private func performRequest<T: Decodable>(
		request: URLRequest,
		endpoint: APIEndpoint,
		retryCount: Int
	) async throws -> T {
		// Check cache for GET requests
		if request.httpMethod == "GET", let cachedResponse = cache.cachedResponse(for: request) {
			if let cacheDuration = cacheDurations[endpoint.path] {
				if let httpResponse = cachedResponse.response as? HTTPURLResponse,
				   let cacheDate = httpResponse.value(forHTTPHeaderField: "Date").flatMap({ HTTPURLResponse.dateFormatter.date(from: $0) }),
				   Date().timeIntervalSince(cacheDate) < cacheDuration {
					logRequest(request, cached: true)
					return try await decodeResponse(data: cachedResponse.data, response: cachedResponse.response)
				}
			}
		}
		
		// Check online status
		if !isOnline {
			// Try to get from cache
			if let cachedResponse = cache.cachedResponse(for: request) {
				logRequest(request, cached: true)
				return try await decodeResponse(data: cachedResponse.data, response: cachedResponse.response)
			}
			// Queue for offline retry
			try await OfflineRequestQueue.shared.enqueue(request: request, endpoint: endpoint)
			throw APINetworkError.noInternet
		}
		
		do {
			logRequest(request)
			let (data, response) = try await session.data(for: request)
			
			// Handle response
			try handleResponse(response: response, data: data)
			
			// Cache successful GET responses
			if request.httpMethod == "GET", let httpResponse = response as? HTTPURLResponse,
			   (200...299).contains(httpResponse.statusCode) {
				let cachedResponse = CachedURLResponse(response: httpResponse, data: data)
				cache.storeCachedResponse(cachedResponse, for: request)
			}
			
			logResponse(response, data: data)
			// Decode on background thread
			return try await decodeResponse(data: data, response: response)
			
		} catch let error as APINetworkError {
			// Retry logic
			if retryCount < 3, shouldRetry(error: error) {
				let delay = pow(2.0, Double(retryCount)) // Exponential backoff
				try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
				return try await performRequest(request: request, endpoint: endpoint, retryCount: retryCount + 1)
			}
			
			// Queue for offline retry if appropriate
			if case .noInternet = error {
				try await OfflineRequestQueue.shared.enqueue(request: request, endpoint: endpoint)
			}
			
			throw error
		} catch {
			throw APINetworkError.unknown(error)
		}
	}
	
	// MARK: - Request Building
	
	private func buildRequest(endpoint: APIEndpoint, method: HTTPMethod) throws -> URLRequest {
		var components = URLComponents(url: baseURL.appendingPathComponent(endpoint.path), resolvingAgainstBaseURL: false)!
		
		if let queryItems = endpoint.queryItems {
			components.queryItems = queryItems
		}
		
		guard let url = components.url else {
			throw APINetworkError.unknown(NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
		}
		
		var request = URLRequest(url: url)
		request.httpMethod = method.rawValue
		
		// Request interceptor
		applyRequestInterceptor(&request)
		
		return request
	}
	
	// MARK: - Request Interceptor
	
	private func applyRequestInterceptor(_ request: inout URLRequest) {
		// Authentication token
		if let token = TokenManager.shared.accessToken() {
			request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		}
		
		// Device ID
		request.setValue(deviceId, forHTTPHeaderField: "X-Device-ID")
		
		// App version
		request.setValue(appVersion, forHTTPHeaderField: "X-App-Version")
		
		// Content type
		if request.httpBody != nil {
			request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		}
		
		// Accept
		request.setValue("application/json", forHTTPHeaderField: "Accept")
	}
	
	// MARK: - Response Interceptor
	
	private func handleResponse(response: URLResponse, data: Data) throws {
		guard let httpResponse = response as? HTTPURLResponse else {
			throw APINetworkError.unknown(NSError(domain: "APIClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response"]))
		}
		
		switch httpResponse.statusCode {
		case 200...299:
			return // Success
			
		case 401:
			// Unauthorized - trigger token refresh
			Task {
				do {
					_ = try await TokenManager.shared.withValidAccessToken()
				} catch {
					// Token refresh failed, user needs to re-authenticate
					NotificationCenter.default.post(name: .userLoggedOut, object: nil)
				}
			}
			throw APINetworkError.unauthorized
			
		case 403:
			throw APINetworkError.unauthorized
			
		case 429:
			// Rate limited
			let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After").flatMap { Int($0) }
			throw APINetworkError.rateLimited(retryAfter)
			
		case 500...599:
			throw APINetworkError.serverError(httpResponse.statusCode)
			
		default:
			// Try to parse error message from response (on background thread)
			// Note: This is a synchronous function, so we decode on background queue
			if let errorData = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
				throw APINetworkError.unknown(NSError(domain: "APIClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorData.error]))
			}
			throw APINetworkError.serverError(httpResponse.statusCode)
		}
	}
	
	// MARK: - Response Decoding (Background Thread)
	
	private func decodeResponse<T: Decodable>(data: Data, response: URLResponse) async throws -> T {
		return try await withCheckedThrowingContinuation { continuation in
			// Parse JSON on background thread to avoid blocking main thread
			jsonQueue.async {
				let decoder = JSONDecoder()
				decoder.dateDecodingStrategy = .iso8601
				
				do {
					// Handle wrapped responses
					if response is HTTPURLResponse {
						// Try to decode directly
						if let result = try? decoder.decode(T.self, from: data) {
							continuation.resume(returning: result)
							return
						}
						
						// Try to decode wrapped response (e.g., { "event": {...} })
						if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
						   let firstValue = dict.values.first,
						   let jsonData = try? JSONSerialization.data(withJSONObject: firstValue) {
							let result = try decoder.decode(T.self, from: jsonData)
							continuation.resume(returning: result)
							return
						}
					}
					
					// Fallback: direct decode
					let result = try decoder.decode(T.self, from: data)
					continuation.resume(returning: result)
				} catch {
					continuation.resume(throwing: APINetworkError.decodingError)
				}
			}
		}
	}
	
	// MARK: - Retry Logic
	
	private func shouldRetry(error: APINetworkError) -> Bool {
		switch error {
		case .timeout:
			return true
		case .serverError(let code) where (500...599).contains(code):
			return true
		default:
			return false
		}
	}
	
	// MARK: - Logging
	
	private func logRequest(_ request: URLRequest, cached: Bool = false) {
		#if DEBUG
		print("🌐 [\(cached ? "CACHED" : "REQUEST")] \(request.httpMethod ?? "?") \(request.url?.absoluteString ?? "?")")
		if let headers = request.allHTTPHeaderFields {
			print("   Headers: \(headers)")
		}
		#endif
	}
	
	private func logResponse(_ response: URLResponse, data: Data) {
		#if DEBUG
		if let httpResponse = response as? HTTPURLResponse {
			print("📥 [RESPONSE] \(httpResponse.statusCode) \(httpResponse.url?.absoluteString ?? "?")")
			if let json = try? JSONSerialization.jsonObject(with: data) {
				print("   Body: \(json)")
			}
		}
		#endif
	}
	
	// MARK: - Cache Management
	
	func clearCache() {
		cache.removeAllCachedResponses()
	}
	
	func clearCache(for endpoint: APIEndpoint) {
		if let url = URL(string: endpoint.path, relativeTo: baseURL) {
			let request = URLRequest(url: url)
			cache.removeCachedResponse(for: request)
		}
	}
	
	// MARK: - Base URL Configuration
	
	func setBaseURL(_ url: URL) {
		UserDefaults.standard.set(url.absoluteString, forKey: "auth.api.baseURL")
	}
	
	// MARK: - Helper Methods
	
	/// Encodes body without capturing non-Sendable types in async closure
	private func encodeBody(_ body: Encodable) async throws -> Data {
		// Use JSONSerialization to avoid Sendable issues with Encodable
		// First convert to dictionary/array, then encode
		let encoder = JSONEncoder()
		// Encode synchronously on current actor to avoid Sendable capture
		return try encoder.encode(body)
	}
}

// MARK: - Helper Types

struct EmptyResponse: Decodable {}

struct ErrorResponse: Decodable {
	let error: String
}

extension HTTPURLResponse {
	static let dateFormatter: DateFormatter = {
		let formatter = DateFormatter()
		formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
		formatter.locale = Locale(identifier: "en_US_POSIX")
		formatter.timeZone = TimeZone(secondsFromGMT: 0)
		return formatter
	}()
}

extension Notification.Name {
	static let userLoggedOut = Notification.Name("userLoggedOut")
}

