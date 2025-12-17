//
//  TagNetworkGraphView.swift
//  CalendarNotes
//
//  Displays related tag connections in a grouped list.
//

import SwiftUI

struct TagNetworkGraphView: View {
    let edges: [TagManagerViewModel.TagNetworkEdge]

    private var groupedEdges: [(source: String, items: [TagManagerViewModel.TagNetworkEdge])] {
        Dictionary(grouping: edges) { $0.sourceName }
            .map { (source: $0.key, items: $0.value) }
            .sorted { $0.source < $1.source }
    }

    var body: some View {
        List {
            ForEach(groupedEdges, id: \.source) { group in
                Section(header: Text(group.source)) {
                    ForEach(group.items) { edge in
                        HStack {
                            Text(edge.targetName)
                            Spacer()
                            Text(String(format: "%.2f", edge.strength))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Tag Network")
    }
}
