//
//  AutomationTemplatesView.swift
//  CalendarNotes
//

import SwiftUI

struct AutomationTemplatesView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (AutomationTemplate) -> Void
    
    var body: some View {
        NavigationView {
            List(AutomationTemplate.all) { template in
                VStack(alignment: .leading, spacing: 8) {
                    Text(template.name)
                        .font(.headline)
                    Text(template.description)
                        .font(.subheadline)
                        .foregroundColor(.cnSecondaryText)
                }
                .padding(.vertical, 4)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect(template)
                    dismiss()
                }
            }
            .navigationTitle("Templates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}


