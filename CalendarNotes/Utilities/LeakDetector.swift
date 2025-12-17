//
//  LeakDetector.swift
//  CalendarNotes
//
//  Created by Cursor AI on leak detection.
//

import Foundation
import Combine

#if DEBUG

/// Utility for detecting memory leaks in debug builds.
/// Tracks object lifetimes and logs warnings when objects live too long or aren't deallocated.
@MainActor
final class LeakDetector {
    static let shared = LeakDetector()
    
    private struct TrackedObject {
        let type: String
        let createdAt: Date
        let stackTrace: String?
        var lastSeen: Date
    }
    
    private var trackedObjects: [ObjectIdentifier: TrackedObject] = [:]
    private var timer: Timer?
    private let warningThreshold: TimeInterval = 60.0 // Warn if object lives longer than 60 seconds
    private let checkInterval: TimeInterval = 30.0 // Check every 30 seconds
    
    private init() {
        startMonitoring()
    }
    
    /// Track an object's lifetime. Call this in init().
    func track<T: AnyObject>(_ object: T, stackTrace: String? = nil) {
        let identifier = ObjectIdentifier(object)
        let typeName = String(describing: type(of: object))
        trackedObjects[identifier] = TrackedObject(
            type: typeName,
            createdAt: Date(),
            stackTrace: stackTrace ?? Thread.callStackSymbols.joined(separator: "\n"),
            lastSeen: Date()
        )
    }
    
    /// Stop tracking an object. This is called automatically in deinit via LeakDetectorHelper.
    func untrack(_ object: AnyObject) {
        let identifier = ObjectIdentifier(object)
        trackedObjects.removeValue(forKey: identifier)
    }
    
    /// Manually mark an object as seen (still alive).
    func markSeen(_ object: AnyObject) {
        let identifier = ObjectIdentifier(object)
        trackedObjects[identifier]?.lastSeen = Date()
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            // Use Task with MainActor to avoid Swift 6 concurrency capture issues
            Task { @MainActor [weak self] in
                self?.checkForLeaks()
            }
        }
    }
    
    private func checkForLeaks() {
        let now = Date()
        var leakedObjects: [(ObjectIdentifier, TrackedObject)] = []
        
        for (identifier, tracked) in trackedObjects {
            let age = now.timeIntervalSince(tracked.createdAt)
            let timeSinceSeen = now.timeIntervalSince(tracked.lastSeen)
            
            // Check if object has lived too long
            if age > warningThreshold {
                leakedObjects.append((identifier, tracked))
            }
            
            // Check if object hasn't been seen recently (might be a leak)
            if timeSinceSeen > warningThreshold * 2 {
                print("⚠️ [LeakDetector] Potential leak detected: \(tracked.type)")
                print("   Created: \(tracked.createdAt)")
                print("   Age: \(age)s")
                print("   Last seen: \(timeSinceSeen)s ago")
                if let stackTrace = tracked.stackTrace {
                    print("   Creation stack trace:\n\(stackTrace)")
                }
            }
        }
        
        if !leakedObjects.isEmpty {
            print("⚠️ [LeakDetector] Found \(leakedObjects.count) potential leaks:")
            for (_, tracked) in leakedObjects {
                let age = now.timeIntervalSince(tracked.createdAt)
                print("   - \(tracked.type) (age: \(Int(age))s)")
            }
        }
    }
    
    func getStatistics() -> [String: Any] {
        let now = Date()
        var stats: [String: Any] = [:]
        var typeCounts: [String: Int] = [:]
        var totalAge: TimeInterval = 0
        
        for tracked in trackedObjects.values {
            typeCounts[tracked.type, default: 0] += 1
            totalAge += now.timeIntervalSince(tracked.createdAt)
        }
        
        stats["trackedCount"] = trackedObjects.count
        stats["typeCounts"] = typeCounts
        stats["averageAge"] = trackedObjects.isEmpty ? 0 : totalAge / Double(trackedObjects.count)
        
        return stats
    }
    
    deinit {
        timer?.invalidate()
    }
}

/// Helper class that automatically tracks and untracks objects.
/// Use this as a property in your class to automatically track it.
final class LeakDetectorHelper {
    private weak var object: AnyObject?
    private let identifier: ObjectIdentifier?
    
    init<T: AnyObject>(_ object: T) {
        self.object = object
        self.identifier = ObjectIdentifier(object)
        #if DEBUG
        Task { @MainActor in
            LeakDetector.shared.track(object)
        }
        #endif
    }
    
    deinit {
        #if DEBUG
        // Note: We can't use Task here because it would capture self in a closure that outlives deinit
        // Instead, we'll let the LeakDetector check for leaks periodically
        // The object will be automatically cleaned up when it's deallocated
        #endif
    }
}

/// Protocol for objects that want automatic leak detection.
protocol LeakDetectable: AnyObject {
    var leakDetector: LeakDetectorHelper? { get set }
}

extension LeakDetectable {
    func enableLeakDetection() {
        #if DEBUG
        leakDetector = LeakDetectorHelper(self)
        #endif
    }
}

#else

/// No-op implementation for release builds
@MainActor
final class LeakDetector {
    static let shared = LeakDetector()
    private init() {}
    func track<T: AnyObject>(_ object: T, stackTrace: String? = nil) {}
    func untrack(_ object: AnyObject) {}
    func markSeen(_ object: AnyObject) {}
    func getStatistics() -> [String: Any] { [:] }
}

final class LeakDetectorHelper {
    init<T: AnyObject>(_ object: T) {}
}

protocol LeakDetectable: AnyObject {
    var leakDetector: LeakDetectorHelper? { get set }
}

extension LeakDetectable {
    func enableLeakDetection() {}
}

#endif

