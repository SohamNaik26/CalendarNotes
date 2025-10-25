//
//  DataManagementView.swift
//  CalendarNotes
//
//  Comprehensive data management interface with export, import, cleanup, and storage management
//

import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit
#endif

struct DataManagementView: View {
    @StateObject private var dataManager = DataManagementService()
    @State private var showingExportPicker = false
    @State private var showingImportPicker = false
    @State private var showingAlert = false
    @State private var alertMessage = ""
    @State private var alertTitle = ""
    @State private var selectedExportURL: URL?
    @State private var showingStorageDetails = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Storage Overview Card
                    storageOverviewCard
                    
                    // Export/Import Section
                    exportImportSection
                    
                    // Cleanup Section
                    cleanupSection
                    
                    // Batch Operations Section
                    batchOperationsSection
                    
                    // Storage Management Section
                    storageManagementSection
                }
                .padding()
            }
            .navigationTitle("Data Management")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .sheet(isPresented: $showingExportPicker) {
                #if os(iOS)
                DocumentPickerView(
                    allowedContentTypes: [UTType.json],
                    onDocumentPicked: handleImport
                )
                #else
                // macOS alternative - use file picker
                Text("File picker not implemented for macOS")
                    .padding()
                #endif
            }
            .sheet(isPresented: $showingStorageDetails) {
                StorageDetailsView(dataManager: dataManager)
            }
            .alert(alertTitle, isPresented: $showingAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
        }
        .onAppear {
            Task {
                await dataManager.calculateStorageInfo()
            }
        }
    }
    
    // MARK: - Storage Overview Card
    
    private var storageOverviewCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "externaldrive.fill")
                    .foregroundColor(.cnPrimary)
                    .font(.title2)
                
                Text("Storage Overview")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Details") {
                    showingStorageDetails = true
                }
                .font(.caption)
                .foregroundColor(.cnPrimary)
            }
            
            if let storageInfo = dataManager.storageInfo {
                VStack(spacing: 12) {
                    // Total Storage
                    HStack {
                        Text("Total Used:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(dataManager.formatStorageSize(storageInfo.totalSize))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    // Available Space
                    HStack {
                        Text("Available:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text(dataManager.formatStorageSize(storageInfo.availableSpace))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(storageInfo.isLowStorage ? .red : .primary)
                    }
                    
                    // Storage Usage Bar
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Usage")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(Int(dataManager.getStorageUsagePercentage()))%")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        
                        ProgressView(value: dataManager.getStorageUsagePercentage() / 100.0)
                            .progressViewStyle(LinearProgressViewStyle(tint: storageInfo.isLowStorage ? .red : .cnPrimary))
                    }
                    
                    // Low Storage Warning
                    if storageInfo.isLowStorage {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.red)
                                .font(.caption)
                            
                            Text("Low storage space available")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        .padding(.top, 4)
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
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cnSecondaryBackground)
        )
    }
    
    // MARK: - Export/Import Section
    
    private var exportImportSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Data Export & Import")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Export Button
                Button(action: exportData) {
                    HStack {
                        if dataManager.isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        
                        Text("Export All Data")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.cnPrimary)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(dataManager.isExporting)
                
                // Import Button
                Button(action: { showingImportPicker = true }) {
                    HStack {
                        if dataManager.isImporting {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "square.and.arrow.down")
                        }
                        
                        Text("Import Data")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.cnSecondary)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(dataManager.isImporting)
                
                // Last Export Date
                if let lastExport = dataManager.lastExportDate {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text("Last export: \(lastExport.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
    
    // MARK: - Cleanup Section
    
    private var cleanupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Automatic Cleanup")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Auto Cleanup Button
                Button(action: performAutoCleanup) {
                    HStack {
                        if dataManager.isCleaning {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "trash")
                        }
                        
                        Text("Clean Up Old Data")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(dataManager.isCleaning)
                
                // Archive Old Notes Button
                Button(action: archiveOldNotes) {
                    HStack {
                        Image(systemName: "archivebox")
                        
                        Text("Archive Old Notes")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // Last Cleanup Date
                if let lastCleanup = dataManager.lastCleanupDate {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        
                        Text("Last cleanup: \(lastCleanup.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
    
    // MARK: - Batch Operations Section
    
    private var batchOperationsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Batch Operations")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Delete Completed Tasks
                Button(action: deleteCompletedTasks) {
                    HStack {
                        Image(systemName: "checkmark.circle")
                        
                        Text("Delete Completed Tasks")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // Delete Archived Notes
                Button(action: deleteArchivedNotes) {
                    HStack {
                        Image(systemName: "archivebox.fill")
                        
                        Text("Delete Archived Notes")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                
                // Delete Old Events
                Button(action: deleteOldEvents) {
                    HStack {
                        Image(systemName: "calendar.badge.minus")
                        
                        Text("Delete Old Events")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cnSecondaryBackground)
        )
    }
    
    // MARK: - Storage Management Section
    
    private var storageManagementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Storage Management")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Compress Database
                Button(action: compressDatabase) {
                    HStack {
                        if dataManager.isCompressing {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.down.circle")
                        }
                        
                        Text("Compress Database")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(dataManager.isCompressing)
                
                // Clear Cache
                Button(action: clearCache) {
                    HStack {
                        Image(systemName: "trash.circle")
                        
                        Text("Clear Cache")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.cnSecondaryBackground)
        )
    }
    
    // MARK: - Actions
    
    private func exportData() {
        Task {
            do {
                let url = try await dataManager.exportAllDataToJSON()
                await MainActor.run {
                    alertTitle = "Export Successful"
                    alertMessage = "Data exported to: \(url.lastPathComponent)"
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = "Export Failed"
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func handleImport(_ url: URL) {
        Task {
            do {
                try await dataManager.importDataFromJSON(url: url)
                await MainActor.run {
                    alertTitle = "Import Successful"
                    alertMessage = "Data imported successfully"
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = "Import Failed"
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func performAutoCleanup() {
        Task {
            do {
                try await dataManager.performAutomaticCleanup()
                await MainActor.run {
                    alertTitle = "Cleanup Complete"
                    alertMessage = "Old data has been cleaned up"
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = "Cleanup Failed"
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func archiveOldNotes() {
        Task {
            do {
                try await dataManager.archiveOldNotes(olderThanDays: 90)
                await MainActor.run {
                    alertTitle = "Archive Complete"
                    alertMessage = "Old notes have been archived"
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = "Archive Failed"
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func deleteCompletedTasks() {
        Task {
            do {
                try await dataManager.batchDeleteCompletedTasks()
                await MainActor.run {
                    alertTitle = "Delete Complete"
                    alertMessage = "Completed tasks have been deleted"
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = "Delete Failed"
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func deleteArchivedNotes() {
        Task {
            do {
                try await dataManager.batchDeleteArchivedNotes()
                await MainActor.run {
                    alertTitle = "Delete Complete"
                    alertMessage = "Archived notes have been deleted"
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = "Delete Failed"
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func deleteOldEvents() {
        Task {
            do {
                try await dataManager.batchDeleteOldEvents(olderThanDays: 365)
                await MainActor.run {
                    alertTitle = "Delete Complete"
                    alertMessage = "Old events have been deleted"
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = "Delete Failed"
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func compressDatabase() {
        Task {
            do {
                try await dataManager.compressDatabase()
                await MainActor.run {
                    alertTitle = "Compression Complete"
                    alertMessage = "Database has been compressed"
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = "Compression Failed"
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func clearCache() {
        Task {
            do {
                try await dataManager.clearCache()
                await MainActor.run {
                    alertTitle = "Cache Cleared"
                    alertMessage = "Cache has been cleared"
                    showingAlert = true
                }
            } catch {
                await MainActor.run {
                    alertTitle = "Cache Clear Failed"
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
}

// MARK: - Storage Details View

struct StorageDetailsView: View {
    @ObservedObject var dataManager: DataManagementService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(spacing: 20) {
                    if let storageInfo = dataManager.storageInfo {
                        // Database Size
                        storageDetailRow(
                            title: "Database",
                            size: storageInfo.databaseSize,
                            icon: "externaldrive.fill",
                            color: .blue
                        )
                        
                        // Cache Size
                        storageDetailRow(
                            title: "Cache",
                            size: storageInfo.cacheSize,
                            icon: "memorychip.fill",
                            color: .orange
                        )
                        
                        // Documents Size
                        storageDetailRow(
                            title: "Documents",
                            size: storageInfo.documentsSize,
                            icon: "folder.fill",
                            color: .green
                        )
                        
                        // Available Space
                        storageDetailRow(
                            title: "Available Space",
                            size: storageInfo.availableSpace,
                            icon: "checkmark.circle.fill",
                            color: storageInfo.isLowStorage ? .red : .green
                        )
                    } else {
                        ProgressView("Calculating storage details...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding()
            }
            .navigationTitle("Storage Details")
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
    }
    
    private func storageDetailRow(title: String, size: Int64, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title2)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(dataManager.formatStorageSize(size))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.cnSecondaryBackground)
        )
    }
}

// MARK: - Document Picker View

#if os(iOS)
struct DocumentPickerView: UIViewControllerRepresentable {
    let allowedContentTypes: [UTType]
    let onDocumentPicked: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedContentTypes)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            parent.onDocumentPicked(url)
        }
    }
}
#endif

#Preview {
    DataManagementView()
}
