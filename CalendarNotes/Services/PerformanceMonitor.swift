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
    
    func clearStats() {
        monitorQueue.async(flags: .barrier) {
            self.operationTimes.removeAll()
            self.cacheHits.removeAll()
            self.cacheMisses.removeAll()
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
