//
//  BookmarkWidgetBundle.swift
//  CalendarNotes
//

#if canImport(WidgetKit) && os(iOS)
import WidgetKit
import SwiftUI

struct BookmarkWidgetBundle: WidgetBundle {
    var body: some Widget {
        BookmarkWidget()
        if #available(iOS 16.0, *) {
            BookmarkLockScreenWidget()
        }
    }
}

#endif


