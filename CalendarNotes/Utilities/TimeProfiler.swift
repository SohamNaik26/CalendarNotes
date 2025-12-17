//
//  TimeProfiler.swift
//  CalendarNotes
//
//  Created for performance monitoring
//

import Foundation
import os.log

/// Utility for measuring function execution time and logging slow operations
@MainActor
class TimeProfiler {
    static let shared = TimeProfiler()
    
    private var measurements: [String: [TimeInterval]] = [:]
    private let logger = Logger(subsystem: "com.calendarnotes.performance", category: "TimeProfiler")
    private let slowOperationThreshold: TimeInterval = 0.1 // 100ms
    
    private init() {}
    
    /// Measure execution time of a block
    func measure<T>(_ operation: String, _ block: () throws -> T) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            recordMeasurement(operation, duration: duration)
            
            if duration > slowOperationThreshold {
                logger.warning("⚠️ Slow operation detected: \(operation) took \(String(format: "%.3f", duration))s")
            }
        }
        return try block()
    }
    
    /// Measure execution time of an async block
    func measureAsync<T>(_ operation: String, _ block: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        defer {
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            recordMeasurement(operation, duration: duration)
            
            if duration > slowOperationThreshold {
                logger.warning("⚠️ Slow async operation detected: \(operation) took \(String(format: "%.3f", duration))s")
            }
        }
        return try await block()
    }
    
    private func recordMeasurement(_ operation: String, duration: TimeInterval) {
        if measurements[operation] == nil {
            measurements[operation] = []
        }
        measurements[operation]?.append(duration)
        
        // Keep only last 100 measurements per operation
        if let count = measurements[operation]?.count, count > 100 {
            measurements[operation]?.removeFirst()
        }
    }
    
    /// Get statistics for an operation
    func getStats(for operation: String) -> OperationStats? {
        guard let durations = measurements[operation], !durations.isEmpty else {
            return nil
        }
        
        let sorted = durations.sorted()
        let average = durations.reduce(0, +) / Double(durations.count)
        let min = sorted.first!
        let max = sorted.last!
        let median = sorted[sorted.count / 2]
        let p95 = sorted[Int(Double(sorted.count) * 0.95)]
        let p99 = sorted[Int(Double(sorted.count) * 0.99)]
        
        return OperationStats(
            operation: operation,
            count: durations.count,
            average: average,
            min: min,
            max: max,
            median: median,
            p95: p95,
            p99: p99
        )
    }
    
    /// Get all operation statistics
    func getAllStats() -> [OperationStats] {
        measurements.keys.compactMap { getStats(for: $0) }
    }
    
    /// Clear all measurements
    func clear() {
        measurements.removeAll()
    }
    
    /// Log a slow operation (>100ms)
    func logSlowOperation(_ operation: String, duration: TimeInterval) {
        if duration > slowOperationThreshold {
            logger.warning("🐌 Slow operation: \(operation) - \(String(format: "%.3f", duration))s")
            PerformanceMonitor.shared.recordQueryTime(query: operation, duration: duration)
        }
    }
}

struct OperationStats {
    let operation: String
    let count: Int
    let average: TimeInterval
    let min: TimeInterval
    let max: TimeInterval
    let median: TimeInterval
    let p95: TimeInterval
    let p99: TimeInterval
    
    var averageMS: Double { average * 1000 }
    var minMS: Double { min * 1000 }
    var maxMS: Double { max * 1000 }
}

/// Property wrapper to automatically profile function execution
@propertyWrapper
struct Profiled<T> {
    private var value: T
    private let operationName: String
    
    init(wrappedValue: T, operation: String) {
        self.value = wrappedValue
        self.operationName = operation
    }
    
    var wrappedValue: T {
        get {
            let startTime = CFAbsoluteTimeGetCurrent()
            defer {
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                TimeProfiler.shared.logSlowOperation(operationName, duration: duration)
            }
            return value
        }
        set {
            value = newValue
        }
    }
}

/// Function decorator for profiling
func profile<T>(_ operation: String, _ block: () throws -> T) rethrows -> T {
    return try TimeProfiler.shared.measure(operation, block)
}

func profileAsync<T>(_ operation: String, _ block: () async throws -> T) async rethrows -> T {
    return try await TimeProfiler.shared.measureAsync(operation, block)
}

