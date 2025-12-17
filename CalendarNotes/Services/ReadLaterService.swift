import Foundation
import CoreData

extension Notification.Name {
    static let readLaterUpdated = Notification.Name("ReadLaterUpdated")
}

@MainActor
final class ReadLaterService {
    struct Constants {
        static let systemIdentifier = "readLater"
        static let collectionName = "Read Later"
    }
    
    enum SortOption: String, CaseIterable {
        case addedDate
        case priority
        case estimatedTime
        
        var displayName: String {
            switch self {
            case .addedDate: return "Recently Added"
            case .priority: return "Priority"
            case .estimatedTime: return "Estimated Time"
            }
        }
    }
    
    enum GoalType: String {
        case daily
        case weekly
    }
    
    struct ReadingStats {
        let totalCompleted: Int
        let totalEstimatedMinutes: Int
        let totalTimeSpent: TimeInterval
        let averageMinutesPerArticle: Double
        let currentStreak: Int
        let bestStreak: Int
        let completedThisWeek: Int
        let completedThisMonth: Int
    }
    
    static let shared = ReadLaterService()
    private init() {
        Task { await refreshUnreadCount() }
    }
    
    private let core = CoreDataManager.shared
    private(set) var unreadCount: Int = 0
    
    // MARK: - Collection Helpers
    
    func ensureSystemCollection() -> Collection {
        let context = core.viewContext
        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        request.predicate = NSPredicate(format: "systemIdentifier == %@", Constants.systemIdentifier)
        request.fetchLimit = 1
        if let existing = try? context.fetch(request).first {
            return existing
        }
        let collection = Collection(context: context,
                                    name: Constants.collectionName,
                                    color: "#4C6EF5",
                                    icon: "bookmark.fill",
                                    sortOrder: -1,
                                    parent: nil,
                                    isSystem: true,
                                    systemIdentifier: Constants.systemIdentifier)
        try? core.save()
        return collection
    }
    
    // MARK: - Mutations
    
    @discardableResult
    func toggleReadLater(for bookmark: Bookmark) throws -> Bool {
        if bookmark.isInReadLater {
            try removeFromReadLater(bookmark)
            return false
        } else {
            try addToReadLater(bookmark)
            return true
        }
    }
    
    func addToReadLater(_ bookmark: Bookmark) throws {
        guard !bookmark.isInReadLater else { return }
        _ = ensureSystemCollection()
        bookmark.isInReadLater = true
        bookmark.readLaterAddedDate = Date()
        if bookmark.estimatedReadingMinutesValue == 0 {
            bookmark.estimatedReadingMinutesValue = estimateMinutes(for: bookmark)
        }
        try core.save()
        awaitRefresh()
    }
    
    func removeFromReadLater(_ bookmark: Bookmark) throws {
        guard bookmark.isInReadLater else { return }
        bookmark.isInReadLater = false
        bookmark.readLaterAddedDate = nil
        try core.save()
        awaitRefresh()
    }
    
    func markRead(_ bookmark: Bookmark, at date: Date = Date()) throws {
        bookmark.markAsRead(on: date)
        updateGoalAfterCompletion(on: date)
        try core.save()
        awaitRefresh()
    }
    
    func markUnread(_ bookmark: Bookmark) throws {
        let previousReadDate = bookmark.readDate
        bookmark.markAsUnread()
        if let previousReadDate {
            rollbackGoal(for: previousReadDate)
        }
        try core.save()
        awaitRefresh()
    }
    
    func recordSession(for bookmark: Bookmark, duration: TimeInterval, device: String? = nil) throws {
        let session = ReadingSession(context: core.viewContext)
        session.id = UUID()
        session.startDate = Date().addingTimeInterval(-duration)
        session.endDate = Date()
        session.duration = duration
        session.device = device
        session.bookmark = bookmark
        bookmark.totalReadingTimeValue += duration
        bookmark.lastReadingSessionDate = session.endDate
        if duration > 0 {
            let progress = min(1.0, bookmark.totalReadingTimeValue / max(60, Double(max(1, bookmark.estimatedReadingMinutesValue)) * 60.0))
            bookmark.readingProgressValue = progress
        }
        try core.save()
        awaitRefresh()
    }
    
    // MARK: - Queries
    
    func readLaterBookmarks(sortedBy option: SortOption, includeRead: Bool = false) -> [Bookmark] {
        let context = core.viewContext
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        var predicates: [NSPredicate] = [NSPredicate(format: "isReadLater == YES")]
        if !includeRead {
            predicates.append(NSPredicate(format: "isRead == NO"))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.fetchLimit = 500
        switch option {
        case .addedDate:
            request.sortDescriptors = [NSSortDescriptor(key: "readLaterAddedDate", ascending: false)]
        case .priority:
            request.sortDescriptors = [
                NSSortDescriptor(key: "readingPriority", ascending: true),
                NSSortDescriptor(key: "readLaterAddedDate", ascending: false)
            ]
        case .estimatedTime:
            request.sortDescriptors = [
                NSSortDescriptor(key: "estimatedReadingMinutes", ascending: true),
                NSSortDescriptor(key: "readLaterAddedDate", ascending: false)
            ]
        }
        var bookmarks = (try? context.fetch(request)) ?? []
        switch option {
        case .priority:
            bookmarks.sort { $0.readingPriorityValue.sortIndex < $1.readingPriorityValue.sortIndex }
        case .estimatedTime:
            bookmarks.sort { lhs, rhs in
                let l = lhs.estimatedReadingMinutesValue
                let r = rhs.estimatedReadingMinutesValue
                if l == 0 { return false }
                if r == 0 { return true }
                if l == r { return (lhs.readLaterAddedDate ?? .distantPast) > (rhs.readLaterAddedDate ?? .distantPast) }
                return l < r
            }
        case .addedDate:
            break
        }
        return bookmarks
    }
    
    func unreadCountPublisher() async -> AsyncStream<Int> {
        AsyncStream { continuation in
            let observer = NotificationCenter.default.addObserver(forName: .readLaterUpdated, object: nil, queue: .main) { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    continuation.yield(self.unreadCount)
                }
            }
            continuation.onTermination = { _ in
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
    
    func readingStats() -> ReadingStats {
        let ctx = core.viewContext
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        request.predicate = NSPredicate(format: "isRead == YES")
        request.sortDescriptors = [NSSortDescriptor(key: "readDate", ascending: false)]
        let completed = (try? ctx.fetch(request)) ?? []
        let calendar = Calendar.current
        let now = Date()
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: now)
        let monthInterval = calendar.dateInterval(of: .month, for: now)
        var totalMinutes = 0
        var totalTimeSpent: TimeInterval = 0
        var weekCount = 0
        var monthCount = 0
        for bookmark in completed {
            let minutes = bookmark.estimatedReadingMinutesValue > 0 ? bookmark.estimatedReadingMinutesValue : estimateMinutes(for: bookmark)
            totalMinutes += minutes
            totalTimeSpent += bookmark.totalReadingTimeValue
            if let readDate = bookmark.readDate {
                if let weekInterval, weekInterval.contains(readDate) { weekCount += 1 }
                if let monthInterval, monthInterval.contains(readDate) { monthCount += 1 }
            }
        }
        let avg = completed.isEmpty ? 0 : Double(totalMinutes) / Double(completed.count)
        let goal = activeGoal()
        return ReadingStats(
            totalCompleted: completed.count,
            totalEstimatedMinutes: totalMinutes,
            totalTimeSpent: totalTimeSpent,
            averageMinutesPerArticle: avg,
            currentStreak: Int(goal?.currentStreak ?? 0),
            bestStreak: Int(goal?.bestStreak ?? 0),
            completedThisWeek: weekCount,
            completedThisMonth: monthCount
        )
    }
    
    func readingHistory(limit: Int? = nil) -> [Bookmark] {
        let ctx = core.viewContext
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        request.predicate = NSPredicate(format: "isRead == YES")
        request.sortDescriptors = [
            NSSortDescriptor(key: "readDate", ascending: false),
            NSSortDescriptor(key: "lastReadingSessionDate", ascending: false)
        ]
        if let limit { request.fetchLimit = limit }
        let result = (try? ctx.fetch(request)) ?? []
        return result
    }
    
    func quickReadSuggestions(limit: Int = 6) -> [Bookmark] {
        readLaterBookmarks(sortedBy: .estimatedTime)
            .filter { readingMinutes(for: $0) <= 7 }
            .prefix(limit)
            .map { $0 }
    }
    
    func longReadSuggestions(limit: Int = 6) -> [Bookmark] {
        readLaterBookmarks(sortedBy: .estimatedTime)
            .filter { readingMinutes(for: $0) >= 20 }
            .prefix(limit)
            .map { $0 }
    }
    
    func priorityRecommendations(limit: Int = 6) -> [Bookmark] {
        readLaterBookmarks(sortedBy: .priority)
            .sorted { $0.readingPriorityValue.sortIndex < $1.readingPriorityValue.sortIndex }
            .prefix(limit)
            .map { $0 }
    }
    
    func eventRecommendations(limit: Int = 6) -> [Bookmark] {
        let horizon = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
        return readLaterBookmarks(sortedBy: .addedDate)
            .filter { bookmark in
                !bookmark.isReadValue && bookmark.linkedEvents.contains { event in
                    guard let date = event.startDate else { return false }
                    return date >= Date() && date <= horizon
                }
            }
            .prefix(limit)
            .map { $0 }
    }
    
    func suggestions(forAvailableMinutes minutes: Int, limit: Int = 6) -> [Bookmark] {
        guard minutes > 0 else { return [] }
        return readLaterBookmarks(sortedBy: .estimatedTime)
            .filter { readingMinutes(for: $0) <= minutes }
            .prefix(limit)
            .map { $0 }
    }
    
    func exportReadingHistoryCSV() throws -> URL {
        let history = readingHistory(limit: nil)
        var csv = "Title,URL,Read Date,Estimated Minutes,Time Spent (minutes)\n"
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        for bookmark in history {
            let title = "\(bookmark.title ?? "Untitled")".replacingOccurrences(of: "\"", with: "\"")
            let url = bookmark.url ?? ""
            let readDate = bookmark.readDate.map { formatter.string(from: $0) } ?? ""
            let estimated = readingMinutes(for: bookmark)
            let spent = bookmark.totalReadingTimeValue / 60.0
            csv += "\"\(title)\",\(url),\(readDate),\(estimated),\(String(format: "%.1f", spent))\n"
        }
        let filename = "ReadingHistory-\(UUID().uuidString).csv"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
    
    func clearGoal() throws {
        if let goal = activeGoal() {
            core.viewContext.delete(goal)
            try core.save()
        }
    }
    
    // MARK: - Goals Helpers
    
    func activeGoal(context: NSManagedObjectContext? = nil) -> ReadingGoal? {
        let ctx = context ?? core.viewContext
        let request: NSFetchRequest<ReadingGoal> = ReadingGoal.fetchRequest()
        request.fetchLimit = 1
        request.sortDescriptors = [NSSortDescriptor(key: "periodStart", ascending: false)]
        return try? ctx.fetch(request).first
    }
    
    func upsertGoal(type: String, target: Int32) throws -> ReadingGoal {
        let goal = activeGoal() ?? ReadingGoal(context: core.viewContext)
        if goal.periodStart == nil {
            goal.periodStart = Calendar.current.startOfDay(for: Date())
        }
        goal.goalType = type
        goal.targetCount = target
        try core.save()
        return goal
    }
    
    // MARK: - Private
    
    private func estimateMinutes(for bookmark: Bookmark) -> Int {
        if let article = bookmark.contentMetadataValue?.article?.estimatedReadTimeMinutes, article > 0 { return article }
        if let videoDuration = bookmark.videoDurationSeconds { return Int(ceil(videoDuration / 60.0)) }
        if let recipeTime = bookmark.recipeCookTimeDescription, let minutes = parseMinutes(from: recipeTime) { return minutes }
        if let pdfPageCount = bookmark.pdfPageCountValue, pdfPageCount > 0 { return max(5, pdfPageCount * 2) }
        return 5
    }
    
    private func readingMinutes(for bookmark: Bookmark) -> Int {
        let minutes = bookmark.estimatedReadingMinutesValue
        return minutes > 0 ? minutes : estimateMinutes(for: bookmark)
    }

    private func parseMinutes(from string: String) -> Int? {
        let numbers = string.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
        return numbers.first
    }
    
    private func awaitRefresh() {
        Task { await refreshUnreadCount() }
    }
    
    private func refreshUnreadCount() async {
        let context = core.viewContext
        let request: NSFetchRequest<NSNumber> = NSFetchRequest(entityName: "Bookmark")
        request.resultType = .countResultType
        request.predicate = NSPredicate(format: "isReadLater == YES AND isRead == NO")
        let count = (try? context.count(for: request)) ?? 0
        unreadCount = count
        NotificationCenter.default.post(name: .readLaterUpdated, object: nil)
    }

    private func updateGoalAfterCompletion(on date: Date) {
        guard let goal = activeGoal() else { return }
        refreshGoal(goal, for: date)
        goal.completedCount += 1
        updateStreak(goal: goal, completionDate: date)
    }
    
    private func rollbackGoal(for date: Date) {
        guard let goal = activeGoal() else { return }
        refreshGoal(goal, for: date)
        if goal.completedCount > 0 {
            goal.completedCount -= 1
        }
        if let last = goal.lastCompletionDate {
            let calendar = Calendar.current
            let type = GoalType(rawValue: goal.goalType ?? GoalType.daily.rawValue) ?? .daily
            let samePeriod: Bool
            switch type {
            case .daily:
                samePeriod = calendar.isDate(last, inSameDayAs: date)
            case .weekly:
                let components = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: last)
                let current = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: date)
                samePeriod = components == current
            }
            if samePeriod {
                goal.lastCompletionDate = nil
                goal.currentStreak = max(0, goal.currentStreak - 1)
            }
        }
    }
    
    private func refreshGoal(_ goal: ReadingGoal, for date: Date) {
        let calendar = Calendar.current
        let type = GoalType(rawValue: goal.goalType ?? GoalType.daily.rawValue) ?? .daily
        let newStart: Date
        let newEnd: Date
        switch type {
        case .daily:
            newStart = calendar.startOfDay(for: date)
            newEnd = calendar.date(byAdding: .day, value: 1, to: newStart) ?? date
        case .weekly:
            let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
            newStart = calendar.date(from: comps) ?? calendar.startOfDay(for: date)
            newEnd = calendar.date(byAdding: .day, value: 7, to: newStart) ?? date
        }
        if let start = goal.periodStart, let end = goal.periodEnd,
           start <= date && date < end {
            return
        }
        goal.periodStart = newStart
        goal.periodEnd = newEnd
        goal.completedCount = 0
    }
    
    private func updateStreak(goal: ReadingGoal, completionDate date: Date) {
        let calendar = Calendar.current
        let type = GoalType(rawValue: goal.goalType ?? GoalType.daily.rawValue) ?? .daily
        defer { goal.bestStreak = max(goal.bestStreak, goal.currentStreak) }
        guard let last = goal.lastCompletionDate else {
            goal.currentStreak = max(goal.currentStreak, 1)
            goal.lastCompletionDate = date
            return
        }
        let delta: Int
        switch type {
        case .daily:
            let lastDay = calendar.startOfDay(for: last)
            let currentDay = calendar.startOfDay(for: date)
            delta = calendar.dateComponents([.day], from: lastDay, to: currentDay).day ?? 0
        case .weekly:
            let lastWeek = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: last)
            let currentWeek = calendar.dateComponents([.weekOfYear, .yearForWeekOfYear], from: date)
            delta = (currentWeek.weekOfYear ?? 0) - (lastWeek.weekOfYear ?? 0) + ((currentWeek.yearForWeekOfYear ?? 0) - (lastWeek.yearForWeekOfYear ?? 0)) * 52
        }
        if delta == 0 {
            // same day/week: do not bump streak, but accept completion
        } else if delta == 1 {
            goal.currentStreak += 1
        } else if delta > 1 {
            goal.currentStreak = 1
        }
        goal.lastCompletionDate = date
    }
}
