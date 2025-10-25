//
//  CloudKitSyncStatusView.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 22/10/25.
//

import SwiftUI
#if os(iOS)
import UIKit
#else
import AppKit
#endif

// MARK: - CloudKit Sync Status View

struct CloudKitSyncStatusView: View {
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @State private var showingSyncDetails = false
    
    private var controlBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Status Icon
            statusIcon
            
            // Status Text
            VStack(alignment: .leading, spacing: 2) {
                Text("iCloud Sync")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Text(cloudKitManager.statusMessage)
                    .font(.caption2)
                    .foregroundColor(statusColor)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Sync Button
            if cloudKitManager.canSync() && !cloudKitManager.isSyncing {
                Button(action: {
                    Task {
                        await cloudKitManager.triggerManualSync()
                    }
                }) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }
            
            // Details Button
            Button(action: {
                showingSyncDetails = true
            }) {
                Image(systemName: "info.circle")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(backgroundColor)
        .cornerRadius(8)
        .sheet(isPresented: $showingSyncDetails) {
            CloudKitSyncDetailsView()
        }
    }
    
    // MARK: - Status Icon
    
    @ViewBuilder
    private var statusIcon: some View {
        switch cloudKitManager.syncStatus {
        case .notConfigured:
            Image(systemName: "icloud.slash")
                .foregroundColor(.secondary)
        case .notSignedIn:
            Image(systemName: "person.crop.circle.badge.exclamationmark")
                .foregroundColor(.orange)
        case .networkUnavailable:
            Image(systemName: "wifi.slash")
                .foregroundColor(.red)
        case .syncing:
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(.blue)
                .rotationEffect(.degrees(cloudKitManager.isSyncing ? 360 : 0))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: cloudKitManager.isSyncing)
        case .synced:
            Image(systemName: "checkmark.icloud")
                .foregroundColor(.green)
        case .error:
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
        }
    }
    
    // MARK: - Status Color
    
    private var statusColor: Color {
        switch cloudKitManager.syncStatus {
        case .notConfigured, .notSignedIn:
            return .secondary
        case .networkUnavailable:
            return .red
        case .syncing:
            return .blue
        case .synced:
            return .green
        case .error:
            return .red
        }
    }
    
    // MARK: - Background Color
    
    private var backgroundColor: Color {
        switch cloudKitManager.syncStatus {
        case .syncing:
            return Color.blue.opacity(0.1)
        case .synced:
            return Color.green.opacity(0.1)
        case .error:
            return Color.red.opacity(0.1)
        default:
            return controlBackgroundColor
        }
    }
}

// MARK: - CloudKit Sync Details View

struct CloudKitSyncDetailsView: View {
    @StateObject private var cloudKitManager = CloudKitManager.shared
    @Environment(\.dismiss) var dismiss
    
    private var controlBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "icloud")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    Text("iCloud Sync Status")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                .padding(.top)
                
                // Status Card
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Current Status")
                            .font(.headline)
                        Spacer()
                        statusBadge
                    }
                    
                    Text(cloudKitManager.statusMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(controlBackgroundColor)
                .cornerRadius(12)
                
                // Sync Statistics
                if cloudKitManager.syncStats.totalChanges > 0 {
                    syncStatisticsCard
                }
                
                // Network Status
                networkStatusCard
                
                // Actions
                VStack(spacing: 12) {
                    if cloudKitManager.canSync() {
                        Button(action: {
                            Task {
                                await cloudKitManager.triggerManualSync()
                            }
                        }) {
                            HStack {
                                if cloudKitManager.isSyncing {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                }
                                Text(cloudKitManager.isSyncing ? "Syncing..." : "Sync Now")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(cloudKitManager.isSyncing)
                    }
                    
                    if cloudKitManager.syncStatus.isError {
                        Button("Reset Sync") {
                            cloudKitManager.resetSyncStatistics()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("iCloud Sync")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
    }
    
    // MARK: - Status Badge
    
    @ViewBuilder
    private var statusBadge: some View {
        switch cloudKitManager.syncStatus {
        case .synced:
            Label("Synced", systemImage: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .syncing:
            Label("Syncing", systemImage: "arrow.triangle.2.circlepath")
                .foregroundColor(.blue)
        case .error:
            Label("Error", systemImage: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        default:
            Label("Not Available", systemImage: "xmark.circle.fill")
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Sync Statistics Card
    
    @ViewBuilder
    private var syncStatisticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sync Statistics")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack(alignment: .leading) {
                    Text("\(cloudKitManager.syncStats.recordsUploaded)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Uploaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading) {
                    Text("\(cloudKitManager.syncStats.recordsDownloaded)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Downloaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading) {
                    Text("\(cloudKitManager.syncStats.recordsDeleted)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Deleted")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading) {
                    Text("\(cloudKitManager.syncStats.conflictsResolved)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Conflicts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let lastSync = cloudKitManager.syncStats.lastSyncDate {
                Text("Last sync: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(controlBackgroundColor)
        .cornerRadius(12)
    }
    
    // MARK: - Network Status Card
    
    @ViewBuilder
    private var networkStatusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Network Status")
                .font(.headline)
            
            HStack {
                Image(systemName: cloudKitManager.isNetworkAvailable ? "wifi" : "wifi.slash")
                    .foregroundColor(cloudKitManager.isNetworkAvailable ? .green : .red)
                
                Text(cloudKitManager.isNetworkAvailable ? "Connected" : "Disconnected")
                    .font(.subheadline)
            }
            
            HStack {
                Image(systemName: cloudKitManager.isWiFiAvailable() ? "wifi" : "antenna.radiowaves.left.and.right")
                    .foregroundColor(.blue)
                
                Text(cloudKitManager.isWiFiAvailable() ? "WiFi" : "Cellular")
                    .font(.subheadline)
            }
            
            if UserDefaults.standard.bool(forKey: "iCloudWiFiOnlySync") {
                HStack {
                    Image(systemName: "checkmark.circle")
                        .foregroundColor(.green)
                    Text("WiFi-only sync enabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(controlBackgroundColor)
        .cornerRadius(12)
    }
}

// MARK: - Compact Sync Status View

struct CompactCloudKitSyncStatusView: View {
    @StateObject private var cloudKitManager = CloudKitManager.shared
    
    private var controlBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    var body: some View {
        HStack(spacing: 4) {
            statusIcon
            Text(cloudKitManager.syncStatus.displayName)
                .font(.caption)
                .foregroundColor(statusColor)
        }
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch cloudKitManager.syncStatus {
        case .synced:
            Image(systemName: "checkmark.icloud")
                .foregroundColor(.green)
        case .syncing:
            Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundColor(.blue)
        case .error:
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.red)
        default:
            Image(systemName: "icloud.slash")
                .foregroundColor(.secondary)
        }
    }
    
    private var statusColor: Color {
        switch cloudKitManager.syncStatus {
        case .synced:
            return .green
        case .syncing:
            return .blue
        case .error:
            return .red
        default:
            return .secondary
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        CloudKitSyncStatusView()
        CompactCloudKitSyncStatusView()
    }
    .padding()
}
