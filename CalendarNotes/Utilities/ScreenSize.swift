//
//  ScreenSize.swift
//  CalendarNotes
//
//  Created for responsive layout system
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

enum ScreenSize {
    static var width: CGFloat {
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.screen.bounds.width
        }
        return 1024 // Fallback
        #else
        return 1024 // Default for macOS
        #endif
    }
    
    static var height: CGFloat {
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            return windowScene.screen.bounds.height
        }
        return 768 // Fallback
        #else
        return 768 // Default for macOS
        #endif
    }
    
    static var isSmallDevice: Bool {
        width <= 375  // iPhone SE, iPhone 12/13 mini
    }
    
    static var isMediumDevice: Bool {
        width > 375 && width <= 390  // iPhone 14, iPhone 15
    }
    
    static var isLargeDevice: Bool {
        width > 390 && width <= 480  // iPhone 14/15 Pro Max, iPhone 16/17 Pro Max
    }
    
    static var isExtraLargeDevice: Bool {
        width > 480  // iPhone 17 Pro Max and future large devices
    }
    
    /// Detects if the device is iPhone 17 Pro Max
    static var isIPhone17ProMax: Bool {
        width == 430 && height == 932
    }
    
    static var dynamicIslandHeight: CGFloat {
        isIPhone17ProMax ? 37 : 0
    }
    
    static var statusBarHeight: CGFloat {
        if isIPhone17ProMax {
            return 59  // Including Dynamic Island
        }
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets.top
        }
        return 44
        #else
        return 44
        #endif
    }
    
    static var homeIndicatorHeight: CGFloat {
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets.bottom
        }
        return 34
        #else
        return 34
        #endif
    }
    
    static var isPad: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        return false
        #endif
    }
}

