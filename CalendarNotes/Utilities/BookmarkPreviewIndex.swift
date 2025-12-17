import Foundation
import CoreData

actor BookmarkPreviewIndex {
    static let shared = BookmarkPreviewIndex()
    
    private let userDefaults: UserDefaults
    private let storageKey = "bookmark.preview.index"
    private var cache: [String: String]
    
    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        if let stored = userDefaults.dictionary(forKey: storageKey) as? [String: String] {
            cache = stored
        } else {
            cache = [:]
        }
    }
    
    func fileName(for objectID: NSManagedObjectID) -> String? {
        cache[objectID.uriRepresentation().absoluteString]
    }
    
    func setFileName(_ fileName: String, for objectID: NSManagedObjectID) {
        cache[objectID.uriRepresentation().absoluteString] = fileName
        persist()
    }
    
    func remove(objectID: NSManagedObjectID) {
        cache.removeValue(forKey: objectID.uriRepresentation().absoluteString)
        persist()
    }
    
    func clear() {
        cache.removeAll()
        userDefaults.removeObject(forKey: storageKey)
    }
    
    private func persist() {
        userDefaults.set(cache, forKey: storageKey)
    }
}
