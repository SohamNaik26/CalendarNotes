//
//  SwiftUIPerformanceOptimizations.swift
//  CalendarNotes
//
//  Created for performance optimization
//

import SwiftUI
import Combine
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Equatable View Modifier
// Note: EquatableView protocol and equatable() extension already exist in
// PerformanceOptimizations.swift and OptimizedViews.swift respectively

// MARK: - Debounced Text Binding

class Debouncer: ObservableObject {
    @Published var debouncedValue: String = ""
    private var cancellable: AnyCancellable?
    private let delay: TimeInterval
    
    init(delay: TimeInterval = 0.3) {
        self.delay = delay
    }
    
    func debounce(_ value: String) {
        cancellable?.cancel()
        cancellable = Just(value)
            .delay(for: .seconds(delay), scheduler: DispatchQueue.main)
            .sink { [weak self] debouncedValue in
                self?.debouncedValue = debouncedValue
            }
    }
}

// MARK: - Debounced Binding Helper

@propertyWrapper
struct DebouncedState<T: Equatable>: DynamicProperty {
    @State private var value: T
    @StateObject private var debouncer: Debouncer
    private let delay: TimeInterval
    
    var wrappedValue: T {
        get { value }
        nonmutating set {
            value = newValue
            debouncer.debounce(String(describing: newValue))
        }
    }
    
    var projectedValue: Binding<T> {
        Binding(
            get: { wrappedValue },
            set: { wrappedValue = $0 }
        )
    }
    
    init(wrappedValue: T, delay: TimeInterval = 0.3) {
        self._value = State(initialValue: wrappedValue)
        self._debouncer = StateObject(wrappedValue: Debouncer(delay: delay))
        self.delay = delay
    }
}

// MARK: - Observable Pagination Helper
// Note: Generic PaginationManager already exists in PerformanceOptimizations.swift
// This is an ObservableObject version for SwiftUI views

class ObservablePaginationManager: ObservableObject {
    @Published var currentPage: Int = 0
    @Published var isLoadingMore: Bool = false
    @Published var hasMore: Bool = true
    
    let pageSize: Int
    
    init(pageSize: Int = 50) {
        self.pageSize = pageSize
    }
    
    func loadMore(loadAction: @escaping (Int, Int) async -> Void) {
        guard !isLoadingMore && hasMore else { return }
        
        isLoadingMore = true
        Task {
            await loadAction(currentPage * pageSize, pageSize)
            await MainActor.run {
                currentPage += 1
                isLoadingMore = false
            }
        }
    }
    
    func reset() {
        currentPage = 0
        isLoadingMore = false
        hasMore = true
    }
}

// MARK: - View Render Time Tracker

class ViewRenderTracker: ObservableObject {
    static let shared = ViewRenderTracker()
    
    @Published var renderTimes: [String: [TimeInterval]] = [:]
    @Published var renderCounts: [String: Int] = [:]
    
    private let maxSamples = 100
    private let trackerQueue = DispatchQueue(label: "com.calendarnotes.renderTracker", attributes: .concurrent)
    
    private init() {}
    
    func trackRender(viewName: String, duration: TimeInterval) {
        trackerQueue.async(flags: .barrier) {
            if self.renderTimes[viewName] == nil {
                self.renderTimes[viewName] = []
            }
            self.renderTimes[viewName]?.append(duration)
            
            if let times = self.renderTimes[viewName], times.count > self.maxSamples {
                self.renderTimes[viewName] = Array(times.suffix(self.maxSamples))
            }
            
            DispatchQueue.main.async {
                self.renderCounts[viewName, default: 0] += 1
            }
        }
    }
    
    func getAverageRenderTime(for viewName: String) -> TimeInterval? {
        return trackerQueue.sync {
            guard let times = renderTimes[viewName], !times.isEmpty else {
                return nil
            }
            return times.reduce(0, +) / Double(times.count)
        }
    }
    
    func getRenderStats(for viewName: String) -> ViewRenderStats? {
        return trackerQueue.sync {
            guard let times = renderTimes[viewName], !times.isEmpty else {
                return nil
            }
            
            let sorted = times.sorted()
            let average = times.reduce(0, +) / Double(times.count)
            let min = sorted.first!
            let max = sorted.last!
            let median = sorted[sorted.count / 2]
            let p95 = sorted[Int(Double(sorted.count) * 0.95)]
            
            return ViewRenderStats(
                viewName: viewName,
                average: average,
                min: min,
                max: max,
                median: median,
                p95: p95,
                renderCount: renderCounts[viewName] ?? 0
            )
        }
    }
    
    func clearStats() {
        trackerQueue.async(flags: .barrier) {
            self.renderTimes.removeAll()
        }
        DispatchQueue.main.async {
            self.renderCounts.removeAll()
        }
    }
}

struct ViewRenderStats {
    let viewName: String
    let average: TimeInterval
    let min: TimeInterval
    let max: TimeInterval
    let median: TimeInterval
    let p95: TimeInterval
    let renderCount: Int
    
    var averageMS: Double {
        average * 1000
    }
}

// MARK: - View Render Time Modifier

struct ViewRenderTimeModifier: ViewModifier {
    let viewName: String
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                let startTime = Date()
                DispatchQueue.main.async {
                    let duration = Date().timeIntervalSince(startTime)
                    ViewRenderTracker.shared.trackRender(viewName: viewName, duration: duration)
                }
            }
    }
}

extension View {
    func trackRenderTime(_ viewName: String) -> some View {
        self.modifier(ViewRenderTimeModifier(viewName: viewName))
    }
}

// MARK: - State Update Frequency Tracker

class StateUpdateTracker: ObservableObject {
    static let shared = StateUpdateTracker()
    
    @Published var updateFrequencies: [String: [Date]] = [:]
    
    private let maxSamples = 1000
    private let trackerQueue = DispatchQueue(label: "com.calendarnotes.stateTracker", attributes: .concurrent)
    
    private init() {}
    
    func trackUpdate(for viewName: String) {
        trackerQueue.async(flags: .barrier) {
            if self.updateFrequencies[viewName] == nil {
                self.updateFrequencies[viewName] = []
            }
            self.updateFrequencies[viewName]?.append(Date())
            
            if let updates = self.updateFrequencies[viewName], updates.count > self.maxSamples {
                self.updateFrequencies[viewName] = Array(updates.suffix(self.maxSamples))
            }
        }
    }
    
    func getUpdateFrequency(for viewName: String, in interval: TimeInterval = 60.0) -> Double? {
        return trackerQueue.sync {
            guard let updates = updateFrequencies[viewName] else {
                return nil
            }
            
            let cutoff = Date().addingTimeInterval(-interval)
            let recentUpdates = updates.filter { $0 >= cutoff }
            return Double(recentUpdates.count) / interval
        }
    }
    
    func clearStats() {
        trackerQueue.async(flags: .barrier) {
            self.updateFrequencies.removeAll()
        }
    }
}

// MARK: - Network Request Counter per View

class NetworkRequestTracker: ObservableObject {
    static let shared = NetworkRequestTracker()
    
    @Published var requestCounts: [String: Int] = [:]
    
    private let trackerQueue = DispatchQueue(label: "com.calendarnotes.networkTracker", attributes: .concurrent)
    
    private init() {}
    
    func trackRequest(for viewName: String) {
        trackerQueue.async(flags: .barrier) {
            self.requestCounts[viewName, default: 0] += 1
        }
    }
    
    func getRequestCount(for viewName: String) -> Int {
        return trackerQueue.sync {
            requestCounts[viewName] ?? 0
        }
    }
    
    func resetCount(for viewName: String) {
        trackerQueue.async(flags: .barrier) {
            self.requestCounts[viewName] = 0
        }
    }
    
    func clearStats() {
        trackerQueue.async(flags: .barrier) {
            self.requestCounts.removeAll()
        }
    }
}

// MARK: - Memory Usage Tracker per View

class ViewMemoryTracker: ObservableObject {
    static let shared = ViewMemoryTracker()
    
    @Published var memoryUsage: [String: UInt64] = [:]
    
    private let trackerQueue = DispatchQueue(label: "com.calendarnotes.memoryTracker", attributes: .concurrent)
    
    private init() {}
    
    func trackMemory(for viewName: String, usage: UInt64) {
        trackerQueue.async(flags: .barrier) {
            self.memoryUsage[viewName] = usage
        }
    }
    
    func getMemoryUsage(for viewName: String) -> UInt64? {
        return trackerQueue.sync {
            memoryUsage[viewName]
        }
    }
    
    func clearStats() {
        trackerQueue.async(flags: .barrier) {
            self.memoryUsage.removeAll()
        }
    }
}

// MARK: - Performance Summary View

struct PerformanceSummaryView: View {
    let viewName: String
    @StateObject private var renderTracker = ViewRenderTracker.shared
    @StateObject private var stateTracker = StateUpdateTracker.shared
    @StateObject private var networkTracker = NetworkRequestTracker.shared
    @StateObject private var memoryTracker = ViewMemoryTracker.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Performance: \(viewName)")
                .font(.headline)
            
            if let renderStats = renderTracker.getRenderStats(for: viewName) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Render Time: \(String(format: "%.2f", renderStats.averageMS))ms avg")
                    Text("Render Count: \(renderStats.renderCount)")
                }
                .font(.caption)
            }
            
            if let frequency = stateTracker.getUpdateFrequency(for: viewName) {
                Text("State Updates: \(String(format: "%.1f", frequency))/min")
                    .font(.caption)
            }
            
            let requestCount = networkTracker.getRequestCount(for: viewName)
            if requestCount > 0 {
                Text("Network Requests: \(requestCount)")
                    .font(.caption)
            }
            
            if let memory = memoryTracker.getMemoryUsage(for: viewName) {
                Text("Memory: \(String(format: "%.1f", Double(memory) / (1024 * 1024))) MB")
                    .font(.caption)
            }
        }
        .padding()
        .background(Color.cnSecondaryBackground)
        .cornerRadius(8)
    }
}

// MARK: - Optimized Image View

struct OptimizedAsyncImage<Placeholder: View, Failure: View>: View {
    let url: URL?
    let placeholder: () -> Placeholder
    let failure: () -> Failure
    let content: (Image) -> Image
    
    @State private var phase: AsyncImagePhase = .empty
    
    init(
        url: URL?,
        @ViewBuilder placeholder: @escaping () -> Placeholder,
        @ViewBuilder failure: @escaping () -> Failure,
        @ViewBuilder content: @escaping (Image) -> Image
    ) {
        self.url = url
        self.placeholder = placeholder
        self.failure = failure
        self.content = content
    }
    
    var body: some View {
        Group {
            switch phase {
            case .empty:
                placeholder()
            case .success(let image):
                content(image)
            case .failure:
                failure()
            @unknown default:
                EmptyView()
            }
        }
        .task(id: url) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        guard let url = url else {
            phase = .failure(NSError(domain: "OptimizedAsyncImage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        phase = .empty
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            #if os(iOS)
            if let uiImage = UIImage(data: data) {
                phase = .success(Image(uiImage: uiImage))
            } else {
                phase = .failure(NSError(domain: "OptimizedAsyncImage", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"]))
            }
            #elseif os(macOS)
            if let nsImage = NSImage(data: data) {
                phase = .success(Image(nsImage: nsImage))
            } else {
                phase = .failure(NSError(domain: "OptimizedAsyncImage", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to create image from data"]))
            }
            #else
            phase = .failure(NSError(domain: "OptimizedAsyncImage", code: -3, userInfo: [NSLocalizedDescriptionKey: "Unsupported platform"]))
            #endif
        } catch {
            phase = .failure(error)
        }
    }
}

// MARK: - Computed Property Cache

@propertyWrapper
struct CachedComputed<Value> {
    private var cachedValue: Value?
    private let compute: () -> Value
    
    var wrappedValue: Value {
        mutating get {
            if let cached = cachedValue {
                return cached
            }
            let value = compute()
            cachedValue = value
            return value
        }
    }
    
    init(_ compute: @escaping () -> Value) {
        self.compute = compute
    }
    
    mutating func invalidate() {
        cachedValue = nil
    }
}

// MARK: - View Body Instrument Helper

struct ViewBodyInstrument: ViewModifier {
    let viewName: String
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                #if DEBUG
                let startTime = Date()
                DispatchQueue.main.async {
                    let duration = Date().timeIntervalSince(startTime)
                    ViewRenderTracker.shared.trackRender(viewName: viewName, duration: duration)
                    PerformanceMonitor.shared.startOperation("view_render_\(viewName)")
                }
                #endif
            }
            .onDisappear {
                #if DEBUG
                PerformanceMonitor.shared.endOperation("view_render_\(viewName)")
                #endif
            }
    }
}

extension View {
    func instrumentBody(_ viewName: String) -> some View {
        self.modifier(ViewBodyInstrument(viewName: viewName))
    }
}

