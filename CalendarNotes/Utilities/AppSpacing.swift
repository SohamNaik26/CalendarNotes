//
//  AppSpacing.swift
//  CalendarNotes
//
//  Created for adaptive spacing system
//

import SwiftUI

struct AppSpacing {
    static var tiny: CGFloat {
        ScreenSize.isSmallDevice ? 4 : 6
    }
    
    static var small: CGFloat {
        ScreenSize.isSmallDevice ? 8 : 12
    }
    
    static var medium: CGFloat {
        ScreenSize.isSmallDevice ? 12 : 16
    }
    
    static var large: CGFloat {
        ScreenSize.isSmallDevice ? 16 : 24
    }
    
    static var extraLarge: CGFloat {
        ScreenSize.isSmallDevice ? 24 : 32
    }
    
    static var horizontalPadding: CGFloat {
        if ScreenSize.isPad {
            return 32
        }
        if ScreenSize.isSmallDevice {
            return 16
        }
        return 20
    }
    
    static var verticalPadding: CGFloat {
        if ScreenSize.isPad {
            return 24
        }
        if ScreenSize.isSmallDevice {
            return 12
        }
        return 16
    }
}

