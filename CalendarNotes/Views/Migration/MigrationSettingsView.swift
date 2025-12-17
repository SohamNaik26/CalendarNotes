//
//  MigrationSettingsView.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import SwiftUI

/// Settings view for migration management
struct MigrationSettingsView: View {
	@StateObject private var migrationService = MigrationService.shared
	@State private var showLogs = false
	@State private var showConfirmReset = false
	@State private var showConfirmRemigration = false
	
	var body: some View {
		List {
			// Migration Status Section
			Section {
				HStack {
					Text("Migration Status")
					Spacer()
					StatusBadge(state: migrationService.migrationState)
				}
				
				if migrationService.migrationState == .completed,
				   let completedDate = UserDefaults.standard.object(forKey: "migration.postgres.completedAt") as? Date {
					HStack {
						Text("Completed")
						Spacer()
						Text(completedDate, style: .relative)
							.foregroundColor(.secondary)
					}
				}
				
				if let backupPath = UserDefaults.standard.string(forKey: "migration.postgres.backup") {
					HStack {
						Text("Backup Location")
						Spacer()
						Text(URL(fileURLWithPath: backupPath).lastPathComponent)
							.foregroundColor(.secondary)
							.lineLimit(1)
					}
				}
			} header: {
				Text("Status")
			}
			
			// Actions Section
			Section {
				if migrationService.isMigrationNeeded() {
					Button(action: {
						Task {
							try? await migrationService.startMigration()
						}
					}) {
						HStack {
							Image(systemName: "arrow.triangle.2.circlepath")
							Text("Start Migration")
						}
					}
				}
				
				if migrationService.migrationState == .completed {
					Button(action: {
						showConfirmRemigration = true
					}) {
						HStack {
							Image(systemName: "arrow.clockwise")
							Text("Force Re-migration")
						}
						.foregroundColor(.orange)
					}
				}
				
				Button(action: {
					showConfirmReset = true
				}) {
					HStack {
						Image(systemName: "arrow.counterclockwise")
						Text("Reset Migration State")
					}
					.foregroundColor(.red)
				}
			} header: {
				Text("Actions")
			}
			
			// Logs Section
			Section {
				Button(action: {
					showLogs = true
				}) {
					HStack {
						Image(systemName: "doc.text")
						Text("View Migration Logs")
						Spacer()
						Text("\(migrationService.getMigrationLogs().count)")
							.foregroundColor(.secondary)
						Image(systemName: "chevron.right")
							.font(.caption)
							.foregroundColor(.secondary)
					}
				}
				
				Button(action: {
					exportBackup()
				}) {
					HStack {
						Image(systemName: "square.and.arrow.up")
						Text("Export Pre-migration Backup")
					}
				}
			} header: {
				Text("Logs & Backup")
			}
			
			// Information Section
			Section {
				VStack(alignment: .leading, spacing: 8) {
					Text("About Migration")
						.font(.headline)
					
					Text("Migration moves your local Core Data to PostgreSQL. After migration, Core Data will be used as a local cache, and PostgreSQL will be the primary database.")
						.font(.caption)
						.foregroundColor(.secondary)
				}
			}
		}
		.navigationTitle("Migration Settings")
#if os(iOS)
		.navigationBarTitleDisplayMode(.inline)
#endif
		.sheet(isPresented: $showLogs) {
			MigrationLogsView()
		}
		.alert("Reset Migration State", isPresented: $showConfirmReset) {
			Button("Cancel", role: .cancel) { }
			Button("Reset", role: .destructive) {
				migrationService.resetMigrationState()
			}
		} message: {
			Text("This will reset the migration state and allow you to run migration again. This does not delete any data.")
		}
		.alert("Force Re-migration", isPresented: $showConfirmRemigration) {
			Button("Cancel", role: .cancel) { }
			Button("Re-migrate", role: .destructive) {
				Task {
					try? await migrationService.forceRemigration()
				}
			}
		} message: {
			Text("This will re-run the migration process. Duplicate data may be created in PostgreSQL.")
		}
	}
	
	private func exportBackup() {
		guard let backupPath = UserDefaults.standard.string(forKey: "migration.postgres.backup") else {
			return
		}
		
		let backupURL = URL(fileURLWithPath: backupPath)
		
		#if os(iOS)
		let activityVC = UIActivityViewController(activityItems: [backupURL], applicationActivities: nil)
		if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
		   let rootVC = windowScene.windows.first?.rootViewController {
			rootVC.present(activityVC, animated: true)
		}
		#elseif os(macOS)
		NSWorkspace.shared.open(backupURL)
		#endif
	}
}

struct StatusBadge: View {
	let state: MigrationState
	
	var body: some View {
		Text(state.displayName)
			.font(.caption)
			.fontWeight(.semibold)
			.padding(.horizontal, 8)
			.padding(.vertical, 4)
			.background(state.color.opacity(0.2))
			.foregroundColor(state.color)
			.cornerRadius(8)
	}
}

extension MigrationState {
	var displayName: String {
		switch self {
		case .notStarted: return "Not Started"
		case .inProgress: return "In Progress"
		case .completed: return "Completed"
		case .failed: return "Failed"
		case .cancelled: return "Cancelled"
		case .partial: return "Partial"
		}
	}
	
	var color: Color {
		switch self {
		case .notStarted: return .gray
		case .inProgress: return .blue
		case .completed: return .green
		case .failed: return .red
		case .cancelled: return .orange
		case .partial: return .yellow
		}
	}
}

/// View for displaying migration logs
struct MigrationLogsView: View {
	@StateObject private var migrationService = MigrationService.shared
	@Environment(\.dismiss) private var dismiss
	
	var logs: [MigrationLogEntry] {
		migrationService.getMigrationLogs().reversed()
	}
	
	var body: some View {
		NavigationView {
			List {
				if logs.isEmpty {
					Text("No migration logs available")
						.foregroundColor(.secondary)
						.frame(maxWidth: .infinity, alignment: .center)
						.padding()
				} else {
					ForEach(logs) { log in
						LogEntryRow(log: log)
					}
				}
			}
			.navigationTitle("Migration Logs")
#if os(iOS)
			.navigationBarTitleDisplayMode(.inline)
#endif
			.toolbar {
				#if os(iOS)
				ToolbarItem(placement: .navigationBarTrailing) {
					Button("Done") {
						dismiss()
					}
				}
				#else
				ToolbarItem {
					Button("Done") {
						dismiss()
					}
				}
				#endif
			}
		}
	}
}

struct LogEntryRow: View {
	let log: MigrationLogEntry
	
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack {
				Image(systemName: log.success ? "checkmark.circle.fill" : "xmark.circle.fill")
					.foregroundColor(log.success ? .green : .red)
				
				Text(log.entity)
					.font(.headline)
				
				Spacer()
				
				Text(log.timestamp, style: .relative)
					.font(.caption)
					.foregroundColor(.secondary)
			}
			
			if log.itemsMigrated > 0 {
				Text("\(log.itemsMigrated) items migrated")
					.font(.caption)
					.foregroundColor(.secondary)
			}
			
			if let error = log.error {
				Text(error)
					.font(.caption)
					.foregroundColor(.red)
			}
		}
		.padding(.vertical, 4)
	}
}

#Preview {
	NavigationView {
		MigrationSettingsView()
	}
}

