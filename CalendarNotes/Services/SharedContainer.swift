//
//  SharedContainer.swift
//  CalendarNotes
//

import Foundation

enum SharedContainer {
    // Update this to your actual App Group identifier when you configure the extension
    static let appGroupId = "group.com.calendarnotes.app"
    
    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupId)
    }
    
    static var queueDirectory: URL? {
        containerURL?.appendingPathComponent("SaveQueue", isDirectory: true)
    }
}


