//
//  TagTimelineView.swift
//  CalendarNotes
//
//  Presents tag usage growth over time.
//

import SwiftUI

struct TagTimelineView: View {
    let points: [TagAnalyticsSnapshot.TrendPoint]

    private var formattedPoints: [(date: String, count: Int)] {
        points.map { point in
            (point.date.formatted(date: .abbreviated, time: .omitted), point.count)
        }
    }

    var body: some View {
        List {
            if points.isEmpty {
                Text("No timeline data available yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                ForEach(Array(formattedPoints.enumerated()), id: \.offset) { _, entry in
                    HStack {
                        Text(entry.date)
                        Spacer()
                        Text("\(entry.count)")
                    }
                }
            }
        }
        .navigationTitle("Usage Timeline")
    }
}
