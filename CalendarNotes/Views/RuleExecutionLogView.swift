//
//  RuleExecutionLogView.swift
//  CalendarNotes
//

import SwiftUI

struct RuleExecutionLogView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = AutomationRuleService.shared
    @State private var selectedRuleId: UUID?
    
    private var filteredLogs: [RuleExecutionLog] {
        if let selectedRuleId {
            return service.executionLogs.filter { $0.ruleId == selectedRuleId }
        } else {
            return service.executionLogs
        }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if filteredLogs.isEmpty {
                    emptyState
                } else {
                    List {
                        if !service.rules.isEmpty {
                            Section {
                                Picker("Rule", selection: $selectedRuleId) {
                                    Text("All Rules").tag(UUID?.none)
                                    ForEach(service.rules) { rule in
                                        Text(rule.name).tag(UUID?.some(rule.id))
                                    }
                                }
                                .platformPickerStyle()
                            }
                        }
                        
                        Section {
                            ForEach(filteredLogs) { log in
                                RuleLogRow(log: log)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Execution Logs")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button("Clear") {
                        service.clearLogs()
                    }
                    .disabled(service.executionLogs.isEmpty)
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 48))
                .foregroundColor(.cnSecondaryText)
            Text("No execution logs yet")
                .font(.headline)
            Text("Run automation rules to see their execution history here")
                .font(.subheadline)
                .foregroundColor(.cnSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct RuleLogRow: View {
    let log: RuleExecutionLog
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: log.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(log.success ? .green : .red)
                VStack(alignment: .leading, spacing: 4) {
                    Text(log.ruleName)
                        .font(.headline)
                    Text(log.bookmarkTitle)
                        .font(.subheadline)
                        .foregroundColor(.cnSecondaryText)
                        .lineLimit(2)
                }
                Spacer()
                Text(log.executedAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.cnSecondaryText)
            }
            
            if !log.actionsPerformed.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Actions")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.cnSecondaryText)
                    Text(log.actionsPerformed.joined(separator: ", "))
                        .font(.caption)
                }
            }
            
            if let error = log.errorMessage, !error.isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 6)
    }
}

private extension View {
    @ViewBuilder
    func platformPickerStyle() -> some View {
#if os(macOS)
        self.pickerStyle(.menu)
#else
        if #available(iOS 17.0, watchOS 10.0, *) {
            self.pickerStyle(.navigationLink)
        } else {
            self.pickerStyle(.automatic)
        }
#endif
    }
}



