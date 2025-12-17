//
//  AuthModels.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation

public struct User: Codable, Identifiable, Equatable {
	public let id: String
	public let email: String
	public let fullName: String?
	public let profileImageUrl: String?
	public let createdAt: Date
	public let emailVerified: Bool
	
	public init(
		id: String,
		email: String,
		fullName: String? = nil,
		profileImageUrl: String? = nil,
		createdAt: Date,
		emailVerified: Bool
	) {
		self.id = id
		self.email = email
		self.fullName = fullName
		self.profileImageUrl = profileImageUrl
		self.createdAt = createdAt
		self.emailVerified = emailVerified
	}
	
	private enum CodingKeys: String, CodingKey {
		case id
		case email
		case fullName
		case profileImageUrl
		case createdAt = "created_at"
		case emailVerified = "email_verified"
	}
}

public struct AuthCredentials {
	public let email: String
	public let password: String
	
	public init(email: String, password: String) {
		self.email = email
		self.password = password
	}
}

public struct AuthResponse: Codable {
	public let user: User
	public let accessToken: String
	public let refreshToken: String
	
	private enum CodingKeys: String, CodingKey {
		case user
		case accessToken = "token"
		case refreshToken
	}
}


