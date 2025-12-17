import Foundation
import Combine
import CoreData

@MainActor
final class ReadLaterViewModel: ObservableObject {
    @Published private(set) var items: [Bookmark] = []
    @Published var includeReadItems: Bool = false {
        didSet { reload() }
    }
    @Published var sort: ReadLaterService.SortOption = BookmarkPreferenceStore.readLaterSortOption {
        didSet {
            BookmarkPreferenceStore.readLaterSortOption = sort
            reload()
        }
    }
    @Published var selectedIndex: Int = 0
    @Published var appearance: ReadingAppearanceSettings = .current
    @Published private(set) var goal: ReadingGoal?
    @Published private(set) var isCelebratingGoal: Bool = false
    @Published private(set) var dailyProgress: Double = 0
    @Published private(set) var stats: ReadLaterService.ReadingStats?
    @Published private(set) var quickReads: [Bookmark] = []
    @Published private(set) var longReads: [Bookmark] = []
    @Published private(set) var priorityReads: [Bookmark] = []
    @Published private(set) var eventRecommendations: [Bookmark] = []
    @Published private(set) var timeFriendlyReads: [Bookmark] = []
    @Published private(set) var history: [Bookmark] = []
    @Published var availableTimeMinutes: Int = 15 {
        didSet { updateAvailableTimeSuggestions() }
    }
    
    private let readLaterService = ReadLaterService.shared
    private let core = CoreDataManager.shared
    private var cancellables = Set<AnyCancellable>()
    private var activeSessionStart: Date?
    
    init() {
        _ = readLaterService.ensureSystemCollection()
        NotificationCenter.default.publisher(for: .readLaterUpdated)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.reload() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.appearance = ReadingAppearanceSettings.current }
            .store(in: &cancellables)
        reload()
    }
    
    func reload() {
        items = readLaterService.readLaterBookmarks(sortedBy: sort, includeRead: includeReadItems)
        if selectedIndex >= items.count { selectedIndex = max(items.count - 1, 0) }
        goal = readLaterService.activeGoal()
        updateProgressRing()
        refreshInsights()
    }
    
    func toggleIncludeRead() {
        includeReadItems.toggle()
    }
    
    func toggleAppearanceTheme() {
        let all = ReadingAppearanceSettings.Theme.allCases
        guard let currentIndex = all.firstIndex(of: appearance.theme) else { return }
        let next = all[(currentIndex + 1) % all.count]
        appearance.theme = next
        appearance.persist()
        objectWillChange.send()
    }
    
    func updateAppearance(_ newValue: ReadingAppearanceSettings) {
        appearance = newValue
        appearance.persist()
    }
    
    func select(index: Int) {
        guard items.indices.contains(index) else { return }
        endSession()
        selectedIndex = index
        startSession()
    }
    
    func startSession() {
        activeSessionStart = Date()
    }
    
    func endSession() {
        guard let start = activeSessionStart,
              items.indices.contains(selectedIndex) else { return }
        let duration = Date().timeIntervalSince(start)
        do {
            try readLaterService.recordSession(for: items[selectedIndex], duration: duration)
        } catch {
            print("Reading session save failed: \(error.localizedDescription)")
        }
        activeSessionStart = nil
    }
    
    func reachedEnd(of bookmark: Bookmark) {
        do {
            try readLaterService.markRead(bookmark)
            celebrateIfNeeded()
        } catch {
            print("Mark read failed: \(error.localizedDescription)")
        }
        advance(after: bookmark)
    }
    
    func toggleReadState(for bookmark: Bookmark) {
        if bookmark.isReadValue {
            do { try readLaterService.markUnread(bookmark) } catch { print(error.localizedDescription) }
            reload()
        } else {
            reachedEnd(of: bookmark)
        }
    }
    
    func removeFromList(_ bookmark: Bookmark) {
        do { try readLaterService.removeFromReadLater(bookmark) } catch { print(error.localizedDescription) }
        reload()
    }
    
    func updateProgress(_ value: Double, for bookmark: Bookmark) {
        bookmark.readingProgressValue = max(0, min(1, value))
        do { try core.save() } catch {
            print("Progress save failed: \(error.localizedDescription)")
        }
        refreshInsights()
    }
    
    func goalCompletionFraction() -> Double {
        guard let goal, goal.targetCount > 0 else { return 0 }
        return min(1.0, Double(goal.completedCount) / Double(goal.targetCount))
    }
    
    func celebrateIfNeeded() {
        guard let goal else { return }
        if goal.completedCount >= goal.targetCount {
            isCelebratingGoal = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.isCelebratingGoal = false
            }
        }
    }
    
    func updateGoal(type: ReadLaterService.GoalType, target: Int) {
        do {
            let goal = try readLaterService.upsertGoal(type: type.rawValue, target: Int32(target))
            self.goal = goal
            updateProgressRing()
            refreshInsights()
        } catch {
            print("Goal update failed: \(error.localizedDescription)")
        }
    }
    
    func clearGoal() {
        do {
            try readLaterService.clearGoal()
            goal = nil
            updateProgressRing()
            refreshInsights()
        } catch {
            print("Goal clear failed: \(error.localizedDescription)")
        }
    }
    
    func exportHistory() -> URL? {
        do {
            return try readLaterService.exportReadingHistoryCSV()
        } catch {
            print("History export failed: \(error.localizedDescription)")
            return nil
        }
    }
    
    func queueForReRead(_ bookmark: Bookmark) {
        do {
            try readLaterService.markUnread(bookmark)
            try readLaterService.addToReadLater(bookmark)
            reload()
        } catch {
            print("Re-read scheduling failed: \(error.localizedDescription)")
        }
    }
    
    private func advance(after bookmark: Bookmark) {
        guard let index = items.firstIndex(where: { $0.objectID == bookmark.objectID }) else {
            reload()
            return
        }
        let nextIndex = index + 1
        reload()
        if nextIndex < items.count {
            selectedIndex = nextIndex
            startSession()
        } else {
            selectedIndex = max(items.count - 1, 0)
        }
    }
    
    private func updateProgressRing() {
        guard let goal else {
            dailyProgress = 0
            return
        }
        switch ReadLaterService.GoalType(rawValue: goal.goalType ?? ReadLaterService.GoalType.daily.rawValue) ?? .daily {
        case .daily, .weekly:
            dailyProgress = goalCompletionFraction()
        }
    }
    
    func refreshInsights() {
        stats = readLaterService.readingStats()
        quickReads = Array(readLaterService.quickReadSuggestions())
        longReads = Array(readLaterService.longReadSuggestions())
        priorityReads = Array(readLaterService.priorityRecommendations())
        eventRecommendations = Array(readLaterService.eventRecommendations())
        history = readLaterService.readingHistory(limit: 50)
        updateAvailableTimeSuggestions()
    }
    
    private func updateAvailableTimeSuggestions() {
        timeFriendlyReads = Array(readLaterService.suggestions(forAvailableMinutes: availableTimeMinutes))
    }
    
    deinit {
        cancellables.removeAll()
    }
}
