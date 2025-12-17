import Foundation

@MainActor
final class AppLaunchMetrics {
    static let shared = AppLaunchMetrics()
    
    private var launchStart: TimeInterval?
    private var firstFrameDuration: TimeInterval?
    
    private init() {}
    
    func markLaunchStart() {
        launchStart = ProcessInfo.processInfo.systemUptime
        firstFrameDuration = nil
    }
    
    func markFirstFrameRendered() {
        guard let start = launchStart, firstFrameDuration == nil else { return }
        firstFrameDuration = ProcessInfo.processInfo.systemUptime - start
        PerformanceMonitor.shared.endOperation("app.launch")
    }
    
    func latestDuration() -> TimeInterval? {
        firstFrameDuration
    }
}
