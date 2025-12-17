//
//  TestRuleView.swift
//  CalendarNotes
//

import SwiftUI
import CoreData

struct TestRuleView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    let rule: AutomationRule
    @StateObject private var service = AutomationRuleService.shared
    @State private var testResults: [RuleExecutionLog] = []
    @State private var isTesting = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isTesting {
                    ProgressView("Testing rule...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if testResults.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "play.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.cnSecondaryText)
                        Text("No test results")
                            .font(.headline)
                        Text("Tap 'Run Test' to test this rule on all bookmarks")
                            .font(.subheadline)
                            .foregroundColor(.cnSecondaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(testResults) { log in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: log.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(log.success ? .green : .red)
                                Text(log.bookmarkTitle)
                                    .font(.headline)
                                Spacer()
                            }
                            
                            if !log.actionsPerformed.isEmpty {
                                Text(log.actionsPerformed.joined(separator: ", "))
                                    .font(.caption)
                                    .foregroundColor(.cnSecondaryText)
                            }
                            
                            if let error = log.errorMessage {
                                Text(error)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Test Rule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Run Test") {
                        runTest()
                    }
                    .disabled(isTesting)
                }
            }
        }
    }
    
    private func runTest() {
        isTesting = true
        testResults = []
        
        let request: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        let bookmarks = (try? context.fetch(request)) ?? []
        
        testResults = service.testRule(rule, on: bookmarks, context: context)
        isTesting = false
    }
}


