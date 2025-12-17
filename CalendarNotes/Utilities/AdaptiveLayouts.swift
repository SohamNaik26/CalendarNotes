//
//  AdaptiveLayouts.swift
//  CalendarNotes
//
//  Created for adaptive grid layouts
//

import SwiftUI

struct AdaptiveLayouts {
    /// Returns adaptive grid columns based on device size
    /// - Parameter columns: Number of columns for iPad (default: 3)
    /// - Returns: Array of GridItem configured for current device
    static func gridColumns(ipadColumns: Int = 3) -> [GridItem] {
        if ScreenSize.isPad {
            return Array(repeating: GridItem(.flexible(), spacing: 16), count: ipadColumns)
        } else if ScreenSize.isExtraLargeDevice {
            return Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
        } else if ScreenSize.isLargeDevice {
            return Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)
        } else {
            return [GridItem(.flexible())]
        }
    }
    
    /// Returns spacing for calendar grid based on device size
    static var calendarGridSpacing: CGFloat {
        if ScreenSize.isPad {
            return 8
        }
        if ScreenSize.isSmallDevice {
            return 2
        }
        return 4
    }
    
    /// Calculates calendar cell height based on available width
    static func calendarCellHeight(availableWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        // Validate inputs
        guard availableWidth.isFinite && availableWidth > 0,
              spacing.isFinite && spacing >= 0 else {
            return 50 // Default fallback height
        }
        
        let totalSpacing = spacing * 6
        let adjustedWidth = availableWidth - totalSpacing
        
        // Ensure adjusted width is positive
        guard adjustedWidth > 0 else {
            return 50 // Default fallback height
        }
        
        let cellWidth = adjustedWidth / 7
        
        // Validate result is finite and positive
        guard cellWidth.isFinite && cellWidth > 0 else {
            return 50 // Default fallback height
        }
        
        // Ensure the result is reasonable (minimum 40, maximum 200)
        return min(max(cellWidth, 40), 200)
    }
}

