//
//  FilterComponents.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import SwiftUI

// MARK: - Filter Panel

struct FilterPanel: View {
    @ObservedObject var viewModel: FilterViewModel
    @State private var showingSavePreset = false
    @State private var presetName = ""
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("Filters")
                        .font(.title3)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    if viewModel.hasActiveFilters {
                        Button("Clear All") {
                            viewModel.clearAllFilters()
                        }
                        .font(.caption)
                        .foregroundColor(.cnStatusError)
                    }
                    
                    Button(action: {
                        viewModel.showFilterPanel = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                
                Divider()
                
                // Content Type Filter
                VStack(alignment: .leading, spacing: 12) {
                    Text("Show")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    HStack(spacing: 12) {
                        ToggleButton(
                            title: "Events",
                            icon: "calendar",
                            isOn: $viewModel.showEvents
                        )
                        
                        ToggleButton(
                            title: "Tasks",
                            icon: "checkmark.square",
                            isOn: $viewModel.showTasks
                        )
                    }
                }
                
                Divider()
                
                // Category Filter
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Categories")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button("All") {
                            viewModel.selectAllCategories()
                        }
                        .font(.caption)
                        .foregroundColor(.cnPrimary)
                    }
                    
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(EventCategory.allCases, id: \.rawValue) { category in
                            CategoryFilterButton(
                                category: category,
                                isSelected: viewModel.selectedCategories.contains(category.rawValue),
                                onTap: {
                                    viewModel.toggleCategory(category.rawValue)
                                }
                            )
                        }
                    }
                }
                
                Divider()
                
                // Priority Filter (for tasks)
                if viewModel.showTasks {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Priority")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            
                            Spacer()
                            
                            Button("All") {
                                viewModel.selectAllPriorities()
                            }
                            .font(.caption)
                            .foregroundColor(.cnPrimary)
                        }
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(TodoItem.Priority.allCases, id: \.rawValue) { priority in
                                PriorityFilterButton(
                                    priority: priority,
                                    isSelected: viewModel.selectedPriorities.contains(priority.rawValue),
                                    onTap: {
                                        viewModel.togglePriority(priority.rawValue)
                                    }
                                )
                            }
                        }
                    }
                    
                    Divider()
                }
                
                // Task Completion Filter
                if viewModel.showTasks {
                    Toggle("Include Completed Tasks", isOn: $viewModel.includeCompleted)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    Divider()
                }
                
                // Date Range Filter
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Date Range", isOn: $viewModel.dateRangeEnabled)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    
                    if viewModel.dateRangeEnabled {
                        VStack(spacing: 12) {
                            DatePicker("From", selection: $viewModel.dateRangeStart, displayedComponents: .date)
                            DatePicker("To", selection: $viewModel.dateRangeEnd, displayedComponents: .date)
                        }
                    }
                }
                
                Divider()
                
                // Presets
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Presets")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        Spacer()
                        
                        Button(action: {
                            showingSavePreset = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.cnPrimary)
                        }
                    }
                    
                    if viewModel.filterPresets.isEmpty {
                        Text("No saved presets")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.filterPresets) { preset in
                            PresetRow(
                                preset: preset,
                                isActive: viewModel.activePresetId == preset.id,
                                onApply: {
                                    viewModel.applyPreset(preset)
                                },
                                onDelete: {
                                    viewModel.deletePreset(preset)
                                }
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.cnBackground)
        .alert("Save Filter Preset", isPresented: $showingSavePreset) {
            TextField("Preset Name", text: $presetName)
            Button("Cancel", role: .cancel) {
                presetName = ""
            }
            Button("Save") {
                if !presetName.isEmpty {
                    viewModel.saveCurrentAsPreset(name: presetName)
                    presetName = ""
                }
            }
        }
    }
}

// MARK: - Toggle Button

struct ToggleButton: View {
    let title: String
    let icon: String
    @Binding var isOn: Bool
    
    var body: some View {
        Button(action: {
            isOn.toggle()
        }) {
            HStack {
                Image(systemName: icon)
                Text(title)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isOn ? Color.cnPrimary.opacity(0.2) : Color.gray.opacity(0.1))
            .foregroundColor(isOn ? .cnPrimary : .secondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isOn ? Color.cnPrimary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Filter Button

struct CategoryFilterButton: View {
    let category: EventCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: category.icon)
                    .font(.caption)
                Text(category.rawValue)
                    .font(.subheadline)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? category.color.opacity(0.2) : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? category.color : .secondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? category.color : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Priority Filter Button

struct PriorityFilterButton: View {
    let priority: TodoItem.Priority
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "flag.fill")
                    .font(.caption)
                Text(priority.rawValue)
                    .font(.subheadline)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(isSelected ? priorityColor.opacity(0.2) : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? priorityColor : .secondary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? priorityColor : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var priorityColor: Color {
        switch priority {
        case .low: return .cnPriorityLow
        case .medium: return .cnPriorityMedium
        case .high: return .cnPriorityHigh
        case .urgent: return .cnPriorityUrgent
        }
    }
}

// MARK: - Preset Row

struct PresetRow: View {
    let preset: FilterPreset
    let isActive: Bool
    let onApply: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            Button(action: onApply) {
                HStack {
                    Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(isActive ? .cnPrimary : .secondary)
                    
                    Text(preset.name)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
            }
            .buttonStyle(.plain)
            
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.cnStatusError)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(isActive ? Color.cnPrimary.opacity(0.1) : Color.cnSecondaryBackground)
        .cornerRadius(8)
    }
}

// MARK: - Quick Filter Chips

struct QuickFilterChips: View {
    @ObservedObject var viewModel: FilterViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Active Filter Count
                if viewModel.hasActiveFilters {
                    FilterChip(
                        title: "\(viewModel.activeFilterCount) Active",
                        icon: "line.3.horizontal.decrease.circle.fill",
                        color: .cnPrimary,
                        isRemovable: false,
                        onTap: {
                            withAnimation {
                                viewModel.showFilterPanel.toggle()
                            }
                        },
                        onRemove: {}
                    )
                }
                
                // Quick Filters
                if !viewModel.dateRangeEnabled {
                    FilterChip(
                        title: "Today",
                        icon: "calendar.badge.clock",
                        color: .cnAccent,
                        isRemovable: false,
                        onTap: {
                            viewModel.showOnlyTodayItems()
                        },
                        onRemove: {}
                    )
                    
                    FilterChip(
                        title: "This Week",
                        icon: "calendar",
                        color: .cnAccent,
                        isRemovable: false,
                        onTap: {
                            viewModel.showOnlyThisWeek()
                        },
                        onRemove: {}
                    )
                }
                
                // Content Type Chips
                if !viewModel.showEvents {
                    FilterChip(
                        title: "Events Hidden",
                        icon: "calendar.badge.minus",
                        color: .cnStatusWarning,
                        onRemove: {
                            viewModel.showEvents = true
                        }
                    )
                }
                
                if !viewModel.showTasks {
                    FilterChip(
                        title: "Tasks Hidden",
                        icon: "checkmark.square.fill",
                        color: .cnStatusWarning,
                        onRemove: {
                            viewModel.showTasks = true
                        }
                    )
                }
                
                // High Priority Filter
                if viewModel.selectedPriorities.count == 2 &&
                   viewModel.selectedPriorities.contains("High") &&
                   viewModel.selectedPriorities.contains("Urgent") {
                    FilterChip(
                        title: "High Priority",
                        icon: "flag.fill",
                        color: .cnPriorityHigh,
                        onRemove: {
                            viewModel.selectAllPriorities()
                        }
                    )
                }
                
                // Active Preset
                if let preset = viewModel.activePreset {
                    FilterChip(
                        title: preset.name,
                        icon: "bookmark.fill",
                        color: .cnSecondary,
                        onRemove: {
                            viewModel.clearAllFilters()
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let icon: String
    let color: Color
    var isRemovable: Bool = true
    var onTap: (() -> Void)? = nil
    var onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
            
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
            
            if isRemovable {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundColor(color)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.15))
        .cornerRadius(16)
        .onTapGesture {
            onTap?()
        }
    }
}

// MARK: - Filter Badge

struct FilterBadge: View {
    let count: Int
    
    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(minWidth: 16, minHeight: 16)
                .padding(.horizontal, 4)
                .background(Color.cnStatusError)
                .clipShape(Circle())
        }
    }
}

// MARK: - Compact Filter Panel

struct CompactFilterPanel: View {
    @ObservedObject var viewModel: FilterViewModel
    
    var body: some View {
        VStack(spacing: 16) {
            // Category Pills
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EventCategory.allCases, id: \.rawValue) { category in
                        CategoryPill(
                            category: category,
                            isSelected: viewModel.selectedCategories.contains(category.rawValue),
                            onTap: {
                                viewModel.toggleCategory(category.rawValue)
                            }
                        )
                    }
                }
            }
            
            // Quick Actions
            HStack(spacing: 12) {
                SmallActionButton(
                    title: "Today",
                    icon: "calendar.badge.clock",
                    action: {
                        viewModel.showOnlyTodayItems()
                    }
                )
                
                SmallActionButton(
                    title: "Week",
                    icon: "calendar",
                    action: {
                        viewModel.showOnlyThisWeek()
                    }
                )
                
                SmallActionButton(
                    title: "Priority",
                    icon: "flag.fill",
                    action: {
                        viewModel.showOnlyHighPriority()
                    }
                )
                
                if viewModel.hasActiveFilters {
                    SmallActionButton(
                        title: "Clear",
                        icon: "xmark.circle",
                        color: .cnStatusError,
                        action: {
                            viewModel.clearAllFilters()
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color.cnSecondaryBackground)
    }
}

// MARK: - Category Pill

struct CategoryPill: View {
    let category: EventCategory
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.caption2)
                Text(category.rawValue)
                    .font(.caption)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? category.color.opacity(0.2) : Color.gray.opacity(0.1))
            .foregroundColor(isSelected ? category.color : .secondary)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? category.color : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Small Action Button

struct SmallActionButton: View {
    let title: String
    let icon: String
    var color: Color = .cnPrimary
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(color.opacity(0.1))
            .foregroundColor(color)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Filter Panel") {
    FilterPanel(viewModel: FilterViewModel())
}

#Preview("Quick Filter Chips") {
    QuickFilterChips(viewModel: FilterViewModel())
}

#Preview("Compact Filter Panel") {
    CompactFilterPanel(viewModel: FilterViewModel())
}

