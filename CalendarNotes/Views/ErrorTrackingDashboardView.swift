//
//  ErrorTrackingDashboardView.swift
//  CalendarNotes
//
//  Error tracking dashboard for debug mode
//

import SwiftUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif
#if canImport(Charts)
import Charts
#endif

struct ErrorTrackingDashboardView: View {
    @StateObject private var errorTracker = ErrorTracker.shared
    @State private var selectedTimeRange: TimeRange = .last24Hours
    @Environment(\.dismiss) var dismiss
    
    enum TimeRange: String, CaseIterable {
        case last24Hours = "Last 24 Hours"
        case last7Days = "Last 7 Days"
        case last30Days = "Last 30 Days"
        case all = "All Time"
    }
    
    var filteredErrors: [TrackedError] {
        let cutoffDate: Date
        switch selectedTimeRange {
        case .last24Hours:
            cutoffDate = Date().addingTimeInterval(-86400)
        case .last7Days:
            cutoffDate = Date().addingTimeInterval(-604800)
        case .last30Days:
            cutoffDate = Date().addingTimeInterval(-2592000)
        case .all:
            return errorTracker.errors
        }
        
        return errorTracker.errors.filter { $0.timestamp >= cutoffDate }
    }
    
    var errorSummary: (total: Int, bySeverity: [ErrorSeverity: Int], byContext: [String: Int]) {
        let bySeverity = Dictionary(grouping: filteredErrors) { $0.severity }
        let byContext = Dictionary(grouping: filteredErrors) { $0.context.category }
        
        return (
            total: filteredErrors.count,
            bySeverity: bySeverity.mapValues { $0.count },
            byContext: byContext.mapValues { $0.count }
        )
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Time Range Picker
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(TimeRange.allCases, id: \.self) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Summary Cards
                    summaryCards
                    
                    // Error Rate Chart
                    errorRateChart
                    
                    // Errors by Type
                    errorsByType
                    
                    // Errors by Context
                    errorsByContext
                    
                    // Recent Errors List
                    recentErrorsList
                }
                .padding()
            }
            .navigationTitle("Error Tracking")
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button("Export") {
                            exportErrors()
                        }
                        Button("Clear") {
                            errorTracker.clearErrors()
                        }
                        .foregroundColor(.red)
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    HStack {
                        Button("Done") {
                            dismiss()
                        }
                        Button("Export") {
                            exportErrors()
                        }
                        Button("Clear") {
                            errorTracker.clearErrors()
                        }
                        .foregroundColor(.red)
                    }
                }
                #endif
            }
        }
    }
    
    private var summaryCards: some View {
        HStack(spacing: 16) {
            SummaryCard(
                title: "Total Errors",
                value: "\(errorSummary.total)",
                color: .red
            )
            
            SummaryCard(
                title: "Critical",
                value: "\(errorSummary.bySeverity[.critical] ?? 0)",
                color: .purple
            )
            
            SummaryCard(
                title: "Errors",
                value: "\(errorSummary.bySeverity[.error] ?? 0)",
                color: .orange
            )
        }
        .padding(.horizontal)
    }
    
    private var errorRateChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Error Rate Over Time")
                .font(.headline)
                .padding(.horizontal)
            
            #if canImport(Charts)
            if #available(iOS 16.0, macOS 13.0, *) {
                Chart {
                    ForEach(hourlyErrorCounts, id: \.hour) { data in
                        BarMark(
                            x: .value("Hour", data.hour, unit: .hour),
                            y: .value("Count", data.count)
                        )
                        .foregroundStyle(.red)
                    }
                }
                .frame(height: 200)
                .padding()
            } else {
                // Fallback for older versions
                Text("Charts require iOS 16+ / macOS 13+")
                    .foregroundColor(.secondary)
                    .padding()
            }
            #else
            // Fallback when Charts is not available
            Text("Error rate chart not available on this platform")
                .foregroundColor(.secondary)
                .padding()
            #endif
        }
    }
    
    private var errorsByType: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Errors by Severity")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(ErrorSeverity.allCases, id: \.self) { severity in
                let count = errorSummary.bySeverity[severity] ?? 0
                if count > 0 {
                    HStack {
                        Text(severity.rawValue)
                        Spacer()
                        Text("\(count)")
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(backgroundColor)
                    .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var errorsByContext: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Errors by Context")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(errorSummary.byContext.keys.sorted(), id: \.self) { context in
                let count = errorSummary.byContext[context] ?? 0
                HStack {
                    Text(context)
                    Spacer()
                    Text("\(count)")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(backgroundColor)
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
    
    private var recentErrorsList: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Most Recent Errors")
                .font(.headline)
                .padding(.horizontal)
            
            ForEach(Array(filteredErrors.prefix(10)), id: \.id) { error in
                ErrorRowView(error: error)
            }
        }
        .padding(.horizontal)
    }
    
    private var hourlyErrorCounts: [(hour: Date, count: Int)] {
        let calendar = Calendar.current
        var counts: [Date: Int] = [:]
        
        for error in filteredErrors {
            let hour = calendar.date(bySettingHour: calendar.component(.hour, from: error.timestamp),
                                    minute: 0,
                                    second: 0,
                                    of: error.timestamp) ?? error.timestamp
            counts[hour, default: 0] += 1
        }
        
        return counts.map { (hour: $0.key, count: $0.value) }
            .sorted { $0.hour < $1.hour }
    }
    
    private var backgroundColor: Color {
        #if os(iOS)
        return Color(UIColor.systemGray6)
        #elseif os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color.gray.opacity(0.2)
        #endif
    }
    
    private func exportErrors() {
        let export = errorTracker.exportErrors()
        // In a real app, you'd share this via a share sheet
        print(export)
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let color: Color
    
    private var backgroundColor: Color {
        #if os(iOS)
        return Color(UIColor.systemGray6)
        #elseif os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color.gray.opacity(0.2)
        #endif
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
    }
}

struct ErrorRowView: View {
    let error: TrackedError
    
    private var backgroundColor: Color {
        #if os(iOS)
        return Color(UIColor.systemGray6)
        #elseif os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color.gray.opacity(0.2)
        #endif
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(error.error.localizedDescription)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                severityBadge(error.severity)
            }
            
            Text(error.context.description)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(error.timestamp, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(8)
    }
    
    @ViewBuilder
    private func severityBadge(_ severity: ErrorSeverity) -> some View {
        Text(severity.rawValue)
            .font(.caption2)
            .fontWeight(.semibold)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(severityColor(severity).opacity(0.2))
            .foregroundColor(severityColor(severity))
            .cornerRadius(4)
    }
    
    private func severityColor(_ severity: ErrorSeverity) -> Color {
        switch severity {
        case .debug: return .gray
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
}

