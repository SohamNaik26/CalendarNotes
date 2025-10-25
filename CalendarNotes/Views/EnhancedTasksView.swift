//
//  EnhancedTasksView.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import SwiftUI

struct EnhancedTasksView: View {
    @StateObject private var viewModel = TasksViewModel()
    @State private var quickAddText = ""
    @State private var showingTaskEditor = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Header with Add Task Button
                HStack {
                    Text("Tasks")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Button(action: {
                        viewModel.selectedTask = nil
                        viewModel.showingTaskEditor = true
                        #if os(iOS)
                        generateHapticFeedback(style: .medium)
                        #endif
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Add Task")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.cnPrimary, .cnAccent]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)
                
                // Quick Add Bar
                QuickAddBar(text: $quickAddText, onAdd: {
                    guard !quickAddText.isEmpty else { return }
                    viewModel.addTask(
                        title: quickAddText,
                        priority: TodoItem.Priority.medium.rawValue,
                        category: EventCategory.other.rawValue,
                        dueDate: nil
                    )
                    quickAddText = ""
                })
                
                // Filter Bar
                FilterBar(selectedFilter: $viewModel.filter)
                
                // Task List or Empty State
                if viewModel.hasTasks {
                    List {
                    // Overdue Section
                    if !viewModel.overdueTasks.isEmpty {
                        Section {
                            ForEach(viewModel.overdueTasks, id: \.id) { task in
                                EnhancedTaskRow(task: task, viewModel: viewModel, onTap: {
                                    viewModel.editTask(task)
                                })
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            viewModel.deleteTask(task)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        
                                        Button {
                                            withAnimation(.spring()) {
                                                viewModel.toggleTaskCompletion(task)
                                            }
                                        } label: {
                                            Label("Complete", systemImage: "checkmark")
                                        }
                                        .tint(.cnStatusSuccess)
                                    }
                            }
                        } header: {
                            SectionHeaderView(title: "Overdue", count: viewModel.overdueCount, color: .cnStatusError)
                        }
                    }
                    
                    // Today Section
                    if !viewModel.todayTasks.isEmpty {
                        Section {
                            ForEach(viewModel.todayTasks, id: \.id) { task in
                                EnhancedTaskRow(task: task, viewModel: viewModel, onTap: {
                                    viewModel.editTask(task)
                                })
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            viewModel.deleteTask(task)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        
                                        Button {
                                            withAnimation(.spring()) {
                                                viewModel.toggleTaskCompletion(task)
                                            }
                                        } label: {
                                            Label("Complete", systemImage: "checkmark")
                                        }
                                        .tint(.cnStatusSuccess)
                                    }
                            }
                        } header: {
                            SectionHeaderView(title: "Today", count: viewModel.todayCount, color: .cnStatusInfo)
                        }
                    }
                    
                    // Upcoming Section
                    if !viewModel.upcomingTasks.isEmpty {
                        Section {
                            ForEach(viewModel.upcomingTasks, id: \.id) { task in
                                EnhancedTaskRow(task: task, viewModel: viewModel, onTap: {
                                    viewModel.editTask(task)
                                })
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            viewModel.deleteTask(task)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        
                                        Button {
                                            withAnimation(.spring()) {
                                                viewModel.toggleTaskCompletion(task)
                                            }
                                        } label: {
                                            Label("Complete", systemImage: "checkmark")
                                        }
                                        .tint(.cnStatusSuccess)
                                    }
                            }
                        } header: {
                            SectionHeaderView(title: "Upcoming", count: viewModel.upcomingCount, color: .cnPrimary)
                        }
                    }
                    
                    // No Due Date Section
                    if !viewModel.noDueDateTasks.isEmpty && viewModel.filter != .completed {
                        Section {
                            ForEach(viewModel.noDueDateTasks, id: \.id) { task in
                                EnhancedTaskRow(task: task, viewModel: viewModel, onTap: {
                                    viewModel.editTask(task)
                                })
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            viewModel.deleteTask(task)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                        
                                        Button {
                                            withAnimation(.spring()) {
                                                viewModel.toggleTaskCompletion(task)
                                            }
                                        } label: {
                                            Label("Complete", systemImage: "checkmark")
                                        }
                                        .tint(.cnStatusSuccess)
                                    }
                            }
                        } header: {
                            Text("No Due Date")
                        }
                    }
                    
                    // Completed Section
                    if !viewModel.completedTasks.isEmpty && viewModel.filter != .active {
                        Section {
                            ForEach(viewModel.completedTasks, id: \.id) { task in
                                EnhancedTaskRow(task: task, viewModel: viewModel, onTap: {
                                    viewModel.editTask(task)
                                })
                                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                        Button(role: .destructive) {
                                            viewModel.deleteTask(task)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            withAnimation(.spring()) {
                                                viewModel.toggleTaskCompletion(task)
                                            }
                                        } label: {
                                            Label("Uncomplete", systemImage: "arrow.uturn.backward")
                                        }
                                        .tint(.cnStatusWarning)
                                    }
                            }
                        } header: {
                            SectionHeaderView(title: "Completed", count: viewModel.completedCount, color: .cnStatusSuccess)
                        }
                    }
                    }
                    #if os(iOS)
                    .listStyle(.insetGrouped)
                    #else
                    .listStyle(.plain)
                    #endif
                } else {
                    TasksEmptyState {
                        viewModel.selectedTask = nil
                        viewModel.showingTaskEditor = true
                    }
                }
            }
            .navigationTitle("Tasks")
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    SortMenu(selectedSort: $viewModel.sortOption)
                }
                
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        viewModel.selectedTask = nil
                        viewModel.showingTaskEditor = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            // Floating Action Button
            FloatingAddButton {
                viewModel.selectedTask = nil
                viewModel.showingTaskEditor = true
                #if os(iOS)
                generateHapticFeedback(style: .medium)
                #endif
            }
            .padding(.bottom, 20)
            .padding(.trailing, 20)
        }
        .sheet(isPresented: $viewModel.showingTaskEditor) {
            TaskEditorView(
                viewModel: viewModel,
                task: viewModel.selectedTask
            )
        }
    }
}

// MARK: - Quick Add Bar

struct QuickAddBar: View {
    @Binding var text: String
    let onAdd: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundColor(.cnPrimary)
            
            TextField("Quick add task...", text: $text)
                .textFieldStyle(.plain)
                .onSubmit {
                    onAdd()
                }
            
            if !text.isEmpty {
                Button(action: onAdd) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                        .foregroundColor(.cnPrimary)
                }
                .transition(.scale)
            }
        }
        .padding()
        .background(Color.cnSecondaryBackground)
        .animation(.spring(), value: text.isEmpty)
    }
}

// MARK: - Filter Bar

struct FilterBar: View {
    @Binding var selectedFilter: TaskFilter
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(TaskFilter.allCases, id: \.self) { filter in
                Button(action: {
                    withAnimation {
                        selectedFilter = filter
                    }
                }) {
                    VStack(spacing: 4) {
                        Text(filter.rawValue)
                            .font(.subheadline)
                            .fontWeight(selectedFilter == filter ? .semibold : .regular)
                            .foregroundColor(selectedFilter == filter ? .cnPrimary : .secondary)
                        
                        if selectedFilter == filter {
                            Rectangle()
                                .fill(Color.cnPrimary)
                                .frame(height: 2)
                                .matchedGeometryEffect(id: "filter", in: namespace)
                        } else {
                            Rectangle()
                                .fill(Color.clear)
                                .frame(height: 2)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.cnBackground)
    }
    
    @Namespace private var namespace
}

// MARK: - Section Header

struct SectionHeaderView: View {
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundColor(color)
            
            Spacer()
            
            Text("\(count)")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(color)
                .cornerRadius(10)
        }
    }
}

// MARK: - Sort Menu

struct SortMenu: View {
    @Binding var selectedSort: TaskSortOption
    
    var body: some View {
        Menu {
            ForEach(TaskSortOption.allCases, id: \.self) { option in
                Button(action: {
                    selectedSort = option
                }) {
                    Label(option.rawValue, systemImage: option.systemImage)
                    if selectedSort == option {
                        Image(systemName: "checkmark")
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
                .font(.title3)
        }
    }
}

// MARK: - Enhanced Task Row

struct EnhancedTaskRow: View {
    let task: TodoItem
    @ObservedObject var viewModel: TasksViewModel
    @State private var isCompleting = false
    @State private var showConfetti = false
    @State private var isCirclePressed = false
    let onTap: (() -> Void)?
    
    init(task: TodoItem, viewModel: TasksViewModel, onTap: (() -> Void)? = nil) {
        self.task = task
        self.viewModel = viewModel
        self.onTap = onTap
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button(action: {
                print("Circle button tapped for task: \(task.title ?? "Untitled")")
                performHapticFeedback()
                
                // Toggle completion immediately
                viewModel.toggleTaskCompletion(task)
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isCompleting = true
                }
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isCompleting = false
                    
                    // Show confetti for completion
                    if !task.isCompleted {
                        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                            showConfetti = true
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            showConfetti = false
                        }
                    }
                }
            }) {
                ZStack {
                    Circle()
                        .stroke(checkboxColor, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    
                    if task.isCompleted || isCompleting {
                        Image(systemName: "checkmark")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .scaleEffect(isCompleting ? 1.2 : 1.0)
                        
                        Circle()
                            .fill(checkboxColor)
                            .frame(width: 24, height: 24)
                            .scaleEffect(isCompleting ? 1.1 : 1.0)
                            .opacity(isCompleting ? 0.8 : 1.0)
                    }
                }
                .frame(width: 44, height: 44) // Larger hit area
                .contentShape(Circle()) // Ensure circular hit area
            }
            .buttonStyle(.plain)
            .onTapGesture {
                // Prevent tap from propagating to parent
                print("Circle button tap gesture fired")
            }
            
            // Priority Indicator
            Rectangle()
                .fill(priorityColor)
                .frame(width: 3, height: 40)
                .cornerRadius(1.5)
            
            // Task Content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title ?? "Untitled")
                    .font(.body)
                    .fontWeight(.medium)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                
                HStack(spacing: 12) {
                    // Priority
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                        Text(task.priority ?? "Medium")
                            .font(.caption)
                    }
                    .foregroundColor(priorityColor)
                    
                    // Due Date
                    if let dueDate = task.dueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(formatDueDate(dueDate))
                                .font(.caption)
                        }
                        .foregroundColor(dueDateColor(dueDate))
                    }
                    
                    // Category
                    HStack(spacing: 4) {
                        Image(systemName: categoryIcon)
                            .font(.caption2)
                        Text(task.category ?? "Other")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(task.isCompleted ? 0.6 : 1.0)
        .background(
            // Invisible background for tap gesture
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    // Handle tap on the main content area (not the circle button)
                    if let onTap = onTap {
                        onTap()
                    }
                }
        )
        .contextMenu {
            Button(role: .destructive, action: {
                viewModel.deleteTask(task)
            }) {
                Label("Delete", systemImage: "trash")
            }
            
            Button(action: {
                viewModel.shareTask(task)
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
        .overlay(
            Group {
                if showConfetti {
                    ConfettiView()
                        .allowsHitTesting(false)
                }
            }
        )
        .animatedListItem()
    }
    
    private var checkboxColor: Color {
        if task.isCompleted {
            return .cnStatusSuccess
        }
        return priorityColor
    }
    
    private var priorityColor: Color {
        switch task.priority {
        case "Low": return .cnPriorityLow
        case "Medium": return .cnPriorityMedium
        case "High": return .cnPriorityHigh
        case "Urgent": return .cnPriorityUrgent
        default: return .cnPriorityMedium
        }
    }
    
    private func dueDateColor(_ date: Date) -> Color {
        if task.isCompleted {
            return .secondary
        }
        
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDay = calendar.startOfDay(for: date)
        
        if dueDay < today {
            return .cnStatusError
        } else if dueDay == today {
            return .cnStatusWarning
        } else {
            return .secondary
        }
    }
    
    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let dueDay = calendar.startOfDay(for: date)
        
        if dueDay == today {
            return "Today"
        } else if dueDay == calendar.date(byAdding: .day, value: 1, to: today) {
            return "Tomorrow"
        } else if dueDay < today {
            let days = calendar.dateComponents([.day], from: dueDay, to: today).day ?? 0
            return "\(days)d overdue"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
    
    private var categoryIcon: String {
        EventCategory(rawValue: task.category ?? "Other")?.icon ?? "square.grid.2x2.fill"
    }
    
    private func performHapticFeedback() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
}

// MARK: - Floating Add Button

private struct FloatingAddButton: View {
    let action: () -> Void
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        HStack {
            Spacer()
            
            Button(action: action) {
                Image(systemName: "plus")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [.cnPrimary, .cnAccent]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .shadow(color: Color.cnPrimary.opacity(0.4), radius: 8, x: 0, y: 4)
            }
        }
    }
}

#Preview {
    EnhancedTasksView()
}

