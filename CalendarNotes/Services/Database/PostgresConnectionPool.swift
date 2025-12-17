//
//  PostgresConnectionPool.swift
//  CalendarNotes
//
//  Connection pool for PostgreSQL connections with reuse, timeout handling, and error recovery
//

import Foundation
import PostgresNIO
import NIOSSL
import Logging

// MARK: - Connection Pool

class PostgresConnectionPool {
    static let shared = PostgresConnectionPool()
    
    // Pool configuration
    private let maxPoolSize: Int = 10
    private let minPoolSize: Int = 2
    private let connectionTimeout: TimeInterval = 5.0
    private let maxIdleTime: TimeInterval = 300.0 // 5 minutes
    
    // Pool state
    private var availableConnections: [PooledConnection] = []
    private var activeConnections: [UUID: PooledConnection] = [:]
    private var connectionQueue: [CheckedContinuation<PooledConnection, Error>] = []
    
    // Thread safety
    private let poolQueue = DispatchQueue(label: "com.calendarnotes.postgres.pool", attributes: .concurrent)
    
    // Configuration
    private let config: DatabaseConfig
    private let logger = Logger(label: "com.calendarnotes.postgres.pool")
    
    // Statistics
    private var totalConnectionsCreated: Int = 0
    private var totalConnectionsReused: Int = 0
    private var totalConnectionErrors: Int = 0
    
    private init() {
        self.config = DatabaseConfig.shared
        startConnectionCleanup()
    }
    
    // MARK: - Connection Acquisition
    
    /// Gets a connection from the pool, creating a new one if needed
    func getConnection() async throws -> PooledConnection {
        return try await withCheckedThrowingContinuation { continuation in
            poolQueue.async(flags: .barrier) { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: DatabaseError.connectionFailed("Pool deallocated"))
                    return
                }
                
                // Check for available connection
                if let connection = self.availableConnections.popFirst() {
                    // Verify connection is still valid
                    Task { [weak self] in
                        guard let self = self else { return }
                        do {
                            try await self.verifyConnection(connection)
                            self.poolQueue.async(flags: .barrier) {
                                self.activeConnections[connection.id] = connection
                                self.totalConnectionsReused += 1
                                continuation.resume(returning: connection)
                            }
                        } catch {
                            // Connection is invalid, create new one
                            self.poolQueue.async(flags: .barrier) {
                                self.totalConnectionErrors += 1
                            }
                            try? await connection.connection.close()
                            try await self.createAndReturnConnection(continuation: continuation)
                        }
                    }
                } else {
                    // No available connection, check if we can create more
                    if self.activeConnections.count + self.availableConnections.count < self.maxPoolSize {
                        Task { [weak self] in
                            guard let self = self else { return }
                            try await self.createAndReturnConnection(continuation: continuation)
                        }
                    } else {
                        // Pool is full, queue the request
                        self.connectionQueue.append(continuation)
                    }
                }
            }
        }
    }
    
    /// Returns a connection to the pool
    func returnConnection(_ connection: PooledConnection) {
        poolQueue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.activeConnections.removeValue(forKey: connection.id)
            
            // Check if connection is still valid
            Task { [weak self] in
                guard let self = self else { return }
                do {
                    try await self.verifyConnection(connection)
                    self.poolQueue.async(flags: .barrier) {
                        connection.lastUsed = Date()
                        self.availableConnections.append(connection)
                        
                        // Process queued requests
                        if let queued = self.connectionQueue.popFirst() {
                            queued.resume(returning: connection)
                        }
                    }
                } catch {
                    // Connection is invalid, don't return to pool
                    self.poolQueue.async(flags: .barrier) {
                        self.totalConnectionErrors += 1
                    }
                    try? await connection.connection.close()
                }
            }
        }
    }
    
    // MARK: - Connection Creation
    
    private func createAndReturnConnection(continuation: CheckedContinuation<PooledConnection, Error>) async throws {
        do {
            let connection = try await createConnection()
            let pooled = PooledConnection(id: UUID(), connection: connection, createdAt: Date(), lastUsed: Date())
            
            poolQueue.async(flags: .barrier) {
                self.activeConnections[pooled.id] = pooled
                self.totalConnectionsCreated += 1
                continuation.resume(returning: pooled)
            }
        } catch {
            poolQueue.async(flags: .barrier) {
                self.totalConnectionErrors += 1
                continuation.resume(throwing: error)
            }
        }
    }
    
    private func createConnection() async throws -> PostgresConnection {
        let tls: PostgresConnection.Configuration.TLS
        if config.sslMode == "require" {
            let tlsConfig = NIOSSL.TLSConfiguration.makeClientConfiguration()
            let sslContext = try NIOSSLContext(configuration: tlsConfig)
            tls = PostgresConnection.Configuration.TLS.require(sslContext)
        } else {
            tls = PostgresConnection.Configuration.TLS.disable
        }
        
        let configuration = PostgresConnection.Configuration(
            host: config.host,
            port: config.port,
            username: config.username,
            password: config.password,
            database: config.database,
            tls: tls
        )
        
        let logger = self.logger
        return try await withTimeout(seconds: connectionTimeout) {
            try await PostgresConnection.connect(
                configuration: configuration,
                id: UUID().hashValue,
                logger: logger
            )
        }
    }
    
    private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw DatabaseError.connectionTimeout
            }
            
            guard let result = try await group.next() else {
                throw DatabaseError.connectionTimeout
            }
            
            group.cancelAll()
            return result
        }
    }
    
    // MARK: - Connection Verification
    
    private func verifyConnection(_ pooled: PooledConnection) async throws {
        // Simple health check
        let logger = self.logger
        _ = try await pooled.connection.query("SELECT 1", logger: logger)
    }
    
    // MARK: - Connection Cleanup
    
    private func startConnectionCleanup() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task {
                await self?.cleanupIdleConnections()
            }
        }
    }
    
    private func cleanupIdleConnections() async {
        poolQueue.async(flags: .barrier) {
            let now = Date()
            var toRemove: [Int] = []
            
            for (index, connection) in self.availableConnections.enumerated() {
                let lastUsed = connection.lastUsed
                if now.timeIntervalSince(lastUsed) > self.maxIdleTime {
                    toRemove.append(index)
                }
            }
            
            // Remove from end to preserve indices
            for index in toRemove.reversed() {
                let connection = self.availableConnections.remove(at: index)
                Task {
                    try? await connection.connection.close()
                }
            }
            
            // Ensure minimum pool size
            while self.availableConnections.count + self.activeConnections.count < self.minPoolSize {
                Task { [weak self] in
                    guard let self = self else { return }
                    do {
                        let connection = try await self.createConnection()
                        // Create PooledConnection - init is nonisolated, but connection might not be Sendable
                        // Create values first, then pass to nonisolated context
                        let id = UUID()
                        let createdAt = Date()
                        let lastUsed = Date()
                        // Use nonisolated(unsafe) pattern to create PooledConnection
                        // since PostgresConnection might not be Sendable
                        let pooled = await withCheckedContinuation { continuation in
                            self.poolQueue.async {
                                // Create in queue context which is nonisolated
                                let pooled = PooledConnection(id: id, connection: connection, createdAt: createdAt, lastUsed: lastUsed)
                                continuation.resume(returning: pooled)
                            }
                        }
                        self.poolQueue.async(flags: .barrier) {
                            self.availableConnections.append(pooled)
                        }
                    } catch {
                        let logger = self.logger
                        logger.error("Failed to create connection for pool: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // MARK: - Statistics
    
    func getPoolStats() -> ConnectionPoolStats {
        return poolQueue.sync {
            ConnectionPoolStats(
                totalCreated: totalConnectionsCreated,
                totalReused: totalConnectionsReused,
                totalErrors: totalConnectionErrors,
                available: availableConnections.count,
                active: activeConnections.count,
                queued: connectionQueue.count
            )
        }
    }
    
    // MARK: - Cleanup
    
    func closeAll() async {
        poolQueue.async(flags: .barrier) {
            for connection in self.availableConnections {
                Task {
                    try? await connection.connection.close()
                }
            }
            for connection in self.activeConnections.values {
                Task {
                    try? await connection.connection.close()
                }
            }
            self.availableConnections.removeAll()
            self.activeConnections.removeAll()
        }
    }
}

// MARK: - Pooled Connection

final class PooledConnection: @unchecked Sendable {
    let id: UUID
    let connection: PostgresConnection
    let createdAt: Date
    private let lastUsedQueue = DispatchQueue(label: "com.calendarnotes.pooledconnection.lastused")
    private var _lastUsed: Date
    
    var lastUsed: Date {
        get {
            lastUsedQueue.sync { _lastUsed }
        }
        set {
            lastUsedQueue.async(flags: .barrier) { [weak self] in
                self?._lastUsed = newValue
            }
        }
    }
    
    nonisolated init(id: UUID, connection: PostgresConnection, createdAt: Date, lastUsed: Date) {
        self.id = id
        self.connection = connection
        self.createdAt = createdAt
        self._lastUsed = lastUsed
    }
}

// MARK: - Connection Pool Statistics

struct ConnectionPoolStats {
    let totalCreated: Int
    let totalReused: Int
    let totalErrors: Int
    let available: Int
    let active: Int
    let queued: Int
    
    var reuseRate: Double {
        let total = totalCreated + totalReused
        return total > 0 ? Double(totalReused) / Double(total) : 0.0
    }
}

// MARK: - Array Extension for Queue Operations

private extension Array {
    mutating func popFirst() -> Element? {
        guard !isEmpty else { return nil }
        return removeFirst()
    }
}

