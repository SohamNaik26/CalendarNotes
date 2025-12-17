//
//  TemporaryCache.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 08/11/25.
//

import Foundation

/// A lightweight in-memory cache that automatically expires entries after a configurable TTL.
///
/// The implementation is thread-safe and optimized for short-lived data sets such as search results.
final class TemporaryCache<Key: Hashable, Value> {
    
    private struct Entry {
        let value: Value
        let expiry: Date
        
        var isExpired: Bool {
            expiry < Date()
        }
    }
    
    private let ttl: TimeInterval
    private let queue = DispatchQueue(label: "com.calendarnotes.utilities.temporarycache", attributes: .concurrent)
    private var storage: [Key: Entry] = [:]
    
    init(ttl: TimeInterval) {
        self.ttl = ttl
    }
    
    func value(for key: Key) -> Value? {
        queue.sync {
            guard let entry = storage[key] else {
                return nil
            }
            if entry.isExpired {
                queue.async(flags: .barrier) {
                    self.storage.removeValue(forKey: key)
                }
                return nil
            }
            return entry.value
        }
    }
    
    func insert(_ value: Value, for key: Key) {
        let entry = Entry(value: value, expiry: Date().addingTimeInterval(ttl))
        queue.async(flags: .barrier) {
            self.storage[key] = entry
        }
    }
    
    func removeValue(for key: Key) {
        queue.async(flags: .barrier) {
            self.storage.removeValue(forKey: key)
        }
    }
    
    func removeAll() {
        queue.async(flags: .barrier) {
            self.storage.removeAll()
        }
    }
}


