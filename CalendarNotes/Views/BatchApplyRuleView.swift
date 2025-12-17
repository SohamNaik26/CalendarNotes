//
//  BatchApplyRuleView.swift
//  CalendarNotes
//

import SwiftUI
import CoreData

struct BatchApplyRuleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    let rule: AutomationRule
    
    @StateObject private var service = AutomationRuleService.shared
    @State private var isApplying = false
    @State private var resultSummary: BatchApplySummary?
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                header
                
                if let summary = resultSummary {
                    resultSection(summary: summary)
                } else {
                    infoSection
                }
                
                Spacer()
                
                Button(action: applyRule) {
                    if isApplying {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Apply Rule to Existing Bookmarks")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isApplying)
            }
            .padding()
            .navigationTitle("Apply Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert(isPresented: Binding(
                get: { errorMessage != nil },
                set: { isPresented in
                    if !isPresented { errorMessage = nil }
                }
            )) {
                Alert(title: Text("Failed to Apply Rule"),
                      message: Text(errorMessage ?? "Unknown error"),
                      dismissButton: .default(Text("OK")))
            }
        }
    }
    
    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This will run '\(rule.name)' against all existing bookmarks.")
                .font(.body)
            
            Text("Only bookmarks matching the rule's trigger will be updated. The actions configured in the rule will be executed for each matching bookmark.")
                .font(.subheadline)
                .foregroundColor(.cnSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func resultSection(summary: BatchApplySummary) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Completed on \(summary.processedCount) bookmark\(summary.processedCount == 1 ? "" : "s").")
                .font(.headline)
            
            if summary.successCount > 0 {
                Label("\(summary.successCount) successful", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
            
            if summary.failureCount > 0 {
                Label("\(summary.failureCount) failed", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
            
            if !summary.failedMessages.isEmpty {
                Divider()
                Text("Errors")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                ForEach(summary.failedMessages, id: \.self) { message in
                    Text("• \(message)")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rule.name)
                .font(.title2)
                .fontWeight(.semibold)
            Text("Trigger: \(triggerDescription(rule.trigger))")
                .font(.subheadline)
                .foregroundColor(.cnSecondaryText)
            Text("\(rule.actions.count) action\(rule.actions.count == 1 ? "" : "s") configured")
                .font(.caption)
                .foregroundColor(.cnSecondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func applyRule() {
        guard !isApplying else { return }
        isApplying = true
        errorMessage = nil
        resultSummary = nil
        
        Task {
            await performBatchApply()
        }
    }
    
    @MainActor
    private func performBatchApply() async {
        let fetchRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        
        do {
            let bookmarks = try context.fetch(fetchRequest)
            let existingLogIds = Set(service.executionLogs.map(\.id))
            
            await service.batchApplyRule(rule, to: bookmarks, context: context)
            
            let newLogs = service.executionLogs.filter { !existingLogIds.contains($0.id) }
            resultSummary = BatchApplySummary(from: newLogs)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isApplying = false
    }
    
    private func triggerDescription(_ trigger: Trigger) -> String {
        switch trigger {
        case .addedToCollection(let name):
            return "Added to collection '\(name)'"
        case .taggedWith(let tag):
            return "Tagged with '\(tag)'"
        case .fromDomain(let domain):
            return "From domain containing '\(domain)'"
        case .savedAtTime:
            return "Saved at specific time"
        case .notOpenedInDays(let days):
            return "Not opened in \(days) day\(days == 1 ? "" : "s")"
        case .matchesAll:
            return "Matches all conditions"
        case .matchesAny:
            return "Matches any condition"
        }
    }
}

private struct BatchApplySummary {
    let processedCount: Int
    let successCount: Int
    let failureCount: Int
    let failedMessages: [String]
    
    init(processedCount: Int, successCount: Int, failureCount: Int, failedMessages: [String]) {
        self.processedCount = processedCount
        self.successCount = successCount
        self.failureCount = failureCount
        self.failedMessages = failedMessages
    }
    
    init(from logs: [RuleExecutionLog]) {
        processedCount = logs.count
        successCount = logs.filter { $0.success }.count
        failureCount = logs.filter { !$0.success }.count
        failedMessages = logs.compactMap { $0.errorMessage }.uniqued()
    }
}

private extension Array where Element == String {
    func uniqued() -> [String] {
        var seen: Set<String> = []
        return filter { seen.insert($0).inserted }
    }
}


