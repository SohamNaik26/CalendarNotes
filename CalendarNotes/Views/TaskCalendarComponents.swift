//
//  TaskCalendarComponents.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import SwiftUI

// MARK: - Task Calendar Item

/// Task displayed on calendar with different visual style from events
struct TaskCalendarItem: View {
    let task: TodoItem
    let onToggle: () -> Void
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                // Checkbox
                Button(action: {
                    performHapticFeedback()
                    onToggle()
                }) {
                    Image(systemName: task.isCompleted ? "checkmark.square.fill" : "square")
                        .font(.caption)
                        .foregroundColor(task.isCompleted ? .cnStatusSuccess : priorityColor)
                }
                .buttonStyle(.plain)
                
                // Title
                Text(task.title ?? "Untitled")
                    .font(.caption)
                    .lineLimit(1)
                    .strikethrough(task.isCompleted)
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                
                Spacer(minLength: 0)
                
                // Priority indicator dot
                Circle()
                    .fill(priorityColor)
                    .frame(width: 6, height: 6)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(priorityColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
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
    
    private var backgroundColor: Color {
        if task.isCompleted {
            return Color.cnStatusSuccess.opacity(0.1)
        }
        return priorityColor.opacity(0.1)
    }
    
    private func performHapticFeedback() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        #endif
    }
}

// MARK: - Compact Task Item

/// Compact task item for calendar date cells
struct CompactTaskItem: View {
    let task: TodoItem
    
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 8))
                .foregroundColor(task.isCompleted ? .cnStatusSuccess : priorityColor)
            
            Text(task.title ?? "")
                .font(.system(size: 9))
                .lineLimit(1)
                .strikethrough(task.isCompleted)
                .foregroundColor(task.isCompleted ? .secondary : .primary)
        }
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
}

// MARK: - Task Count Badge

/// Badge showing task count on calendar dates
struct TaskCountBadge: View {
    let count: Int
    let activeCount: Int
    
    var body: some View {
        if count > 0 {
            HStack(spacing: 2) {
                Image(systemName: "checkmark.square")
                    .font(.system(size: 8))
                
                Text("\(activeCount)/\(count)")
                    .font(.system(size: 8))
                    .fontWeight(.medium)
            }
            .foregroundColor(activeCount == 0 ? .cnStatusSuccess : .cnPrimary)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                (activeCount == 0 ? Color.cnStatusSuccess : Color.cnPrimary)
                    .opacity(0.15)
            )
            .cornerRadius(6)
        }
    }
}

// MARK: - Task Detail Sheet

/// Task detail view accessible from calendar
struct TaskDetailSheetView: View {
    @Environment(\.dismiss) var dismiss
    let task: TodoItem
    let onToggleComplete: () -> Void
    let onConvertToEvent: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Title
                    HStack {
                        Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.title)
                            .foregroundColor(task.isCompleted ? .cnStatusSuccess : .cnPrimary)
                        
                        Text(task.title ?? "Untitled")
                            .font(.title2)
                            .fontWeight(.bold)
                            .strikethrough(task.isCompleted)
                    }
                    
                    Divider()
                    
                    // Details
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(
                            icon: "flag.fill",
                            title: "Priority",
                            value: task.priority ?? "Medium",
                            color: priorityColor
                        )
                        
                        DetailRow(
                            icon: categoryIcon,
                            title: "Category",
                            value: task.category ?? "Other",
                            color: .cnSecondary
                        )
                        
                        if let dueDate = task.dueDate {
                            DetailRow(
                                icon: "calendar",
                                title: "Due Date",
                                value: formatDate(dueDate),
                                color: dueDateColor(dueDate)
                            )
                        }
                        
                        if task.isRecurring {
                            DetailRow(
                                icon: "repeat",
                                title: "Repeats",
                                value: "Yes",
                                color: .cnPrimary
                            )
                        }
                        
                        DetailRow(
                            icon: "checkmark.circle",
                            title: "Status",
                            value: task.isCompleted ? "Completed" : "Active",
                            color: task.isCompleted ? .cnStatusSuccess : .cnStatusWarning
                        )
                    }
                    
                    Divider()
                    
                    // Actions
                    VStack(spacing: 12) {
                        ActionButton(
                            icon: task.isCompleted ? "arrow.uturn.backward" : "checkmark.circle.fill",
                            title: task.isCompleted ? "Mark as Incomplete" : "Mark as Complete",
                            color: task.isCompleted ? .cnStatusWarning : .cnStatusSuccess,
                            action: {
                                onToggleComplete()
                                dismiss()
                            }
                        )
                        
                        ActionButton(
                            icon: "calendar.badge.plus",
                            title: "Convert to Event",
                            color: .cnPrimary,
                            action: {
                                onConvertToEvent()
                                dismiss()
                            }
                        )
                        
                        ActionButton(
                            icon: "pencil",
                            title: "Edit Task",
                            color: .cnSecondary,
                            action: {
                                onEdit()
                                dismiss()
                            }
                        )
                        
                        ActionButton(
                            icon: "trash",
                            title: "Delete Task",
                            color: .cnStatusError,
                            action: {
                                onDelete()
                                dismiss()
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Task Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
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
    
    private var categoryIcon: String {
        EventCategory(rawValue: task.category ?? "Other")?.icon ?? "square.grid.2x2.fill"
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
        }
        return .cnStatusInfo
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(title)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }
}

// MARK: - Action Button

struct ActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 24)
                
                Text(title)
                
                Spacer()
            }
            .foregroundColor(color)
            .padding()
            .background(color.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("Task Calendar Item") {
    VStack(spacing: 8) {
        TaskCalendarItem(
            task: {
                let task = TodoItem(
                    context: CoreDataManager.shared.viewContext,
                    title: "Complete project",
                    priority: "High",
                    category: "Work",
                    dueDate: Date()
                )
                return task
            }(),
            onToggle: { print("Toggled") },
            onTap: { print("Tapped") }
        )
        .padding()
    }
}

#Preview("Task Count Badge") {
    VStack(spacing: 8) {
        TaskCountBadge(count: 5, activeCount: 3)
        TaskCountBadge(count: 2, activeCount: 0)
        TaskCountBadge(count: 0, activeCount: 0)
    }
    .padding()
}

