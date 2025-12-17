//
//  OfflineRequestQueue.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation

struct QueuedRequest: Codable {
	let id: UUID
	let url: String
	let method: String
	let headers: [String: String]
	let body: Data?
	let endpoint: String
	let createdAt: Date
	var retryCount: Int
}

@MainActor
final class OfflineRequestQueue {
	static let shared = OfflineRequestQueue()
	
	private let queueFile: URL
	private var queue: [QueuedRequest] = []
	
	private init() {
		let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
		queueFile = documentsPath.appendingPathComponent("offline_requests.json")
		loadQueue()
	}
	
	func enqueue(request: URLRequest, endpoint: APIEndpoint) async throws {
		guard let url = request.url else { return }
		
		let queuedRequest = QueuedRequest(
			id: UUID(),
			url: url.absoluteString,
			method: request.httpMethod ?? "GET",
			headers: request.allHTTPHeaderFields ?? [:],
			body: request.httpBody,
			endpoint: endpoint.path,
			createdAt: Date(),
			retryCount: 0
		)
		
		queue.append(queuedRequest)
		saveQueue()
	}
	
	func processQueue() async {
		guard !queue.isEmpty else { return }
		
		let requestsToProcess = queue
		queue.removeAll()
		saveQueue()
		
		for var queuedRequest in requestsToProcess {
			do {
				guard let url = URL(string: queuedRequest.url) else { continue }
				var request = URLRequest(url: url)
				request.httpMethod = queuedRequest.method
				request.allHTTPHeaderFields = queuedRequest.headers
				request.httpBody = queuedRequest.body
				
				let (_, response) = try await URLSession.shared.data(for: request)
				
				if let httpResponse = response as? HTTPURLResponse,
				   (200...299).contains(httpResponse.statusCode) {
					// Success - request completed
					continue
				} else {
					// Failed - re-queue if retry count < 5
					if queuedRequest.retryCount < 5 {
						queuedRequest.retryCount += 1
						queue.append(queuedRequest)
					}
				}
			} catch {
				// Re-queue if retry count < 5
				if queuedRequest.retryCount < 5 {
					queuedRequest.retryCount += 1
					queue.append(queuedRequest)
				}
			}
		}
		
		saveQueue()
	}
	
	func clearQueue() {
		queue.removeAll()
		saveQueue()
	}
	
	var pendingCount: Int {
		queue.count
	}
	
	// MARK: - Persistence
	
	private func loadQueue() {
		guard FileManager.default.fileExists(atPath: queueFile.path),
			  let data = try? Data(contentsOf: queueFile),
			  let loaded = try? JSONDecoder().decode([QueuedRequest].self, from: data) else {
			return
		}
		queue = loaded
	}
	
	private func saveQueue() {
		guard let data = try? JSONEncoder().encode(queue) else { return }
		try? data.write(to: queueFile)
	}
}

