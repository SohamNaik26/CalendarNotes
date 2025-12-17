//
//  OptimizedEventRowView.swift
//  CalendarNotes
//
//  Optimized EventRowView with Equatable conformance
//

import SwiftUI
import CoreData

// MARK: - Optimized Event Row View

struct OptimizedEventRowView: View, Equatable {
    let event: CalendarEvent
    let formattedTime: String
    let formattedDuration: String?
    let categoryColor: Color
    let cardBackground: Color
    
    init(event: CalendarEvent, colorScheme: ColorScheme) {
        self.event = event
        
        // Pre-compute formatted values
        if let start = event.startDate, let end = event.endDate {
            let calendar = Calendar.current
            if calendar.component(.hour, from: start) == 0 &&
               calendar.component(.minute, from: start) == 0 &&
               calendar.component(.hour, from: end) == 0 &&
               calendar.component(.minute, from: end) == 0 {
                self.formattedTime = "All Day"
            } else {
                let startTime = start.timeOnly(style: .short)
                let endTime = end.timeOnly(style: .short)
                self.formattedTime = "\(startTime) - \(endTime)"
            }
        } else {
            self.formattedTime = "Time not set"
        }
        
        self.formattedDuration = event.durationMinutes > 0 ? event.durationDescription : nil
        self.categoryColor = EventCategory(rawValue: event.category ?? "Other")?.color ?? .gray
        
        #if canImport(UIKit)
        if colorScheme == .dark {
            self.cardBackground = Color(white: 0.18)
        } else {
            self.cardBackground = Color(UIColor.secondarySystemBackground)
        }
        #elseif canImport(AppKit)
        if colorScheme == .dark {
            self.cardBackground = Color(white: 0.18)
        } else {
            self.cardBackground = Color(NSColor.windowBackgroundColor)
        }
        #else
        self.cardBackground = Color.gray.opacity(0.1)
        #endif
    }
    
    static func == (lhs: OptimizedEventRowView, rhs: OptimizedEventRowView) -> Bool {
        lhs.event.objectID == rhs.event.objectID &&
        lhs.event.title == rhs.event.title &&
        lhs.event.startDate == rhs.event.startDate &&
        lhs.event.endDate == rhs.event.endDate &&
        lhs.event.category == rhs.event.category &&
        lhs.event.location == rhs.event.location &&
        lhs.event.notes == rhs.event.notes
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(categoryColor)
                    .frame(width: 4)
                    .padding(.top, 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Image(systemName: event.eventKind.icon)
                            .foregroundColor(categoryColor)
                        Text(event.title ?? "Untitled Event")
                            .font(.headline)
                            .dynamicTypeSize(.medium ... .xxxLarge)
                            .lineLimit(nil)
                        if let sentiment = event.eventSentiment {
                            Image(systemName: sentimentIcon(sentiment))
                                .foregroundColor(sentimentColor(sentiment))
                                .font(.caption)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .accessibilityHidden(true)
                    }
                    
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formattedTime)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        if let duration = formattedDuration {
                            Text("· \(duration)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let summary = event.detectedSummary, !summary.isEmpty {
                        Text(summary)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    } else if let notes = event.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    if let location = event.location, !location.isEmpty {
                        Label(location, systemImage: "location.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    metadataFooter
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(categoryColor.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.08), radius: 3, x: 0, y: 1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            AccessibilityHelpers.calendarEventLabel(
                title: event.title ?? "Untitled event",
                startTime: (event.startDate ?? Date()).timeOnly(style: .short),
                endTime: event.endDate?.timeOnly(style: .short),
                location: event.location
            )
        )
    }
    
    private var metadataFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(event.category ?? "Other")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(categoryColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(categoryColor.opacity(0.15))
                    .cornerRadius(6)
                
                let attendees = event.attendees
                if !attendees.isEmpty {
                    Label("\(attendees.count)", systemImage: "person.2")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if !event.preparationChecklist.isEmpty {
                    Label("Prep \(event.preparationChecklist.count)", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.cnAccent)
                }
            }
            
            let attendees = event.attendees
            if !attendees.isEmpty {
                Text(attendees.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
    }
    
    private func sentimentIcon(_ sentiment: CalendarEvent.EventSentiment) -> String {
        switch sentiment {
        case .positive: return "face.smiling"
        case .neutral: return "face.dashed"
        case .negative: return "face.frown"
        }
    }
    
    private func sentimentColor(_ sentiment: CalendarEvent.EventSentiment) -> Color {
        switch sentiment {
        case .positive: return .green
        case .neutral: return .secondary
        case .negative: return .red
        }
    }
}

