//
//  KeychainManager.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import Security
import LocalAuthentication

final class KeychainManager {
	static let shared = KeychainManager()
	private init() {}
	
	enum Key: String {
		case accessToken = "com.calendarnotes.accessToken"
		case refreshToken = "com.calendarnotes.refreshToken"
		case userId = "com.calendarnotes.userId"
		case biometricEnabled = "cn.auth.biometricEnabled" // preference flag, not secure item
	}
	
	func set(_ value: Data, for key: Key, requireBiometric: Bool = false) -> Bool {
		var query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: key.rawValue,
			kSecValueData as String: value,
			kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
		]
		if requireBiometric {
			let access = SecAccessControlCreateWithFlags(nil, kSecAttrAccessibleAfterFirstUnlock, [.biometryAny, .devicePasscode], nil)
			if let access {
				query[kSecAttrAccessControl as String] = access
			}
		}
		SecItemDelete(query as CFDictionary)
		let status = SecItemAdd(query as CFDictionary, nil)
		return status == errSecSuccess
	}
	
	func setString(_ value: String, for key: Key, requireBiometric: Bool = false) -> Bool {
		guard let data = value.data(using: .utf8) else { return false }
		return set(data, for: key, requireBiometric: requireBiometric)
	}
	
	func get(_ key: Key, context: LAContext? = nil) -> Data? {
		var query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: key.rawValue,
			kSecReturnData as String: true,
			kSecMatchLimit as String: kSecMatchLimitOne
		]
		if let context {
			query[kSecUseAuthenticationContext as String] = context
		}
		var item: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &item)
		guard status == errSecSuccess else { return nil }
		return item as? Data
	}
	
	func getString(_ key: Key, context: LAContext? = nil) -> String? {
		guard let data = get(key, context: context) else { return nil }
		return String(data: data, encoding: .utf8)
	}
	
	func remove(_ key: Key) {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: key.rawValue
		]
		SecItemDelete(query as CFDictionary)
	}
	
	func exists(_ key: Key) -> Bool {
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrService as String: key.rawValue,
			kSecReturnData as String: false,
			kSecMatchLimit as String: kSecMatchLimitOne
		]
		return SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
	}
}


