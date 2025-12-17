//
//  BrowserTab.swift
//  CalendarNotes
//
//  Represents a single browser tab within the in-app bookmark browser.
//

import Foundation

struct BrowserTab: Identifiable, Equatable {
    let id: UUID
    var url: URL?
    var title: String
    var isLoading: Bool
    var canGoBack: Bool
    var canGoForward: Bool
    var isPrivate: Bool
    var zoomScale: Double
    var lastScrollOffset: Double
    var userAgent: BrowserUserAgent
    var javaScriptEnabled: Bool
    var contentBlockingEnabled: Bool

    init(
        id: UUID = UUID(),
        url: URL? = nil,
        title: String = "New Tab",
        isLoading: Bool = false,
        canGoBack: Bool = false,
        canGoForward: Bool = false,
        isPrivate: Bool = false,
        zoomScale: Double = 1.0,
        lastScrollOffset: Double = 0,
        userAgent: BrowserUserAgent = .automatic,
        javaScriptEnabled: Bool = true,
        contentBlockingEnabled: Bool = true
    ) {
        self.id = id
        self.url = url
        self.title = title
        self.isLoading = isLoading
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.isPrivate = isPrivate
        self.zoomScale = zoomScale
        self.lastScrollOffset = lastScrollOffset
        self.userAgent = userAgent
        self.javaScriptEnabled = javaScriptEnabled
        self.contentBlockingEnabled = contentBlockingEnabled
    }
}

enum BrowserUserAgent: String, CaseIterable, Identifiable {
    case automatic
    case desktop
    case mobile

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .desktop: return "Desktop"
        case .mobile: return "Mobile"
        }
    }
}


