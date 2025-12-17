import Foundation
import CoreData
import CryptoKit
import SwiftUI
import Security
import Combine
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Option Sets & Enumerations

struct BackupContentOptions: OptionSet, Codable, Sendable {
    let rawValue: Int
    
    static let metadata    = BackupContentOptions(rawValue: 1 << 0)
    static let previewImages = BackupContentOptions(rawValue: 1 << 1)
    static let userNotes   = BackupContentOptions(rawValue: 1 << 2)
    static let collections = BackupContentOptions(rawValue: 1 << 3)
    static let tags        = BackupContentOptions(rawValue: 1 << 4)
    static let highlights  = BackupContentOptions(rawValue: 1 << 5)
    
    static let defaults: BackupContentOptions = [.metadata, .userNotes, .collections, .tags]
    
    init(rawValue: Int) { self.rawValue = rawValue }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.rawValue = try container.decode(Int.self)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum BackupStoragePreference: String, Codable, Sendable, CaseIterable {
    case automatic
    case localOnly
    case iCloudIfAvailable
}

enum BackupRestoreMode: String, Codable, Sendable, CaseIterable {
    case replaceAll
    case merge
    case collectionsOnly
    case bookmarksOnly
}

enum BackupTrigger: String, Codable, Sendable {
    case manual
    case automaticDaily
    case appLaunch
}

enum BackupFileFormat: String, Codable, Sendable {
    case archive
    case json
    case html
}

// MARK: - Backup Models

struct BackupOptions: Codable, Sendable {
    var content: BackupContentOptions
    var storagePreference: BackupStoragePreference
    var incremental: Bool
    var passwordHint: String?
    var encryptWithPassword: Bool
    
    static let `default` = BackupOptions(content: .defaults,
                                         storagePreference: .iCloudIfAvailable,
                                         incremental: true,
                                         passwordHint: nil,
                                         encryptWithPassword: false)
}

struct BackupChecksumSummary: Codable, Sendable {
    var bookmarks: [UUID: String]
    var collections: [UUID: String]
    var tags: [UUID: String]
    var highlights: [UUID: String]
    
    static let empty = BackupChecksumSummary(bookmarks: [:], collections: [:], tags: [:], highlights: [:])
}

struct BackupManifest: Codable, Identifiable, Sendable {
    enum BackupType: String, Codable, Sendable { case full, incremental }
    enum StorageLocation: String, Codable, Sendable { case local, iCloud }
    
    let id: UUID
    let createdAt: Date
    let trigger: BackupTrigger
    let type: BackupType
    let storageLocation: StorageLocation
    let fileName: String
    let contentOptionsRaw: Int
    let encrypted: Bool
    let baseBackupID: UUID?
    var size: Int64
    var checksumSummary: BackupChecksumSummary
    
    var contentOptions: BackupContentOptions { BackupContentOptions(rawValue: contentOptionsRaw) }
}

struct BackupStatus: Sendable {
    var lastBackupDate: Date?
    var lastAutomaticBackup: Date?
    var lastManualBackup: Date?
    var backupCount: Int
    var autoBackupEnabled: Bool
    var iCloudAvailable: Bool
    var lastError: String?
    var lastBackupSize: Int64
    var passwordHint: String?
    
    static let empty = BackupStatus(lastBackupDate: nil,
                                    lastAutomaticBackup: nil,
                                    lastManualBackup: nil,
                                    backupCount: 0,
                                    autoBackupEnabled: false,
                                    iCloudAvailable: false,
                                    lastError: nil,
                                    lastBackupSize: 0,
                                    passwordHint: nil)
}

struct BookmarkBackupSnapshot: Codable, Sendable {
    var metadata: BackupMetadata?
    var bookmarks: [BookmarkRecord]
    var collections: [CollectionRecord]
    var tags: [TagRecord]
    var highlights: [HighlightRecord]
}

struct BackupMetadata: Codable, Sendable {
    let createdAt: Date
    let deviceName: String
    let appVersion: String
    let totalBookmarks: Int
    let totalCollections: Int
    let totalTags: Int
    let notesIncluded: Bool
}

struct BookmarkRecord: Codable, Sendable {
    let id: UUID
    let url: String?
    let title: String?
    let description: String?
    let collectionID: UUID?
    let collectionName: String?
    let tagNames: [String]
    let isFavorite: Bool
    let isArchived: Bool
    let createdDate: Date?
    let lastOpenedDate: Date?
    let lastModifiedDate: Date?
    let openCount: Int32
    let notes: String?
    let previewImage: Data?
    let favicon: Data?
    let metadata: BookmarkSnapshotMetadata
}

struct BookmarkSnapshotMetadata: Codable, Sendable {
    let checksum: String
}

struct CollectionRecord: Codable, Sendable {
    let id: UUID
    let name: String
    let color: String?
    let icon: String?
    let sortOrder: Int32
    let parentID: UUID?
    let checksum: String
}

struct TagRecord: Codable, Sendable {
    let id: UUID
    let name: String
    let color: String?
    let usageCount: Int32
    let checksum: String
}

struct HighlightRecord: Codable, Sendable {
    let id: UUID
    let bookmarkID: UUID?
    let selectedText: String
    let color: String
    let note: String?
    let rangeStart: Int32
    let rangeEnd: Int32
    let xpath: String?
    let offset: Int32
    let createdDate: Date?
    let checksum: String
}

struct BookmarkBackupDiff: Codable, Sendable {
    var bookmarksAddedOrUpdated: [BookmarkRecord]
    var bookmarksDeleted: [UUID]
    var collectionsAddedOrUpdated: [CollectionRecord]
    var collectionsDeleted: [UUID]
    var tagsAddedOrUpdated: [TagRecord]
    var tagsDeleted: [UUID]
    var highlightsAddedOrUpdated: [HighlightRecord]
    var highlightsDeleted: [UUID]
}

struct BookmarkBackupPackage: Codable, Sendable {
    struct Header: Codable, Sendable {
        let id: UUID
        let createdAt: Date
        let trigger: BackupTrigger
        let type: BackupManifest.BackupType
        let contentOptionsRaw: Int
        let baseBackupID: UUID?
    }
    
    struct Payload: Codable, Sendable {
        let snapshot: BookmarkBackupSnapshot?
        let diff: BookmarkBackupDiff?
        let checksumSummary: BackupChecksumSummary
    }
    
    let header: Header
    let payload: Payload
}

struct BackupEnvelope: Codable, Sendable {
    let salt: Data
    let nonce: Data
    let ciphertext: Data
}

struct BackupPreviewSummary: Sendable {
    let manifest: BackupManifest
    let metadata: BackupMetadata?
    let bookmarkCount: Int
    let collectionCount: Int
    let tagCount: Int
    let highlightCount: Int
    let sampleBookmarks: [BookmarkRecord]
}

// MARK: - Backup Service

@MainActor
final class BookmarkBackupService: ObservableObject {
    static let shared = BookmarkBackupService()
    
    @Published private(set) var manifests: [BackupManifest] = []
    @Published private(set) var status: BackupStatus = .empty
    @Published private(set) var isRunningBackup: Bool = false
    @Published private(set) var lastBackupPath: URL?
    
    private let coreData = CoreDataManager.shared
    private let fileManager = FileManager.default
    private let userDefaults = UserDefaults.standard
    private let manifestsFileName = "backup_manifests.json"
    private let optionsKey = "bookmark.backup.options"
    private let autoBackupKey = "bookmark.backup.autoEnabled"
    private let lastAutoBackupKey = "bookmark.backup.lastAuto"
    private let passwordHintKey = "bookmark.backup.passwordHint"
    private let keychainServiceID = "com.calendarnotes.backup"
    private let keychainAccountID = "encryption"
    
    private let localDirectory: URL
    private var iCloudDirectory: URL?
    
    private init() {
        self.localDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Backups", isDirectory: true)
        try? fileManager.createDirectory(at: localDirectory, withIntermediateDirectories: true)
        self.iCloudDirectory = BookmarkBackupService.locateICloudDirectory()
        loadManifestsFromDisk()
        refreshStatus()
    }
    
    // MARK: - Preferences
    
    var options: BackupOptions {
        if let data = userDefaults.data(forKey: optionsKey),
           let decoded = try? JSONDecoder().decode(BackupOptions.self, from: data) {
            return decoded
        }
        return .default
    }
    
    func updateOptions(_ newOptions: BackupOptions) {
        if let data = try? JSONEncoder().encode(newOptions) {
            userDefaults.set(data, forKey: optionsKey)
        }
        if let hint = newOptions.passwordHint {
            userDefaults.set(hint, forKey: passwordHintKey)
        } else {
            userDefaults.removeObject(forKey: passwordHintKey)
        }
        refreshStatus()
    }
    
    var autoBackupEnabled: Bool {
        get { userDefaults.bool(forKey: autoBackupKey) }
        set {
            userDefaults.set(newValue, forKey: autoBackupKey)
            refreshStatus()
        }
    }
    
    private var lastAutomaticBackup: Date? {
        get {
            let interval = userDefaults.double(forKey: lastAutoBackupKey)
            return interval == 0 ? nil : Date(timeIntervalSince1970: interval)
        }
        set {
            if let value = newValue {
                userDefaults.set(value.timeIntervalSince1970, forKey: lastAutoBackupKey)
            }
        }
    }
    
    // MARK: - Public API
    
    func refreshStatus(lastError: String? = nil) {
        status = BackupStatus(
            lastBackupDate: manifests.sorted(by: { $0.createdAt > $1.createdAt }).first?.createdAt,
            lastAutomaticBackup: lastAutomaticBackup,
            lastManualBackup: manifests.filter { $0.trigger == .manual }.sorted(by: { $0.createdAt > $1.createdAt }).first?.createdAt,
            backupCount: manifests.count,
            autoBackupEnabled: autoBackupEnabled,
            iCloudAvailable: iCloudDirectory != nil,
            lastError: lastError,
            lastBackupSize: manifests.sorted(by: { $0.createdAt > $1.createdAt }).first?.size ?? 0,
            passwordHint: userDefaults.string(forKey: passwordHintKey)
        )
    }
    
    func performManualBackup(password: String?) async throws -> BackupManifest {
        try await performBackup(trigger: .manual, options: options, password: password)
    }
    
    func performBackup(trigger: BackupTrigger, options: BackupOptions, password: String?) async throws -> BackupManifest {
        guard !isRunningBackup else { throw NSError(domain: "CalendarNotes", code: -99, userInfo: [NSLocalizedDescriptionKey: "A backup is already running."]) }
        isRunningBackup = true
        defer { isRunningBackup = false }
        
        do {
            let manifest = try await generateBackup(trigger: trigger, options: options, password: password ?? storedPasswordIfNeeded(for: options))
            manifests.append(manifest)
            manifests.sort { $0.createdAt > $1.createdAt }
            trimOldBackupsIfNeeded()
            saveManifestsToDisk()
            refreshStatus()
            if trigger != .manual {
                lastAutomaticBackup = Date()
            }
            return manifest
        } catch {
            refreshStatus(lastError: error.localizedDescription)
            throw error
        }
    }
    
    func performAutomaticBackupIfNeeded(reason: BackupTrigger) async {
        guard autoBackupEnabled else { return }
        let now = Date()
        if let last = lastAutomaticBackup, now.timeIntervalSince(last) < 24 * 3600, reason == .appLaunch {
            return
        }
        do {
            let _ = try await performBackup(trigger: reason, options: options, password: storedPasswordIfNeeded(for: options))
        } catch {
            refreshStatus(lastError: error.localizedDescription)
        }
    }
    
    func calculateBackupSize(options: BackupOptions) async throws -> Int64 {
        let package = try await createBackupPackage(trigger: .manual, options: options, password: nil, dryRun: true)
        let data = try JSONEncoder().encode(package)
        return Int64(data.count)
    }
    
    func exportBackup(manifest: BackupManifest, format: BackupFileFormat, password: String?) async throws -> URL {
        let url = try backupURL(for: manifest)
        switch format {
        case .archive:
            return url
        case .json, .html:
            let data = try Data(contentsOf: url)
            let packageData = try unwrapIfEncrypted(data: data, password: password)
            let package = try JSONDecoder().decode(BookmarkBackupPackage.self, from: packageData)
            switch format {
            case .json:
                let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("Backup_\(manifest.id.uuidString).json")
                try packageData.write(to: exportURL, options: .atomic)
                return exportURL
            case .html:
                let snapshot = try await rebuildSnapshot(from: package, password: password)
                let html = BackupHTMLRenderer.render(snapshot: snapshot)
                let exportURL = FileManager.default.temporaryDirectory.appendingPathComponent("Backup_\(manifest.id.uuidString).html")
                try html.data(using: .utf8)?.write(to: exportURL, options: .atomic)
                return exportURL
            default:
                return url
            }
        }
    }
    
    func availableManifests() -> [BackupManifest] {
        manifests.sorted { $0.createdAt > $1.createdAt }
    }
    
    func deleteBackup(manifest: BackupManifest) {
        let url = try? backupURL(for: manifest)
        if let url = url {
            try? fileManager.removeItem(at: url)
        }
        manifests.removeAll { $0.id == manifest.id }
        saveManifestsToDisk()
        refreshStatus()
    }
    
    func restore(from manifest: BackupManifest, mode: BackupRestoreMode, password: String?) async throws {
        let packageData = try Data(contentsOf: backupURL(for: manifest))
        let unpackedData = try unwrapIfEncrypted(data: packageData, password: password)
        let package = try JSONDecoder().decode(BookmarkBackupPackage.self, from: unpackedData)
        let snapshot = try await rebuildSnapshot(from: package, password: password)
        try await applySnapshot(snapshot, mode: mode)
    }
    
    func previewSummary(for manifest: BackupManifest, password: String?) async throws -> BackupPreviewSummary {
        let snapshot = try await loadSnapshotFromManifest(manifest, password: password)
        let summary = BackupPreviewSummary(manifest: manifest,
                                           metadata: snapshot.metadata,
                                           bookmarkCount: snapshot.bookmarks.count,
                                           collectionCount: snapshot.collections.count,
                                           tagCount: snapshot.tags.count,
                                           highlightCount: snapshot.highlights.count,
                                           sampleBookmarks: Array(snapshot.bookmarks.prefix(10)))
        return summary
    }

    // MARK: - Internal Helpers
    
    private func generateBackup(trigger: BackupTrigger, options: BackupOptions, password: String?) async throws -> BackupManifest {
        let resolvedPassword = password ?? storedPasswordIfNeeded(for: options)
        let package = try await createBackupPackage(trigger: trigger, options: options, password: resolvedPassword, dryRun: false)
        let data = try JSONEncoder().encode(package)
        let finalData: Data
        let encrypted: Bool
        if options.encryptWithPassword, let resolvedPassword {
            let envelope = try encrypt(data: data, password: resolvedPassword)
            finalData = try JSONEncoder().encode(envelope)
            encrypted = true
        } else {
            finalData = data
            encrypted = false
        }
        let directory = resolveDirectory(for: options.storagePreference)
        let fileName = makeFileName(trigger: trigger, type: package.header.type)
        let fileURL = directory.appendingPathComponent(fileName)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try finalData.write(to: fileURL, options: .atomic)
        lastBackupPath = fileURL
        let size = Int64(finalData.count)
        let manifest = BackupManifest(id: package.header.id,
                                      createdAt: package.header.createdAt,
                                      trigger: trigger,
                                      type: package.header.type,
                                      storageLocation: directory == localDirectory ? .local : .iCloud,
                                      fileName: fileName,
                                      contentOptionsRaw: package.header.contentOptionsRaw,
                                      encrypted: encrypted,
                                      baseBackupID: package.header.baseBackupID,
                                      size: size,
                                      checksumSummary: package.payload.checksumSummary)
        return manifest
    }
    
    private func createBackupPackage(trigger: BackupTrigger, options: BackupOptions, password: String?, dryRun: Bool) async throws -> BookmarkBackupPackage {
        let includeOptions = options.content
        let snapshot = try await collectSnapshot(options: includeOptions)
        let checksumSummary = makeChecksumSummary(from: snapshot)
        
        var baseManifest: BackupManifest?
        if options.incremental {
            baseManifest = manifests.first(where: { $0.type == .full && $0.contentOptionsRaw == includeOptions.rawValue && !$0.encrypted })
        }
        let type: BackupManifest.BackupType = (options.incremental && baseManifest != nil) ? .incremental : .full
        var payloadSnapshot: BookmarkBackupSnapshot? = snapshot
        var diff: BookmarkBackupDiff?
        if type == .incremental, let base = baseManifest {
            let baseSnapshot = try await loadSnapshotFromManifest(base, password: password)
            diff = makeDiff(current: snapshot, base: baseSnapshot)
            payloadSnapshot = nil
        }
        let header = BookmarkBackupPackage.Header(id: UUID(),
                                                  createdAt: Date(),
                                                  trigger: trigger,
                                                  type: type,
                                                  contentOptionsRaw: includeOptions.rawValue,
                                                  baseBackupID: baseManifest?.id)
        let payload = BookmarkBackupPackage.Payload(snapshot: payloadSnapshot,
                                                    diff: diff,
                                                    checksumSummary: checksumSummary)
        return BookmarkBackupPackage(header: header, payload: payload)
    }
    
    private func collectSnapshot(options: BackupContentOptions) async throws -> BookmarkBackupSnapshot {
        try await coreData.performBackgroundTask { context in
            var bookmarks: [BookmarkRecord] = []
            var checksumDict: [UUID: String] = [:]
            let bookmarkRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
            bookmarkRequest.relationshipKeyPathsForPrefetching = ["collection", "tagRelations"]
            let fetchedBookmarks = try context.fetch(bookmarkRequest)
            for bookmark in fetchedBookmarks {
                let id = bookmark.id ?? UUID()
                let collectionID = bookmark.collection?.id
                let record = BookmarkRecord(
                    id: id,
                    url: bookmark.url,
                    title: bookmark.title,
                    description: options.contains(.metadata) ? bookmark.bookmarkDescription : nil,
                    collectionID: collectionID,
                    collectionName: bookmark.collection?.name ?? bookmark.collectionName,
                    tagNames: options.contains(.tags) ? bookmark.decodedTags : [],
                    isFavorite: bookmark.isFavorite,
                    isArchived: bookmark.isArchived,
                    createdDate: bookmark.createdDate,
                    lastOpenedDate: bookmark.lastOpenedDate,
                    lastModifiedDate: bookmark.lastModifiedDate,
                    openCount: bookmark.openCount,
                    notes: options.contains(.userNotes) ? bookmark.notes : nil,
                    previewImage: options.contains(.previewImages) ? bookmark.previewImage : nil,
                    favicon: options.contains(.previewImages) ? bookmark.favicon : nil,
                    metadata: BookmarkSnapshotMetadata(checksum: BookmarkBackupService.checksum(for: bookmark))
                )
                bookmarks.append(record)
                checksumDict[id] = record.metadata.checksum
            }
            
            var collections: [CollectionRecord] = []
            var collectionChecksums: [UUID: String] = [:]
            if options.contains(.collections) {
                let request: NSFetchRequest<Collection> = Collection.fetchRequest()
                let fetchedCollections = try context.fetch(request)
                for collection in fetchedCollections {
                    let id = collection.id ?? UUID()
                    let checksum = BookmarkBackupService.checksum(for: collection)
                    let record = CollectionRecord(id: id,
                                                  name: collection.name ?? "Unnamed",
                                                  color: collection.color,
                                                  icon: collection.icon,
                                                  sortOrder: collection.sortOrder,
                                                  parentID: collection.parent?.id,
                                                  checksum: checksum)
                    collections.append(record)
                    collectionChecksums[id] = checksum
                }
            }
            
            var tagRecords: [TagRecord] = []
            var tagChecksums: [UUID: String] = [:]
            if options.contains(.tags) {
                let request: NSFetchRequest<Tag> = Tag.fetchRequest()
                let tags = try context.fetch(request)
                for tag in tags {
                    let id = tag.id ?? UUID()
                    let checksum = BookmarkBackupService.checksum(for: tag)
                    tagRecords.append(TagRecord(id: id,
                                                name: tag.name ?? "",
                                                color: tag.color,
                                                usageCount: tag.usageCount,
                                                checksum: checksum))
                    tagChecksums[id] = checksum
                }
            }
            
            var highlightRecords: [HighlightRecord] = []
            var highlightChecksums: [UUID: String] = [:]
            if options.contains(.highlights) {
                let request: NSFetchRequest<Highlight> = Highlight.fetchRequest()
                let highlights = try context.fetch(request)
                for highlight in highlights {
                    let id = highlight.id ?? UUID()
                    let checksum = BookmarkBackupService.checksum(for: highlight)
                    highlightRecords.append(HighlightRecord(
                        id: id,
                        bookmarkID: highlight.bookmark?.id,
                        selectedText: highlight.selectedText ?? "",
                        color: highlight.color ?? HighlightColor.yellow.rawValue,
                        note: highlight.note,
                        rangeStart: highlight.rangeStart,
                        rangeEnd: highlight.rangeEnd,
                        xpath: highlight.xpath,
                        offset: highlight.offset,
                        createdDate: highlight.createdDate,
                        checksum: checksum
                    ))
                    highlightChecksums[id] = checksum
                }
            }
            
            let metadata = options.contains(.metadata) ? BackupMetadata(
                createdAt: Date(),
                deviceName: {
                    #if canImport(UIKit)
                    return UIDevice.current.name
                    #else
                    return Host.current().localizedName ?? "Device"
                    #endif
                }(),
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
                totalBookmarks: bookmarks.count,
                totalCollections: collections.count,
                totalTags: tagRecords.count,
                notesIncluded: options.contains(.userNotes)
            ) : nil
            
            return BookmarkBackupSnapshot(metadata: metadata,
                                           bookmarks: bookmarks,
                                           collections: collections,
                                           tags: tagRecords,
                                           highlights: highlightRecords)
        }
    }
    
    private func makeChecksumSummary(from snapshot: BookmarkBackupSnapshot) -> BackupChecksumSummary {
        let bookmarkChecks = Dictionary(uniqueKeysWithValues: snapshot.bookmarks.map { ($0.id, $0.metadata.checksum) })
        let collectionChecks = Dictionary(uniqueKeysWithValues: snapshot.collections.map { ($0.id, $0.checksum) })
        let tagChecks = Dictionary(uniqueKeysWithValues: snapshot.tags.map { ($0.id, $0.checksum) })
        let highlightChecks = Dictionary(uniqueKeysWithValues: snapshot.highlights.map { ($0.id, $0.checksum) })
        return BackupChecksumSummary(bookmarks: bookmarkChecks,
                                     collections: collectionChecks,
                                     tags: tagChecks,
                                     highlights: highlightChecks)
    }
    
    private func makeDiff(current: BookmarkBackupSnapshot, base: BookmarkBackupSnapshot) -> BookmarkBackupDiff {
        func diffRecords<T>(_ current: [T], base: [T], key: (T) -> UUID, checksum: (T) -> String) -> ([T], [UUID]) {
            let baseMap = Dictionary(uniqueKeysWithValues: base.map { (key($0), checksum($0)) })
            var updated: [T] = []
            var deleted = Set(baseMap.keys)
            for record in current {
                let identifier = key(record)
                let currentChecksum = checksum(record)
                if let baseChecksum = baseMap[identifier] {
                    if baseChecksum != currentChecksum {
                        updated.append(record)
                    }
                } else {
                    updated.append(record)
                }
                deleted.remove(identifier)
            }
            return (updated, Array(deleted))
        }
        let (bookmarkUpdates, bookmarkDeletes) = diffRecords(current.bookmarks, base: base.bookmarks, key: { $0.id }, checksum: { $0.metadata.checksum })
        let (collectionUpdates, collectionDeletes) = diffRecords(current.collections, base: base.collections, key: { $0.id }, checksum: { $0.checksum })
        let (tagUpdates, tagDeletes) = diffRecords(current.tags, base: base.tags, key: { $0.id }, checksum: { $0.checksum })
        let (highlightUpdates, highlightDeletes) = diffRecords(current.highlights, base: base.highlights, key: { $0.id }, checksum: { $0.checksum })
        return BookmarkBackupDiff(bookmarksAddedOrUpdated: bookmarkUpdates,
                                  bookmarksDeleted: bookmarkDeletes,
                                  collectionsAddedOrUpdated: collectionUpdates,
                                  collectionsDeleted: collectionDeletes,
                                  tagsAddedOrUpdated: tagUpdates,
                                  tagsDeleted: tagDeletes,
                                  highlightsAddedOrUpdated: highlightUpdates,
                                  highlightsDeleted: highlightDeletes)
    }
    
    private func backupURL(for manifest: BackupManifest) throws -> URL {
        let directory = manifest.storageLocation == .local ? localDirectory : (iCloudDirectory ?? localDirectory)
        return directory.appendingPathComponent(manifest.fileName)
    }
    
    private func resolveDirectory(for preference: BackupStoragePreference) -> URL {
        switch preference {
        case .localOnly:
            return localDirectory
        case .iCloudIfAvailable:
            return iCloudDirectory ?? localDirectory
        case .automatic:
            if let iCloudDirectory {
                return iCloudDirectory
            }
            return localDirectory
        }
    }
    
    private func makeFileName(trigger: BackupTrigger, type: BackupManifest.BackupType) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withFullTime, .withDashSeparatorInDate, .withColonSeparatorInTime]
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        return "bookmark_\(type.rawValue)_\(trigger.rawValue)_\(timestamp).cnbak"
    }
    
    private func saveManifestsToDisk() {
        let manifestURL = localDirectory.appendingPathComponent(manifestsFileName)
        if let data = try? JSONEncoder().encode(manifests) {
            try? data.write(to: manifestURL, options: .atomic)
        }
    }
    
    private func loadManifestsFromDisk() {
        let manifestURL = localDirectory.appendingPathComponent(manifestsFileName)
        if let data = try? Data(contentsOf: manifestURL),
           let decoded = try? JSONDecoder().decode([BackupManifest].self, from: data) {
            self.manifests = decoded
        } else {
            self.manifests = []
        }
    }
    
    private func trimOldBackupsIfNeeded() {
        guard manifests.count > 7 else { return }
        let sorted = manifests.sorted { $0.createdAt > $1.createdAt }
        let keep = Array(sorted.prefix(7).map { $0.id })
        for manifest in manifests where !keep.contains(manifest.id) {
            if let url = try? backupURL(for: manifest) {
                try? fileManager.removeItem(at: url)
            }
        }
        manifests.removeAll { !keep.contains($0.id) }
    }
    
    private func unwrapIfEncrypted(data: Data, password: String?) throws -> Data {
        if let envelope = try? JSONDecoder().decode(BackupEnvelope.self, from: data) {
            guard let password else {
                throw NSError(domain: "CalendarNotes", code: -2, userInfo: [NSLocalizedDescriptionKey: "Password required to decrypt backup.\n"])
            }
            return try decrypt(envelope: envelope, password: password)
        }
        return data
    }

    private func storedPasswordIfNeeded(for options: BackupOptions) -> String? {
        guard options.encryptWithPassword else { return nil }
        return KeychainHelper.readPassword(service: keychainServiceID, account: keychainAccountID)
    }

    func configureEncryption(enabled: Bool, password: String?, hint: String?) {
        if enabled, let password {
            try? KeychainHelper.savePassword(password, service: keychainServiceID, account: keychainAccountID)
        } else {
            KeychainHelper.deletePassword(service: keychainServiceID, account: keychainAccountID)
        }
        var updated = options
        updated.encryptWithPassword = enabled
        updated.passwordHint = hint
        updateOptions(updated)
    }

    func hasStoredEncryptionPassword() -> Bool {
        storedPasswordIfNeeded(for: options) != nil
    }

    private func rebuildSnapshot(from package: BookmarkBackupPackage, password: String?) async throws -> BookmarkBackupSnapshot {
        if let snapshot = package.payload.snapshot {
            return snapshot
        }
        guard let diff = package.payload.diff else {
            throw NSError(domain: "CalendarNotes", code: -3, userInfo: [NSLocalizedDescriptionKey: "Backup payload missing snapshot data."])
        }
        guard let baseID = package.header.baseBackupID,
              let baseManifest = manifests.first(where: { $0.id == baseID }) else {
            throw NSError(domain: "CalendarNotes", code: -4, userInfo: [NSLocalizedDescriptionKey: "Base backup not found for incremental restore."])
        }
        let baseSnapshot = try await loadSnapshotFromManifest(baseManifest, password: password)
        return apply(diff: diff, to: baseSnapshot)
    }
    
    private func loadSnapshotFromManifest(_ manifest: BackupManifest, password: String?) async throws -> BookmarkBackupSnapshot {
        let data = try Data(contentsOf: backupURL(for: manifest))
        let unpacked = try unwrapIfEncrypted(data: data, password: password)
        let package = try JSONDecoder().decode(BookmarkBackupPackage.self, from: unpacked)
        return try await rebuildSnapshot(from: package, password: password)
    }
    
    private func apply(diff: BookmarkBackupDiff, to base: BookmarkBackupSnapshot) -> BookmarkBackupSnapshot {
        var bookmarks = Dictionary(uniqueKeysWithValues: base.bookmarks.map { ($0.id, $0) })
        for record in diff.bookmarksAddedOrUpdated {
            bookmarks[record.id] = record
        }
        for deleted in diff.bookmarksDeleted {
            bookmarks.removeValue(forKey: deleted)
        }
        
        var collections = Dictionary(uniqueKeysWithValues: base.collections.map { ($0.id, $0) })
        for record in diff.collectionsAddedOrUpdated {
            collections[record.id] = record
        }
        for deleted in diff.collectionsDeleted {
            collections.removeValue(forKey: deleted)
        }
        
        var tags = Dictionary(uniqueKeysWithValues: base.tags.map { ($0.id, $0) })
        for record in diff.tagsAddedOrUpdated {
            tags[record.id] = record
        }
        for deleted in diff.tagsDeleted {
            tags.removeValue(forKey: deleted)
        }
        
        var highlights = Dictionary(uniqueKeysWithValues: base.highlights.map { ($0.id, $0) })
        for record in diff.highlightsAddedOrUpdated {
            highlights[record.id] = record
        }
        for deleted in diff.highlightsDeleted {
            highlights.removeValue(forKey: deleted)
        }
        
        return BookmarkBackupSnapshot(metadata: base.metadata,
                                       bookmarks: Array(bookmarks.values),
                                       collections: Array(collections.values),
                                       tags: Array(tags.values),
                                       highlights: Array(highlights.values))
    }
    
    private func applySnapshot(_ snapshot: BookmarkBackupSnapshot, mode: BackupRestoreMode) async throws {
        try await coreData.performBackgroundTask { context in
            let bookmarkRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
            let bookmarks = try context.fetch(bookmarkRequest)
            let collectionRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
            let collections = try context.fetch(collectionRequest)
            let tagRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
            let tags = try context.fetch(tagRequest)
            let highlightRequest: NSFetchRequest<Highlight> = Highlight.fetchRequest()
            let highlights = try context.fetch(highlightRequest)
            
            switch mode {
            case .replaceAll:
                for bookmark in bookmarks { context.delete(bookmark) }
                for collection in collections { context.delete(collection) }
                for tag in tags { context.delete(tag) }
                for highlight in highlights { context.delete(highlight) }
                try context.save()
                fallthrough
            case .merge:
                try self.applyCollections(snapshot.collections, in: context)
                try self.applyTags(snapshot.tags, in: context)
                try self.applyBookmarks(snapshot.bookmarks, in: context, replaceExisting: mode == .replaceAll)
                try self.applyHighlights(snapshot.highlights, in: context, replaceExisting: mode == .replaceAll)
            case .collectionsOnly:
                try self.applyCollections(snapshot.collections, in: context)
            case .bookmarksOnly:
                try self.applyBookmarks(snapshot.bookmarks, in: context, replaceExisting: mode == .replaceAll)
            }
            try context.save()
        }
    }
    
    private func applyCollections(_ records: [CollectionRecord], in context: NSManagedObjectContext) throws {
        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        let existing = try context.fetch(request)
        let map = Dictionary(uniqueKeysWithValues: existing.compactMap { collection -> (UUID, Collection)? in
            guard let id = collection.id else { return nil }
            return (id, collection)
        })
        for record in records {
            if let existing = map[record.id] {
                existing.name = record.name
                existing.color = record.color
                existing.icon = record.icon
                existing.sortOrder = record.sortOrder
            } else {
                _ = Collection(context: context,
                                id: record.id,
                                name: record.name,
                                color: record.color ?? "#999999",
                                icon: record.icon,
                                sortOrder: record.sortOrder)
            }
        }
    }
    
    private func applyTags(_ records: [TagRecord], in context: NSManagedObjectContext) throws {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        let existing = try context.fetch(request)
        let map = Dictionary(uniqueKeysWithValues: existing.compactMap { tag -> (UUID, Tag)? in
            guard let id = tag.id else { return nil }
            return (id, tag)
        })
        for record in records {
            if let existing = map[record.id] {
                existing.name = record.name
                existing.color = record.color
                existing.usageCount = record.usageCount
            } else {
                _ = Tag(context: context,
                        id: record.id,
                        name: record.name,
                        color: record.color,
                        usageCount: record.usageCount)
            }
        }
    }
    
    private func applyBookmarks(_ records: [BookmarkRecord], in context: NSManagedObjectContext, replaceExisting: Bool) throws {
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        let existingList = try context.fetch(request)
        let map = Dictionary(uniqueKeysWithValues: existingList.compactMap { bookmark -> (UUID, Bookmark)? in
            guard let id = bookmark.id else { return nil }
            return (id, bookmark)
        })
        
        let collectionRequest: NSFetchRequest<Collection> = Collection.fetchRequest()
        let allCollections = try context.fetch(collectionRequest)
        var collectionMap = Dictionary(uniqueKeysWithValues: allCollections.compactMap { collection -> (UUID, Collection)? in
            guard let id = collection.id else { return nil }
            return (id, collection)
        })
        
        for record in records {
            let sanitizedURL = URLPrivacySanitizer.sanitized(record.url ?? "")
            if let existing = map[record.id], !replaceExisting {
                existing.title = record.title
                existing.url = sanitizedURL
                existing.bookmarkDescription = record.description
                existing.isFavorite = record.isFavorite
                existing.isArchived = record.isArchived
                existing.notes = record.notes ?? existing.notes
                if let preview = record.previewImage { existing.previewImage = preview }
                if let favicon = record.favicon { existing.favicon = favicon }
                if let collectionID = record.collectionID, let target = collectionMap[collectionID] {
                    existing.collection = target
                } else if let collectionName = record.collectionName, !collectionName.isEmpty {
                    let target = try self.ensureCollection(named: collectionName, existing: &collectionMap, in: context)
                    existing.collection = target
                    existing.collectionName = target.name
                }
                try self.setTags(record.tagNames, for: existing, in: context)
            } else {
                let bookmark = Bookmark(context: context)
                bookmark.id = record.id
                bookmark.url = sanitizedURL
                bookmark.title = record.title
                bookmark.bookmarkDescription = record.description
                bookmark.collectionName = record.collectionName
                bookmark.isFavorite = record.isFavorite
                bookmark.isArchived = record.isArchived
                bookmark.createdDate = record.createdDate
                bookmark.lastOpenedDate = record.lastOpenedDate
                bookmark.lastModifiedDate = record.lastModifiedDate
                bookmark.openCount = record.openCount
                bookmark.notes = record.notes
                bookmark.previewImage = record.previewImage
                bookmark.favicon = record.favicon
                if let collectionID = record.collectionID, let target = collectionMap[collectionID] {
                    bookmark.collection = target
                } else if let collectionName = record.collectionName, !collectionName.isEmpty {
                    let target = try self.ensureCollection(named: collectionName, existing: &collectionMap, in: context)
                    bookmark.collection = target
                    bookmark.collectionName = target.name
                }
                try self.setTags(record.tagNames, for: bookmark, in: context)
            }
        }
    }
    
    private func applyHighlights(_ records: [HighlightRecord], in context: NSManagedObjectContext, replaceExisting: Bool) throws {
        guard !records.isEmpty else { return }
        let request: NSFetchRequest<Highlight> = Highlight.fetchRequest()
        let existing = try context.fetch(request)
        let map = Dictionary(uniqueKeysWithValues: existing.compactMap { highlight -> (UUID, Highlight)? in
            guard let id = highlight.id else { return nil }
            return (id, highlight)
        })
        let bookmarkRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        let bookmarks = try context.fetch(bookmarkRequest)
        let bookmarkMap = Dictionary(uniqueKeysWithValues: bookmarks.compactMap { bookmark -> (UUID, Bookmark)? in
            guard let id = bookmark.id else { return nil }
            return (id, bookmark)
        })
        for record in records {
            if let existing = map[record.id], !replaceExisting {
                existing.selectedText = record.selectedText
                existing.color = record.color
                existing.note = record.note
                existing.rangeStart = record.rangeStart
                existing.rangeEnd = record.rangeEnd
                existing.xpath = record.xpath
                existing.offset = record.offset
                existing.createdDate = record.createdDate
                if let bookmarkID = record.bookmarkID, let bookmark = bookmarkMap[bookmarkID] {
                    existing.bookmark = bookmark
                }
            } else {
                let highlight = Highlight(context: context)
                highlight.id = record.id
                highlight.selectedText = record.selectedText
                highlight.color = record.color
                highlight.note = record.note
                highlight.rangeStart = record.rangeStart
                highlight.rangeEnd = record.rangeEnd
                highlight.xpath = record.xpath
                highlight.offset = record.offset
                highlight.createdDate = record.createdDate
                if let bookmarkID = record.bookmarkID, let bookmark = bookmarkMap[bookmarkID] {
                    highlight.bookmark = bookmark
                }
            }
        }
    }
    
    // MARK: - Encryption Helpers
    
    private func encrypt(data: Data, password: String) throws -> BackupEnvelope {
        let salt = randomData(count: 16)
        let nonceData = randomData(count: 12)
        let key = deriveKey(password: password, salt: salt)
        let sealedBox = try AES.GCM.seal(data, using: key, nonce: try AES.GCM.Nonce(data: nonceData))
        return BackupEnvelope(salt: salt, nonce: nonceData, ciphertext: sealedBox.ciphertext + sealedBox.tag)
    }
    
    private func decrypt(envelope: BackupEnvelope, password: String) throws -> Data {
        let key = deriveKey(password: password, salt: envelope.salt)
        let ciphertext = envelope.ciphertext.dropLast(16)
        let tag = envelope.ciphertext.suffix(16)
        let sealedBox = try AES.GCM.SealedBox(nonce: try AES.GCM.Nonce(data: envelope.nonce), ciphertext: ciphertext, tag: tag)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    private func deriveKey(password: String, salt: Data) -> SymmetricKey {
        let passwordData = Data(password.utf8)
        var keyMaterial = Data()
        keyMaterial.append(passwordData)
        keyMaterial.append(salt)
        let hashed = SHA256.hash(data: keyMaterial)
        return SymmetricKey(data: hashed)
    }
    
    private func randomData(count: Int) -> Data {
        var data = Data(count: count)
        data.withUnsafeMutableBytes { bytes in
            _ = SecRandomCopyBytes(kSecRandomDefault, count, bytes.baseAddress!)
        }
        return data
    }
    
    // MARK: - Utility
    
    private static func locateICloudDirectory() -> URL? {
        guard let container = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.calendarnotes.app") else {
            return nil
        }
        let backupsURL = container.appendingPathComponent("Documents/Backups", isDirectory: true)
        try? FileManager.default.createDirectory(at: backupsURL, withIntermediateDirectories: true)
        return backupsURL
    }
    
    private static func checksum(for bookmark: Bookmark) -> String {
        var components: [String] = []
        components.append(bookmark.id?.uuidString ?? "")
        components.append(bookmark.url ?? "")
        components.append(bookmark.title ?? "")
        components.append(bookmark.bookmarkDescription ?? "")
        components.append(bookmark.notes ?? "")
        components.append((bookmark.collection?.name ?? bookmark.collectionName) ?? "")
        components.append(bookmark.decodedTags.joined(separator: ","))
        return hash(components.joined(separator: "|"))
    }
    
    private static func checksum(for collection: Collection) -> String {
        let components = [collection.id?.uuidString ?? "",
                          collection.name ?? "",
                          collection.color ?? "",
                          collection.icon ?? "",
                          String(collection.sortOrder)]
        return hash(components.joined(separator: "|"))
    }
    
    private static func checksum(for tag: Tag) -> String {
        let components = [tag.id?.uuidString ?? "",
                          tag.name ?? "",
                          tag.color ?? "",
                          String(tag.usageCount)]
        return hash(components.joined(separator: "|"))
    }
    
    private static func checksum(for highlight: Highlight) -> String {
        let components = [highlight.id?.uuidString ?? "",
                          highlight.bookmark?.id?.uuidString ?? "",
                          highlight.selectedText ?? "",
                          highlight.color ?? "",
                          highlight.note ?? ""]
        return hash(components.joined(separator: "|"))
    }
    
    private static func hash(_ string: String) -> String {
        let data = Data(string.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func applySnapshotsToTags(_ bookmark: Bookmark, tagNames: [String], context: NSManagedObjectContext) throws {
        guard !tagNames.isEmpty else {
            bookmark.tagRelations = NSSet()
            bookmark.decodedTags = []
            return
        }
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "name IN[cd] %@", tagNames)
        let existingTags = try context.fetch(request)
        var tagMap = Dictionary(uniqueKeysWithValues: existingTags.compactMap { tag -> (String, Tag)? in
            guard let name = tag.name?.lowercased() else { return nil }
            return (name, tag)
        })
        var tagsToAssign: [Tag] = []
        for name in tagNames {
            let lower = name.lowercased()
            if let tag = tagMap[lower] {
                tagsToAssign.append(tag)
            } else {
                let newTag = Tag(context: context, name: name)
                tagsToAssign.append(newTag)
                tagMap[lower] = newTag
            }
        }
        bookmark.tagRelations = NSSet(array: tagsToAssign)
        bookmark.decodedTags = tagNames
    }
 
     private func ensureCollection(named name: String, existing map: inout [UUID: Collection], in context: NSManagedObjectContext) throws -> Collection {
         if let match = map.values.first(where: { ($0.name ?? "").caseInsensitiveCompare(name) == .orderedSame }) {
             return match
         }
         let collection = Collection(context: context, name: name)
         if let id = collection.id { map[id] = collection }
         return collection
     }
 
     private func setTags(_ tagNames: [String], for bookmark: Bookmark, in context: NSManagedObjectContext) throws {
         try applySnapshotsToTags(bookmark, tagNames: tagNames, context: context)
     }
 }

// MARK: - HTML Renderer

enum BackupHTMLRenderer {
    static func render(snapshot: BookmarkBackupSnapshot) -> String {
        var html = "<html><head><meta charset=\"utf-8\"><style>body{font-family:-apple-system,Helvetica,Arial;padding:24px;color:#111;background:#fff;}h1{font-size:24px;}h2{margin-top:24px;}table{border-collapse:collapse;width:100%;}th,td{border:1px solid #ccc;padding:8px;font-size:12px;}th{background:#f3f3f3;text-align:left;}</style></head><body>"
        html += "<h1>CalendarNotes Backup</h1>"
        if let metadata = snapshot.metadata {
            html += "<p><strong>Created:</strong> \(metadata.createdAt)</p>"
            html += "<p><strong>Device:</strong> \(metadata.deviceName)</p>"
            html += "<p><strong>App Version:</strong> \(metadata.appVersion)</p>"
            html += "<p><strong>Total Bookmarks:</strong> \(metadata.totalBookmarks)</p>"
        }
        html += "<h2>Bookmarks</h2>"
        html += "<table><tr><th>Title</th><th>URL</th><th>Collection</th><th>Tags</th><th>Favorite</th></tr>"
        for bookmark in snapshot.bookmarks {
            html += "<tr><td>\(bookmark.title ?? "Untitled")</td><td>\(bookmark.url ?? "")</td><td>\(bookmark.collectionName ?? "")</td><td>\(bookmark.tagNames.joined(separator: ", "))</td><td>\(bookmark.isFavorite ? "★" : "-")</td></tr>"
        }
        html += "</table>"
        if !snapshot.collections.isEmpty {
            html += "<h2>Collections</h2><ul>"
            for collection in snapshot.collections {
                html += "<li>\(collection.name)</li>"
            }
            html += "</ul>"
        }
        if !snapshot.tags.isEmpty {
            html += "<h2>Tags</h2><ul>"
            for tag in snapshot.tags {
                html += "<li>\(tag.name)</li>"
            }
            html += "</ul>"
        }
        html += "</body></html>"
        return html
    }
}

// MARK: - Backup Scheduler

@MainActor
final class BookmarkBackupScheduler {
    static let shared = BookmarkBackupScheduler()
    private var observerTokens: [NSObjectProtocol] = []
    private init() {}
    
    func start() {
        guard observerTokens.isEmpty else { return }
        #if canImport(UIKit)
        let didBecomeActive = UIApplication.didBecomeActiveNotification
        #else
        let didBecomeActive = NSApplication.didBecomeActiveNotification
        #endif
        let token = NotificationCenter.default.addObserver(forName: didBecomeActive, object: nil, queue: .main) { _ in
            Task { await BookmarkBackupService.shared.performAutomaticBackupIfNeeded(reason: .automaticDaily) }
        }
        observerTokens.append(token)
    }
    
    func handleAppLaunch() {
        Task { await BookmarkBackupService.shared.performAutomaticBackupIfNeeded(reason: .appLaunch) }
    }
}
