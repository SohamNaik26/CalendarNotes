//
//  ConflictResolutionView.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import SwiftUI

struct ConflictResolutionView: View {
    @EnvironmentObject private var conflictStore: ConflictStore
    @State private var selectedConflict: SyncConflict?
    @State private var showManualMerge: Bool = false
    
    var body: some View {
        VStack(spacing: 16) {
            header
            if conflictStore.conflicts.isEmpty {
                emptyState
            } else {
                conflictsList
            }
        }
        .padding()
        .sheet(isPresented: $showManualMerge) {
            if let conflict = selectedConflict {
                ManualMergeView(conflict: conflict) { mergedFields in
                    // For now, treat manual merge as resolution pathway
                    conflictStore.resolve(conflict, with: .manualMerge)
                    selectedConflict = nil
                }
            }
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Sync Conflicts")
                    .font(.title2).bold()
                Text(conflictStore.conflicts.isEmpty ? "No conflicts detected" : "\(conflictStore.conflicts.count) unresolved")
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)
            Text("No conflicts at the moment")
                .font(.headline)
            Text("You're all set. We'll notify you if conflicts appear.")
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
    
    private var conflictsList: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(conflictStore.conflicts) { conflict in
                    conflictRow(conflict)
                        .background(Color.cnSecondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 2)
                }
            }
        }
    }
    
    private func conflictRow(_ conflict: SyncConflict) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("\(conflict.entityType.rawValue.capitalized) • \(conflict.conflictTypeTitle)", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.headline)
                Spacer()
                Text("ID: \(conflict.entityId)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .top, spacing: 12) {
                sideColumn(title: "Local", side: conflict.local, align: .leading, color: .red)
                Divider()
                sideColumn(title: "Server", side: conflict.server, align: .trailing, color: .green)
            }
            
            fieldDiffGrid(conflict)
            
            actionButtons(conflict)
        }
        .padding(12)
    }
    
    private func sideColumn(title: String, side: ConflictSide, align: HorizontalAlignment, color: Color) -> some View {
        VStack(alignment: align, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline).bold()
                Spacer()
                Text(side.timestamp.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text(side.deviceName)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    private func fieldDiffGrid(_ conflict: SyncConflict) -> some View {
        let diffs = conflict.computeFieldDiffs()
        return VStack(alignment: .leading, spacing: 8) {
            ForEach(diffs) { diff in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(diff.fieldKey)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 120, alignment: .leading)
                    roundedValueView(diff.localValue ?? "—", color: color(for: diff, isLocal: true))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    roundedValueView(diff.serverValue ?? "—", color: color(for: diff, isLocal: false))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }
    
    private func color(for diff: ConflictFieldDiff, isLocal: Bool) -> Color {
        switch diff.changeType {
        case .same:
            return .gray.opacity(0.15)
        case .changed:
            return isLocal ? .red.opacity(0.2) : .green.opacity(0.2)
        case .added:
            return isLocal ? .red.opacity(0.2) : .green.opacity(0.2)
        case .removed:
            return isLocal ? .red.opacity(0.2) : .green.opacity(0.2)
        }
    }
    
    private func roundedValueView(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.callout)
            .padding(8)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
    
    private func actionButtons(_ conflict: SyncConflict) -> some View {
        HStack {
            Button("Keep Local") {
                conflictStore.resolve(conflict, with: .keepLocal)
            }
            .buttonStyle(.bordered)
            
            Button("Keep Server") {
                conflictStore.resolve(conflict, with: .keepServer)
            }
            .buttonStyle(.bordered)
            
            Button("Keep Both") {
                conflictStore.resolve(conflict, with: .keepBoth)
            }
            .buttonStyle(.bordered)
            
            Button("Manual Merge") {
                selectedConflict = conflict
                showManualMerge = true
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
            
            Button("Skip for Now") {
                conflictStore.resolve(conflict, with: .skipped)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
        }
    }
}

private extension SyncConflict {
    var conflictTypeTitle: String {
        switch conflictType {
        case .editedOnMultipleDevices: return "Edited on multiple devices"
        case .deletedVsEdited: return "Deleted on one device, edited on another"
        case .duplicateCreationSameId: return "Created with same ID"
        }
    }
}


