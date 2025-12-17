//
//  WatchConnectivityService.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation
import Combine

#if os(iOS)
import WatchConnectivity

/// Synchronises lightweight bookmark data with the Apple Watch companion.
@MainActor
final class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published private(set) var isSupported: Bool = false
    @Published private(set) var isPaired: Bool = false
    @Published private(set) var isWatchAppInstalled: Bool = false

    private let defaults = UserDefaults.standard
    private let enabledKey = "watch.sync.enabled"

    private lazy var session: WCSession? = {
        guard WCSession.isSupported() else { return nil }
        let session = WCSession.default
        session.delegate = self
        session.activate()
        return session
    }()

    @Published var syncEnabled: Bool {
        didSet { defaults.set(syncEnabled, forKey: enabledKey); Task { await refreshState() } }
    }

    private override init() {
        syncEnabled = defaults.object(forKey: enabledKey) as? Bool ?? true
        super.init()
        Task { await refreshState() }
    }

    func refreshState() async {
        guard let session else {
            isSupported = false
            isPaired = false
            isWatchAppInstalled = false
            return
        }
        isSupported = true
        isPaired = session.isPaired
        isWatchAppInstalled = session.isWatchAppInstalled
    }

    func sendSnapshot(_ snapshot: WatchBookmarkSnapshot) async {
        guard syncEnabled, let session, session.isPaired, session.isWatchAppInstalled else { return }
        do {
            let data = try JSONEncoder().encode(snapshot)
            try session.updateApplicationContext(["bookmarkSnapshot": data])
        } catch {
            print("WatchConnectivityService: failed to send snapshot – \(error.localizedDescription)")
        }
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor in
            session.activate()
        }
    }
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            await WatchConnectivityService.shared.refreshState()
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String : Any]) {
        // Handle responses from watch if needed.
    }
}

#else

/// Stubbed connectivity service used on platforms without WatchConnectivity.
@MainActor
final class WatchConnectivityService: ObservableObject {
    static let shared = WatchConnectivityService()

    @Published private(set) var isSupported: Bool = false
    @Published private(set) var isPaired: Bool = false
    @Published private(set) var isWatchAppInstalled: Bool = false
    @Published var syncEnabled: Bool = false

    private init() {}

    func refreshState() async {}
    func sendSnapshot(_ snapshot: WatchBookmarkSnapshot) async {}
}

#endif

struct WatchBookmarkSnapshot: Codable {
    var totalCount: Int
    var unreadCount: Int
    var favoriteCount: Int
    var topBookmarks: [WatchBookmarkSummary]
}

struct WatchBookmarkSummary: Codable, Hashable {
    var id: UUID
    var title: String
    var url: String
    var collectionName: String?
    var isFavorite: Bool
    var isUnread: Bool
}


