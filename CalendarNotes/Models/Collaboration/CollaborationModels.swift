import Foundation

// MARK: - Core DTOs used for backend sync (independent of Core Data)

struct CollabUser: Codable, Hashable, Identifiable {
    let id: String
    let email: String
    var name: String?
    var avatarURL: URL?
}

struct CollabCollection: Codable, Hashable, Identifiable {
    let id: String
    var ownerId: String
    var name: String
    var description: String?
    var visibility: Visibility
    var createdAt: Date
    var updatedAt: Date

    enum Visibility: String, Codable { case privateOnly, sharedLink, organization }
}

struct CollabMember: Codable, Hashable, Identifiable {
    let id: String
    let collectionId: String
    let userId: String
    var role: Role
    var invitedBy: String?
    var status: Status

    enum Role: String, Codable { case owner, editor, contributor, viewer }
    enum Status: String, Codable { case pending, active, removed }
}

struct CollabBookmark: Codable, Hashable, Identifiable {
    let id: String
    let collectionId: String
    var url: URL
    var title: String
    var description: String?
    var tags: [String]
    var previewURL: URL?
    var createdBy: String
    var createdAt: Date
    var updatedAt: Date
    var version: Int
}

struct CollabComment: Codable, Hashable, Identifiable {
    let id: String
    let collectionId: String
    let bookmarkId: String
    let authorId: String
    var text: String
    var createdAt: Date
}

struct CollabActivity: Codable, Hashable, Identifiable {
    let id: String
    let collectionId: String
    let actorId: String
    let type: ActivityType
    let payload: [String: String]
    let createdAt: Date

    enum ActivityType: String, Codable {
        case addBookmark, editBookmark, deleteBookmark
        case comment
        case invite, roleChange, transferOwnership
    }
}

struct CollabInvite: Codable, Hashable, Identifiable {
    let id: String
    let collectionId: String
    let email: String
    let invitedBy: String
    let role: CollabMember.Role
    let token: String
    let expiresAt: Date
    var status: InviteStatus

    enum InviteStatus: String, Codable { case sent, accepted, expired, revoked }
}

struct CollabVersionRecord: Codable, Hashable, Identifiable {
    let id: String
    let entityType: EntityType
    let entityId: String
    let version: Int
    let diff: [String: String] // compact field diffs
    let actorId: String
    let createdAt: Date

    enum EntityType: String, Codable { case bookmark, collection }
}

struct CollabNotificationItem: Codable, Hashable, Identifiable {
    let id: String
    let userId: String
    let type: String
    let payload: [String: String]
    var readAt: Date?
    let createdAt: Date
}


