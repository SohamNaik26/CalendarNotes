//
//  NoteExtension.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import Foundation
import CoreData
import Combine

extension Note {
    convenience init(context: NSManagedObjectContext, content: String, linkedDate: Date? = nil, tags: String? = nil) {
        self.init(context: context)
        self.id = UUID()
        self.content = content
        self.createdDate = Date()
        self.linkedDate = linkedDate
        self.tags = tags
    }
    
    var tagArray: [String] {
        get {
            guard let tags = tags else { return [] }
            return tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        }
        set {
            tags = newValue.joined(separator: ", ")
        }
    }
}

