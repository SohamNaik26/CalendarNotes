//
//  CollectionEditorView.swift
//  CalendarNotes
//
//  Collection creation and editing interface
//

import SwiftUI
import CoreData

struct CollectionEditorView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CollectionEditorViewModel
    @State private var showingDeleteConfirmation = false
    @State private var showingIconPicker = false
    @State private var showingColorPicker = false
    @State private var showingParentPicker = false
    @State private var showingSmartRules = false
    
    private let editingCollection: Collection?
    
    init(context: NSManagedObjectContext, collection: Collection? = nil) {
        self.editingCollection = collection
        _viewModel = StateObject(wrappedValue: CollectionEditorViewModel(context: context, collection: collection))
    }
    
    var body: some View {
        NavigationView {
            formContent
                .navigationTitle(viewModel.isEditing ? "Edit Collection" : "New Collection")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    #if os(iOS)
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Save") {
                            saveAndDismiss()
                        }
                        .disabled(!viewModel.validateName())
                    }
                    #else
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveAndDismiss()
                        }
                        .disabled(!viewModel.validateName())
                    }
                    #endif
                }
                .sheet(isPresented: $showingIconPicker) {
                    IconPickerView(selectedIcon: $viewModel.selectedIcon)
                }
                .sheet(isPresented: $showingColorPicker) {
                    ColorPickerView(selectedColor: $viewModel.selectedColor)
                }
                .sheet(isPresented: $showingParentPicker) {
                    ParentCollectionPicker(
                        selectedParent: $viewModel.selectedParent,
                        excluding: editingCollection
                    )
                }
                .sheet(isPresented: $showingSmartRules) {
                    SmartCollectionRulesView(
                        rules: $viewModel.smartRules,
                        availableTags: viewModel.availableTags
                    )
                }
                .alert("Delete Collection", isPresented: $showingDeleteConfirmation) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        deleteCollection()
                    }
                } message: {
                    Text("Are you sure you want to delete this collection? All bookmarks will be moved to 'All'.")
                }
        }
    }
    
    // MARK: - Body Components
    
    private var formContent: some View {
        Form {
            previewSection
            basicInformationSection
            appearanceSection
            organizationSection
            projectSection
            smartRulesSection
            if viewModel.isEditing {
                deleteSection
            }
        }
    }
    
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        Section {
            HStack {
                Spacer()
                VStack(spacing: 12) {
                    // Collection Icon Preview
                    ZStack {
                        Circle()
                            .fill(Color.hex(viewModel.selectedColor) ?? .gray)
                            .frame(width: 64, height: 64)
                        
                        Image(systemName: viewModel.selectedIcon)
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                    }
                    
                    // Collection Name Preview
                    Text(viewModel.name.isEmpty ? "Collection Name" : viewModel.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Basic Information Section
    
    private var basicInformationSection: some View {
        Section(header: Text("Basic Information")) {
            VStack(alignment: .leading, spacing: 4) {
                TextField("Collection Name", text: $viewModel.name)
                    .textFieldStyle(.plain)
                    .onChange(of: viewModel.name) { _, _ in
                        _ = viewModel.validateName()
                    }
                
                if let error = viewModel.nameValidationError {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
    }
    
    // MARK: - Appearance Section
    
    private var appearanceSection: some View {
        Section(header: Text("Appearance")) {
            // Icon Picker
            Button {
                showingIconPicker = true
            } label: {
                HStack {
                    Text("Icon")
                    Spacer()
                    Image(systemName: viewModel.selectedIcon)
                            .foregroundColor(Color.hex(viewModel.selectedColor) ?? .gray)
                    Text(viewModel.selectedIcon)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Color Picker
            Button {
                showingColorPicker = true
            } label: {
                HStack {
                    Text("Color")
                    Spacer()
                    Circle()
                        .fill(Color.hex(viewModel.selectedColor) ?? .gray)
                        .frame(width: 24, height: 24)
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.2), lineWidth: 1)
                        )
                }
            }
        }
    }
    
    // MARK: - Organization Section
    
    private var organizationSection: some View {
        Section(header: Text("Organization")) {
            // Parent Collection
            Button {
                showingParentPicker = true
            } label: {
                HStack {
                    Text("Parent Collection")
                    Spacer()
                    if let parent = viewModel.selectedParent {
                        Text(parent.name ?? "None")
                            .foregroundColor(.secondary)
                    } else {
                        Text("None")
                            .foregroundColor(.secondary)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Sort Order
            Picker("Sort Order", selection: $viewModel.sortOrder) {
                ForEach(CollectionEditorViewModel.SortOrder.allCases) { order in
                    Text(order.rawValue).tag(order)
                }
            }
        }
    }
    
    // MARK: - Project Section

    private var projectSection: some View {
        Section(header: Text("Project Settings"), footer: Text("Enable project mode to track milestones, timelines, and progress.")) {
            Toggle("Treat as Project", isOn: $viewModel.isProject)

            if viewModel.isProject {
                Picker("Status", selection: $viewModel.projectStatus) {
                    ForEach(ProjectStatus.allCases) { status in
                        Label(status.displayName, systemImage: status.systemImageName)
                            .tag(status)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Summary")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $viewModel.projectSummary)
                        .frame(minHeight: 80)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.2))
                        )
                }

                DatePicker(
                    "Start Date",
                    selection: bindingForOptionalDate($viewModel.projectStartDate),
                    displayedComponents: .date
                )
                Button("Clear Start Date") {
                    viewModel.projectStartDate = nil
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)

                DatePicker(
                    "Target Date",
                    selection: bindingForOptionalDate($viewModel.projectTargetDate, default: Date().addingTimeInterval(24 * 60 * 60)),
                    displayedComponents: .date
                )
                Button("Clear Target Date") {
                    viewModel.projectTargetDate = nil
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.secondary)

                DatePicker(
                    "Completion Date",
                    selection: bindingForOptionalDate($viewModel.projectCompletionDate),
                    displayedComponents: .date
                )
                .opacity(viewModel.projectStatus == .completed || viewModel.projectStatus == .archived ? 1 : 0.5)
                .disabled(!(viewModel.projectStatus == .completed || viewModel.projectStatus == .archived))
                if viewModel.projectCompletionDate != nil {
                    Button("Clear Completion Date") {
                        viewModel.projectCompletionDate = nil
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Progress")
                        Spacer()
                        Text("\(Int(viewModel.projectProgress * 100))%")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $viewModel.projectProgress, in: 0...1)
                }
            }
        }
    }
    
    // MARK: - Smart Rules Section
    
    private var smartRulesSection: some View {
        Section(header: Text("Smart Collection Rules"), footer: Text("Automatically organize bookmarks based on rules")) {
            Toggle("Enable Smart Rules", isOn: $viewModel.smartRules.isEnabled)
            
            if viewModel.smartRules.isEnabled {
                Button {
                    showingSmartRules = true
                } label: {
                    HStack {
                        Text("Configure Rules")
                        Spacer()
                        if viewModel.smartRules.hasAnyRule {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
    
    // MARK: - Delete Section
    
    private var deleteSection: some View {
        Section {
            Button(role: .destructive) {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Spacer()
                    Text("Delete Collection")
                    Spacer()
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func saveAndDismiss() {
        do {
            try viewModel.save()
            dismiss()
        } catch {
            // Handle error - could show alert
            print("Error saving collection: \(error)")
        }
    }
    
    private func deleteCollection() {
        do {
            try viewModel.delete()
            dismiss()
        } catch {
            // Handle error
            print("Error deleting collection: \(error)")
        }
    }
}

// MARK: - Helpers

private extension CollectionEditorView {
    func bindingForOptionalDate(_ binding: Binding<Date?>, default defaultValue: Date = Date()) -> Binding<Date> {
        Binding(
            get: { binding.wrappedValue ?? defaultValue },
            set: { binding.wrappedValue = $0 }
        )
    }
}

// MARK: - Extensions

extension CollectionEditorViewModel.SmartCollectionRules {
    var hasAnyRule: Bool {
        tagFilter != nil ||
        domainFilter != nil ||
        dateRangeStart != nil ||
        dateRangeEnd != nil ||
        favoriteStatus != nil
    }
}

