//
//  AppFonts.swift
//  CalendarNotes
//
//  Created for adaptive font system
//

import SwiftUI

struct AppFonts {
    static var largeTitle: Font {
        if ScreenSize.isSmallDevice {
            return .system(size: 28, weight: .bold)
        }
        return .largeTitle
    }
    
    static var title: Font {
        if ScreenSize.isSmallDevice {
            return .system(size: 22, weight: .semibold)
        }
        return .title
    }
    
    static var title2: Font {
        if ScreenSize.isSmallDevice {
            return .system(size: 20, weight: .semibold)
        }
        return .title2
    }
    
    static var title3: Font {
        if ScreenSize.isSmallDevice {
            return .system(size: 18, weight: .semibold)
        }
        return .title3
    }
    
    static var headline: Font {
        if ScreenSize.isSmallDevice {
            return .system(size: 15, weight: .semibold)
        }
        return .headline
    }
    
    static var subheadline: Font {
        if ScreenSize.isSmallDevice {
            return .system(size: 13, weight: .medium)
        }
        return .subheadline
    }
    
    static var body: Font {
        if ScreenSize.isSmallDevice {
            return .system(size: 14)
        }
        return .body
    }
    
    static var callout: Font {
        if ScreenSize.isSmallDevice {
            return .system(size: 13)
        }
        return .callout
    }
    
    static var caption: Font {
        if ScreenSize.isSmallDevice {
            return .system(size: 11)
        }
        return .caption
    }
    
    static var caption2: Font {
        if ScreenSize.isSmallDevice {
            return .system(size: 10)
        }
        return .caption2
    }
}

