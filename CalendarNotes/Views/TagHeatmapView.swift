//
//  TagHeatmapView.swift
//  CalendarNotes
//
//  Visualizes tag usage intensity across day and hour buckets.
//

import SwiftUI

struct TagHeatmapView: View {
    let cells: [TagManagerViewModel.TagUsageHeatmapCell]

    private let days = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    private let hours = Array(0..<24)

    private var lookup: [String: Int] {
        Dictionary(uniqueKeysWithValues: cells.map { ("\($0.dayOfWeek)-\($0.hour)", $0.count) })
    }

    private var maxCount: Double {
        Double(cells.map { $0.count }.max() ?? 1)
    }

    var body: some View {
        ScrollView([.vertical, .horizontal]) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text("")
                        .frame(width: 36)
                    ForEach(hours, id: \.self) { hour in
                        Text(String(format: "%02d", hour))
                            .font(.caption2)
                            .frame(width: 24)
                            .foregroundColor(.secondary)
                    }
                }

                ForEach(Array(days.enumerated()), id: \.offset) { dayIndex, label in
                    HStack(spacing: 4) {
                        Text(label)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 36, alignment: .leading)
                        ForEach(hours, id: \.self) { hour in
                            let key = "\(dayIndex)-\(hour)"
                            let value = Double(lookup[key] ?? 0)
                            RoundedRectangle(cornerRadius: 4)
                                .fill(color(for: value))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Text(value > 0 ? String(Int(value)) : "")
                                        .font(.system(size: 8))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Usage Heatmap")
    }

    private func color(for value: Double) -> Color {
        guard maxCount > 0 else { return Color.gray.opacity(0.1) }
        let normalized = value / maxCount
        return Color(red: 0.2, green: 0.4, blue: 0.9, opacity: normalized == 0 ? 0.1 : 0.2 + normalized * 0.8)
    }
}
