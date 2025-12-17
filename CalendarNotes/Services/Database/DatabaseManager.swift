//
//  DatabaseManager.swift
//  CalendarNotes
//
//  Created on [Date]
//

import Foundation
import PostgresNIO
import NIOSSL
import Logging
import Combine

/// Singleton database manager for PostgreSQL connections
class DatabaseManager {
    static let shared = DatabaseManager()
    
    // MARK: - Properties
    private var connection: PostgresConnection?
    private let config = DatabaseConfig.shared
    private let networkMonitor = NetworkReachability.shared
    private let offlineQueue = DatabaseOfflineQueue.shared
    private let connectionQueue = DispatchQueue(label: "DatabaseConnectionQueue")
    private var isConnecting = false
    private var connectionAttempts = 0
    
    private let _connectionStatus = CurrentValueSubject<ConnectionStatus, Never>(.disconnected)
    var connectionStatus: ConnectionStatus {
        _connectionStatus.value
    }
    
    enum ConnectionStatus {
        case connected
        case connecting
        case disconnected
        case error(String)
    }
    
    private init() {
        // Start monitoring connection status
        startHealthCheck()
        _connectionStatus.send(.disconnected)
    }
    
    // MARK: - Connection Management
    func connect() async throws {
        // Check network availability
        guard networkMonitor.checkReachability() else {
            throw DatabaseError.networkUnavailable
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            connectionQueue.async { [weak self] in
                guard let self = self, !self.isConnecting else {
                    continuation.resume()
                    return
                }
                
                self.isConnecting = true
                self._connectionStatus.send(.connecting)
                
                Task {
                    do {
                        let connection = try await self.createConnection()
                        await MainActor.run {
                            self.connection = connection
                            self._connectionStatus.send(.connected)
                            self.connectionAttempts = 0
                            self.isConnecting = false
                            continuation.resume()
                        }
                    } catch {
                        await MainActor.run {
                            self._connectionStatus.send(.error(error.localizedDescription))
                            self.isConnecting = false
                            self.connectionAttempts += 1
                            continuation.resume(throwing: error)
                        }
                    }
                }
            }
        }
    }
    
    private func createConnection() async throws -> PostgresConnection {
        // Use the new non-deprecated API: init(host:port:username:password:database:tls:)
        let tls: PostgresConnection.Configuration.TLS
        if config.sslMode == "require" {
            // TLS.require takes an NIOSSLContext
            let tlsConfig = NIOSSL.TLSConfiguration.makeClientConfiguration()
            let sslContext = try NIOSSLContext(configuration: tlsConfig)
            tls = PostgresConnection.Configuration.TLS.require(sslContext)
        } else {
            tls = PostgresConnection.Configuration.TLS.disable
        }
        
        // Create main configuration using the new API
        let configuration = PostgresConnection.Configuration(
            host: config.host,
            port: config.port,
            username: config.username,
            password: config.password,
            database: config.database,
            tls: tls
        )
        
        let logger = Logger(label: "com.calendarnotes.database")
        let dbConnection = try await PostgresConnection.connect(
            configuration: configuration,
            id: 1,
            logger: logger
        )
        
        return dbConnection
    }
    
    func disconnect() async {
        try? await connection?.close()
        connection = nil
        _connectionStatus.send(.disconnected)
    }
    
    // MARK: - Connection Retry with Exponential Backoff
    func connectWithRetry() async throws {
        let maxAttempts = config.maxConnectionAttempts
        var delay = config.retryDelay
        
        for attempt in 1...maxAttempts {
            do {
                try await connect()
                return
            } catch {
                if attempt == maxAttempts {
                    throw DatabaseError.connectionFailed("Failed after \(maxAttempts) attempts: \(error.localizedDescription)")
                }
                
                // Exponential backoff
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay *= 2
            }
        }
    }
    
    // MARK: - Health Check
    private func startHealthCheck() {
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task {
                await self?.performHealthCheck()
            }
        }
    }
    
    func performHealthCheck() async {
        guard let connection = connection else {
            _connectionStatus.send(.disconnected)
            return
        }
        
        let logger = Logger(label: "com.calendarnotes.database")
        do {
            _ = try await connection.query("SELECT 1", logger: logger)
            await MainActor.run {
                _connectionStatus.send(.connected)
            }
        } catch {
            await MainActor.run {
                _connectionStatus.send(.error(error.localizedDescription))
            }
            // Attempt to reconnect
            try? await connectWithRetry()
        }
    }
    
    // MARK: - Query Execution
    func executeQuery(sql: String, parameters: [PostgresData] = []) async throws -> PostgresRowSequence {
        // Use connection pool if available, otherwise fall back to single connection
        let pooledConnection = try await PostgresConnectionPool.shared.getConnection()
        defer {
            Task {
                PostgresConnectionPool.shared.returnConnection(pooledConnection)
            }
        }
        
        let logger = Logger(label: "com.calendarnotes.database")
        
        // Measure query performance
        return try await DatabaseOptimizer.shared.measureQueryAsync(
            name: sql.prefix(100).description,
            threshold: 0.5,
            alertThreshold: 2.0
        ) {
            do {
                // Create bindings from array
                var bindings = PostgresBindings()
                for param in parameters {
                    bindings.append(param)
                }
                let query = PostgresQuery(unsafeSQL: sql, binds: bindings)
                let result = try await pooledConnection.connection.query(query, logger: logger)
                return result
            } catch {
                // If query fails and network is unavailable, queue it
                if !networkMonitor.checkReachability() {
                    queueOperation(sql: sql, parameters: parameters, type: .query)
                }
                throw DatabaseError.queryExecutionFailed(error.localizedDescription)
            }
        }
    }
    
    func executeUpdate(sql: String, parameters: [PostgresData] = []) async throws -> Bool {
        // Use connection pool
        let pooledConnection = try await PostgresConnectionPool.shared.getConnection()
        defer {
            Task {
                PostgresConnectionPool.shared.returnConnection(pooledConnection)
            }
        }
        
        let logger = Logger(label: "com.calendarnotes.database")
        
        return try await DatabaseOptimizer.shared.measureQueryAsync(
            name: sql.prefix(100).description,
            threshold: 0.5,
            alertThreshold: 2.0
        ) {
            do {
                // Create bindings from array
                var bindings = PostgresBindings()
                for param in parameters {
                    bindings.append(param)
                }
                let query = PostgresQuery(unsafeSQL: sql, binds: bindings)
                _ = try await pooledConnection.connection.query(query, logger: logger)
                return true
            } catch {
                if !networkMonitor.checkReachability() {
                    queueOperation(sql: sql, parameters: parameters, type: .update)
                }
                throw DatabaseError.queryExecutionFailed(error.localizedDescription)
            }
        }
    }
    
    // MARK: - Transaction Support
    func executeTransaction(queries: [(sql: String, parameters: [PostgresData])]) async throws -> Bool {
        var connection = self.connection
        if connection == nil {
            if !networkMonitor.checkReachability() {
                for query in queries {
                    queueOperation(sql: query.sql, parameters: query.parameters, type: .transaction)
                }
                throw DatabaseError.networkUnavailable
            }
            try await connectWithRetry()
            if let newConnection = self.connection {
                connection = newConnection
            } else {
                throw DatabaseError.connectionFailed("Unable to establish connection")
            }
        }
        
        // At this point, connection is guaranteed to be non-nil
        guard let conn = connection else {
            throw DatabaseError.connectionFailed("Connection is nil")
        }
        
        let logger = Logger(label: "com.calendarnotes.database")
        do {
            // Begin transaction
            let beginQuery = PostgresQuery(unsafeSQL: "BEGIN")
            _ = try await conn.query(beginQuery, logger: logger)
            
            // Execute all queries
            for query in queries {
                var bindings = PostgresBindings()
                for param in query.parameters {
                    bindings.append(param)
                }
                let postgresQuery = PostgresQuery(unsafeSQL: query.sql, binds: bindings)
                _ = try await conn.query(postgresQuery, logger: logger)
            }
            
            // Commit transaction
            let commitQuery = PostgresQuery(unsafeSQL: "COMMIT")
            _ = try await conn.query(commitQuery, logger: logger)
            return true
        } catch {
            // Rollback on error
            let rollbackQuery = PostgresQuery(unsafeSQL: "ROLLBACK")
            _ = try? await conn.query(rollbackQuery, logger: logger)
            throw DatabaseError.transactionFailed(error.localizedDescription)
        }
    }
    
    // MARK: - Prepared Statements
    // Note: Prepared statements are not currently used in the repositories
    // This method is commented out because prepareStatement is internal in PostgresNIO
    // If needed in the future, use direct queries or check PostgresNIO documentation for public API
    /*
    func prepareStatement(sql: String) async throws -> Any {
        guard let connection = connection else {
            try await connectWithRetry()
            guard let connection = connection else {
                throw DatabaseError.connectionFailed("Unable to establish connection")
            }
        }
        
        let logger = Logger(label: "com.calendarnotes.database")
        let query = PostgresQuery(unsafeSQL: sql)
        let preparedStatement = try await connection.prepareStatement(query, with: .init(), logger: logger)
        return preparedStatement
    }
    */
    
    // MARK: - Offline Queue Management
    private func queueOperation(sql: String, parameters: [PostgresData], type: QueuedDatabaseOperation.OperationType) {
        // Convert PostgresData to dictionary for storage
        var paramsDict: [String: AnyCodable] = [:]
        for (index, param) in parameters.enumerated() {
            // Convert PostgresData to Any for storage
            if let string = param.string {
                paramsDict["param_\(index)"] = AnyCodable(string)
            } else if let int = param.int {
                paramsDict["param_\(index)"] = AnyCodable(int)
            } else if let double = param.double {
                paramsDict["param_\(index)"] = AnyCodable(double)
            } else if let bool = param.bool {
                paramsDict["param_\(index)"] = AnyCodable(bool)
            } else if let uuid = param.uuid {
                paramsDict["param_\(index)"] = AnyCodable(uuid.uuidString)
            }
        }
        
        let operation = QueuedDatabaseOperation(
            id: UUID(),
            type: type,
            sql: sql,
            parameters: paramsDict,
            timestamp: Date(),
            retryCount: 0
        )
        
        offlineQueue.enqueue(operation: operation)
    }
    
    func processOfflineQueue() async {
        guard networkMonitor.checkReachability() else {
            return
        }
        
        guard connection != nil else {
            try? await connectWithRetry()
            return
        }
        
        let operations = offlineQueue.getAllOperations()
        
        for operation in operations {
            do {
                // Convert parameters back to PostgresData
                var parameters: [PostgresData] = []
                let sortedParams = operation.parameters.sorted { $0.key < $1.key }
                for (_, codable) in sortedParams {
                    if let string = codable.value as? String {
                        parameters.append(PostgresData(string: string))
                    } else if let int = codable.value as? Int {
                        parameters.append(PostgresData(int: int))
                    } else if let double = codable.value as? Double {
                        parameters.append(PostgresData(double: double))
                    } else if let bool = codable.value as? Bool {
                        parameters.append(PostgresData(bool: bool))
                    } else if let uuidString = codable.value as? String, let uuid = UUID(uuidString: uuidString) {
                        parameters.append(PostgresData(uuid: uuid))
                    }
                }
                
                _ = try await executeUpdate(sql: operation.sql, parameters: parameters)
                offlineQueue.remove(operationId: operation.id)
            } catch {
                if !offlineQueue.incrementRetry(operationId: operation.id) {
                    // Max retries reached, remove from queue
                    offlineQueue.remove(operationId: operation.id)
                }
            }
        }
    }
    
    // MARK: - Connection Timeout Handling
    func executeWithTimeout<T>(
        timeout: TimeInterval = 10.0,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw DatabaseError.connectionTimeout
            }
            
            guard let result = try await group.next() else {
                throw DatabaseError.connectionTimeout
            }
            
            group.cancelAll()
            return result
        }
    }
}

// MARK: - Published Property Wrapper
extension DatabaseManager {
    var connectionStatusPublisher: AnyPublisher<ConnectionStatus, Never> {
        _connectionStatus.eraseToAnyPublisher()
    }
}

// MARK: - PostgresData Helper
extension PostgresData {
    // Helper to create PostgresData from common Swift types
    static func from(_ value: Any) -> PostgresData? {
        switch value {
        case let string as String:
            return PostgresData(string: string)
        case let int as Int:
            return PostgresData(int: int)
        case let int64 as Int64:
            return PostgresData(int: Int(int64))
        case let double as Double:
            return PostgresData(double: double)
        case let bool as Bool:
            return PostgresData(bool: bool)
        case let date as Date:
            return PostgresData(date: date)
        case let uuid as UUID:
            return PostgresData(uuid: uuid)
        default:
            return nil
        }
    }
}

