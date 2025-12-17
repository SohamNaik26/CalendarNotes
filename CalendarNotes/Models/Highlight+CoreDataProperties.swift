//
//  Highlight+CoreDataProperties.swift
//  CalendarNotes
//

import Foundation
import CoreData

extension Highlight {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Highlight> {
        return NSFetchRequest<Highlight>(entityName: "Highlight")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var selectedText: String?
    @NSManaged public var color: String?
    @NSManaged public var note: String?
    @NSManaged public var rangeStart: Int32
    @NSManaged public var rangeEnd: Int32
    @NSManaged public var xpath: String?
    @NSManaged public var offset: Int32
    @NSManaged public var createdDate: Date?
    @NSManaged public var lastModifiedDate: Date?

    // Relationships
    @NSManaged public var bookmark: Bookmark?
}

extension Highlight: Identifiable {}


