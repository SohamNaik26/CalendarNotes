import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif

struct ReadLaterView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = ReadLaterViewModel()
    @Namespace private var readerSpace
    @State private var showingInsights = false
    @State private var showingGoalSettings = false
    @State private var showingAppearanceSettings = false
    @State private var showingHistoryShare = false
    @State private var historyExportURL: URL?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                Divider()
                content
            }
            .background(viewModel.appearance.theme.backgroundColor.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        showingInsights = true
                    } label: {
                        Image(systemName: "chart.bar.doc.horizontal")
                    }
                    .help("View reading insights")
                    Menu {
                        Button("Reading Goal Settings") { showingGoalSettings = true }
                        Button("Reading Mode Settings") { showingAppearanceSettings = true }
                        Divider()
                        Button("Cycle Theme") { viewModel.toggleAppearanceTheme() }
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .help("More options")
                }
            }
            .navigationTitle("Read Later")
#if canImport(UIKit)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .sheet(isPresented: $showingInsights) {
                ReadLaterInsightsView(viewModel: viewModel) {
                    exportHistory()
                }
            }
            .sheet(isPresented: $showingGoalSettings) {
                ReadingGoalSettingsView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingAppearanceSettings) {
                ReadingAppearanceSettingsSheet(viewModel: viewModel)
            }
#if canImport(UIKit)
            .sheet(isPresented: $showingHistoryShare, onDismiss: { historyExportURL = nil }) {
                if let url = historyExportURL {
                    ShareSheet(activityItems: [url])
                }
            }
#else
            .onChange(of: historyExportURL) { _, newValue in
                guard let url = newValue else { return }
                copyHistoryURLToPasteboard(url)
                historyExportURL = nil
            }
#endif
        }
    }
    
    private var header: some View {
        VStack(spacing: 12) {
            HStack(alignment: .center) {
                GoalProgressRing(progress: viewModel.goalCompletionFraction())
                    .frame(width: 54, height: 54)
                    .overlay(
                        VStack(spacing: 2) {
                            Text("Goal")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.0f%%", viewModel.goalCompletionFraction() * 100))
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(.primary)
                        }
                    )
                VStack(alignment: .leading, spacing: 4) {
                    if let goal = viewModel.goal {
                        Text(goal.goalType == "weekly" ? "Weekly Goal" : "Daily Goal")
                            .font(.headline)
                        Text("Completed: \(goal.completedCount) / \(goal.targetCount)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("Streak: \(goal.currentStreak) 🔥  Best: \(goal.bestStreak)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("No reading goal yet")
                            .font(.headline)
                        Text("Set one in settings to stay motivated")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Menu {
                    Picker("Sort", selection: $viewModel.sort) {
                        ForEach(ReadLaterService.SortOption.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    Toggle(isOn: $viewModel.includeReadItems) {
                        Label("Show Read", systemImage: "checkmark.circle")
                    }
                    Divider()
                    Button("Insights") { showingInsights = true }
                    Button("Reading Goal Settings") { showingGoalSettings = true }
                    Button("Reading Mode Settings") { showingAppearanceSettings = true }
                } label: {
                    Label("Options", systemImage: "ellipsis.circle")
                        .labelStyle(.iconOnly)
                        .font(.title3)
                }
            }
            .padding(.horizontal)
            if viewModel.isCelebratingGoal {
                celebrationBanner
            }
        }
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }
    
    private var content: some View {
        Group {
            if viewModel.items.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "text.book.closed")
                        .font(.system(size: 56))
                        .foregroundColor(.secondary)
                    Text(viewModel.includeReadItems ? "Nothing to show." : "No unread items in Read Later")
                        .font(.headline)
                        .foregroundColor(.primary)
                    if !viewModel.includeReadItems {
                        Button("Show reading history") {
                            viewModel.toggleIncludeRead()
                        }
                    }
                }
                .padding()
            } else {
                TabView(selection: $viewModel.selectedIndex) {
                    ForEach(Array(viewModel.items.enumerated()), id: \.offset) { index, bookmark in
                        ReaderPage(bookmark: bookmark,
                                   appearance: viewModel.appearance,
                                   progressHandler: { progress in viewModel.updateProgress(progress, for: bookmark) },
                                   reachedEnd: { viewModel.reachedEnd(of: bookmark) },
                                   toggleReadLater: { viewModel.toggleReadState(for: bookmark) },
                                   removeAction: { viewModel.removeFromList(bookmark) })
                        .tag(index)
                        .background(viewModel.appearance.theme.backgroundColor)
                        .onAppear {
                            viewModel.select(index: index)
                        }
                        .onDisappear {
                            viewModel.endSession()
                        }
                    }
                }
#if canImport(UIKit)
                .tabViewStyle(.page(indexDisplayMode: .never))
#endif
            }
        }
    }
    
    private var celebrationBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .foregroundColor(.yellow)
            Text("Goal achieved! Keep the streak alive ✨")
                .font(.subheadline.weight(.semibold))
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(0.15))
        )
        .padding(.horizontal)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
    
    private func exportHistory() {
        guard let url = viewModel.exportHistory() else { return }
        historyExportURL = url
#if os(iOS)
        showingHistoryShare = true
#endif
    }
    
#if os(macOS)
    private func copyHistoryURLToPasteboard(_ url: URL) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([url as NSURL])
    }
#endif
}

private struct ReaderPage: View {
    @ObservedObject var bookmark: Bookmark
    let appearance: ReadingAppearanceSettings
    let progressHandler: (Double) -> Void
    let reachedEnd: () -> Void
    let toggleReadLater: () -> Void
    let removeAction: () -> Void
    
    @State private var progress: Double = 0
    @State private var didTriggerCompletion = false
    
    private var textAlignment: TextAlignment { appearance.alignment.textAlignment }
    private var frameAlignment: Alignment { appearance.alignment == .center ? .center : .leading }
    private var vStackAlignment: HorizontalAlignment { appearance.alignment.multilineAlignment }
    
    var body: some View {
        ScrollView {
            VStack(alignment: vStackAlignment, spacing: appearance.margin) {
                header
                Divider()
                articleBody
                bottomSentinel
            }
            .padding(.horizontal, appearance.margin)
            .padding(.vertical, 24)
        }
        .background(appearance.theme.backgroundColor)
        .foregroundColor(appearance.theme.foregroundColor)
        .onAppear {
            progress = bookmark.readingProgressValue
        }
        .onDisappear {
            progressHandler(progress)
        }
    }
    
    private var header: some View {
        VStack(alignment: vStackAlignment, spacing: 12) {
            Text(bookmark.title ?? bookmark.url ?? "Untitled")
                .font(appearance.headingFont())
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: frameAlignment)
            if let host = URL(string: bookmark.url ?? "")?.host {
                Text(host)
                    .font(appearance.captionFont())
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
            HStack(spacing: 12) {
                Label(bookmark.estimatedReadingDescription ?? "Quick read", systemImage: "clock")
                    .font(appearance.captionFont())
                if bookmark.isReadValue {
                    Label("Read", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(appearance.captionFont())
                }
            }
            ProgressView(value: bookmark.readingProgressValue)
                .progressViewStyle(.linear)
                .tint(appearance.theme == .night || appearance.theme == .pitch ? .cyan : .cnAccent)
                .opacity(bookmark.readingProgressValue > 0 ? 1 : 0)
            HStack(spacing: 10) {
                Button(bookmark.isReadValue ? "Mark Unread" : "Mark Read") {
                    toggleReadLater()
                }
                .buttonStyle(.bordered)
                Button("Remove") {
                    removeAction()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    private var articleBody: some View {
        VStack(alignment: vStackAlignment, spacing: appearance.margin) {
            if let description = bookmark.bookmarkDescription, !description.isEmpty {
                Text(description)
                    .font(appearance.bodyFont())
                    .lineSpacing(appearance.lineHeight * 2)
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
            if let notes = bookmark.notes, !notes.isEmpty {
                Text(notes)
                    .font(appearance.bodyFont())
                    .lineSpacing(appearance.lineHeight * 2)
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
        }
    }
    
    private var bottomSentinel: some View {
        Color.clear
            .frame(height: 1)
            .onAppear {
                guard !didTriggerCompletion else { return }
                didTriggerCompletion = true
                progress = 1.0
                reachedEnd()
            }
    }
}

private struct GoalProgressRing: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.secondary.opacity(0.2), lineWidth: 6)
            Circle()
                .trim(from: 0, to: CGFloat(max(0, min(1, progress))))
                .stroke(AngularGradient(colors: [.accentColor, .purple, .pink], center: .center), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .animation(.spring(duration: 0.55), value: progress)
    }
}

private struct ReadLaterInsightsView: View {
    @ObservedObject var viewModel: ReadLaterViewModel
    let exportHistory: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var showAllHistory = false
    
    private var historyToDisplay: [Bookmark] {
        showAllHistory ? viewModel.history : Array(viewModel.history.prefix(20))
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    statsSection
                    if !viewModel.quickReads.isEmpty {
                        suggestionSection(title: "5-minute reads", subtitle: "Perfect when time is tight", icon: "timer", bookmarks: viewModel.quickReads)
                    }
                    if !viewModel.priorityReads.isEmpty {
                        suggestionSection(title: "Priority picks", subtitle: "High-priority articles to tackle next", icon: "exclamationmark.circle", bookmarks: viewModel.priorityReads)
                    }
                    if !viewModel.longReads.isEmpty {
                        suggestionSection(title: "Long reads", subtitle: "Set aside time for these deep dives", icon: "book", bookmarks: viewModel.longReads)
                    }
                    if !viewModel.eventRecommendations.isEmpty {
                        suggestionSection(title: "For upcoming meetings", subtitle: "Recommended before scheduled events", icon: "calendar", bookmarks: viewModel.eventRecommendations)
                    }
                    availableTimeSection
                    historySection
                }
                .padding()
            }
            .navigationTitle("Reading Insights")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Export History") { exportHistory() }
                }
            }
            .onAppear { viewModel.refreshInsights() }
        }
    }
    
    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Overview")
                .font(.headline)
            if let stats = viewModel.stats {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 16)], spacing: 16) {
                    StatCard(title: "Completed", value: "\(stats.totalCompleted)", caption: "All time")
                    StatCard(title: "Est. minutes", value: "\(stats.totalEstimatedMinutes)", caption: "Estimated reading")
                    StatCard(title: "Time spent", value: formatTimeSpent(stats.totalTimeSpent), caption: "Tracked sessions")
                    StatCard(title: "Avg/min", value: String(format: "%.1f", stats.averageMinutesPerArticle), caption: "Per article")
                    StatCard(title: "Streak", value: "\(stats.currentStreak)", caption: "Current · Best \(stats.bestStreak)")
                    StatCard(title: "This week", value: "\(stats.completedThisWeek)", caption: "This month \(stats.completedThisMonth)")
                }
            } else {
                Text("No reading history yet. Complete a few articles to see your stats.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func suggestionSection(title: String, subtitle: String, icon: String, bookmarks: [Bookmark]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: icon)
                    .font(.headline)
                Spacer()
            }
            Text(subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(bookmarks, id: \.objectID) { bookmark in
                        SuggestionCard(bookmark: bookmark)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private var availableTimeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Time-friendly picks", systemImage: "hourglass")
                .font(.headline)
            Text("Tell us how much time you have and we’ll line up a quick stack.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Slider(value: Binding(
                get: { Double(viewModel.availableTimeMinutes) },
                set: { viewModel.availableTimeMinutes = Int($0) }
            ), in: 5...60, step: 5) {
                Text("Available minutes")
            }
            .tint(.accentColor)
            HStack {
                Text("Available time")
                Spacer()
                Text("\(viewModel.availableTimeMinutes) min")
                    .fontWeight(.semibold)
            }
            .font(.caption)
            if viewModel.timeFriendlyReads.isEmpty {
                Text("No matches yet. Try expanding the time window or add more bookmarks to Read Later.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(viewModel.timeFriendlyReads, id: \.objectID) { bookmark in
                        HistoryRow(bookmark: bookmark, actionTitle: "Open") {
                            if let urlString = bookmark.url, let url = URL(string: urlString) {
                                #if os(iOS)
                                UIApplication.shared.open(url)
                                #else
                                NSWorkspace.shared.open(url)
                                #endif
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Reading history", systemImage: "clock.arrow.circlepath")
                .font(.headline)
            if viewModel.history.isEmpty {
                Text("Once you finish a few articles, they’ll appear here with reading time and an option to re-queue them.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(historyToDisplay, id: \.objectID) { bookmark in
                        HistoryRow(bookmark: bookmark, actionTitle: "Re-read") {
                            viewModel.queueForReRead(bookmark)
                        }
                    }
                    if viewModel.history.count > historyToDisplay.count {
                        Button(showAllHistory ? "Show less" : "Show all history") {
                            withAnimation { showAllHistory.toggle() }
                        }
                        .font(.caption)
                    }
                }
            }
        }
    }
    
    private func formatTimeSpent(_ interval: TimeInterval) -> String {
        guard interval > 0 else { return "0m" }
        let minutes = interval / 60
        if minutes >= 60 {
            let hours = floor(minutes / 60)
            let mins = Int(minutes) % 60
            return String(format: "%.0fh %dm", hours, mins)
        }
        return String(format: "%.0fm", minutes)
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let caption: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(value)
                .font(.title2.bold())
            Text(title)
                .font(.subheadline)
            Text(caption)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.cnSecondaryBackground))
    }
}

private struct SuggestionCard: View {
    @ObservedObject var bookmark: Bookmark
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(bookmark.title ?? bookmark.url ?? "Untitled")
                .font(.headline)
                .lineLimit(2)
            if let estimate = bookmark.estimatedReadingDescription {
                Label(estimate, systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let host = URL(string: bookmark.url ?? "")?.host {
                Text(host)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(width: 200, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.cnSecondaryBackground))
    }
}

private struct HistoryRow: View {
    @ObservedObject var bookmark: Bookmark
    let actionTitle: String
    let action: () -> Void
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(bookmark.title ?? bookmark.url ?? "Untitled")
                    .font(.subheadline.bold())
                    .lineLimit(2)
                Spacer()
                Button(actionTitle, action: action)
                    .buttonStyle(.bordered)
            }
            if let date = bookmark.readDate {
                Text(dateFormatter.string(from: date))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 12) {
                if let estimate = bookmark.estimatedReadingDescription {
                    Label(estimate, systemImage: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                if bookmark.totalReadingTimeValue > 0 {
                    let minutes = bookmark.totalReadingTimeValue / 60
                    Label(String(format: "%.1f min", minutes), systemImage: "timer")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.cnSecondaryBackground))
    }
}

private struct ReadingGoalSettingsView: View {
    @ObservedObject var viewModel: ReadLaterViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedGoalType: ReadLaterService.GoalType
    @State private var targetCount: Int
    
    init(viewModel: ReadLaterViewModel) {
        self.viewModel = viewModel
        let goal = viewModel.goal
        _selectedGoalType = State(initialValue: ReadLaterService.GoalType(rawValue: goal?.goalType ?? "daily") ?? .daily)
        _targetCount = State(initialValue: max(Int(goal?.targetCount ?? 3), 1))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Goal cadence") {
                    Picker("Goal type", selection: $selectedGoalType) {
                        Text("Daily").tag(ReadLaterService.GoalType.daily)
                        Text("Weekly").tag(ReadLaterService.GoalType.weekly)
                    }
                    .pickerStyle(.segmented)
                    Stepper(value: $targetCount, in: 1...20) {
                        Text("Target articles: \(targetCount)")
                    }
                }
                if let goal = viewModel.goal {
                    Section("Current streak") {
                        Text("Completed: \(goal.completedCount) / \(goal.targetCount)")
                        Text("Current streak: \(goal.currentStreak)")
                        Text("Best streak: \(goal.bestStreak)")
                    }
                }
                Section {
                    Button("Reset Goal", role: .destructive) {
                        viewModel.clearGoal()
                        dismiss()
                    }
                    .disabled(viewModel.goal == nil)
                }
            }
            .navigationTitle("Reading Goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.updateGoal(type: selectedGoalType, target: targetCount)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ReadingAppearanceSettingsSheet: View {
    @ObservedObject var viewModel: ReadLaterViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var settings: ReadingAppearanceSettings
    
    init(viewModel: ReadLaterViewModel) {
        self.viewModel = viewModel
        _settings = State(initialValue: viewModel.appearance)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Typography") {
                    Picker("Font", selection: $settings.fontFamily) {
                        ForEach(ReadingAppearanceSettings.FontFamily.allCases) { family in
                            Text(family.displayName).tag(family)
                        }
                    }
                    Slider(value: $settings.fontSize, in: 14...28, step: 1) {
                        Text("Font size")
                    }
                    HStack {
                        Text("Font size")
                        Spacer()
                        Text("\(Int(settings.fontSize)) pt")
                    }
                    Slider(value: $settings.lineHeight, in: 1.2...2.0, step: 0.05) {
                        Text("Line height")
                    }
                    HStack {
                        Text("Line height")
                        Spacer()
                        Text(String(format: "%.2f", settings.lineHeight))
                    }
                    Picker("Alignment", selection: $settings.alignment) {
                        ForEach(ReadingAppearanceSettings.TextAlignmentOption.allCases) { alignment in
                            Text(alignment.displayName).tag(alignment)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                Section("Theme") {
                    Picker("Background", selection: $settings.theme) {
                        ForEach(ReadingAppearanceSettings.Theme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    Slider(value: $settings.margin, in: 10...60, step: 2) {
                        Text("Margin")
                    }
                    HStack {
                        Text("Margin")
                        Spacer()
                        Text("\(Int(settings.margin)) pt")
                    }
                }
                Section("Preview") {
                    VStack(alignment: .leading, spacing: settings.margin * 0.8) {
                        Text("Design your ideal reading experience")
                            .font(settings.headingFont())
                            .multilineTextAlignment(settings.alignment.textAlignment)
                        Text("Adjust font, spacing, and background to create a distraction-free environment tailored to your reading habits.")
                            .font(settings.bodyFont())
                            .lineSpacing(settings.lineHeight * 2)
                            .multilineTextAlignment(settings.alignment.textAlignment)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(settings.theme.backgroundColor)
                    .foregroundColor(settings.theme.foregroundColor)
                    .cornerRadius(12)
                }
                Section {
                    Button("Reset to Defaults") {
                        settings = ReadingAppearanceSettings(
                            fontFamily: .serif,
                            fontSize: 17,
                            lineHeight: 1.4,
                            theme: .day,
                            margin: 20,
                            alignment: .leading
                        )
                    }
                }
            }
            .navigationTitle("Reading Mode")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: settings) { _, newValue in
                viewModel.updateAppearance(newValue)
            }
        }
    }
}
