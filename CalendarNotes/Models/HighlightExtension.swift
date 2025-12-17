//
//  HighlightExtension.swift
//  CalendarNotes
//
//  Highlight and annotation model for bookmarks
//

import Foundation
import CoreData
import SwiftUI

extension Highlight {
    convenience init(
        context: NSManagedObjectContext,
        id: UUID = UUID(),
        bookmark: Bookmark,
        selectedText: String,
        color: String = "#FFEB3B",
        note: String? = nil,
        rangeStart: Int32 = 0,
        rangeEnd: Int32 = 0,
        xpath: String? = nil,
        offset: Int32 = 0,
        createdDate: Date = Date()
    ) {
        self.init(context: context)
        self.id = id
        self.bookmark = bookmark
        self.selectedText = selectedText
        self.color = color
        self.note = note
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.xpath = xpath
        self.offset = offset
        self.createdDate = createdDate
        // Set lastModifiedDate if the attribute exists in the model
        if self.entity.attributesByName.keys.contains("lastModifiedDate") {
            setValue(createdDate, forKey: "lastModifiedDate")
        }
    }
}

// MARK: - Highlight Color Enum

enum HighlightColor: String, CaseIterable, Identifiable {
    case yellow = "#FFEB3B"
    case green = "#4CAF50"
    case blue = "#2196F3"
    case pink = "#E91E63"
    case purple = "#9C27B0"
    
    var id: String { rawValue }
    
    var name: String {
        switch self {
        case .yellow: return "Yellow"
        case .green: return "Green"
        case .blue: return "Blue"
        case .pink: return "Pink"
        case .purple: return "Purple"
        }
    }
    
    var displayColor: Color {
        Color.hex(rawValue) ?? .yellow
    }
}

