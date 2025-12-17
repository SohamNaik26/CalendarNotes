//
//  HighlightStatisticsView.swift
//  CalendarNotes
//
//  View displaying highlight statistics
//

import SwiftUI

struct HighlightStatisticsView: View {
    @ObservedObject var viewModel: HighlightAnnotationViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Total Highlights
                Section(header: Text("Overview")) {
                    StatRow(
                        title: "Total Highlights",
                        value: "\(viewModel.statistics.totalHighlights)",
                        icon: "highlighter"
                    )
                    
                    StatRow(
                        title: "Highlights with Notes",
                        value: "\(viewModel.statistics.highlightsWithNotes)",
                        icon: "note.text"
                    )
                }
                
                // Highlights by Color
                if !viewModel.statistics.highlightsByColor.isEmpty {
                    Section(header: Text("By Color")) {
                        ForEach(HighlightColor.allCases) { color in
                            if let count = viewModel.statistics.highlightsByColor[color.rawValue], count > 0 {
                                HStack {
                                    Circle()
                                        .fill(color.displayColor)
                                        .frame(width: 20, height: 20)
                                    
                                    Text(color.name)
                                    
                                    Spacer()
                                    
                                    Text("\(count)")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                
                // Most Highlighted Section
                if let mostHighlighted = viewModel.statistics.mostHighlightedText {
                    Section(header: Text("Most Highlighted")) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(mostHighlighted)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Text("Highlighted \(viewModel.statistics.mostHighlightedCount) time\(viewModel.statistics.mostHighlightedCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Statistics")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Stat Row

struct StatRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            
            Text(title)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
        }
    }
}

