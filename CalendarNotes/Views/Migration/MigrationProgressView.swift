//
//  MigrationProgressView.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// View for displaying migration progress
struct MigrationProgressView: View {
	
	// MARK: - Helper Colors
	
	private var gray6Color: Color {
		#if canImport(UIKit)
		return Color(uiColor: UIColor.systemGray6)
		#elseif canImport(AppKit)
		return Color(nsColor: NSColor.controlBackgroundColor)
		#else
		return Color.gray.opacity(0.1)
		#endif
	}
	
	private var gray5Color: Color {
		#if canImport(UIKit)
		return Color(uiColor: UIColor.systemGray5)
		#elseif canImport(AppKit)
		return Color(nsColor: NSColor.controlBackgroundColor)
		#else
		return Color.gray.opacity(0.15)
		#endif
	}
	@StateObject private var migrationService = MigrationService.shared
	@Environment(\.dismiss) private var dismiss
	
	var body: some View {
		VStack(spacing: 0) {
			ScrollView {
				VStack(spacing: 24) {
					// Header
					VStack(spacing: 8) {
						Image(systemName: "arrow.triangle.2.circlepath")
							.font(.system(size: 48))
							.foregroundColor(.blue)
						
						Text("Migrating to PostgreSQL")
							.font(.title2)
							.fontWeight(.semibold)
						
						Text("Moving your data to the cloud")
							.font(.subheadline)
							.foregroundColor(.secondary)
					}
					.padding(.top, 40)
					
					// Progress Section
					VStack(spacing: 16) {
						// Progress Bar
						VStack(alignment: .leading, spacing: 8) {
							HStack {
								Text(migrationService.currentEntity ?? "Preparing...")
									.font(.headline)
								
								Spacer()
								
								Text("\(Int(migrationService.migrationProgress.progressPercentage))%")
									.font(.headline)
									.foregroundColor(.secondary)
							}
							
							ProgressView(value: migrationService.migrationProgress.progress, total: 1.0)
								.progressViewStyle(LinearProgressViewStyle(tint: .blue))
								.frame(height: 8)
							
							// Count and Time
							HStack {
								Text("\(migrationService.migrationProgress.currentStep) of \(migrationService.migrationProgress.totalSteps) items")
									.font(.caption)
									.foregroundColor(.secondary)
								
								Spacer()
								
								if let timeRemaining = migrationService.migrationProgress.formattedTimeRemaining {
									Text("~\(timeRemaining) remaining")
										.font(.caption)
										.foregroundColor(.secondary)
								}
							}
						}
						.padding()
						.background(gray6Color)
						.cornerRadius(12)
					}
					.padding(.horizontal)
					
					// Status Message
					if let error = migrationService.error {
						VStack(spacing: 8) {
							Image(systemName: "exclamationmark.triangle.fill")
								.font(.title2)
								.foregroundColor(.orange)
							
							Text("Migration Error")
								.font(.headline)
							
							Text(error.localizedDescription)
								.font(.caption)
								.foregroundColor(.secondary)
								.multilineTextAlignment(.center)
						}
						.padding()
						.frame(maxWidth: .infinity)
						.background(gray6Color)
						.cornerRadius(12)
						.padding(.horizontal)
					}
				}
				.padding(.bottom, 120) // Extra padding for button space
			}
			
			// Action Buttons - Fixed at bottom
			VStack(spacing: 0) {
				Divider()
				VStack(spacing: 12) {
				if migrationService.isMigrating {
					Button(action: {
						migrationService.cancelMigration()
					}) {
						HStack {
							Image(systemName: "xmark.circle.fill")
							Text("Cancel Migration")
						}
						.frame(maxWidth: .infinity)
						.padding()
						.background(gray5Color)
						.foregroundColor(.primary)
						.cornerRadius(12)
					}
				} else if migrationService.migrationState == .completed {
					Button(action: {
						dismiss()
					}) {
						HStack {
							Image(systemName: "checkmark.circle.fill")
							Text("Done")
						}
						.frame(maxWidth: .infinity)
						.padding()
						.background(Color.blue)
						.foregroundColor(.white)
						.cornerRadius(12)
					}
				} else if migrationService.migrationState == .failed {
					VStack(spacing: 12) {
						Button(action: {
							Task {
								try? await migrationService.startMigration()
							}
						}) {
							HStack {
								Image(systemName: "arrow.clockwise")
								Text("Retry Migration")
							}
							.frame(maxWidth: .infinity)
							.padding()
							.background(Color.blue)
							.foregroundColor(.white)
							.cornerRadius(12)
						}
						
						Button(action: {
							dismiss()
						}) {
							Text("Close")
								.frame(maxWidth: .infinity)
								.padding()
								.background(gray5Color)
								.foregroundColor(.primary)
								.cornerRadius(12)
						}
					}
				}
				}
				.padding(.horizontal)
				.padding(.top, 12)
				.padding(.bottom, 20)
				.background(Color.cnBackground)
			}
		}
#if os(iOS)
		.navigationBarTitleDisplayMode(.inline)
#endif
		.onAppear {
			if migrationService.migrationState == .notStarted {
				Task {
					try? await migrationService.startMigration()
				}
			}
		}
	}
}

/// Compact migration banner for showing in settings
struct MigrationBannerView: View {
	@StateObject private var migrationService = MigrationService.shared
	@State private var showMigrationView = false
	
	// MARK: - Helper Colors
	
	private var gray6Color: Color {
		#if canImport(UIKit)
		return Color(uiColor: UIColor.systemGray6)
		#elseif canImport(AppKit)
		return Color(nsColor: NSColor.controlBackgroundColor)
		#else
		return Color.gray.opacity(0.1)
		#endif
	}
	
	var body: some View {
		if migrationService.isMigrationNeeded() {
			Button(action: {
				showMigrationView = true
			}) {
				HStack {
					Image(systemName: "arrow.triangle.2.circlepath")
						.foregroundColor(.blue)
					
					VStack(alignment: .leading, spacing: 4) {
						Text("Data Migration Available")
							.font(.headline)
							.foregroundColor(.primary)
						
						Text("Migrate your data to PostgreSQL")
							.font(.caption)
							.foregroundColor(.secondary)
					}
					
					Spacer()
					
					Image(systemName: "chevron.right")
						.foregroundColor(.secondary)
				}
				.padding()
				.background(gray6Color)
				.cornerRadius(12)
			}
			.sheet(isPresented: $showMigrationView) {
				NavigationView {
					MigrationProgressView()
						.navigationTitle("Data Migration")
#if os(iOS)
						.navigationBarTitleDisplayMode(.inline)
#endif
				}
			}
		} else if migrationService.migrationState == .completed {
			HStack {
				Image(systemName: "checkmark.circle.fill")
					.foregroundColor(.green)
				
				VStack(alignment: .leading, spacing: 4) {
					Text("Migration Complete")
						.font(.headline)
						.foregroundColor(.primary)
					
					Text("Your data has been migrated to PostgreSQL")
						.font(.caption)
						.foregroundColor(.secondary)
				}
				
				Spacer()
			}
			.padding()
			.background(gray6Color)
			.cornerRadius(12)
		}
	}
}

#Preview {
	NavigationView {
		MigrationProgressView()
	}
}

