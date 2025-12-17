//
//  AutomationRulesManagerView.swift
//  CalendarNotes
//

import SwiftUI
import CoreData

struct AutomationRulesManagerView: View {
    @StateObject private var service = AutomationRuleService.shared
    @Environment(\.managedObjectContext) private var context
    @State private var showingBuilder = false
    @State private var editingRule: AutomationRule?
    @State private var showingTemplates = false
    @State private var showingLogs = false
    @State private var selectedRule: AutomationRule?
    
    var body: some View {
        NavigationView {
            List {
                if service.rules.isEmpty {
                    emptyState
                } else {
                    ForEach(service.rules) { rule in
                        RuleRow(rule: rule, service: service)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    service.deleteRule(rule)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    editingRule = rule
                                    showingBuilder = true
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    service.toggleRule(rule)
                                } label: {
                                    Label(rule.isEnabled ? "Disable" : "Enable", systemImage: rule.isEnabled ? "pause.circle" : "play.circle")
                                }
                            }
                    }
                }
            }
            .navigationTitle("Automation Rules")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showingTemplates = true
                        } label: {
                            Label("Use Template", systemImage: "doc.text")
                        }
                        Button {
                            editingRule = nil
                            showingBuilder = true
                        } label: {
                            Label("New Rule", systemImage: "plus")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
                ToolbarItem(placement: .automatic) {
                    Button {
                        showingLogs = true
                    } label: {
                        Label("Logs", systemImage: "list.bullet.rectangle")
                    }
                }
            }
            .sheet(isPresented: $showingBuilder) {
                if let rule = editingRule {
                    AutomationRuleBuilderView(rule: rule) { updatedRule in
                        service.updateRule(updatedRule)
                        editingRule = nil
                    } onCancel: {
                        editingRule = nil
                    }
                } else {
                    AutomationRuleBuilderView { newRule in
                        service.addRule(newRule)
                    } onCancel: {}
                }
            }
            .sheet(isPresented: $showingTemplates) {
                AutomationTemplatesView { template in
                    editingRule = template.rule
                    showingTemplates = false
                    showingBuilder = true
                }
            }
            .sheet(isPresented: $showingLogs) {
                RuleExecutionLogView()
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "gearshape.2")
                .font(.system(size: 48))
                .foregroundColor(.cnSecondaryText)
            Text("No automation rules")
                .font(.headline)
            Text("Create rules to automatically organize and manage your bookmarks")
                .font(.subheadline)
                .foregroundColor(.cnSecondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

private struct RuleRow: View {
    let rule: AutomationRule
    let service: AutomationRuleService
    @State private var showingTest = false
    @State private var showingBatchApply = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Toggle("", isOn: Binding(
                    get: { rule.isEnabled },
                    set: { _ in service.toggleRule(rule) }
                ))
                .labelsHidden()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.name)
                        .font(.headline)
                        .foregroundColor(rule.isEnabled ? .cnPrimaryText : .cnSecondaryText)
                    
                    Text(triggerDescription(rule.trigger))
                        .font(.caption)
                        .foregroundColor(.cnSecondaryText)
                        .lineLimit(2)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    if rule.executionCount > 0 {
                        Label("\(rule.executionCount)", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.cnAccent)
                    }
                    if let lastExecuted = rule.lastExecuted {
                        Text(lastExecuted, style: .relative)
                            .font(.caption2)
                            .foregroundColor(.cnSecondaryText)
                    }
                }
            }
            
            HStack {
                Menu {
                    Button {
                        showingTest = true
                    } label: {
                        Label("Test Rule", systemImage: "play.circle")
                    }
                    Button {
                        showingBatchApply = true
                    } label: {
                        Label("Apply to Existing", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Label("Actions", systemImage: "ellipsis.circle")
                        .font(.caption)
                }
                
                Spacer()
                
                Text("\(rule.actions.count) action\(rule.actions.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.cnSecondaryText)
            }
        }
        .padding(.vertical, 4)
        .sheet(isPresented: $showingTest) {
            TestRuleView(rule: rule)
        }
        .sheet(isPresented: $showingBatchApply) {
            BatchApplyRuleView(rule: rule)
        }
    }
    
    private func triggerDescription(_ trigger: Trigger) -> String {
        switch trigger {
        case .addedToCollection(let name):
            return "Added to: \(name)"
        case .taggedWith(let tag):
            return "Tagged with: \(tag)"
        case .fromDomain(let domain):
            return "From domain: \(domain)"
        case .savedAtTime:
            return "Saved at specific time"
        case .notOpenedInDays(let days):
            return "Not opened in \(days) days"
        case .matchesAll:
            return "All conditions"
        case .matchesAny:
            return "Any condition"
        }
    }
}


