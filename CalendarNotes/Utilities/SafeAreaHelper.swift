//
//  SafeAreaHelper.swift
//  CalendarNotes
//
//  Helper utilities for safe area insets and device detection
//

import SwiftUI
#if os(iOS)
import UIKit
#endif

struct SafeAreaHelper {
    /// Detects if the device is iPhone 17 Pro Max
    static var isIPhone17ProMax: Bool {
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            let bounds = windowScene.screen.bounds
            // iPhone 17 Pro Max dimensions: 430 x 932
            return bounds.height == 932 && bounds.width == 430
        }
        return false
        #else
        return false
        #endif
    }
    
    /// Gets the top safe area inset
    static var topSafeArea: CGFloat {
        #if os(iOS)
        if isIPhone17ProMax {
            return 59  // Dynamic Island height for iPhone 17 Pro Max
        }
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets.top
        }
        return 0
        #else
        return 0
        #endif
    }
    
    /// Gets the bottom safe area inset
    static var bottomSafeArea: CGFloat {
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets.bottom
        }
        return 0
        #else
        return 0
        #endif
    }
    
    /// Gets the leading safe area inset
    static var leadingSafeArea: CGFloat {
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets.left
        }
        return 0
        #else
        return 0
        #endif
    }
    
    /// Gets the trailing safe area inset
    static var trailingSafeArea: CGFloat {
        #if os(iOS)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.safeAreaInsets.right
        }
        return 0
        #else
        return 0
        #endif
    }
}

// MARK: - View Extension for Safe Area

extension View {
    /// Applies proper safe area handling for navigation views
    func safeNavigationView() -> some View {
        self
            .ignoresSafeArea(.keyboard, edges: .bottom)
    }
    
    /// Adds top padding to prevent content from hiding under navigation bar
    func safeTopPadding() -> some View {
        self
            .padding(.top, 1)
    }
}

