//
//  DatabaseConfig.swift
//  CalendarNotes
//
//  Created on [Date]
//

import Foundation
import Security

/// Configuration manager for database connection parameters
class DatabaseConfig {
    static let shared = DatabaseConfig()
    
    // MARK: - Configuration Keys
    private let keychainService = "com.calendarnotes.database"
    private let keychainHostKey = "db_host"
    private let keychainPortKey = "db_port"
    private let keychainDatabaseKey = "db_database"
    private let keychainUsernameKey = "db_username"
    private let keychainPasswordKey = "db_password"
    
    // MARK: - Default Values
    var host: String {
        get {
            if let value = getFromKeychain(key: keychainHostKey) {
                return value
            }
            // Try environment variable or config file
            if let envHost = ProcessInfo.processInfo.environment["POSTGRES_HOST"] {
                return envHost
            }
            // Default to localhost for local development
            return "localhost"
        }
        set {
            saveToKeychain(key: keychainHostKey, value: newValue)
        }
    }
    
    var port: Int {
        get {
            if let value = getFromKeychain(key: keychainPortKey), let intValue = Int(value) {
                return intValue
            }
            if let envPort = ProcessInfo.processInfo.environment["POSTGRES_PORT"],
               let intValue = Int(envPort) {
                return intValue
            }
            return 5432
        }
        set {
            saveToKeychain(key: keychainPortKey, value: String(newValue))
        }
    }
    
    var database: String {
        get {
            if let value = getFromKeychain(key: keychainDatabaseKey) {
                return value
            }
            if let envDb = ProcessInfo.processInfo.environment["POSTGRES_DB"] {
                return envDb
            }
            return "calendarnotes_db"
        }
        set {
            saveToKeychain(key: keychainDatabaseKey, value: newValue)
        }
    }
    
    var username: String {
        get {
            if let value = getFromKeychain(key: keychainUsernameKey) {
                return value
            }
            if let envUser = ProcessInfo.processInfo.environment["POSTGRES_USER"] {
                return envUser
            }
            return "calendarnotes_user"
        }
        set {
            saveToKeychain(key: keychainUsernameKey, value: newValue)
        }
    }
    
    var password: String {
        get {
            if let value = getFromKeychain(key: keychainPasswordKey) {
                return value
            }
            if let envPassword = ProcessInfo.processInfo.environment["POSTGRES_PASSWORD"] {
                return envPassword
            }
            return "secure_password_here"
        }
        set {
            saveToKeychain(key: keychainPasswordKey, value: newValue)
        }
    }
    
    var sslMode: String {
        get {
            // For local development, disable SSL; for production, use require
            #if DEBUG
            return "disable"
            #else
            return "require"
            #endif
        }
    }
    
    var connectionTimeout: TimeInterval {
        return 10.0 // 10 seconds
    }
    
    var maxConnectionAttempts: Int {
        return 3
    }
    
    var retryDelay: TimeInterval {
        return 2.0 // 2 seconds base delay
    }
    
    // MARK: - Connection String
    var connectionString: String {
        var components: [String] = []
        components.append("host=\(host)")
        components.append("port=\(port)")
        components.append("dbname=\(database)")
        components.append("user=\(username)")
        components.append("password=\(password)")
        components.append("sslmode=\(sslMode)")
        components.append("connect_timeout=\(Int(connectionTimeout))")
        return components.joined(separator: " ")
    }
    
    // MARK: - Keychain Management
    private func saveToKeychain(key: String, value: String) {
        let data = value.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func getFromKeychain(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return value
    }
    
    // MARK: - Configuration Methods
    func configure(
        host: String? = nil,
        port: Int? = nil,
        database: String? = nil,
        username: String? = nil,
        password: String? = nil
    ) {
        if let host = host {
            self.host = host
        }
        if let port = port {
            self.port = port
        }
        if let database = database {
            self.database = database
        }
        if let username = username {
            self.username = username
        }
        if let password = password {
            self.password = password
        }
    }
    
    func clearKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService
        ]
        SecItemDelete(query as CFDictionary)
    }
}

