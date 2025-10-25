//
//  CalendarEventExtension.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import Foundation
import CoreData
import Combine

extension CalendarEvent {
    convenience init(context: NSManagedObjectContext, title: String, startDate: Date, endDate: Date, category: String, location: String? = nil, notes: String? = nil, isRecurring: Bool = false, recurrenceRule: String? = nil) {
        self.init(context: context)
        self.id = UUID()
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.category = category
        self.location = location
        self.notes = notes
        self.isRecurring = isRecurring
        self.recurrenceRule = recurrenceRule
    }
}

