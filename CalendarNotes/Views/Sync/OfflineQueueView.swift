//
//  OfflineQueueView.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import SwiftUI

struct OfflineQueueView: View {
	@State private var operations: [OfflineOperationQueue.Operation] = []
	@State private var filterFailedOnly: Bool = false
	@State private var observerToken: NSObjectProtocol?
	
	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack {
				Text("Offline Operations")
					.font(.title2.bold())
				Spacer()
				Toggle("Show Failed Only", isOn: $filterFailedOnly)
					.toggleStyle(.switch)
					.labelsHidden()
			}
			
			List(filteredOps()) { op in
				VStack(alignment: .leading, spacing: 4) {
					HStack {
						Text("\(op.operationType.rawValue.uppercased())")
							.font(.caption.bold())
							.padding(.horizontal, 6)
							.padding(.vertical, 2)
							.background(badgeColor(for: op.operationType))
							.foregroundColor(.white)
							.cornerRadius(4)
						Text(op.entityType)
							.font(.headline)
						Spacer()
						Text(op.status.rawValue.capitalized)
							.font(.subheadline)
							.foregroundColor(statusColor(for: op.status))
					}
					Text("ID: \(op.entityId.uuidString)")
						.font(.caption)
						.foregroundColor(.secondary)
					HStack(spacing: 16) {
						Text("Attempts: \(op.attemptCount)")
						Text("Created: \(op.createdAt.formatted(date: .abbreviated, time: .standard))")
						if let last = op.lastAttemptAt {
							Text("Last Attempt: \(last.formatted(date: .abbreviated, time: .standard))")
						}
					}
					.font(.caption2)
					.foregroundColor(.secondary)
				}
			}
			
			HStack {
				Button("Retry Failed") {
					OfflineOperationQueue.shared.retryAllFailedNow()
					reload()
				}
				Button("Clear Failed") {
					OfflineOperationQueue.shared.clearFailed()
					reload()
				}
				Spacer()
				Button("Close") {
					// handled by parent, or dismiss if presented
				}
			}
		}
		.padding()
		.onAppear {
			reload()
			observerToken = NotificationCenter.default.addObserver(forName: OfflineOperationQueue.Notifications.queueChanged, object: nil, queue: .main) { _ in
				reload()
			}
		}
		.onDisappear {
			if let token = observerToken {
				NotificationCenter.default.removeObserver(token)
				observerToken = nil
			}
		}
	}
	
	private func reload() {
		operations = OfflineOperationQueue.shared.pendingOperations()
	}
	
	private func filteredOps() -> [OfflineOperationQueue.Operation] {
		if filterFailedOnly {
			return operations.filter { $0.status == .failed }
		}
		return operations
	}
	
	private func badgeColor(for type: OfflineOperationQueue.OperationType) -> Color {
		switch type {
		case .create: return .blue
		case .update: return .orange
		case .delete: return .red
		}
	}
	
	private func statusColor(for status: OfflineOperationQueue.OperationStatus) -> Color {
		switch status {
		case .pending: return .secondary
		case .processing: return .yellow
		case .failed: return .red
		case .completed: return .green
		}
	}
}

#if DEBUG
struct OfflineQueueView_Previews: PreviewProvider {
	static var previews: some View {
		OfflineQueueView()
			.frame(width: 700, height: 500)
	}
}
#endif


