//
//  ManualMergeView.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import SwiftUI

struct ManualMergeView: View {
    let conflict: SyncConflict
    var onSave: (_ mergedFields: [String: String]) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var selection: [String: Bool] = [:] // true -> choose local, false -> choose server
    
    private var allKeys: [String] {
        Array(Set(conflict.local.fields.keys).union(conflict.server.fields.keys)).sorted()
    }
    
    private var previewMerged: [String: String] {
        var merged: [String: String] = [:]
        for key in allKeys {
            let chooseLocal = selection[key] ?? false
            let localVal = conflict.local.fields[key]
            let serverVal = conflict.server.fields[key]
            merged[key] = chooseLocal ? (localVal ?? "") : (serverVal ?? "")
        }
        return merged
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Text("\(conflict.entityType.rawValue.capitalized) • Manual Merge")
                        .font(.headline)
                    Spacer()
                    Text("ID: \(conflict.entityId)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                fieldSelectionList
                
                previewSection
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(previewMerged)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            initializeSelection()
        }
    }
    
    private func initializeSelection() {
        // Default choose the more recent side per field if values differ, else local
        var initial: [String: Bool] = [:]
        for key in allKeys {
            let l = conflict.local.fields[key]
            let s = conflict.server.fields[key]
            if l == s {
                initial[key] = true
            } else {
                initial[key] = conflict.local.timestamp >= conflict.server.timestamp
            }
        }
        selection = initial
    }
    
    private var fieldSelectionList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(allKeys, id: \.self) { key in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(key)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        HStack(spacing: 8) {
                            toggleButton(title: "Local", selected: selection[key] ?? false, color: .red.opacity(0.2)) {
                                selection[key] = true
                            }
                            Text(conflict.local.fields[key] ?? "—")
                                .font(.callout)
                                .lineLimit(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            toggleButton(title: "Server", selected: !(selection[key] ?? false), color: .green.opacity(0.2)) {
                                selection[key] = false
                            }
                            Text(conflict.server.fields[key] ?? "—")
                                .font(.callout)
                                .lineLimit(3)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(8)
                    .background(Color.cnSecondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
    
    private func toggleButton(title: String, selected: Bool, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color.opacity(selected ? 1.0 : 0.3))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Preview")
                .font(.subheadline).bold()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(allKeys, id: \.self) { key in
                        HStack {
                            Text(key)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 120, alignment: .leading)
                            Text(previewMerged[key] ?? "—")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 2)
                        Divider()
                    }
                }
            }
            .frame(maxHeight: 180)
        }
        .padding(8)
        .background(Color.cnSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}


