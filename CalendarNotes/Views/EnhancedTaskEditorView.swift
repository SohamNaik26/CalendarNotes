//
//  EnhancedTaskEditorView.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import SwiftUI

#if os(iOS)
import UIKit
#else
import AppKit
#endif

struct EnhancedTaskEditorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: TasksViewModel
    let task: TodoItem?
    
    private var systemBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.textBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    private var controlBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    // Basic Properties
    @State private var title: String
    @State private var priority: String
    @State private var category: String
    @State private var taskDescription: String
    
    // Date and Time
    @State private var hasDueDate: Bool
    @State private var dueDate: Date
    
    // Recurring
    @State private var isRecurring: Bool
    @State private var recurrencePattern: RecurrencePattern
    
    // Notifications
    @State private var hasNotification: Bool
    @State private var notificationTime: Date
    
    // Calendar Integration
    @State private var showInCalendar: Bool
    @State private var linkedCalendarEvent: CalendarEvent?
    
    // Subtasks
    @State private var subtasks: [Subtask]
    @State private var newSubtaskTitle: String = ""
    @FocusState private var isAddingSubtask: Bool
    
    // UI State
    @State private var showingRecurrenceOptions = false
    @State private var showingEventPicker = false
    
    // Computed Properties
    private var daysUntilDue: String {
        guard hasDueDate else { return "" }
        let calendar = Calendar.current
        let now = Date()
        let days = calendar.dateComponents([.day], from: now, to: dueDate).day ?? 0
        
        if days < 0 {
            return "Overdue"
        } else if days == 0 {
            return "Today"
        } else if days == 1 {
            return "Tomorrow"
        } else {
            return "\(days) days"
        }
    }
    
    private let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()
    
    init(viewModel: TasksViewModel, task: TodoItem?) {
        self.viewModel = viewModel
        self.task = task
        
        // Initialize state from task or defaults
        _title = State(initialValue: task?.title ?? "")
        _priority = State(initialValue: task?.priority ?? TodoItem.Priority.medium.rawValue)
        _category = State(initialValue: task?.category ?? EventCategory.work.rawValue)
        _taskDescription = State(initialValue: "") // Will add to model later
        _hasDueDate = State(initialValue: task?.dueDate != nil)
        _dueDate = State(initialValue: task?.dueDate ?? Date())
        _isRecurring = State(initialValue: task?.isRecurring ?? false)
        _recurrencePattern = State(initialValue: .daily)
        _hasNotification = State(initialValue: false)
        _notificationTime = State(initialValue: Date())
        _showInCalendar = State(initialValue: false)
        _subtasks = State(initialValue: [])
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Enhanced Header with Gradient
            HStack {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        dismiss()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                        Text("Cancel")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                VStack(spacing: 2) {
                    Text("Task Details")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if task == nil {
                        Text("Create a new task")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Edit existing task")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        saveTask()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: task == nil ? "plus" : "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                        Text(task == nil ? "Create" : "Save")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: title.isEmpty ? [.gray, .gray] : [.cnPrimary, .cnAccent]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .scaleEffect(title.isEmpty ? 0.95 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(title.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    gradient: Gradient(colors: {
                        #if os(macOS)
                        return [Color(NSColor.controlBackgroundColor), Color(NSColor.controlBackgroundColor).opacity(0.8)]
                        #else
                        return [Color(UIColor.systemBackground), Color(UIColor.systemBackground).opacity(0.8)]
                        #endif
                    }()),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .overlay(
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 0.5),
                alignment: .bottom
            )
            
            // Content
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Basic Information
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.cnPrimary)
                                .font(.title3)
                            Text("Task Details")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Title")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if !title.isEmpty {
                                        Text("\(title.count) characters")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                TextField("Enter task title", text: $title)
                                    .textFieldStyle(.plain)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(systemBackgroundColor)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(title.isEmpty ? Color.gray.opacity(0.3) : Color.cnPrimary.opacity(0.5), lineWidth: 1)
                                            )
                                    )
                                    #if os(iOS)
                                    .autocapitalization(.sentences)
                                    #endif
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Priority Level")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                PrioritySelector(selectedPriority: $priority)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Category")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Picker("Category", selection: $category) {
                                    ForEach(EventCategory.allCases, id: \.rawValue) { cat in
                                        Label(cat.rawValue, systemImage: cat.icon)
                                            .tag(cat.rawValue)
                                    }
                                }
                                .pickerStyle(.menu)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(systemBackgroundColor)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(controlBackgroundColor)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                    )
                
                    // MARK: - Description
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.cnPrimary)
                                .font(.title3)
                            Text("Description")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Additional Notes")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if !taskDescription.isEmpty {
                                    Text("\(taskDescription.count) characters")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            TextEditor(text: $taskDescription)
                                .frame(minHeight: 80)
                                .padding(12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(systemBackgroundColor)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(taskDescription.isEmpty ? Color.gray.opacity(0.3) : Color.cnPrimary.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                #if os(iOS)
                                .autocapitalization(.sentences)
                                #endif
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(controlBackgroundColor)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                    )
                
                    // MARK: - Due Date
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundColor(.cnPrimary)
                                .font(.title3)
                            Text("Schedule")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Toggle("Set Due Date", isOn: $hasDueDate)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                if hasDueDate {
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock")
                                            .font(.caption)
                                        Text("Due in \(daysUntilDue)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            if hasDueDate {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Due Date & Time")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    DatePicker(
                                        "Date & Time",
                                        selection: $dueDate,
                                        displayedComponents: [.date, .hourAndMinute]
                                    )
                                    .datePickerStyle(.compact)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(systemBackgroundColor)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.cnPrimary.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(controlBackgroundColor)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                    )
                
                    // MARK: - Recurring Task
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "repeat.circle.fill")
                                .foregroundColor(.cnPrimary)
                                .font(.title3)
                            Text("Recurrence")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Toggle("Repeat Task", isOn: $isRecurring)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                if isRecurring {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.clockwise")
                                            .font(.caption)
                                        Text(recurrencePattern.rawValue)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            if isRecurring {
                                Button(action: { 
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showingRecurrenceOptions = true 
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "calendar.badge.clock")
                                            .foregroundColor(.cnPrimary)
                                            .font(.subheadline)
                                        
                                        Text("Pattern")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        Text(recurrencePattern.rawValue)
                                            .foregroundColor(.secondary)
                                            .font(.subheadline)
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(systemBackgroundColor)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.cnPrimary.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(controlBackgroundColor)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                    )
                
                    // MARK: - Notifications
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundColor(.cnPrimary)
                                .font(.title3)
                            Text("Notifications")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Toggle("Remind Me", isOn: $hasNotification)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                if hasNotification {
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock.badge")
                                            .font(.caption)
                                        Text(notificationTime, formatter: timeFormatter)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            if hasNotification {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Reminder Time")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    DatePicker(
                                        "Notification Time",
                                        selection: $notificationTime,
                                        displayedComponents: [.hourAndMinute]
                                    )
                                    .datePickerStyle(.compact)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(systemBackgroundColor)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.cnPrimary.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(controlBackgroundColor)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                    )
                
                    // MARK: - Calendar Integration
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                                .foregroundColor(.cnPrimary)
                                .font(.title3)
                            Text("Calendar")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Toggle("Show in Calendar", isOn: $showInCalendar)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                Spacer()
                                
                                if showInCalendar {
                                    HStack(spacing: 4) {
                                        Image(systemName: "calendar")
                                            .font(.caption)
                                        Text(linkedCalendarEvent != nil ? "Linked" : "Not Linked")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            
                            if showInCalendar {
                                Button(action: { 
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showingEventPicker = true 
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "link")
                                            .foregroundColor(.cnPrimary)
                                            .font(.subheadline)
                                        
                                        Text("Link to Event")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.primary)
                                        
                                        Spacer()
                                        
                                        if linkedCalendarEvent != nil {
                                            HStack(spacing: 4) {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.cnStatusSuccess)
                                                    .font(.caption)
                                                Text("Linked")
                                                    .foregroundColor(.cnStatusSuccess)
                                                    .font(.caption)
                                            }
                                        } else {
                                            Text("None")
                                                .foregroundColor(.secondary)
                                                .font(.subheadline)
                                        }
                                        
                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .fill(systemBackgroundColor)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .stroke(Color.cnPrimary.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                                .buttonStyle(.plain)
                                .transition(.asymmetric(
                                    insertion: .scale.combined(with: .opacity),
                                    removal: .scale.combined(with: .opacity)
                                ))
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(controlBackgroundColor)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                    )
                
                    // MARK: - Subtasks
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "list.bullet.below.rectangle")
                                .foregroundColor(.cnPrimary)
                                .font(.title3)
                            Text("Subtasks")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if !subtasks.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle")
                                        .font(.caption)
                                    Text("\(subtasks.filter { $0.isCompleted }.count)/\(subtasks.count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            if !subtasks.isEmpty {
                                VStack(spacing: 8) {
                                    ForEach(subtasks) { subtask in
                                        HStack(spacing: 12) {
                                            Button(action: {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                                    toggleSubtask(subtask)
                                                }
                                            }) {
                                                Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                                    .foregroundColor(subtask.isCompleted ? .cnStatusSuccess : .secondary)
                                                    .font(.title3)
                                            }
                                            .buttonStyle(.plain)
                                            
                                            Text(subtask.title)
                                                .strikethrough(subtask.isCompleted)
                                                .foregroundColor(subtask.isCompleted ? .secondary : .primary)
                                                .font(.subheadline)
                                            
                                            Spacer()
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(systemBackgroundColor)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(subtask.isCompleted ? Color.green.opacity(0.3) : Color.gray.opacity(0.2), lineWidth: 1)
                                                )
                                        )
                                    }
                                    .onDelete { indexSet in
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            subtasks.remove(atOffsets: indexSet)
                                        }
                                    }
                                }
                            }
                            
                            // Add Subtask Field
                            HStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(.cnPrimary)
                                    .font(.title3)
                                
                                TextField("Add subtask", text: $newSubtaskTitle)
                                    .focused($isAddingSubtask)
                                    .onSubmit {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            addSubtask()
                                        }
                                    }
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(NSColor.textBackgroundColor))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(isAddingSubtask ? Color.cnPrimary.opacity(0.5) : Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(controlBackgroundColor)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                    )
                
                    // MARK: - Delete Button
                    if task != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.red)
                                    .font(.title3)
                                Text("Danger Zone")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                    .foregroundColor(.red)
                            }
                            
                            Button(role: .destructive, action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    deleteTask()
                                }
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "trash.fill")
                                        .font(.title3)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Delete Task")
                                            .font(.subheadline)
                                            .fontWeight(.semibold)
                                        
                                        Text("This action cannot be undone")
                                            .font(.caption)
                                            .opacity(0.8)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(Color.red.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10)
                                                .stroke(Color.red.opacity(0.3), lineWidth: 1)
                                        )
                                )
                                .foregroundColor(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.red.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.red.opacity(0.2), lineWidth: 1)
                                )
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .sheet(isPresented: $showingRecurrenceOptions) {
                RecurrencePatternPicker(selectedPattern: $recurrencePattern)
            }
            .sheet(isPresented: $showingEventPicker) {
                CalendarEventPicker(selectedEvent: $linkedCalendarEvent)
            }
        }
        .frame(maxWidth: 600, maxHeight: 700)
    }
    
    // MARK: - Actions
    
    private func addSubtask() {
        guard !newSubtaskTitle.isEmpty else { return }
        
        let subtask = Subtask(title: newSubtaskTitle)
        subtasks.append(subtask)
        newSubtaskTitle = ""
    }
    
    private func toggleSubtask(_ subtask: Subtask) {
        if let index = subtasks.firstIndex(where: { $0.id == subtask.id }) {
            subtasks[index].isCompleted.toggle()
        }
    }
    
    private func saveTask() {
        if let task = task {
            // Edit existing task
            task.title = title
            task.priority = priority
            task.category = category
            task.dueDate = hasDueDate ? dueDate : nil
            task.isRecurring = isRecurring
            
            do {
                try viewModel.coreDataService.save()
                viewModel.loadTasks()
            } catch {
                print("Error saving task: \(error)")
            }
        } else {
            // Create new task
            viewModel.addTask(
                title: title,
                priority: priority,
                category: category,
                dueDate: hasDueDate ? dueDate : nil
            )
        }
    }
    
    private func deleteTask() {
        if let task = task {
            viewModel.deleteTask(task)
            dismiss()
        }
    }
}

// MARK: - Priority Selector

struct PrioritySelector: View {
    @Binding var selectedPriority: String
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(TodoItem.Priority.allCases, id: \.rawValue) { priority in
                PriorityButton(
                    priority: priority,
                    isSelected: selectedPriority == priority.rawValue,
                    action: {
                        selectedPriority = priority.rawValue
                    }
                )
            }
        }
    }
}

struct PriorityButton: View {
    let priority: TodoItem.Priority
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: "flag.fill")
                    .font(.title3)
                
                Text(priority.rawValue)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(isSelected ? priorityColor.opacity(0.2) : Color.clear)
            .foregroundColor(isSelected ? priorityColor : .secondary)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? priorityColor : Color.secondary.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(8)
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

// MARK: - Recurrence Pattern

enum RecurrencePattern: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Every 2 Weeks"
    case monthly = "Monthly"
    case yearly = "Yearly"
    case weekdays = "Weekdays Only"
    case custom = "Custom"
    
    var icon: String {
        switch self {
        case .daily: return "sun.max"
        case .weekly: return "calendar"
        case .biweekly: return "calendar.badge.clock"
        case .monthly: return "calendar.circle"
        case .yearly: return "calendar.badge.plus"
        case .weekdays: return "briefcase"
        case .custom: return "gearshape"
        }
    }
}

struct RecurrencePatternPicker: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedPattern: RecurrencePattern
    
    var body: some View {
        NavigationView {
            List {
                ForEach(RecurrencePattern.allCases, id: \.self) { pattern in
                    Button(action: {
                        selectedPattern = pattern
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: pattern.icon)
                                .foregroundColor(.cnPrimary)
                                .frame(width: 30)
                            
                            Text(pattern.rawValue)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedPattern == pattern {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.cnPrimary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Repeat Pattern")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Calendar Event Picker

struct CalendarEventPicker: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedEvent: CalendarEvent?
    @StateObject private var viewModel = CalendarViewModel()
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(action: {
                        selectedEvent = nil
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                                .foregroundColor(.secondary)
                            Text("No Event")
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedEvent == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.cnPrimary)
                            }
                        }
                    }
                }
                
                Section("Upcoming Events") {
                    ForEach(viewModel.upcomingEvents, id: \.id) { event in
                        Button(action: {
                            selectedEvent = event
                            dismiss()
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(event.title ?? "Untitled")
                                        .foregroundColor(.primary)
                                    
                                    Text(event.startDate?.formatted() ?? "")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if selectedEvent?.id == event.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.cnPrimary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Link to Event")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Subtask Model

struct Subtask: Identifiable {
    let id = UUID()
    var title: String
    var isCompleted: Bool = false
}

// MARK: - Preview

#Preview {
    EnhancedTaskEditorView(viewModel: TasksViewModel(), task: nil)
}

