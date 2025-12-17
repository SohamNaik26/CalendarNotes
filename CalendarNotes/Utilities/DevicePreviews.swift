//
//  DevicePreviews.swift
//  CalendarNotes
//
//  Created for device preview helpers
//

import SwiftUI

// Convenience extension for easier preview usage
extension View {
    /// Adds previews for all common device sizes
    func previewAllDevices() -> some View {
        Group {
            self
                .previewDevice("iPhone SE (3rd generation)")
                .previewDisplayName("iPhone SE")
            
            self
                .previewDevice("iPhone 15")
                .previewDisplayName("iPhone 15")
            
            self
                .previewDevice("iPhone 15 Pro Max")
                .previewDisplayName("iPhone 15 Pro Max")
            
            self
                .previewDevice("iPad Pro (11-inch)")
                .previewDisplayName("iPad Pro 11\"")
            
            self
                .previewDevice("iPad Pro (12.9-inch)")
                .previewDisplayName("iPad Pro 12.9\"")
        }
    }
    
    /// Adds previews for iPhone devices only
    func previewIPhones() -> some View {
        Group {
            self
                .previewDevice("iPhone SE (3rd generation)")
                .previewDisplayName("iPhone SE")
            
            self
                .previewDevice("iPhone 15")
                .previewDisplayName("iPhone 15")
            
            self
                .previewDevice("iPhone 15 Pro Max")
                .previewDisplayName("iPhone 15 Pro Max")
        }
    }
    
    /// Adds previews for iPad devices only
    func previewIPads() -> some View {
        Group {
            self
                .previewDevice("iPad Pro (11-inch)")
                .previewDisplayName("iPad Pro 11\"")
            
            self
                .previewDevice("iPad Pro (12.9-inch)")
                .previewDisplayName("iPad Pro 12.9\"")
        }
    }
}

