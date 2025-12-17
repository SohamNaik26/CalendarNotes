import Foundation

// High-level protocol for backend operations; implementations can use URLSession, GRPC, etc.
protocol CollaborationAPI {
    // Collections
    func listCollections() async throws -> [CollabCollection]
    func createCollection(_ draft: CollabCollection) async throws -> CollabCollection
    func updateCollection(_ collection: CollabCollection) async throws -> CollabCollection
    func deleteCollection(id: String) async throws

    // Members
    func listMembers(collectionId: String) async throws -> [CollabMember]
    func addMember(collectionId: String, userEmail: String, role: CollabMember.Role) async throws -> CollabInvite
    func updateMember(collectionId: String, memberId: String, role: CollabMember.Role) async throws -> CollabMember
    func removeMember(collectionId: String, memberId: String) async throws

    // Invites
    func acceptInvite(token: String) async throws -> CollabMember

    // Bookmarks
    func listBookmarks(collectionId: String, updatedSince: Date?) async throws -> [CollabBookmark]
    func createBookmark(_ bookmark: CollabBookmark) async throws -> CollabBookmark
    func updateBookmark(_ bookmark: CollabBookmark) async throws -> CollabBookmark
    func deleteBookmark(id: String) async throws

    // Comments
    func listComments(bookmarkId: String) async throws -> [CollabComment]
    func createComment(_ comment: CollabComment) async throws -> CollabComment
    func deleteComment(id: String) async throws

    // Activity & Versions
    func listActivity(collectionId: String, page: Int, pageSize: Int) async throws -> [CollabActivity]
    func listVersions(entityType: CollabVersionRecord.EntityType, entityId: String) async throws -> [CollabVersionRecord]
    func restoreVersion(recordId: String) async throws
}

// Real-time events delivered via WebSocket/SSE or similar
enum CollaborationEvent: Equatable {
    case bookmarkCreated(CollabBookmark)
    case bookmarkUpdated(CollabBookmark)
    case bookmarkDeleted(String)
    case commentCreated(CollabComment)
    case memberUpdated(CollabMember)
    case activityCreated(CollabActivity)
}

protocol CollaborationRealtime {
    func connect(toCollectionId id: String) async throws
    func disconnect(fromCollectionId id: String)
    var onEvent: ((String, CollaborationEvent) -> Void)? { get set } // (collectionId, event)
}


