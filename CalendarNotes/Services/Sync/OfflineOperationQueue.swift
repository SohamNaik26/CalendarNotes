//
//  OfflineOperationQueue.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import Combine
import Network

/// Advanced offline operation queue with priority and retry/backoff.
final class OfflineOperationQueue {
	static let shared = OfflineOperationQueue()
	
	enum OperationType: String, Codable {
		case create
		case update
		case delete
	}
	
	enum OperationStatus: String, Codable {
		case pending
		case processing
		case failed
		case completed
	}
	
	struct Operation: Codable, Identifiable, Equatable {
		let id: UUID
		let entityType: String
		let entityId: UUID
		let operationType: OperationType
		let payload: Data?
		var attemptCount: Int
		let createdAt: Date
		var lastAttemptAt: Date?
		var status: OperationStatus
		
		init(id: UUID = UUID(),
		     entityType: String,
		     entityId: UUID,
		     operationType: OperationType,
		     payload: Data?,
		     attemptCount: Int = 0,
		     createdAt: Date = Date(),
		     lastAttemptAt: Date? = nil,
		     status: OperationStatus = .pending) {
			self.id = id
			self.entityType = entityType
			self.entityId = entityId
			self.operationType = operationType
			self.payload = payload
			self.attemptCount = attemptCount
			self.createdAt = createdAt
			self.lastAttemptAt = lastAttemptAt
			self.status = status
		}
	}
	
	/// Notifications
	struct Notifications {
		static let queueChanged = Notification.Name("OfflineOperationQueue.queueChanged")
	}
	
	/// Settings
	struct Settings {
		static let maxAttempts = 5
		static let baseBackoffSeconds: TimeInterval = 2
	}
	
	private let encoder = JSONEncoder()
	private let decoder = JSONDecoder()
	private let ioQueue = DispatchQueue(label: "OfflineOperationQueue.IO", qos: .utility)
	private let processQueue = DispatchQueue(label: "OfflineOperationQueue.Process", qos: .utility)
	private let storageURL: URL
	
	private var cancellables = Set<AnyCancellable>()
	private var isProcessing: Bool = false
	
	private init() {
		let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
		self.storageURL = directory.appendingPathComponent("advanced_offline_queue.json")
		if !FileManager.default.fileExists(atPath: storageURL.deletingLastPathComponent().path) {
			try? FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
		}
		// Observe connectivity restoration
		ConnectivityMonitor.shared.publisher
			.sink { [weak self] path in
				guard let self else { return }
				if path.status == .satisfied {
					self.process()
				}
			}
			.store(in: &cancellables)
	}
	
	// MARK: - Public API
	
	func append(_ operation: Operation) {
		ioQueue.async {
			var ops = self.loadSync()
			ops.append(operation)
			self.saveSync(ops)
			NotificationCenter.default.post(name: Notifications.queueChanged, object: nil)
		}
	}
	
	func pendingOperations() -> [Operation] {
		loadSync().filter { $0.status == .pending || $0.status == .failed }
	}
	
	func clearFailed() {
		ioQueue.async {
			var ops = self.loadSync()
			ops.removeAll { $0.status == .failed }
			self.saveSync(ops)
			NotificationCenter.default.post(name: Notifications.queueChanged, object: nil)
		}
	}
	
	func retryAllFailedNow() {
		ioQueue.async {
			var ops = self.loadSync()
			for index in ops.indices {
				if ops[index].status == .failed {
					ops[index].status = .pending
					ops[index].lastAttemptAt = nil
				}
			}
			self.saveSync(ops)
			NotificationCenter.default.post(name: Notifications.queueChanged, object: nil)
			self.process()
		}
	}
	
	/// Process queue respecting priority and backoff.
	func process() {
		processQueue.async { [weak self] in
			guard let self else { return }
			guard !self.isProcessing else { return }
			self.isProcessing = true
			defer { self.isProcessing = false }
			
			var ops = self.loadSync()
			
			// Order by priority: delete > update > create, then by createdAt
			ops.sort { lhs, rhs in
				let lp = self.priority(of: lhs.operationType)
				let rp = self.priority(of: rhs.operationType)
				if lp != rp { return lp < rp }
				return lhs.createdAt < rhs.createdAt
			}
			
			for index in ops.indices {
				var op = ops[index]
				guard op.status == .pending || op.status == .failed else { continue }
				
				// Check backoff window
				if let last = op.lastAttemptAt, op.status == .failed {
					let wait = self.backoffDelay(for: op.attemptCount)
					if Date().timeIntervalSince(last) < wait {
						continue
					}
				}
				
				// Mark processing
				op.status = .processing
				op.lastAttemptAt = Date()
				ops[index] = op
				self.saveSync(ops)
				NotificationCenter.default.post(name: Notifications.queueChanged, object: nil)
				
				// Execute operation via network layer (stubbed here)
				let success = self.performNetworkOperation(op)
				
				if success {
					op.status = .completed
				} else {
					op.attemptCount += 1
					if op.attemptCount >= Settings.maxAttempts {
						op.status = .failed
					} else {
						op.status = .failed
					}
				}
				
				ops[index] = op
				self.saveSync(ops)
				NotificationCenter.default.post(name: Notifications.queueChanged, object: nil)
			}
		}
	}
	
	// MARK: - Helpers
	
	private func priority(of type: OperationType) -> Int {
		switch type {
		case .delete: return 0
		case .update: return 1
		case .create: return 2
		}
	}
	
	private func backoffDelay(for attempts: Int) -> TimeInterval {
		let clamped = max(0, attempts - 1)
		return pow(2.0, Double(clamped)) * Settings.baseBackoffSeconds
	}
	
	private func performNetworkOperation(_ operation: Operation) -> Bool {
		// TODO: integrate with real API layer; return true/false based on result
		// For now, simulate success after a short delay.
		usleep(120_000)
		return true
	}
	
	private func loadSync() -> [Operation] {
		(ioQueue.sync { () -> [Operation] in
			guard let data = try? Data(contentsOf: storageURL) else { return [] }
			return (try? decoder.decode([Operation].self, from: data)) ?? []
		})
	}
	
	private func saveSync(_ operations: [Operation]) {
		ioQueue.async {
			let data = (try? self.encoder.encode(operations)) ?? Data()
			try? data.write(to: self.storageURL, options: .atomic)
		}
	}
}


