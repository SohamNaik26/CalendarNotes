//
//  SyncStatusBanner.swift
//  CalendarNotes
//
//  Created by Cursor AI on 08/11/25.
//

import SwiftUI

struct SyncStatusBanner: View {
    @EnvironmentObject private var syncManager: SyncManager
    
    var body: some View {
        VStack(spacing: 8) {
            if syncManager.isOffline {
                banner(icon: "wifi.slash", title: "Offline Mode") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Changes will sync when you're back online.")
                        if syncManager.pendingChanges > 0 {
                            Text("\(syncManager.pendingChanges) pending changes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            switch syncManager.state {
            case .syncing(let progress):
                banner(icon: "arrow.triangle.2.circlepath", title: "Syncing…") {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                }
            case .failed(let error):
                banner(icon: "exclamationmark.triangle.fill", title: "Sync Failed") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(error)
                        HStack {
                            Button("Retry") {
                                syncManager.triggerManualSync()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            if syncManager.pendingChanges > 0 {
                                Text("\(syncManager.pendingChanges) pending changes")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            case .succeeded:
                banner(icon: "checkmark.circle.fill", title: "All changes synced") {
                    if let last = syncManager.statistics.lastSuccessfulSync {
                        Text("Last synced \(last.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            default:
                EmptyView()
            }
        }
        .animation(.default, value: syncManager.state)
    }
    
    private func banner<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.white)
                .padding(8)
                .background(Color.cnAccent)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .fontWeight(.semibold)
                    Spacer()
                    Button {
                        syncManager.triggerManualSync()
                    } label: {
                        Label("Sync Now", systemImage: "arrow.clockwise")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                }
                content()
            }
        }
        .padding(12)
        .background(Color.cnSecondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 2)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}


