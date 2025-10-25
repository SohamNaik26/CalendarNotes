//
//  TodoItemExtension.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import Foundation
import CoreData
import Combine

extension TodoItem {
    convenience init(context: NSManagedObjectContext, title: String, priority: String, category: String, dueDate: Date? = nil, isCompleted: Bool = false, isRecurring: Bool = false) {
        self.init(context: context)
        self.id = UUID()
        self.title = title
        self.priority = priority
        self.category = category
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.isRecurring = isRecurring
    }
    
    enum Priority: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case urgent = "Urgent"
    }
    
    var priorityEnum: Priority {
        get { Priority(rawValue: priority ?? "Medium") ?? .medium }
        set { priority = newValue.rawValue }
    }
}

