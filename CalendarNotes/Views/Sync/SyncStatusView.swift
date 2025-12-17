//
//  SyncStatusView.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import SwiftUI

struct SyncStatusView: View {
	@EnvironmentObject private var syncManager: SyncManager
	@EnvironmentObject private var conflictStore: ConflictStore
	@StateObject private var status = SyncStatusStore.shared
	
	@State private var showDetails: Bool = false
	
	var body: some View {
		if status.showIndicator {
			Button {
				showDetails = true
			} label: {
				compactIndicator
			}
			.buttonStyle(.plain)
			.sheet(isPresented: $showDetails) {
				detailsSheet
					.presentationDetents([.medium, .large])
			}
		}
	}
	
	private var compactIndicator: some View {
		HStack(spacing: 8) {
			indicatorIcon
			switch status.indicator {
			case .syncing(let progress):
				Text("\(Int((progress * 100).rounded()))%")
					.font(.caption2)
					.foregroundColor(.secondary)
			case .synced(let last):
				Text(lastText(last))
					.font(.caption2)
					.foregroundColor(.secondary)
			case .error:
				Text("Error")
					.font(.caption2)
					.foregroundColor(.secondary)
			case .offline:
				Text("Offline")
					.font(.caption2)
					.foregroundColor(.secondary)
			case .pending(let count):
				Text("\(count) pending")
					.font(.caption2)
					.foregroundColor(.secondary)
			}
		}
		.padding(.horizontal, 10)
		.padding(.vertical, 6)
		.background(Color.cnSecondaryBackground)
		.clipShape(Capsule())
		.shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
	}
	
	@ViewBuilder
	private var indicatorIcon: some View {
		switch status.indicator {
		case .syncing:
			ProgressView()
				.progressViewStyle(.circular)
		case .synced:
			Image(systemName: "checkmark.circle.fill")
				.foregroundColor(.green)
		case .error:
			Image(systemName: "xmark.octagon.fill")
				.foregroundColor(.red)
		case .offline:
			Image(systemName: "wifi.slash")
				.foregroundColor(.orange)
		case .pending:
			Image(systemName: "clock.badge.exclamationmark.fill")
				.foregroundColor(.yellow)
		}
	}
	
	private func lastText(_ last: Date?) -> String {
		guard let last else { return "Synced" }
		return "Last \(last.formatted(date: .omitted, time: .shortened))"
	}
	
	private var detailsSheet: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 16) {
					overallSection
					perEntitySection
					controlsSection
					infoSection
					historySection
				}
				.padding()
			}
			.navigationTitle("Sync Status")
			.toolbar {
				ToolbarItem(placement: .primaryAction) {
					Button("Done") { showDetails = false }
				}
			}
		}
	}
	
	private var overallSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack {
				Text("Overall Progress")
					.font(.headline)
				Spacer()
				switch status.indicator {
				case .syncing(let progress):
					Text("\(Int((progress * 100).rounded()))%")
						.foregroundColor(.secondary)
				case .synced(let last):
					Text(lastText(last))
						.foregroundColor(.secondary)
				case .error(let msg):
					Text(msg)
						.foregroundColor(.red)
				case .offline:
					Text("Offline mode")
						.foregroundColor(.orange)
				case .pending(let count):
					Text("\(count) changes pending")
						.foregroundColor(.yellow)
				}
			}
			ProgressView(value: status.overallProgress)
				.progressViewStyle(.linear)
		}
		.padding(12)
		.background(Color.cnSecondaryBackground)
		.clipShape(RoundedRectangle(cornerRadius: 12))
	}
	
	private var perEntitySection: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Per-Entity Status")
				.font(.headline)
			VStack(spacing: 8) {
				ForEach(status.perEntity) { entity in
					HStack {
						Image(systemName: entity.iconSystemName)
							.foregroundColor(.accentColor)
						Text(entity.name)
						Spacer()
						switch entity.state {
						case .synced(let total):
							Label("\(total) items", systemImage: "checkmark.circle")
								.foregroundColor(.green)
						case .syncing(let done, let total):
							Label("\(done) of \(total)", systemImage: "arrow.triangle.2.circlepath")
								.foregroundColor(.accentColor)
						case .error(let failed):
							Label("\(failed) failed", systemImage: "exclamationmark.triangle.fill")
								.foregroundColor(.red)
						case .pending(let changes):
							Label("\(changes) pending", systemImage: "clock")
								.foregroundColor(.yellow)
						}
					}
					.padding(8)
					.background(Color.cnSecondaryBackground)
					.clipShape(RoundedRectangle(cornerRadius: 10))
				}
			}
		}
	}
	
	private var controlsSection: some View {
		VStack(alignment: .leading, spacing: 12) {
			Text("Controls")
				.font(.headline)
			HStack {
				Button {
					syncManager.triggerManualSync()
				} label: {
					Label("Sync Now", systemImage: "arrow.clockwise")
				}
				.buttonStyle(.borderedProminent)
				
				if conflictStore.unresolvedCount > 0 {
					NavigationLink {
						ConflictResolutionView()
							.environmentObject(conflictStore)
					} label: {
						Label("Resolve Conflicts", systemImage: "exclamationmark.triangle.fill")
					}
					.buttonStyle(.bordered)
				}
			}
			
			HStack {
				Button {
					// Placeholder for log viewing
				} label: {
					Label("View Logs", systemImage: "doc.text.magnifyingglass")
				}
				.buttonStyle(.bordered)
				
				Button {
					// Placeholder: navigate to app's sync settings screen, if any
				} label: {
					Label("Sync Settings", systemImage: "gearshape")
				}
				.buttonStyle(.bordered)
			}
			
			Divider()
			
			Toggle("Auto-sync", isOn: Binding(
				get: { status.autoSyncEnabled },
				set: { status.autoSyncEnabled = $0; if $0 { syncManager.triggerManualSync() } }
			))
			
			HStack {
				Text("Sync frequency")
				Spacer()
				Menu("\(status.frequencyMinutes) min") {
					ForEach([5, 15, 30, 60], id: \.self) { m in
						Button("\(m) minutes") { status.frequencyMinutes = m }
					}
				}
			}
			
			Toggle("WiFi-only sync", isOn: Binding(
				get: { status.wifiOnly },
				set: { status.wifiOnly = $0 }
			))
			
			Toggle("Sync on cellular data", isOn: Binding(
				get: { !status.wifiOnly },
				set: { status.wifiOnly = !$0 }
			))
			.tint(.orange)
			
			Toggle("Background sync", isOn: Binding(
				get: { status.backgroundSyncEnabled },
				set: { status.backgroundSyncEnabled = $0 }
			))
			
			Toggle("Show sync status indicator", isOn: Binding(
				get: { status.showIndicator },
				set: { status.showIndicator = $0 }
			))
		}
		.padding(12)
		.background(Color.cnSecondaryBackground)
		.clipShape(RoundedRectangle(cornerRadius: 12))
	}
	
	private var infoSection: some View {
		VStack(alignment: .leading, spacing: 8) {
			Text("Info")
				.font(.headline)
			HStack {
				Label("Last successful sync", systemImage: "checkmark")
				Spacer()
				Text(status.lastSuccessfulSync?.formatted(date: .abbreviated, time: .shortened) ?? "—")
					.foregroundColor(.secondary)
			}
			HStack {
				Label("Next scheduled sync", systemImage: "calendar")
				Spacer()
				Text(status.nextScheduledSync?.formatted(date: .abbreviated, time: .shortened) ?? "—")
					.foregroundColor(.secondary)
			}
			HStack {
				Label("Network", systemImage: "wifi")
				Spacer()
				Text(status.networkStatusDescription)
					.foregroundColor(.secondary)
			}
			HStack {
				Label("Pending operations", systemImage: "clock")
				Spacer()
				Text("\(status.pendingOperations)")
					.foregroundColor(.secondary)
			}
		}
		.padding(12)
		.background(Color.cnSecondaryBackground)
		.clipShape(RoundedRectangle(cornerRadius: 12))
	}
	
	private var historySection: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack {
				Text("Recent Sync Events")
					.font(.headline)
				Spacer()
				Button {
					// Stub: export logs
					let encoder = JSONEncoder()
					encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
					if let data = try? encoder.encode(status.recentEvents),
					   let text = String(data: data, encoding: .utf8) {
						print(text)
					}
				} label: {
					Label("Export", systemImage: "square.and.arrow.up")
				}
			}
			
			if status.recentEvents.isEmpty {
				Text("No recent events")
					.foregroundColor(.secondary)
			} else {
				ForEach(status.recentEvents) { event in
					HStack(alignment: .top, spacing: 8) {
						Image(systemName: icon(for: event))
							.foregroundColor(color(for: event))
						VStack(alignment: .leading, spacing: 2) {
							Text(event.timestamp.formatted(date: .abbreviated, time: .shortened))
								.font(.caption)
								.foregroundColor(.secondary)
							Text(event.message)
							if event.items > 0 {
								Text("\(event.items) items")
									.font(.caption2)
									.foregroundColor(.secondary)
							}
						}
						Spacer()
					}
					.padding(8)
					.background(Color.cnSecondaryBackground)
					.clipShape(RoundedRectangle(cornerRadius: 10))
				}
			}
		}
	}
	
	private func icon(for event: SyncEventLog) -> String {
		switch event.level {
		case .info: return "info.circle"
		case .warning: return "exclamationmark.triangle.fill"
		case .error: return "xmark.octagon.fill"
		}
	}
	private func color(for event: SyncEventLog) -> Color {
		switch event.level {
		case .info: return .accentColor
		case .warning: return .orange
		case .error: return .red
		}
	}
}


