import Foundation
import CoreData

extension ProjectMilestone {
    convenience init(
        context: NSManagedObjectContext,
        title: String,
        detail: String? = nil,
        dueDate: Date? = nil,
        sortOrder: Int32 = 0,
        collection: Collection? = nil
    ) {
        self.init(context: context)
        self.id = UUID()
        self.title = title
        self.detail = detail
        self.dueDate = dueDate
        self.createdDate = Date()
        self.sortOrder = sortOrder
        self.collection = collection
        self.isCompleted = false
    }

    var statusDescription: String {
        if isCompleted {
            if let completedDate {
                return "Completed on \(DateFormatter.shortDateFormatter.string(from: completedDate))"
            }
            return "Completed"
        }
        if let dueDate {
            let formatter = DateFormatter.shortDateFormatter
            if dueDate < Date() {
                return "Overdue since \(formatter.string(from: dueDate))"
            }
            return "Due \(formatter.string(from: dueDate))"
        }
        return "No due date"
    }
}

private extension DateFormatter {
    static let shortDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
