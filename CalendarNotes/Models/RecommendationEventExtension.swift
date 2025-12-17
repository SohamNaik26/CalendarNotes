import Foundation
import CoreData

extension RecommendationEvent {
    enum Action: String {
        case impression
        case save
        case dismiss
        case notInterested
        case open
        case reminder
    }

    convenience init(context: NSManagedObjectContext, bookmark: Bookmark?, collection: Collection?, reason: String, source: String, score: Double) {
        self.init(context: context)
        self.id = UUID()
        self.createdDate = Date()
        self.reason = reason
        self.source = source
        self.score = NSNumber(value: score)
        self.bookmark = bookmark
        self.collection = collection
    }

    var actionValue: Action? {
        get {
            guard let action else { return nil }
            return Action(rawValue: action)
        }
        set {
            action = newValue?.rawValue
        }
    }

    var metadataDictionary: [String: Any]? {
        get {
            guard let metadataJSON,
                  let data = metadataJSON.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return nil }
            return dict
        }
        set {
            if let newValue,
               let data = try? JSONSerialization.data(withJSONObject: newValue, options: []),
               let json = String(data: data, encoding: .utf8) {
                metadataJSON = json
            } else {
                metadataJSON = nil
            }
        }
    }
}
