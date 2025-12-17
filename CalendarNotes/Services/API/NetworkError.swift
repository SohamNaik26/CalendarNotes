//
//  NetworkError.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation

enum APINetworkError: LocalizedError, Equatable {
	case noInternet
	case timeout
	case unauthorized
	case serverError(Int)
	case decodingError
	case unknown(Error)
	case rateLimited(Int?) // Retry after seconds
	
	var errorDescription: String? {
		switch self {
		case .noInternet:
			return "No internet connection available"
		case .timeout:
			return "Request timed out"
		case .unauthorized:
			return "Authentication required"
		case .serverError(let code):
			return "Server error: \(code)"
		case .decodingError:
			return "Failed to decode response"
		case .unknown(let error):
			return error.localizedDescription
		case .rateLimited(let retryAfter):
			if let retryAfter = retryAfter {
				return "Rate limit exceeded. Retry after \(retryAfter) seconds"
			}
			return "Rate limit exceeded"
		}
	}
	
	static func == (lhs: Self, rhs: Self) -> Bool {
		switch (lhs, rhs) {
		case (.noInternet, .noInternet),
			 (.timeout, .timeout),
			 (.unauthorized, .unauthorized),
			 (.decodingError, .decodingError):
			return true
		case (.serverError(let lhsCode), .serverError(let rhsCode)):
			return lhsCode == rhsCode
		case (.rateLimited(let lhsRetry), .rateLimited(let rhsRetry)):
			return lhsRetry == rhsRetry
		case (.unknown(let lhsError), .unknown(let rhsError)):
			return lhsError.localizedDescription == rhsError.localizedDescription
		default:
			return false
		}
	}
}

