//
//  DataManagementDashboard.swift
//  CalendarNotes
//
//  Comprehensive dashboard for all data management features
//

import SwiftUI
import Charts

struct DataManagementDashboard: View {
    @StateObject private var dataManager = DataManagementService()
    @StateObject private var cleanupService = ScheduledCleanupService()
    @State private var showingDataManagement = false
    @State private var showingCleanupDetails = false
    @State private var cleanupStats: CleanupStatistics?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // Storage Overview
                    storageOverviewSection
                    
                    // Quick Actions
                    quickActionsSection
                    
                    // Cleanup Status
                    cleanupStatusSection
                    
                    // Data Statistics
                    dataStatisticsSection
                    
                    // Recent Activity
                    recentActivitySection
                }
                .padding()
            }
            .navigationTitle("Data Management")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Manage") {
                        showingDataManagement = true
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("Manage") {
                        showingDataManagement = true
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingDataManagement) {
                DataManagementView()
            }
            .sheet(isPresented: $showingCleanupDetails) {
                CleanupDetailsView(cleanupService: cleanupService)
            }
        }
        .onAppear {
            Task {
                await loadDashboardData()
            }
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.cnPrimary)
                    .font(.title2)
                
                Text("Data Management Dashboard")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
            }
            
            Text("Monitor and manage your CalendarNotes data")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cnSecondaryBackground)
        )
    }
    
    // MARK: - Storage Overview Section
    
    private var storageOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Storage Overview")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if let storageInfo = dataManager.storageInfo, storageInfo.isLowStorage {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.caption)
                        
                        Text("Low Storage")
                            .font(.caption)
                            .foregroundColor(.red)
                            .fontWeight(.medium)
                    }
                }
            }
            
            if let storageInfo = dataManager.storageInfo {
                VStack(spacing: 12) {
                    // Storage Usage Chart
                    if #available(iOS 16.0, *) {
                        storageUsageChart(storageInfo: storageInfo)
                    } else {
                        storageUsageLegacy(storageInfo: storageInfo)
                    }
                    
                    // Storage Details
                    VStack(spacing: 8) {
                        storageDetailRow(
                            title: "Database",
                            size: storageInfo.databaseSize,
                            icon: "externaldrive.fill",
                            color: .blue
                        )
                        
                        storageDetailRow(
                            title: "Cache",
                            size: storageInfo.cacheSize,
                            icon: "memorychip.fill",
                            color: .orange
                        )
                        
                        storageDetailRow(
                            title: "Documents",
                            size: storageInfo.documentsSize,
                            icon: "folder.fill",
                            color: .green
                        )
                        
                        storageDetailRow(
                            title: "Available",
                            size: storageInfo.availableSpace,
                            icon: "checkmark.circle.fill",
                            color: storageInfo.isLowStorage ? .red : .green
                        )
                    }
                }
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Calculating storage...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cnSecondaryBackground)
        )
    }
    
    @available(iOS 16.0, *)
    private func storageUsageChart(storageInfo: StorageInfo) -> some View {
        Chart {
            BarMark(
                x: .value("Size", storageInfo.databaseSize),
                y: .value("Type", "Database")
            )
            .foregroundStyle(.blue)
            
            BarMark(
                x: .value("Size", storageInfo.cacheSize),
                y: .value("Type", "Cache")
            )
            .foregroundStyle(.orange)
            
            BarMark(
                x: .value("Size", storageInfo.documentsSize),
                y: .value("Type", "Documents")
            )
            .foregroundStyle(.green)
        }
        .frame(height: 120)
        .chartXAxis {
            AxisMarks { value in
                AxisValueLabel {
                    if let size = value.as(Int64.self) {
                        Text(dataManager.formatStorageSize(size))
                            .font(.caption)
                    }
                }
            }
        }
    }
    
    private func storageUsageLegacy(storageInfo: StorageInfo) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("Database")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(dataManager.formatStorageSize(storageInfo.databaseSize))
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("Cache")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(dataManager.formatStorageSize(storageInfo.cacheSize))
                    .font(.caption)
                    .fontWeight(.medium)
            }
            
            HStack {
                Text("Documents")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(dataManager.formatStorageSize(storageInfo.documentsSize))
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }
    
    // MARK: - Quick Actions Section
    
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                quickActionButton(
                    title: "Export Data",
                    icon: "square.and.arrow.up",
                    color: .cnPrimary,
                    action: { showingDataManagement = true }
                )
                
                quickActionButton(
                    title: "Clean Cache",
                    icon: "trash.circle",
                    color: .orange,
                    action: clearCache
                )
                
                quickActionButton(
                    title: "Compress DB",
                    icon: "arrow.down.circle",
                    color: .purple,
                    action: compressDatabase
                )
                
                quickActionButton(
                    title: "Cleanup Now",
                    icon: "trash",
                    color: .red,
                    action: performCleanup
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cnSecondaryBackground)
        )
    }
    
    private func quickActionButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(color.opacity(0.1))
            )
        }
    }
    
    // MARK: - Cleanup Status Section
    
    private var cleanupStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Cleanup Status")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Details") {
                    showingCleanupDetails = true
                }
                .font(.caption)
                .foregroundColor(.cnPrimary)
            }
            
            if let stats = cleanupStats {
                VStack(spacing: 12) {
                    // Cleanup Status Indicator
                    HStack {
                        Circle()
                            .fill(cleanupService.getCleanupStatus().color)
                            .frame(width: 12, height: 12)
                        
                        Text(cleanupService.getCleanupStatus().description)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        if let lastCleanup = stats.lastCleanupDate {
                            Text("Last: \(lastCleanup.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Cleanup Statistics
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(stats.completedTodos)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.cnPrimary)
                            
                            Text("Completed Tasks")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(stats.archivedNotes)")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                            
                            Text("Archived Notes")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Int(stats.cleanupEfficiency * 100))%")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                            
                            Text("Efficiency")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Loading cleanup status...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cnSecondaryBackground)
        )
    }
    
    // MARK: - Data Statistics Section
    
    private var dataStatisticsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data Statistics")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let stats = cleanupStats {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    statisticCard(
                        title: "Events",
                        value: "\(stats.totalEvents)",
                        icon: "calendar",
                        color: .blue
                    )
                    
                    statisticCard(
                        title: "Notes",
                        value: "\(stats.totalNotes)",
                        icon: "note.text",
                        color: .green
                    )
                    
                    statisticCard(
                        title: "Tasks",
                        value: "\(stats.totalTodos)",
                        icon: "checklist",
                        color: .orange
                    )
                    
                    statisticCard(
                        title: "Completed",
                        value: "\(stats.completedTodos)",
                        icon: "checkmark.circle",
                        color: .cnPrimary
                    )
                }
            } else {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Loading statistics...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cnSecondaryBackground)
        )
    }
    
    private func statisticCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(color.opacity(0.1))
        )
    }
    
    // MARK: - Recent Activity Section
    
    private var recentActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Activity")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 8) {
                if let lastExport = dataManager.lastExportDate {
                    activityRow(
                        icon: "square.and.arrow.up",
                        title: "Data Exported",
                        subtitle: lastExport.formatted(date: .abbreviated, time: .shortened),
                        color: .cnPrimary
                    )
                }
                
                if let lastCleanup = dataManager.lastCleanupDate {
                    activityRow(
                        icon: "trash",
                        title: "Cleanup Performed",
                        subtitle: lastCleanup.formatted(date: .abbreviated, time: .shortened),
                        color: .orange
                    )
                }
                
                if cleanupService.isScheduled {
                    activityRow(
                        icon: "clock",
                        title: "Auto Cleanup Scheduled",
                        subtitle: "Running automatically",
                        color: .green
                    )
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cnSecondaryBackground)
        )
    }
    
    private func activityRow(icon: String, title: String, subtitle: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Helper Methods
    
    private func storageDetailRow(title: String, size: Int64, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
                .frame(width: 24)
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(dataManager.formatStorageSize(size))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
    
    private func loadDashboardData() async {
        await dataManager.calculateStorageInfo()
        cleanupStats = await cleanupService.getCleanupStatistics()
    }
    
    // MARK: - Actions
    
    private func clearCache() {
        Task {
            do {
                try await dataManager.clearCache()
                await loadDashboardData()
            } catch {
                print("Failed to clear cache: \(error)")
            }
        }
    }
    
    private func compressDatabase() {
        Task {
            do {
                try await dataManager.compressDatabase()
                await loadDashboardData()
            } catch {
                print("Failed to compress database: \(error)")
            }
        }
    }
    
    private func performCleanup() {
        Task {
            do {
                try await cleanupService.triggerImmediateCleanup()
                await loadDashboardData()
            } catch {
                print("Failed to perform cleanup: \(error)")
            }
        }
    }
}

// MARK: - Cleanup Details View

struct CleanupDetailsView: View {
    @ObservedObject var cleanupService: ScheduledCleanupService
    @Environment(\.dismiss) private var dismiss
    @State private var cleanupStats: CleanupStatistics?
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Cleanup Status
                    cleanupStatusCard
                    
                    // Cleanup Actions
                    cleanupActionsCard
                    
                    // Statistics
                    statisticsCard
                }
                .padding()
            }
            .navigationTitle("Cleanup Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #endif
            }
        }
        .onAppear {
            Task {
                cleanupStats = await cleanupService.getCleanupStatistics()
            }
        }
    }
    
    private var cleanupStatusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cleanup Status")
                .font(.headline)
                .fontWeight(.semibold)
            
            let status = cleanupService.getCleanupStatus()
            
            HStack {
                Circle()
                    .fill(status.color)
                    .frame(width: 16, height: 16)
                
                Text(status.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            
            if let stats = cleanupStats {
                VStack(spacing: 8) {
                    if let lastCleanup = stats.lastCleanupDate {
                        HStack {
                            Text("Last Cleanup:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(lastCleanup.formatted(date: .complete, time: .shortened))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                    
                    if let nextCleanup = stats.nextCleanupDate {
                        HStack {
                            Text("Next Cleanup:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text(nextCleanup.formatted(date: .complete, time: .shortened))
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cnSecondaryBackground)
        )
    }
    
    private var cleanupActionsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cleanup Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                Button("Run Daily Cleanup") {
                    Task {
                        try await cleanupService.triggerImmediateCleanup()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.orange)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Button("Run Weekly Cleanup") {
                    Task {
                        try await cleanupService.triggerWeeklyCleanup()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                
                Button("Run Monthly Cleanup") {
                    Task {
                        try await cleanupService.triggerMonthlyCleanup()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(10)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cnSecondaryBackground)
        )
    }
    
    private var statisticsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Cleanup Statistics")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let stats = cleanupStats {
                VStack(spacing: 12) {
                    HStack {
                        Text("Total Items:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(stats.totalEvents + stats.totalNotes + stats.totalTodos)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Cleanable Items:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(stats.completedTodos + stats.archivedNotes)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    HStack {
                        Text("Cleanup Efficiency:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("\(Int(stats.cleanupEfficiency * 100))%")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
            } else {
                ProgressView("Loading statistics...")
                    .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cnSecondaryBackground)
        )
    }
}

#Preview {
    DataManagementDashboard()
}
