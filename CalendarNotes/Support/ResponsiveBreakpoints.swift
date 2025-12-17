//
//  ResponsiveBreakpoints.swift
//  CalendarNotes
//
//  Centralized breakpoint model for mobile / tablet layouts.
//

import SwiftUI

/// Logical breakpoint buckets used across the mobile layout.
enum CNBreakpoint {
    case mobilePortrait       // ~320–428pt width
    case mobileLandscape      // ~568–926pt width
    case tabletPortrait       // ~768–834pt width
    case tabletLandscape      // ~1024–1366pt width
    case regular              // Anything else / fallback
    
    var isCompact: Bool {
        switch self {
        case .mobilePortrait: return true
        default: return false
        }
    }
    
    var isTablet: Bool {
        switch self {
        case .tabletPortrait, .tabletLandscape:
            return true
        default:
            return false
        }
    }
}

struct CNBreakpointInfo {
    let breakpoint: CNBreakpoint
    let size: CGSize
    let isPortrait: Bool
    
    /// Suggested column count for grid-based layouts.
    var suggestedColumns: Int {
        switch breakpoint {
        case .mobilePortrait:
            // Single column on very narrow phones, two otherwise.
            return size.width <= 360 ? 1 : 2
        case .mobileLandscape:
            return 3
        case .tabletPortrait:
            return 3
        case .tabletLandscape:
            return 4
        case .regular:
            return isPortrait ? 2 : 3
        }
    }
    
    /// Base card spacing tuned per breakpoint.
    var cardSpacing: CGFloat {
        switch breakpoint {
        case .mobilePortrait: return 12
        case .mobileLandscape: return 14
        case .tabletPortrait: return 16
        case .tabletLandscape: return 18
        case .regular: return 14
        }
    }
    
    /// Base font scale factor for titles / key labels.
    var titleScale: CGFloat {
        switch breakpoint {
        case .mobilePortrait: return 0.95
        case .mobileLandscape: return 1.0
        case .tabletPortrait: return 1.1
        case .tabletLandscape: return 1.15
        case .regular: return 1.0
        }
    }
    
    /// Convenience flags mirroring the underlying breakpoint.
    var isCompact: Bool {
        breakpoint.isCompact
    }
    
    var isTablet: Bool {
        breakpoint.isTablet
    }
}

extension CNBreakpointInfo {
    /// Create breakpoint metadata from a `CGSize` in points.
    static func from(size: CGSize) -> CNBreakpointInfo {
        let width = size.width
        let height = size.height
        let isPortrait = height >= width
        
        let breakpoint: CNBreakpoint
        
        if isPortrait {
            switch width {
            case 320...428:
                breakpoint = .mobilePortrait
            case 768...834:
                breakpoint = .tabletPortrait
            default:
                breakpoint = .regular
            }
        } else {
            switch width {
            case 568...926:
                breakpoint = .mobileLandscape
            case 1024...1366:
                breakpoint = .tabletLandscape
            default:
                breakpoint = .regular
            }
        }
        
        return CNBreakpointInfo(
            breakpoint: breakpoint,
            size: size,
            isPortrait: isPortrait
        )
    }
}


