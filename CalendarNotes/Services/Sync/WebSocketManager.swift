//
//  WebSocketManager.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import Combine
import Network

#if canImport(UIKit)
import UIKit
#endif

#if canImport(Starscream)
import Starscream
#endif

/// Real-time sync via WebSocket. Uses Starscream when available, falls back to URLSessionWebSocketTask.
@MainActor
final class WebSocketManager: ObservableObject {
	static let shared = WebSocketManager()
	
	enum ConnectionState: Equatable {
		case disconnected
		case connecting
		case connected
		case error(String)
	}
	
	struct SyncMessage: Codable {
		enum MessageType: String, Codable { case sync_event }
		enum Action: String, Codable { case create, update, delete }
		
		let type: MessageType
		let entity: String
		let action: Action
		let data: Data? // raw JSON payload to avoid tight coupling
		let user_id: UUID
		let device_id: String
		let timestamp: String
	}
	
	@Published private(set) var state: ConnectionState = .disconnected
	@Published private(set) var lastHeartbeatAt: Date?
	
	private let urlString = "wss://your-server.com/ws"
	private let tokenKey = "auth.token"
	private let realtimeEnabledKey = "realtimeSyncEnabled"
	private let wifiOnlyKey = "realtimeSyncWifiOnly"
	private let batterySaverKey = "realtimeSyncBatterySaver"
	
	private var retryAttempts: Int = 0
	private var pingTimer: Timer?
	private var cancellables = Set<AnyCancellable>()
	
	#if canImport(Starscream)
	private var starscreamSocket: WebSocket?
	#else
	private var urlSessionSocket: URLSessionWebSocketTask?
	private let session = URLSession(configuration: .default)
	#endif
	
	private init() {
		ConnectivityMonitor.shared.publisher
			.receive(on: DispatchQueue.main)
			.sink { [weak self] path in
				guard let self else { return }
				self.handleConnectivityChange(path)
			}
			.store(in: &cancellables)
		
		#if canImport(UIKit)
		NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(appWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
		#endif
	}
	
	// MARK: - Public API
	
	func connectIfAllowed() {
		// Skip connection if URL is a placeholder
		if urlString.contains("your-server.com") {
			return
		}
		guard UserDefaults.standard.bool(forKey: realtimeEnabledKey) else { return }
		if UserDefaults.standard.bool(forKey: wifiOnlyKey) {
			guard ConnectivityMonitor.shared.currentPath?.connectionQuality == .excellent else { return }
		}
		if UserDefaults.standard.bool(forKey: batterySaverKey) {
			return
		}
		connect()
	}
	
	func disconnect() {
		stopHeartbeat()
		#if canImport(Starscream)
		starscreamSocket?.disconnect()
		starscreamSocket = nil
		#else
		urlSessionSocket?.cancel(with: .goingAway, reason: nil)
		urlSessionSocket = nil
		#endif
		state = .disconnected
	}
	
	func emit(entity: String, action: SyncMessage.Action, data: Data) {
		guard case .connected = state else { return }
		let msg = SyncMessage(
			type: .sync_event,
			entity: entity,
			action: action,
			data: data,
			user_id: currentUserId(),
			device_id: SyncService.shared.deviceId(),
			timestamp: ISO8601DateFormatter().string(from: Date())
		)
		guard let payload = try? JSONEncoder().encode(msg) else { return }
		send(payload)
	}
	
	// MARK: - Private
	
	private func connect() {
		switch state {
		case .disconnected, .error:
			break
		default:
			return
		}
		state = .connecting
		retryAttempts = 0
		startSocket()
	}
	
	private func startSocket() {
		guard let url = URL(string: urlString) else {
			state = .error("Invalid URL")
			return
		}
		let token = UserDefaults.standard.string(forKey: tokenKey) ?? ""
		#if canImport(Starscream)
		var request = URLRequest(url: url)
		request.timeoutInterval = 10
		request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		let socket = WebSocket(request: request)
		socket.onEvent = { [weak self] event in
			guard let self else { return }
			Task { await MainActor.run { self.handleStarscreamEvent(event) } }
		}
		socket.connect()
		self.starscreamSocket = socket
		#else
		var request = URLRequest(url: url)
		request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		let task = session.webSocketTask(with: request)
		task.resume()
		self.urlSessionSocket = task
		self.receiveLoopURLSession()
		state = .connected
		startHeartbeat()
		#endif
	}
	
	#if canImport(Starscream)
	private func handleStarscreamEvent(_ event: WebSocketEvent) {
		switch event {
		case .connected(_):
			state = .connected
			startHeartbeat()
		case .disconnected(let reason, let code):
			state = .error("Disconnected (\(code)): \(reason)")
			handleReconnect()
		case .text(let string):
			handleIncoming(Data(string.utf8))
		case .binary(let data):
			handleIncoming(data)
		case .error(let error):
			state = .error(error?.localizedDescription ?? "Unknown error")
			handleReconnect()
		case .cancelled:
			state = .disconnected
			handleReconnect()
		case .ping(_):
			break
		case .pong(_):
			lastHeartbeatAt = Date()
		case .viabilityChanged(_), .reconnectSuggested(_), .peerClosed:
			break
		}
	}
	#endif
	
	private func handleIncoming(_ data: Data) {
		guard let message = try? JSONDecoder().decode(SyncMessage.self, from: data) else { return }
		guard message.device_id != SyncService.shared.deviceId() else { return }
		route(message)
	}
	
	private func send(_ data: Data) {
		#if canImport(Starscream)
		starscreamSocket?.write(data: data, completion: nil)
		#else
		urlSessionSocket?.send(.data(data)) { _ in }
		#endif
	}
	
	private func startHeartbeat() {
		stopHeartbeat()
		pingTimer = Timer.scheduledTimer(withTimeInterval: 25, repeats: true) { [weak self] _ in
			guard let self else { return }
			Task { @MainActor in
				self.lastHeartbeatAt = Date()
				#if canImport(Starscream)
				self.starscreamSocket?.write(ping: Data())
				#else
				self.urlSessionSocket?.sendPing { _ in }
				#endif
			}
		}
	}
	
	private func stopHeartbeat() {
		pingTimer?.invalidate()
		pingTimer = nil
	}
	
	private func handleReconnect() {
		stopHeartbeat()
		state = .disconnected
		retryAttempts += 1
		let delay = min(pow(2.0, Double(retryAttempts)), 60.0)
		DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
			self?.connectIfAllowed()
		}
	}
	
	private func route(_ message: SyncMessage) {
		switch message.entity {
		case "calendar_event":
			onCalendarEvent(message)
		case "note":
			onNote(message)
		case "todo":
			onTodo(message)
		case "bookmark":
			onBookmark(message)
		default:
			break
		}
	}
	
	// MARK: - Entity Handlers (stubs)
	
	private func onCalendarEvent(_ message: SyncMessage) {
		// TODO: decode and merge; last-write-wins, soft delete on .delete
	}
	
	private func onNote(_ message: SyncMessage) {
	}
	
	private func onTodo(_ message: SyncMessage) {
	}
	
	private func onBookmark(_ message: SyncMessage) {
	}
	
	deinit {
		// Inline cleanup since deinit cannot call actor-isolated methods
		pingTimer?.invalidate()
		pingTimer = nil
		cancellables.removeAll()
		#if canImport(UIKit)
		NotificationCenter.default.removeObserver(self)
		#endif
		#if canImport(Starscream)
		starscreamSocket?.disconnect()
		starscreamSocket = nil
		#else
		urlSessionSocket?.cancel(with: .goingAway, reason: nil)
		urlSessionSocket = nil
		#endif
	}
	
	// MARK: - URLSession fallback receive loop
	
	private func receiveLoopURLSession() {
		guard let socket = urlSessionSocket else { return }
		socket.receive { [weak self] result in
			guard let self else { return }
			Task { @MainActor in
				switch result {
				case .failure(let error):
					self.state = .error(error.localizedDescription)
					self.handleReconnect()
				case .success(let message):
					switch message {
					case .data(let data):
						self.handleIncoming(data)
					case .string(let text):
						self.handleIncoming(Data(text.utf8))
					@unknown default:
						break
					}
					self.receiveLoopURLSession()
				}
			}
		}
	}
	
	// MARK: - App lifecycle
	
	@objc private func appDidEnterBackground() {
		disconnect()
	}
	
	@objc private func appWillEnterForeground() {
		connectIfAllowed()
	}
	
	// MARK: - Utilities
	
	private func handleConnectivityChange(_ path: NWPath) {
		let connected = path.status == .satisfied
		if connected {
			connectIfAllowed()
		} else {
			disconnect()
		}
	}
	
	private func currentUserId() -> UUID {
		// TODO: provide real user id from auth/session
		return UUID(uuidString: "00000000-0000-0000-0000-000000000000") ?? UUID()
	}
}


