import Foundation
import CoreData

extension RecommendationSettings {
    convenience init(context: NSManagedObjectContext, collection: Collection?) {
        self.init(context: context)
        self.id = UUID()
        self.createdDate = Date()
        self.updatedDate = Date()
        self.frequency = 1
        self.allowSimilarContent = true
        self.allowReadingPattern = true
        self.allowTagAffinity = true
        self.allowDomainFrequency = true
        self.allowTrending = true
        self.allowRediscovery = true
        self.allowSerendipity = true
        self.notificationsEnabled = true
        self.collection = collection
    }

    func updateTimestamp() {
        updatedDate = Date()
    }

    var frequencyPerWeek: Int {
        get { Int(frequency) }
        set { frequency = Int16(max(0, newValue)) }
    }
}
