//
//  PerformanceMonitor.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 23/10/25.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Performance Monitor

class PerformanceMonitor: ObservableObject {
    static let shared = PerformanceMonitor()
    
    @Published var isMonitoring = false
    @Published var memoryUsage: UInt64 = 0
    @Published var cacheHitRate: Double = 0.0
    @Published var averageLoadTime: Double = 0.0
    @Published var activeOperations: Int = 0
    
    private var operationTimes: [String: TimeInterval] = [:]
    private var cacheHits: [String: Int] = [:]
    private var cacheMisses: [String: Int] = [:]
    private var memoryCheckTimer: Timer?
    private let monitorQueue = DispatchQueue(label: "com.calendarnotes.performance", attributes: .concurrent)
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Monitoring
    
    func startMonitoring() {
        isMonitoring = true
        memoryCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateMemoryUsage()
        }
    }
    
    func stopMonitoring() {
        isMonitoring = false
        memoryCheckTimer?.invalidate()
        memoryCheckTimer = nil
    }
    
    // MARK: - Operation Tracking
    
    func startOperation(_ operationId: String) {
        monitorQueue.async(flags: .barrier) {
            self.operationTimes[operationId] = Date().timeIntervalSince1970
            DispatchQueue.main.async {
                self.activeOperations += 1
            }
        }
    }
    
    func endOperation(_ operationId: String) {
        monitorQueue.async(flags: .barrier) {
            guard let startTime = self.operationTimes[operationId] else { return }
            let duration = Date().timeIntervalSince1970 - startTime
            self.operationTimes.removeValue(forKey: operationId)
            
            DispatchQueue.main.async {
                self.updateAverageLoadTime(duration)
                self.activeOperations = max(0, self.activeOperations - 1)
            }
        }
    }
    
    private func updateAverageLoadTime(_ newTime: TimeInterval) {
        // Simple moving average
        averageLoadTime = (averageLoadTime * 0.9) + (newTime * 0.1)
    }
    
    // MARK: - Cache Tracking
    
    func recordCacheHit(for key: String) {
        monitorQueue.async(flags: .barrier) {
            self.cacheHits[key, default: 0] += 1
            DispatchQueue.main.async {
                self.updateCacheHitRate()
            }
        }
    }
    
    func recordCacheMiss(for key: String) {
        monitorQueue.async(flags: .barrier) {
            self.cacheMisses[key, default: 0] += 1
            DispatchQueue.main.async {
                self.updateCacheHitRate()
            }
        }
    }
    
    private func updateCacheHitRate() {
        let totalHits = cacheHits.values.reduce(0, +)
        let totalMisses = cacheMisses.values.reduce(0, +)
        let total = totalHits + totalMisses
        
        if total > 0 {
            cacheHitRate = Double(totalHits) / Double(total)
        }
    }
    
    // MARK: - Memory Monitoring
    
    private func updateMemoryUsage() {
        var memoryInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &memoryInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            DispatchQueue.main.async {
                self.memoryUsage = memoryInfo.resident_size
            }
        }
    }
    
    // MARK: - API Latency Tracking
    
    private var apiLatencies: [String: [TimeInterval]] = [:]
    private let maxLatencySamples = 100
    
    func recordAPILatency(endpoint: String, latency: TimeInterval) {
        monitorQueue.async(flags: .barrier) {
            if self.apiLatencies[endpoint] == nil {
                self.apiLatencies[endpoint] = []
            }
            self.apiLatencies[endpoint]?.append(latency)
            
            // Limit samples
            if let samples = self.apiLatencies[endpoint], samples.count > self.maxLatencySamples {
                self.apiLatencies[endpoint] = Array(samples.suffix(self.maxLatencySamples))
            }
        }
    }
    
    func getAPILatencyStats(for endpoint: String) -> APILatencyStats? {
        return monitorQueue.sync {
            guard let latencies = apiLatencies[endpoint], !latencies.isEmpty else {
                return nil
            }
            
            let sorted = latencies.sorted()
            let average = latencies.reduce(0, +) / Double(latencies.count)
            let min = sorted.first!
            let max = sorted.last!
            let median = sorted[sorted.count / 2]
            let p95 = sorted[Int(Double(sorted.count) * 0.95)]
            let p99 = sorted[Int(Double(sorted.count) * 0.99)]
            
            return APILatencyStats(
                endpoint: endpoint,
                average: average,
                min: min,
                max: max,
                median: median,
                p95: p95,
                p99: p99,
                sampleCount: latencies.count
            )
        }
    }
    
    // MARK: - Sync Duration Tracking
    
    private var syncDurations: [TimeInterval] = []
    private let maxSyncSamples = 50
    
    func recordSyncDuration(_ duration: TimeInterval) {
        monitorQueue.async(flags: .barrier) {
            self.syncDurations.append(duration)
            if self.syncDurations.count > self.maxSyncSamples {
                self.syncDurations.removeFirst()
            }
        }
    }
    
    func getSyncDurationStats() -> SyncDurationStats? {
        return monitorQueue.sync {
            guard !syncDurations.isEmpty else { return nil }
            
            let sorted = syncDurations.sorted()
            let average = syncDurations.reduce(0, +) / Double(syncDurations.count)
            let min = sorted.first!
            let max = sorted.last!
            let median = sorted[sorted.count / 2]
            
            return SyncDurationStats(
                average: average,
                min: min,
                max: max,
                median: median,
                sampleCount: syncDurations.count
            )
        }
    }
    
    // MARK: - Database Query Time Tracking
    
    private var queryTimes: [String: [TimeInterval]] = [:]
    private let maxQuerySamples = 100
    
    func recordQueryTime(query: String, duration: TimeInterval) {
        monitorQueue.async(flags: .barrier) {
            let queryKey = self.sanitizeQuery(query)
            if self.queryTimes[queryKey] == nil {
                self.queryTimes[queryKey] = []
            }
            self.queryTimes[queryKey]?.append(duration)
            
            if let samples = self.queryTimes[queryKey], samples.count > self.maxQuerySamples {
                self.queryTimes[queryKey] = Array(samples.suffix(self.maxQuerySamples))
            }
        }
    }
    
    private func sanitizeQuery(_ query: String) -> String {
        // Remove parameters to group similar queries
        return query.replacingOccurrences(of: #"\$\d+"#, with: "?", options: .regularExpression)
    }
    
    func getQueryTimeStats(for query: String) -> QueryTimeStats? {
        return monitorQueue.sync {
            let queryKey = sanitizeQuery(query)
            guard let times = queryTimes[queryKey], !times.isEmpty else {
                return nil
            }
            
            let sorted = times.sorted()
            let average = times.reduce(0, +) / Double(times.count)
            let min = sorted.first!
            let max = sorted.last!
            let median = sorted[sorted.count / 2]
            
            return QueryTimeStats(
                query: queryKey,
                average: average,
                min: min,
                max: max,
                median: median,
                sampleCount: times.count
            )
        }
    }
    
    // MARK: - CPU Usage Tracking
    
    private var cpuUsageSamples: [Double] = []
    private let maxCPUSamples = 100
    private var cpuCheckTimer: Timer?
    
    func startCPUMonitoring() {
        cpuCheckTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.recordCPUUsage()
        }
    }
    
    func stopCPUMonitoring() {
        cpuCheckTimer?.invalidate()
        cpuCheckTimer = nil
    }
    
    private func recordCPUUsage() {
        // Simplified CPU usage tracking
        // In production, use proper system APIs
        let usage = getCurrentCPUUsage()
        monitorQueue.async(flags: .barrier) {
            self.cpuUsageSamples.append(usage)
            if self.cpuUsageSamples.count > self.maxCPUSamples {
                self.cpuUsageSamples.removeFirst()
            }
        }
    }
    
    private func getCurrentCPUUsage() -> Double {
        // Placeholder - would use proper system APIs
        return Double.random(in: 0...100)
    }
    
    func getCPUUsageStats() -> CPUUsageStats? {
        return monitorQueue.sync {
            guard !cpuUsageSamples.isEmpty else { return nil }
            
            let average = cpuUsageSamples.reduce(0, +) / Double(cpuUsageSamples.count)
            let min = cpuUsageSamples.min()!
            let max = cpuUsageSamples.max()!
            
            return CPUUsageStats(
                average: average,
                min: min,
                max: max,
                current: cpuUsageSamples.last ?? 0,
                sampleCount: cpuUsageSamples.count
            )
        }
    }
    
    // MARK: - Network Usage Tracking
    
    private var networkUsage: NetworkUsageStats = NetworkUsageStats()
    
    func recordNetworkRequest(bytesSent: Int, bytesReceived: Int) {
        monitorQueue.async(flags: .barrier) {
            self.networkUsage.totalBytesSent += bytesSent
            self.networkUsage.totalBytesReceived += bytesReceived
            self.networkUsage.requestCount += 1
        }
    }
    
    func getNetworkUsageStats() -> NetworkUsageStats {
        return monitorQueue.sync {
            networkUsage
        }
    }
    
    // MARK: - Performance Statistics
    
    func getPerformanceStats() -> PerformanceStats {
        return monitorQueue.sync {
            PerformanceStats(
                memoryUsage: memoryUsage,
                cacheHitRate: cacheHitRate,
                averageLoadTime: averageLoadTime,
                activeOperations: activeOperations,
                totalCacheHits: cacheHits.values.reduce(0, +),
                totalCacheMisses: cacheMisses.values.reduce(0, +)
            )
        }
    }
    
    func getDetailedPerformanceReport() -> DetailedPerformanceReport {
        return monitorQueue.sync {
            DetailedPerformanceReport(
                memoryUsage: memoryUsage,
                memoryUsageMB: Double(memoryUsage) / (1024 * 1024),
                cacheHitRate: cacheHitRate,
                averageLoadTime: averageLoadTime,
                activeOperations: activeOperations,
                totalCacheHits: cacheHits.values.reduce(0, +),
                totalCacheMisses: cacheMisses.values.reduce(0, +),
                syncDurationStats: getSyncDurationStats(),
                cpuUsageStats: getCPUUsageStats(),
                networkUsageStats: getNetworkUsageStats(),
                apiLatencyStats: apiLatencies.map { getAPILatencyStats(for: $0.key) }.compactMap { $0 }
            )
        }
    }
    
    func clearStats() {
        monitorQueue.async(flags: .barrier) {
            self.operationTimes.removeAll()
            self.cacheHits.removeAll()
            self.cacheMisses.removeAll()
            self.apiLatencies.removeAll()
            self.syncDurations.removeAll()
            self.queryTimes.removeAll()
            self.cpuUsageSamples.removeAll()
            self.networkUsage = NetworkUsageStats()
        }
        
        DispatchQueue.main.async {
            self.averageLoadTime = 0.0
            self.cacheHitRate = 0.0
            self.activeOperations = 0
        }
    }
}

// MARK: - Performance Statistics

struct PerformanceStats {
    let memoryUsage: UInt64
    let cacheHitRate: Double
    let averageLoadTime: Double
    let activeOperations: Int
    let totalCacheHits: Int
    let totalCacheMisses: Int
    
    var memoryUsageMB: Double {
        return Double(memoryUsage) / (1024 * 1024)
    }
    
    var cacheHitRatePercentage: Double {
        return cacheHitRate * 100
    }
    
    var averageLoadTimeMS: Double {
        return averageLoadTime * 1000
    }
}

// MARK: - Enhanced Performance Stats

struct APILatencyStats {
    let endpoint: String
    let average: TimeInterval
    let min: TimeInterval
    let max: TimeInterval
    let median: TimeInterval
    let p95: TimeInterval
    let p99: TimeInterval
    let sampleCount: Int
}

struct SyncDurationStats {
    let average: TimeInterval
    let min: TimeInterval
    let max: TimeInterval
    let median: TimeInterval
    let sampleCount: Int
}

struct QueryTimeStats {
    let query: String
    let average: TimeInterval
    let min: TimeInterval
    let max: TimeInterval
    let median: TimeInterval
    let sampleCount: Int
}

struct CPUUsageStats {
    let average: Double
    let min: Double
    let max: Double
    let current: Double
    let sampleCount: Int
}

struct NetworkUsageStats {
    var totalBytesSent: Int = 0
    var totalBytesReceived: Int = 0
    var requestCount: Int = 0
    
    var totalBytesSentMB: Double {
        return Double(totalBytesSent) / (1024 * 1024)
    }
    
    var totalBytesReceivedMB: Double {
        return Double(totalBytesReceived) / (1024 * 1024)
    }
}

struct DetailedPerformanceReport {
    let memoryUsage: UInt64
    let memoryUsageMB: Double
    let cacheHitRate: Double
    let averageLoadTime: TimeInterval
    let activeOperations: Int
    let totalCacheHits: Int
    let totalCacheMisses: Int
    let syncDurationStats: SyncDurationStats?
    let cpuUsageStats: CPUUsageStats?
    let networkUsageStats: NetworkUsageStats
    let apiLatencyStats: [APILatencyStats]
}


// MARK: - Performance Tracking Modifiers

struct PerformanceTrackingModifier: ViewModifier {
    let operationId: String
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                PerformanceMonitor.shared.startOperation(operationId)
            }
            .onDisappear {
                PerformanceMonitor.shared.endOperation(operationId)
            }
    }
}

extension View {
    func trackPerformance(_ operationId: String) -> some View {
        self.modifier(PerformanceTrackingModifier(operationId: operationId))
    }
}

// MARK: - Memory Warning Handler

class MemoryWarningHandler: ObservableObject {
    @Published var isMemoryWarningActive = false
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupMemoryWarningObserver()
    }
    
    private func setupMemoryWarningObserver() {
        #if os(iOS)
        NotificationCenter.default
            .publisher(for: UIApplication.didReceiveMemoryWarningNotification)
            .sink { [weak self] _ in
                self?.handleMemoryWarning()
            }
            .store(in: &cancellables)
        #endif
    }
    
    private func handleMemoryWarning() {
        isMemoryWarningActive = true
        
        // Clear caches
        OptimizedCoreDataService().clearAllCache()
        ImageCacheService.shared.clearAllCache()
        
        // Clear performance stats
        PerformanceMonitor.shared.clearStats()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.isMemoryWarningActive = false
        }
    }
}

// MARK: - Background Task Manager

class BackgroundTaskManager: ObservableObject {
    @Published var isBackgroundTaskActive = false
    
    #if os(iOS)
    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    #endif
    
    func startBackgroundTask() {
        #if os(iOS)
        guard !isBackgroundTaskActive else { return }
        
        backgroundTaskId = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        isBackgroundTaskActive = true
        #endif
    }
    
    func endBackgroundTask() {
        #if os(iOS)
        guard isBackgroundTaskActive else { return }
        
        UIApplication.shared.endBackgroundTask(backgroundTaskId)
        backgroundTaskId = .invalid
        isBackgroundTaskActive = false
        #endif
    }
}
