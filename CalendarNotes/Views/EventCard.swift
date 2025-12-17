//
//  EventCard.swift
//  CalendarNotes
//
//  Created for responsive event card layouts
//

import SwiftUI

struct EventCard: View {
    let event: CalendarEvent
    
    var body: some View {
        VStack(alignment: .leading, spacing: cardSpacing) {
            Text(event.title ?? "Untitled Event")
                .font(cardTitleFont)
                .lineLimit(1)
            
            if let description = event.notes, !description.isEmpty {
                Text(description)
                    .font(cardBodyFont)
                    .foregroundColor(.secondary)
                    .lineLimit(lineLimit)
            }
            
            if let location = event.location, !location.isEmpty {
                HStack(spacing: AppSpacing.tiny) {
                    Image(systemName: "location.fill")
                        .font(AppFonts.caption2)
                    Text(location)
                        .font(cardBodyFont)
                }
                .foregroundColor(.secondary)
            }
            
            if let startDate = event.startDate {
                HStack(spacing: AppSpacing.tiny) {
                    Image(systemName: "clock.fill")
                        .font(AppFonts.caption2)
                    Text(startDate, style: .time)
                        .font(cardBodyFont)
                }
                .foregroundColor(.secondary)
            }
        }
        .padding(cardPadding)
        .background(categoryColor.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(categoryColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    private var cardSpacing: CGFloat {
        ScreenSize.isSmallDevice ? 4 : 8
    }
    
    private var cardTitleFont: Font {
        ScreenSize.isSmallDevice ? .system(size: 14, weight: .semibold) : AppFonts.headline
    }
    
    private var cardBodyFont: Font {
        ScreenSize.isSmallDevice ? .system(size: 12) : AppFonts.subheadline
    }
    
    private var lineLimit: Int {
        ScreenSize.isSmallDevice ? 2 : 3
    }
    
    private var cardPadding: CGFloat {
        ScreenSize.isSmallDevice ? 12 : 16
    }
    
    private var categoryColor: Color {
        EventCategory(rawValue: event.category ?? "Other")?.color ?? .gray
    }
}

