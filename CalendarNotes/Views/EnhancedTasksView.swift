//
//  EnhancedTasksView.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import SwiftUI
import CoreData

struct EnhancedTasksView: View {
    @StateObject private var viewModel = TasksViewModel()
    @State private var quickAddText = ""
    @State private var showingTaskEditor = false
    @FocusState private var isSearchFieldFocused: Bool
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Background
            #if os(macOS)
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()
            #else
            Color(UIColor.systemBackground)
                .ignoresSafeArea()
            #endif
            
            VStack(spacing: 0) {
                // Header with Title
                HStack {
                    Text("Tasks")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 4)
                
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.cnSecondaryText)
                        .font(.system(size: 16))
                    TextField("Search tasks...", text: $viewModel.searchText)
                        .focused($isSearchFieldFocused)
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.cnTertiaryBackground)
                        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
                )
                .padding(.horizontal)
                .padding(.bottom, 8)
                
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

struct EnhancedTaskRow: View, Equatable {
    let task: TodoItem
    @ObservedObject var viewModel: TasksViewModel
    @State private var isCompleting = false
    @State private var showConfetti = false
    @State private var isCirclePressed = false
    let onTap: (() -> Void)?
    
    // Pre-computed properties
    let taskID: NSManagedObjectID
    let title: String
    let priority: String
    let category: String
    let isCompleted: Bool
    let formattedDueDate: String?
    let dueDateColor: Color
    let priorityColor: Color
    let categoryIcon: String
    
    init(task: TodoItem, viewModel: TasksViewModel, onTap: (() -> Void)? = nil) {
        self.task = task
        self.viewModel = viewModel
        self.onTap = onTap
        
        // Pre-compute properties
        self.taskID = task.objectID
        self.title = task.title ?? "Untitled"
        self.priority = task.priority ?? "Medium"
        self.category = task.category ?? "Other"
        self.isCompleted = task.isCompleted
        
        // Format due date
        if let dueDate = task.dueDate {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let dueDay = calendar.startOfDay(for: dueDate)
            
            if dueDay == today {
                self.formattedDueDate = "Today"
            } else if dueDay == calendar.date(byAdding: .day, value: 1, to: today) {
                self.formattedDueDate = "Tomorrow"
            } else if dueDay < today {
                let days = calendar.dateComponents([.day], from: dueDay, to: today).day ?? 0
                self.formattedDueDate = "\(days)d overdue"
            } else {
                let formatter = DateFormatter()
                formatter.dateFormat = "MMM d"
                self.formattedDueDate = formatter.string(from: dueDate)
            }
            
            // Compute due date color
            if task.isCompleted {
                self.dueDateColor = .secondary
            } else if dueDay < today {
                self.dueDateColor = .cnStatusError
            } else if dueDay == today {
                self.dueDateColor = .cnStatusWarning
            } else {
                self.dueDateColor = .secondary
            }
        } else {
            self.formattedDueDate = nil
            self.dueDateColor = .secondary
        }
        
        // Compute priority color
        switch self.priority {
        case "Low": self.priorityColor = .cnPriorityLow
        case "Medium": self.priorityColor = .cnPriorityMedium
        case "High": self.priorityColor = .cnPriorityHigh
        case "Urgent": self.priorityColor = .cnPriorityUrgent
        default: self.priorityColor = .cnPriorityMedium
        }
        
        self.categoryIcon = EventCategory(rawValue: self.category)?.icon ?? "square.grid.2x2.fill"
    }
    
    static func == (lhs: EnhancedTaskRow, rhs: EnhancedTaskRow) -> Bool {
        lhs.taskID == rhs.taskID &&
        lhs.title == rhs.title &&
        lhs.priority == rhs.priority &&
        lhs.category == rhs.category &&
        lhs.isCompleted == rhs.isCompleted &&
        lhs.formattedDueDate == rhs.formattedDueDate
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
                    if !isCompleted {
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
            
            // Priority Indicator
            Rectangle()
                .fill(priorityColor)
                .frame(width: 3, height: 40)
                .cornerRadius(1.5)
            
            // Task Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .strikethrough(isCompleted)
                    .foregroundColor(isCompleted ? .secondary : .primary)
                
                HStack(spacing: 12) {
                    // Priority
                    HStack(spacing: 4) {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                        Text(priority)
                            .font(.caption)
                    }
                    .foregroundColor(priorityColor)
                    
                    // Due Date
                    if let formattedDueDate = formattedDueDate {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(formattedDueDate)
                                .font(.caption)
                        }
                        .foregroundColor(dueDateColor)
                    }
                    
                    // Category
                    HStack(spacing: 4) {
                        Image(systemName: categoryIcon)
                            .font(.caption2)
                        Text(category)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .opacity(isCompleted ? 0.6 : 1.0)
        .contentShape(Rectangle())
        .onTapGesture {
            if let onTap {
                onTap()
            }
        }
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
        if isCompleted {
            return .cnStatusSuccess
        }
        return priorityColor
    }
    
    private func performHapticFeedback() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
}

// MARK: - Floating Add Button

private struct TasksFloatingAddButton: View {
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

