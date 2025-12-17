//
//  DeepLinkRouter.swift
//  CalendarNotes
//
//  Handles custom scheme and universal link routing.
//

import Foundation
import CoreData

#if os(macOS)
import AppKit
#else
import UIKit
#endif

@MainActor
final class DeepLinkRouter {
    static let shared = DeepLinkRouter()

    private init() {}

    private let coreData = CoreDataManager.shared
    private var pendingAddBookmark: PendingAddBookmark?

    private enum MainTabIndex: Int {
        case calendar = 0
        case search = 1
        case notes = 2
        case tasks = 3
        case bookmarks = 4
        case settings = 5
    }

    enum Route {
        case showBookmarks
        case addBookmark(url: URL, collection: String?)
        case search(query: String)
        case collection(id: UUID)
        case bookmark(id: UUID)
        case tag(name: String)
        case openRandom
    }

    struct ParsedLink {
        let route: Route
        let callback: XCallbackContext?
    }

    struct XCallbackContext {
        let success: URL?
        let error: URL?
        let cancel: URL?
        let source: String?
        let state: String?
        let extra: [String: String]
        let nextAction: URL?

        init?(queryItems: [URLQueryItem]) {
            func urlValue(_ name: String) -> URL? {
                guard let value = queryItems.first(where: { $0.name == name })?.value,
                      let encoded = value.removingPercentEncoding,
                      let url = URL(string: encoded) ?? URL(string: value) else { return nil }
                return url
            }

            let success = urlValue("x-success")
            let error = urlValue("x-error")
            let cancel = urlValue("x-cancel")
            let source = queryItems.first(where: { $0.name == "x-source" })?.value
            let state = queryItems.first(where: { $0.name == "x-state" || $0.name == "state" })?.value
            let next = urlValue("x-next") ?? urlValue("next")

            if success == nil && error == nil && cancel == nil && next == nil {
                return nil
            }

            self.success = success
            self.error = error
            self.cancel = cancel
            self.source = source
            self.state = state
            self.extra = Dictionary(uniqueKeysWithValues: queryItems.map { ($0.name, $0.value ?? "") })
            self.nextAction = next
        }
    }

    private struct PendingAddBookmark {
        let route: Route
        let context: XCallbackContext
        let requestedURL: URL
        let collection: String?
    }

    enum DeepLinkError: LocalizedError, Equatable {
        case invalidQuery
        case missingResource
        case unsupported

        var errorDescription: String? {
            switch self {
            case .invalidQuery: return "The supplied deep link is missing required parameters."
            case .missingResource: return "The requested resource could not be found."
            case .unsupported: return "This deep link is not supported."
            }
        }
    }

    func parse(url: URL) -> ParsedLink? {
        let scheme = (url.scheme ?? "").lowercased()
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let callback = XCallbackContext(queryItems: queryItems)

        if scheme == "calendarnotes" {
            guard let route = parseCustomScheme(url: url, queryItems: queryItems) else { return nil }
            return ParsedLink(route: route, callback: callback)
        }

        if scheme == "https" || scheme == "http" {
            guard let route = parseUniversalLink(url: url, queryItems: queryItems) else { return nil }
            return ParsedLink(route: route, callback: callback)
        }

        return nil
    }

    private func parseCustomScheme(url: URL, queryItems: [URLQueryItem]) -> Route? {
        guard let host = url.host?.lowercased() else { return nil }

        switch host {
        case "bookmarks":
            return .showBookmarks

        case "add-bookmark":
            guard let urlString = queryItems.first(where: { $0.name == "url" })?.value,
                  let encoded = urlString.removingPercentEncoding,
                  let target = URL(string: encoded) ?? URL(string: urlString) else { return nil }
            let collection = queryItems.first(where: { $0.name == "collection" })?.value?
                .removingPercentEncoding ?? queryItems.first(where: { $0.name == "collection" })?.value
            return .addBookmark(url: target, collection: collection?.isEmpty == true ? nil : collection)

        case "search":
            guard let query = queryItems.first(where: { $0.name == "query" || $0.name == "q" })?.value,
                  !query.isEmpty else { return nil }
            return .search(query: query)

        case "collection":
            guard let identifier = url.pathComponents.dropFirst().first,
                  let id = UUID(uuidString: identifier) else { return nil }
            return .collection(id: id)

        case "bookmark":
            guard let identifier = url.pathComponents.dropFirst().first,
                  let id = UUID(uuidString: identifier) else { return nil }
            return .bookmark(id: id)

        case "tag":
            guard let raw = url.pathComponents.dropFirst().first else { return nil }
            let decoded = raw.removingPercentEncoding ?? raw
            return .tag(name: decoded)

        case "open-random":
            return .openRandom

        default:
            return nil
        }
    }

    private func parseUniversalLink(url: URL, queryItems: [URLQueryItem]) -> Route? {
        guard let host = url.host?.lowercased(),
              Self.supportedDomains.contains(host) else { return nil }

        let components = url.pathComponents.filter { $0 != "/" }

        guard let first = components.first else {
            return .showBookmarks
        }

        switch first.lowercased() {
        case "bookmarks":
            return .showBookmarks

        case "add-bookmark":
            guard let urlString = queryItems.first(where: { $0.name == "url" })?.value,
                  let encoded = urlString.removingPercentEncoding,
                  let target = URL(string: encoded) ?? URL(string: urlString) else { return nil }
            let collection = queryItems.first(where: { $0.name == "collection" })?.value?
                .removingPercentEncoding ?? queryItems.first(where: { $0.name == "collection" })?.value
            return .addBookmark(url: target, collection: collection?.isEmpty == true ? nil : collection)

        case "search":
            guard let query = queryItems.first(where: { $0.name == "query" || $0.name == "q" })?.value,
                  !query.isEmpty else { return nil }
            return .search(query: query)

        case "collection":
            guard components.count >= 2,
                  let id = UUID(uuidString: components[1]) else { return nil }
            return .collection(id: id)

        case "bookmark":
            guard components.count >= 2,
                  let id = UUID(uuidString: components[1]) else { return nil }
            return .bookmark(id: id)

        case "tag":
            guard components.count >= 2 else { return nil }
            let decoded = components[1].removingPercentEncoding ?? components[1]
            return .tag(name: decoded)

        case "open-random":
            return .openRandom

        default:
            return nil
        }
    }

    func handle(_ parsed: ParsedLink) async {
        do {
            let payload = try await perform(route: parsed.route, callback: parsed.callback)
            if let callback = parsed.callback {
                if case .addBookmark = parsed.route {
                    // Deferred: success is reported when the user completes or cancels the flow.
                } else {
                    await XCallbackService.handleSuccess(callback, data: payload)
                    await handleChainedLink(from: callback, originalRoute: parsed.route)
                }
            }
        } catch {
            if let callback = parsed.callback {
                if let deepLinkError = error as? DeepLinkError, deepLinkError == .unsupported {
                    await XCallbackService.handleCancel(callback)
                } else {
                    await XCallbackService.handleError(callback, error: error)
                }
            }
        }
    }

    private func perform(route: Route, callback: XCallbackContext?) async throws -> [String: String] {
        switch route {
        case .showBookmarks:
            postNavigate(to: .bookmarks)
            return ["action": "bookmarks"]

        case .addBookmark(let pageURL, let collection):
            guard await BookmarkService.shared.validate(url: pageURL) else {
                throw DeepLinkError.invalidQuery
            }

            _ = try? await BookmarkService.shared.fetchMetadata(for: pageURL)
            postNavigate(to: .bookmarks)

            var info: [String: String] = [
                "action": "add-bookmark",
                "url": pageURL.absoluteString
            ]

            if let collection {
                info["collection"] = collection
                NotificationCenter.default.post(
                    name: .deepLinkPrefillCollectionForNewBookmark,
                    object: nil,
                    userInfo: [DeepLinkUserInfoKey.collectionName: collection]
                )
            }

            NotificationCenter.default.post(name: .init("OpenAddBookmark"), object: pageURL)

            if let callback {
                if let existing = pendingAddBookmark {
                    Task { await XCallbackService.handleCancel(existing.context) }
                }
                pendingAddBookmark = PendingAddBookmark(
                    route: route,
                    context: callback,
                    requestedURL: pageURL,
                    collection: collection
                )
            }

            return info

        case .search(let query):
            postNavigate(to: .search)
            NotificationCenter.default.post(
                name: .deepLinkPerformSearch,
                object: nil,
                userInfo: [DeepLinkUserInfoKey.searchQuery: query]
            )
            return ["action": "search", "query": query]

        case .collection(let id):
            guard let collection = try coreData.fetchCollection(id: id) else {
                throw DeepLinkError.missingResource
            }
            let name = collection.name ?? ""
            postNavigate(to: .bookmarks)
            NotificationCenter.default.post(
                name: .deepLinkShowCollection,
                object: nil,
                userInfo: [
                    DeepLinkUserInfoKey.collectionID: collection.objectID,
                    DeepLinkUserInfoKey.collectionName: name
                ]
            )
            return [
                "action": "collection",
                "collectionId": id.uuidString,
                "collectionName": name
            ]

        case .bookmark(let id):
            guard let bookmark = try coreData.fetchBookmark(id: id) else {
                throw DeepLinkError.missingResource
            }
            postNavigate(to: .bookmarks)
            NotificationCenter.default.post(
                name: .deepLinkOpenBookmark,
                object: nil,
                userInfo: [DeepLinkUserInfoKey.bookmarkObjectID: bookmark.objectID]
            )
            return [
                "action": "bookmark",
                "bookmarkId": id.uuidString,
                "url": bookmark.url ?? "",
                "title": bookmark.title ?? ""
            ]

        case .tag(let name):
            postNavigate(to: .bookmarks)
            NotificationCenter.default.post(
                name: .deepLinkShowTag,
                object: nil,
                userInfo: [DeepLinkUserInfoKey.tagName: name]
            )
            return [
                "action": "tag",
                "tag": name
            ]

        case .openRandom:
            guard let bookmark = BookmarkDiscoveryService.shared.randomSuggestion() else {
                throw DeepLinkError.missingResource
            }
            postNavigate(to: .bookmarks)
            NotificationCenter.default.post(
                name: .deepLinkOpenBookmark,
                object: nil,
                userInfo: [DeepLinkUserInfoKey.bookmarkObjectID: bookmark.objectID,
                           DeepLinkUserInfoKey.wasRandomSelection: true]
            )
            return [
                "action": "open-random",
                "bookmarkId": bookmark.id?.uuidString ?? "",
                "url": bookmark.url ?? "",
                "title": bookmark.title ?? ""
            ]
        }
    }

    private func postNavigate(to tab: MainTabIndex) {
        NotificationCenter.default.post(
            name: .deepLinkNavigateToTab,
            object: nil,
            userInfo: [DeepLinkUserInfoKey.tabIndex: tab.rawValue]
        )
    }

    private func handleChainedLink(from context: XCallbackContext, originalRoute: Route) async {
        guard let next = context.nextAction else { return }
        guard let parsed = parse(url: next) else {
            Self.openExternally(next)
            return
        }

        // Avoid simple infinite recursion by ensuring the chained route differs
        let sameRoute = {
            switch (originalRoute, parsed.route) {
            case (.showBookmarks, .showBookmarks),
                 (.openRandom, .openRandom),
                 (.search, .search):
                return true
            case (.addBookmark(let lhs, _), .addBookmark(let rhs, _)):
                return lhs == rhs
            case (.collection(let lhs), .collection(let rhs)):
                return lhs == rhs
            case (.bookmark(let lhs), .bookmark(let rhs)):
                return lhs == rhs
            case (.tag(let lhs), .tag(let rhs)):
                return lhs.caseInsensitiveCompare(rhs) == .orderedSame
            default:
                return false
            }
        }()

        if sameRoute { return }
        await handle(parsed)
    }

    private static func openExternally(_ url: URL) {
        #if os(macOS)
        NSWorkspace.shared.open(url)
        #else
        UIApplication.shared.open(url)
        #endif
    }

    func notifyAddBookmarkSucceeded(bookmark: Bookmark) async {
        guard let pending = pendingAddBookmark else { return }
        pendingAddBookmark = nil

        var payload: [String: String] = [
            "action": "add-bookmark",
            "bookmarkId": bookmark.id?.uuidString ?? bookmark.objectID.uriRepresentation().absoluteString,
            "url": bookmark.url ?? pending.requestedURL.absoluteString,
            "title": bookmark.title ?? ""
        ]

        if let collectionName = bookmark.collectionName ?? pending.collection {
            payload["collection"] = collectionName
        }

        await XCallbackService.handleSuccess(pending.context, data: payload)
        await handleChainedLink(from: pending.context, originalRoute: pending.route)
    }

    func notifyAddBookmarkCancelled() async {
        guard let pending = pendingAddBookmark else { return }
        pendingAddBookmark = nil
        await XCallbackService.handleCancel(pending.context)
    }

    private static let supportedDomains: Set<String> = [
        "yourapp.com",
        "www.yourapp.com"
    ]
}
