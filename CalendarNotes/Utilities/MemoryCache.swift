//
//  MemoryCache.swift
//  CalendarNotes
//
//  TTL-based memory cache for frequently accessed data
//

import Foundation
import CoreData
import Combine

// MARK: - Cache Entry

private struct CacheEntry<T> {
    let value: T
    let expirationDate: Date
    let key: String
    
    var isExpired: Bool {
        Date() > expirationDate
    }
}

// MARK: - Memory Cache

class MemoryCache {
    static let shared = MemoryCache()
    
    // Cache storage
    private var eventsCache: [String: CacheEntry<[CalendarEvent]>] = [:]
    private var userProfileCache: CacheEntry<UserProfile>?
    private var collectionsCache: CacheEntry<[Collection]>?
    private var tagsCache: CacheEntry<[Tag]>?
    private var bookmarksCache: [String: CacheEntry<[Bookmark]>] = [:]
    
    // Cache configuration
    private let eventsTTL: TimeInterval = 5 * 60 // 5 minutes
    private let userProfileTTL: TimeInterval = 30 * 60 // 30 minutes
    private let collectionsTTL: TimeInterval = 15 * 60 // 15 minutes
    private let tagsTTL: TimeInterval = 15 * 60 // 15 minutes
    private let bookmarksTTL: TimeInterval = 10 * 60 // 10 minutes
    
    // Thread safety
    private let cacheQueue = DispatchQueue(label: "com.calendarnotes.memorycache", attributes: .concurrent)
    
    // Cache statistics
    private var hitCount: Int = 0
    private var missCount: Int = 0
    
    private init() {
        startCleanupTimer()
    }
    
    // MARK: - Today's Events Cache
    
    func getTodaysEvents() -> [CalendarEvent]? {
        return cacheQueue.sync {
            let key = todayKey()
            guard let entry = eventsCache[key], !entry.isExpired else {
                missCount += 1
                return nil
            }
            hitCount += 1
            return entry.value
        }
    }
    
    func setTodaysEvents(_ events: [CalendarEvent]) {
        cacheQueue.async(flags: .barrier) {
            let key = self.todayKey()
            let expiration = Date().addingTimeInterval(self.eventsTTL)
            self.eventsCache[key] = CacheEntry(value: events, expirationDate: expiration, key: key)
        }
    }
    
    func getEvents(for date: Date) -> [CalendarEvent]? {
        return cacheQueue.sync {
            let key = dateKey(for: date)
            guard let entry = eventsCache[key], !entry.isExpired else {
                missCount += 1
                return nil
            }
            hitCount += 1
            return entry.value
        }
    }
    
    func setEvents(_ events: [CalendarEvent], for date: Date) {
        cacheQueue.async(flags: .barrier) {
            let key = self.dateKey(for: date)
            let expiration = Date().addingTimeInterval(self.eventsTTL)
            self.eventsCache[key] = CacheEntry(value: events, expirationDate: expiration, key: key)
        }
    }
    
    // MARK: - User Profile Cache
    
    func getUserProfile() -> UserProfile? {
        return cacheQueue.sync {
            guard let entry = userProfileCache, !entry.isExpired else {
                missCount += 1
                return nil
            }
            hitCount += 1
            return entry.value
        }
    }
    
    func setUserProfile(_ profile: UserProfile) {
        cacheQueue.async(flags: .barrier) {
            let expiration = Date().addingTimeInterval(self.userProfileTTL)
            self.userProfileCache = CacheEntry(value: profile, expirationDate: expiration, key: "userProfile")
        }
    }
    
    // MARK: - Collections Cache
    
    func getCollections() -> [Collection]? {
        return cacheQueue.sync {
            guard let entry = collectionsCache, !entry.isExpired else {
                missCount += 1
                return nil
            }
            hitCount += 1
            return entry.value
        }
    }
    
    func setCollections(_ collections: [Collection]) {
        cacheQueue.async(flags: .barrier) {
            let expiration = Date().addingTimeInterval(self.collectionsTTL)
            self.collectionsCache = CacheEntry(value: collections, expirationDate: expiration, key: "collections")
        }
    }
    
    // MARK: - Tags Cache
    
    func getTags() -> [Tag]? {
        return cacheQueue.sync {
            guard let entry = tagsCache, !entry.isExpired else {
                missCount += 1
                return nil
            }
            hitCount += 1
            return entry.value
        }
    }
    
    func setTags(_ tags: [Tag]) {
        cacheQueue.async(flags: .barrier) {
            let expiration = Date().addingTimeInterval(self.tagsTTL)
            self.tagsCache = CacheEntry(value: tags, expirationDate: expiration, key: "tags")
        }
    }
    
    // MARK: - Bookmarks Cache
    
    func getBookmarks(for collection: String?) -> [Bookmark]? {
        return cacheQueue.sync {
            let key = collectionKey(for: collection)
            guard let entry = bookmarksCache[key], !entry.isExpired else {
                missCount += 1
                return nil
            }
            hitCount += 1
            return entry.value
        }
    }
    
    func setBookmarks(_ bookmarks: [Bookmark], for collection: String?) {
        cacheQueue.async(flags: .barrier) {
            let key = self.collectionKey(for: collection)
            let expiration = Date().addingTimeInterval(self.bookmarksTTL)
            self.bookmarksCache[key] = CacheEntry(value: bookmarks, expirationDate: expiration, key: key)
        }
    }
    
    // MARK: - Cache Invalidation
    
    func invalidateEvents() {
        cacheQueue.async(flags: .barrier) {
            self.eventsCache.removeAll()
        }
    }
    
    func invalidateUserProfile() {
        cacheQueue.async(flags: .barrier) {
            self.userProfileCache = nil
        }
    }
    
    func invalidateCollections() {
        cacheQueue.async(flags: .barrier) {
            self.collectionsCache = nil
        }
    }
    
    func invalidateTags() {
        cacheQueue.async(flags: .barrier) {
            self.tagsCache = nil
        }
    }
    
    func invalidateBookmarks(for collection: String? = nil) {
        cacheQueue.async(flags: .barrier) {
            if let collection = collection {
                let key = self.collectionKey(for: collection)
                self.bookmarksCache.removeValue(forKey: key)
            } else {
                self.bookmarksCache.removeAll()
            }
        }
    }
    
    func invalidateAll() {
        cacheQueue.async(flags: .barrier) {
            self.eventsCache.removeAll()
            self.userProfileCache = nil
            self.collectionsCache = nil
            self.tagsCache = nil
            self.bookmarksCache.removeAll()
        }
    }
    
    // MARK: - Cache Statistics
    
    func getCacheStats() -> CacheStatistics {
        return cacheQueue.sync {
            let total = hitCount + missCount
            let hitRate = total > 0 ? Double(hitCount) / Double(total) : 0.0
            
            return CacheStatistics(
                hitCount: hitCount,
                missCount: missCount,
                hitRate: hitRate,
                eventsCacheSize: eventsCache.count,
                bookmarksCacheSize: bookmarksCache.count
            )
        }
    }
    
    func resetStats() {
        cacheQueue.async(flags: .barrier) {
            self.hitCount = 0
            self.missCount = 0
        }
    }
    
    // MARK: - Private Helpers
    
    private func todayKey() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "events_\(formatter.string(from: Date()))"
    }
    
    private func dateKey(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return "events_\(formatter.string(from: date))"
    }
    
    private func collectionKey(for collection: String?) -> String {
        return "bookmarks_\(collection ?? "all")"
    }
    
    // MARK: - Cleanup Timer
    
    private func startCleanupTimer() {
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.cleanupExpiredEntries()
        }
    }
    
    private func cleanupExpiredEntries() {
        cacheQueue.async(flags: .barrier) {
            // Clean expired events
            self.eventsCache = self.eventsCache.filter { !$0.value.isExpired }
            
            // Clean expired bookmarks
            self.bookmarksCache = self.bookmarksCache.filter { !$0.value.isExpired }
            
            // Clean single-entry caches
            if let profile = self.userProfileCache, profile.isExpired {
                self.userProfileCache = nil
            }
            if let collections = self.collectionsCache, collections.isExpired {
                self.collectionsCache = nil
            }
            if let tags = self.tagsCache, tags.isExpired {
                self.tagsCache = nil
            }
        }
    }
}

// MARK: - Cache Statistics

struct CacheStatistics {
    let hitCount: Int
    let missCount: Int
    let hitRate: Double
    let eventsCacheSize: Int
    let bookmarksCacheSize: Int
    
    var hitRatePercentage: Double {
        hitRate * 100
    }
}

// MARK: - User Profile (Placeholder - adjust based on your actual model)

struct UserProfile {
    let id: UUID
    let email: String
    let name: String?
    // Add other profile fields as needed
}

