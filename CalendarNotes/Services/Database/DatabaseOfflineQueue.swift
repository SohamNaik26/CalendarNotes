//
//  DatabaseOfflineQueue.swift
//  CalendarNotes
//
//  Created on [Date]
//

import Foundation

/// Represents a queued database operation
struct QueuedDatabaseOperation: Codable {
    let id: UUID
    let type: OperationType
    let sql: String
    let parameters: [String: AnyCodable]
    let timestamp: Date
    let retryCount: Int
    
    enum OperationType: String, Codable {
        case insert
        case update
        case delete
        case transaction
        case query
    }
}

/// Wrapper for Any type to make it Codable
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "AnyCodable value cannot be decoded"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(
                value,
                EncodingError.Context(
                    codingPath: container.codingPath,
                    debugDescription: "AnyCodable value cannot be encoded"
                )
            )
        }
    }
}

/// Offline queue manager for failed database operations
class DatabaseOfflineQueue {
    static let shared = DatabaseOfflineQueue()
    
    private let queueFileURL: URL
    private var operations: [QueuedDatabaseOperation] = []
    private let maxRetries = 3
    private let queue = DispatchQueue(label: "DatabaseOfflineQueue", attributes: .concurrent)
    
    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        queueFileURL = documentsPath.appendingPathComponent("database_offline_queue.json")
        loadQueue()
    }
    
    // MARK: - Queue Management
    func enqueue(operation: QueuedDatabaseOperation) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.operations.append(operation)
            self.saveQueue()
        }
    }
    
    func dequeue() -> QueuedDatabaseOperation? {
        return queue.sync {
            return operations.first
        }
    }
    
    func remove(operationId: UUID) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.operations.removeAll { $0.id == operationId }
            self.saveQueue()
        }
    }
    
    func clear() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            self.operations.removeAll()
            self.saveQueue()
        }
    }
    
    func count() -> Int {
        return queue.sync {
            return operations.count
        }
    }
    
    func getAllOperations() -> [QueuedDatabaseOperation] {
        return queue.sync {
            return operations
        }
    }
    
    // MARK: - Persistence
    private func saveQueue() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(operations)
            try data.write(to: queueFileURL, options: .atomic)
        } catch {
            print("Failed to save database offline queue: \(error)")
        }
    }
    
    private func loadQueue() {
        guard FileManager.default.fileExists(atPath: queueFileURL.path) else {
            return
        }
        
        do {
            let data = try Data(contentsOf: queueFileURL)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            operations = try decoder.decode([QueuedDatabaseOperation].self, from: data)
        } catch {
            print("Failed to load database offline queue: \(error)")
            operations = []
        }
    }
    
    // MARK: - Retry Logic
    func incrementRetry(operationId: UUID) -> Bool {
        return queue.sync(flags: .barrier) {
            guard let index = operations.firstIndex(where: { $0.id == operationId }) else {
                return false
            }
            
            let operation = operations[index]
            if operation.retryCount >= maxRetries {
                operations.remove(at: index)
                saveQueue()
                return false
            }
            
            let updatedOperation = QueuedDatabaseOperation(
                id: operation.id,
                type: operation.type,
                sql: operation.sql,
                parameters: operation.parameters,
                timestamp: operation.timestamp,
                retryCount: operation.retryCount + 1
            )
            operations[index] = updatedOperation
            saveQueue()
            return true
        }
    }
}

