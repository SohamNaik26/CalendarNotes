import Foundation

@MainActor
final class CollaborativeSyncService {
    private let api: CollaborationAPI
    private var realtime: CollaborationRealtime?

    // Local mapping/state placeholders
    private var subscribedCollectionIds: Set<String> = []

    init(api: CollaborationAPI, realtime: CollaborationRealtime? = nil) {
        self.api = api
        self.realtime = realtime
        self.realtime?.onEvent = { [weak self] collectionId, event in
            Task { @MainActor in
                self?.apply(event: event, for: collectionId)
            }
        }
    }

    func startRealtime(for collectionId: String) async {
        guard CollaborationFeatureFlags.realTimeEnabled else { return }
        guard !subscribedCollectionIds.contains(collectionId) else { return }
        do {
            try await realtime?.connect(toCollectionId: collectionId)
            subscribedCollectionIds.insert(collectionId)
        } catch {
            // Intentionally swallow for skeleton
        }
    }

    func stopRealtime(for collectionId: String) {
        realtime?.disconnect(fromCollectionId: collectionId)
        subscribedCollectionIds.remove(collectionId)
    }

    // Pull delta updates and reconcile with local store (Core Data integration to be added later)
    func pullChanges(collectionId: String, updatedSince: Date?) async {
        do {
            _ = try await api.listBookmarks(collectionId: collectionId, updatedSince: updatedSince)
            // TODO: map DTOs to Core Data once model is extended
        } catch {
            // no-op in skeleton
        }
    }

    // Mutations (server-first, then apply locally on success)
    func addBookmark(_ bookmark: CollabBookmark) async {
        do {
            let created = try await api.createBookmark(bookmark)
            apply(event: .bookmarkCreated(created), for: bookmark.collectionId)
        } catch {}
    }

    func updateBookmark(_ bookmark: CollabBookmark) async {
        do {
            let updated = try await api.updateBookmark(bookmark)
            apply(event: .bookmarkUpdated(updated), for: bookmark.collectionId)
        } catch {}
    }

    func deleteBookmark(id: String, collectionId: String) async {
        do {
            try await api.deleteBookmark(id: id)
            apply(event: .bookmarkDeleted(id), for: collectionId)
        } catch {}
    }

    func createComment(_ comment: CollabComment) async {
        do {
            let created = try await api.createComment(comment)
            apply(event: .commentCreated(created), for: comment.collectionId)
        } catch {}
    }

    // Event application (local side-effects; to be wired to Core Data later)
    private func apply(event: CollaborationEvent, for collectionId: String) {
        switch event {
        case .bookmarkCreated:
            break
        case .bookmarkUpdated:
            break
        case .bookmarkDeleted:
            break
        case .commentCreated:
            break
        case .memberUpdated:
            break
        case .activityCreated:
            break
        }
    }
}


