//
//  SmartCollectionRulesView.swift
//  CalendarNotes
//
//  Interface for configuring smart collection filter rules
//

import SwiftUI

struct SmartCollectionRulesView: View {
    @Binding var rules: CollectionEditorViewModel.SmartCollectionRules
    @Environment(\.dismiss) private var dismiss
    let availableTags: [String]
    
    @State private var tagSearchText: String = ""
    @State private var showingDateRangePicker = false
    
    var body: some View {
        NavigationView {
            Form {
                // Tag Filter
                Section(header: Text("Filter by Tag")) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Use simple text input for backward compatibility
                        TextField("Tag name", text: $tagSearchText)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: tagSearchText) { oldValue, newValue in
                                rules.tagFilter = newValue.isEmpty ? nil : newValue
                            }
                            .onAppear {
                                tagSearchText = rules.tagFilter ?? ""
                            }
                        
                        // Tag suggestions
                        if !tagSearchText.isEmpty && !filteredTags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(filteredTags.prefix(5), id: \.self) { tag in
                                        Button {
                                            tagSearchText = tag
                                            rules.tagFilter = tag
                                        } label: {
                                            Text(tag)
                                                .font(.caption)
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.accentColor.opacity(0.1))
                                                .foregroundColor(.accentColor)
                                                .cornerRadius(8)
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        
                        if let tag = rules.tagFilter, !tag.isEmpty {
                            Button {
                                rules.tagFilter = nil
                                tagSearchText = ""
                            } label: {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Clear tag filter")
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                        }
                        
                        // Note: For full tag management, use TagManagerView
                        Text("Use Tag Manager for advanced tag filtering")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Domain Filter
                Section(header: Text("Filter by Domain")) {
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Domain (e.g., example.com)", text: Binding(
                            get: { rules.domainFilter ?? "" },
                            set: { rules.domainFilter = $0.isEmpty ? nil : $0 }
                        ))
                        .textFieldStyle(.roundedBorder)
                        #if os(iOS)
                        .autocapitalization(.none)
                        #endif
                        .disableAutocorrection(true)
                        
                        if rules.domainFilter != nil {
                            Button {
                                rules.domainFilter = nil
                            } label: {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Clear domain filter")
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                // Date Range Filter
                Section(header: Text("Filter by Date Range")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Button {
                            showingDateRangePicker = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Start Date")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if let start = rules.dateRangeStart {
                                        Text(start.formatted(date: .abbreviated, time: .omitted))
                                            .foregroundColor(.primary)
                                    } else {
                                        Text("Not set")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button {
                            showingDateRangePicker = true
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("End Date")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if let end = rules.dateRangeEnd {
                                        Text(end.formatted(date: .abbreviated, time: .omitted))
                                            .foregroundColor(.primary)
                                    } else {
                                        Text("Not set")
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if rules.dateRangeStart != nil || rules.dateRangeEnd != nil {
                            Button {
                                rules.dateRangeStart = nil
                                rules.dateRangeEnd = nil
                            } label: {
                                HStack {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Clear date range")
                                }
                                .font(.caption)
                                .foregroundColor(.red)
                            }
                        }
                    }
                }
                
                // Favorite Status Filter
                Section(header: Text("Filter by Favorite Status")) {
                    Picker("Favorite Status", selection: Binding(
                        get: { rules.favoriteStatus },
                        set: { rules.favoriteStatus = $0 }
                    )) {
                        Text("Any").tag(nil as Bool?)
                        Text("Favorites Only").tag(true as Bool?)
                        Text("Non-Favorites Only").tag(false as Bool?)
                    }
                }
                
                // Summary
                if rules.hasAnyRule {
                    Section(header: Text("Active Rules")) {
                        VStack(alignment: .leading, spacing: 8) {
                            if rules.tagFilter != nil {
                                RuleSummaryRow(icon: "tag", text: "Tag: \(rules.tagFilter!)")
                            }
                            if rules.domainFilter != nil {
                                RuleSummaryRow(icon: "globe", text: "Domain: \(rules.domainFilter!)")
                            }
                            if rules.dateRangeStart != nil || rules.dateRangeEnd != nil {
                                let startText = rules.dateRangeStart?.formatted(date: .abbreviated, time: .omitted) ?? "Any"
                                let endText = rules.dateRangeEnd?.formatted(date: .abbreviated, time: .omitted) ?? "Any"
                                RuleSummaryRow(icon: "calendar", text: "Date: \(startText) - \(endText)")
                            }
                            if let favoriteStatus = rules.favoriteStatus {
                                RuleSummaryRow(icon: "star", text: favoriteStatus ? "Favorites Only" : "Non-Favorites Only")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Smart Rules")
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
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #endif
            }
            .sheet(isPresented: $showingDateRangePicker) {
                DateRangePickerView(
                    startDate: $rules.dateRangeStart,
                    endDate: $rules.dateRangeEnd
                )
            }
        }
    }
    
    private var filteredTags: [String] {
        if tagSearchText.isEmpty {
            return []
        }
        return availableTags.filter { tag in
            tag.localizedCaseInsensitiveContains(tagSearchText)
        }
    }
}

// MARK: - Rule Summary Row

struct RuleSummaryRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .font(.caption)
            Text(text)
                .font(.caption)
        }
    }
}

// MARK: - Date Range Picker View

struct DateRangePickerView: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    @Environment(\.dismiss) private var dismiss
    
    @State private var tempStartDate: Date = Date()
    @State private var tempEndDate: Date = Date()
    @State private var hasStartDate: Bool = false
    @State private var hasEndDate: Bool = false
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Start Date")) {
                    Toggle("Set Start Date", isOn: $hasStartDate)
                    
                    if hasStartDate {
                        DatePicker("", selection: $tempStartDate, displayedComponents: .date)
                    }
                }
                
                Section(header: Text("End Date")) {
                    Toggle("Set End Date", isOn: $hasEndDate)
                    
                    if hasEndDate {
                        DatePicker("", selection: $tempEndDate, displayedComponents: .date)
                    }
                }
            }
            .navigationTitle("Date Range")
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
                    Button("Done") {
                        startDate = hasStartDate ? tempStartDate : nil
                        endDate = hasEndDate ? tempEndDate : nil
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        startDate = hasStartDate ? tempStartDate : nil
                        endDate = hasEndDate ? tempEndDate : nil
                        dismiss()
                    }
                }
                #endif
            }
            .onAppear {
                hasStartDate = startDate != nil
                hasEndDate = endDate != nil
                if let start = startDate {
                    tempStartDate = start
                }
                if let end = endDate {
                    tempEndDate = end
                }
            }
        }
    }
}

