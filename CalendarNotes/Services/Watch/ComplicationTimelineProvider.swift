//
//  ComplicationTimelineProvider.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation
#if canImport(ClockKit)
import ClockKit
#endif

#if canImport(ClockKit) && os(watchOS)
@MainActor
final class ComplicationTimelineProvider {
    private let snapshotProvider = WatchBookmarkSnapshotProvider()

    func template(for family: CLKComplicationFamily) -> CLKComplicationTemplate {
        let snapshot = snapshotProvider.buildSnapshot(limit: 3)
        switch family {
        case .circularSmall:
            let textTemplate = CLKComplicationTemplateCircularSmallSimpleText()
            textTemplate.textProvider = CLKSimpleTextProvider(text: "\(snapshot.unreadCount)")
            textTemplate.tintColor = .systemBlue
            return textTemplate

        case .modularSmall:
            let template = CLKComplicationTemplateModularSmallStackImage()
            template.line1ImageProvider = CLKImageProvider(onePieceImage: UIImage(systemName: "bookmark.fill") ?? UIImage())
            template.line2TextProvider = CLKSimpleTextProvider(text: "\(snapshot.unreadCount)")
            return template

        case .modularLarge:
            let template = CLKComplicationTemplateModularLargeStandardBody()
            template.headerTextProvider = CLKSimpleTextProvider(text: "Bookmarks")
            template.body1TextProvider = CLKSimpleTextProvider(text: "Unread \(snapshot.unreadCount)")
            template.body2TextProvider = CLKSimpleTextProvider(text: "Favorites \(snapshot.favoriteCount)")
            return template

        default:
            let textTemplate = CLKComplicationTemplateModularSmallSimpleText()
            textTemplate.textProvider = CLKSimpleTextProvider(text: "\(snapshot.unreadCount)")
            return textTemplate
        }
    }
}
#endif

