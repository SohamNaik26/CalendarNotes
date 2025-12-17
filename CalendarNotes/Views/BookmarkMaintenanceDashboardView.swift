//
//  BookmarkMaintenanceDashboardView.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import SwiftUI

struct BookmarkMaintenanceDashboardView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var maintenanceService = BookmarkMaintenanceService.shared

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    healthScoreSection
                    issuesSection
                    scheduledTasksSection
                }
                .padding()
            }
            .navigationTitle("Bookmark Maintenance")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: maintenanceService.refreshHealth) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .help("Refresh Health Snapshot")
                }
            }
        }
        .onAppear {
            maintenanceService.refreshHealth()
        }
    }

    private var healthScoreSection: some View {
        let snapshot = maintenanceService.healthSnapshot
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Health Score")
                        .font(.headline)
                    Text("Overall bookmark collection health")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(String(format: "%.0f", snapshot.healthScore))
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(snapshot.healthScore >= 80 ? .green : (snapshot.healthScore >= 60 ? .orange : .red))
            }

            ProgressView(value: snapshot.healthScore, total: 100)
                .accentColor(.accentColor)

            HStack(spacing: 12) {
                metricChip(title: "Broken", value: snapshot.brokenLinks)
                metricChip(title: "Duplicates", value: snapshot.duplicateGroups)
                metricChip(title: "Untagged", value: snapshot.untaggedCount)
                metricChip(title: "Stale", value: snapshot.staleCount)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cnSecondaryBackground)
        )
    }

    private func metricChip(title: String, value: Int) -> some View {
        VStack {
            Text("\(value)")
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.cnBackground)
        )
    }

    private var issuesSection: some View {
        let suggestions = maintenanceService.healthSnapshot.suggestions
        return VStack(alignment: .leading, spacing: 16) {
            Text("Maintenance Suggestions")
                .font(.headline)
            if suggestions.isEmpty {
                Text("No issues detected. Great job keeping your bookmarks healthy!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(suggestions) { suggestion in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(suggestion.title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(suggestion.detail)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.cnSecondaryBackground)
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cnSecondaryBackground.opacity(0.7))
        )
    }

    private var scheduledTasksSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Scheduled Tasks")
                .font(.headline)

            if maintenanceService.tasks.isEmpty {
                Text("No maintenance tasks scheduled yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ForEach(maintenanceService.tasks) { task in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(task.typeTitle)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                            statusBadge(for: task.status)
                        }
                        if let last = task.lastRun {
                            Text("Last run: \(formatted(date: last))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        if let next = task.nextRun {
                            Text("Next run: \(formatted(date: next))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.cnBackground)
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cnSecondaryBackground)
        )
    }

    private func formatted(date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func statusBadge(for status: MaintenanceTaskStatus) -> some View {
        let text: String
        let color: Color
        switch status {
        case .idle:
            text = "Idle"
            color = .secondary
        case .running:
            text = "Running"
            color = .blue
        case .scheduled:
            text = "Scheduled"
            color = .green
        case .failed:
            text = "Failed"
            color = .red
        }
        return Text(text)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }
}

private extension MaintenanceTaskSummary.TaskType {
    var title: String {
        switch self {
        case .linkCheck: return "Link Checker"
        case .duplicateScan: return "Duplicate Scan"
        case .cleanup: return "Cleanup"
        case .autoArchive: return "Auto Archive"
        }
    }
}

private extension MaintenanceTaskSummary {
    var typeTitle: String { type.title }
}

struct BookmarkMaintenanceDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        BookmarkMaintenanceDashboardView()
    }
}
