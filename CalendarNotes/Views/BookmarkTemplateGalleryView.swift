//
//  BookmarkTemplateGalleryView.swift
//  CalendarNotes
//
//  Created by Cursor AI on 09/11/25.
//

import SwiftUI

struct BookmarkTemplateGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = BookmarkTemplateService.shared

    let onSelect: (BookmarkTemplate) -> Void
    let onCreateCustom: (() -> Void)?

    init(
        onSelect: @escaping (BookmarkTemplate) -> Void,
        onCreateCustom: (() -> Void)? = nil
    ) {
        self.onSelect = onSelect
        self.onCreateCustom = onCreateCustom
    }

    var body: some View {
        NavigationStack {
            List {
                if !systemTemplates.isEmpty {
                    Section("Suggested Templates") {
                        ForEach(systemTemplates) { template in
                            buttonRow(for: template)
                        }
                    }
                }

                Section {
                    if service.customTemplates.isEmpty {
                        VStack(spacing: 6) {
                            Text("No custom templates yet")
                                .font(.subheadline)
                                .foregroundColor(.cnSecondaryText)
                            Text("Save your current bookmark setup as a template to reuse it later.")
                                .font(.caption)
                                .foregroundColor(.cnTertiaryText)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    } else {
                        ForEach(service.customTemplates) { template in
                            buttonRow(for: template)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        service.deleteCustomTemplate(template)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                } header: {
                    HStack {
                        Text("My Templates")
                        Spacer()
                        if let onCreateCustom {
                            Button {
                                dismiss()
                                onCreateCustom()
                            } label: {
                                Label("New", systemImage: "plus.circle")
                                    .labelStyle(.iconOnly)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Create custom template")
                        }
                    }
                }
            }
#if os(iOS)
            .listStyle(.insetGrouped)
#else
            .listStyle(.inset)
#endif
            .navigationTitle("Bookmark Templates")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private var systemTemplates: [BookmarkTemplate] {
        service.templates.filter { $0.isSystemTemplate }
    }

    private func buttonRow(for template: BookmarkTemplate) -> some View {
        Button {
            onSelect(template)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: template.systemImageName)
                    .font(.system(size: 24))
                    .foregroundStyle(Color.cnAccent)
                    .frame(width: 32, height: 32)
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.cnSecondaryBackground)
                    )
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                        .foregroundColor(.cnPrimaryText)
                    Text(template.shortDescription)
                        .font(.subheadline)
                        .foregroundColor(.cnSecondaryText)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(.cnTertiaryText)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint("Apply template")
    }
}


