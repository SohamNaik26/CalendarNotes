//
//  EnhancedSwipeActions.swift
//  CalendarNotes
//
//  Enhanced swipe actions with smooth reveal animations
//

import SwiftUI
import CoreData

// MARK: - Swipe Action Container

struct SwipeActionContainer<Content: View>: View {
    let content: Content
    let leadingActions: [SwipeAction]
    let trailingActions: [SwipeAction]
    
    @State private var dragOffset: CGFloat = 0
    @State private var isRevealed = false
    @State private var actionWidth: CGFloat = 0
    
    init(
        @ViewBuilder content: () -> Content,
        leading: [SwipeAction] = [],
        trailing: [SwipeAction] = []
    ) {
        self.content = content()
        self.leadingActions = leading
        self.trailingActions = trailing
    }
    
    var body: some View {
        ZStack(alignment: .leading) {
            // Background Actions
            HStack(spacing: 0) {
                // Leading Actions
                if !leadingActions.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(Array(leadingActions.enumerated()), id: \.offset) { index, action in
                            SwipeActionButton(action: action) {
                                performAction(action)
                            }
                            .frame(width: 80)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
                
                // Trailing Actions
                if !trailingActions.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(Array(trailingActions.enumerated()), id: \.offset) { index, action in
                            SwipeActionButton(action: action) {
                                performAction(action)
                            }
                            .frame(width: 80)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .opacity(isRevealed ? 1 : 0)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isRevealed)
            
            // Main Content
            content
                .offset(x: dragOffset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            let translation = value.translation.width
                            
                            if translation > 0 && !leadingActions.isEmpty {
                                // Swiping right (leading actions)
                                dragOffset = min(translation, CGFloat(leadingActions.count) * 80)
                            } else if translation < 0 && !trailingActions.isEmpty {
                                // Swiping left (trailing actions)
                                dragOffset = max(translation, -CGFloat(trailingActions.count) * 80)
                            }
                        }
                        .onEnded { value in
                            let translation = value.translation.width
                            
                            if abs(translation) > 40 {
                                // Reveal actions
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    if translation > 0 && !leadingActions.isEmpty {
                                        dragOffset = CGFloat(leadingActions.count) * 80
                                        isRevealed = true
                                    } else if translation < 0 && !trailingActions.isEmpty {
                                        dragOffset = -CGFloat(trailingActions.count) * 80
                                        isRevealed = true
                                    }
                                }
                                
                                HapticFeedback.swipeAction()
                            } else {
                                // Reset position
                                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                    dragOffset = 0
                                    isRevealed = false
                                }
                            }
                        }
                )
        }
        .clipped()
    }
    
    private func performAction(_ action: SwipeAction) {
        HapticFeedback.medium.trigger()
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            action.action()
            dragOffset = 0
            isRevealed = false
        }
    }
}

// MARK: - Swipe Action Model

struct SwipeAction {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    init(icon: String, title: String, color: Color, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.color = color
        self.action = action
    }
}

// MARK: - Swipe Action Button

struct SwipeActionButton: View {
    let action: SwipeAction
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: action.icon)
                    .font(.title2)
                    .foregroundColor(.white)
                
                Text(action.title)
                    .font(.caption)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(action.color)
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
        }
        .buttonStyle(.plain)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                    isPressed = false
                }
            }
        }
    }
}

// MARK: - Enhanced Task Row with Swipe Actions

struct SwipeableTaskRow: View {
    let task: TodoItem
    @ObservedObject var viewModel: TasksViewModel
    @State private var isCompleting = false
    @State private var showConfetti = false
    
    var body: some View {
        SwipeActionContainer(
            content: {
                HStack(spacing: 12) {
                    // Checkbox
                    Button(action: {
                        performHapticFeedback()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                            isCompleting = true
                        }
                        
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            viewModel.toggleTaskCompletion(task)
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
                    }
                    .buttonStyle(.plain)
                    
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
                .contentShape(Rectangle())
                .opacity(task.isCompleted ? 0.6 : 1.0)
                .overlay(
                    Group {
                        if showConfetti {
                            ConfettiView()
                                .allowsHitTesting(false)
                        }
                    }
                )
                .animatedListItem()
            },
            leading: [
                SwipeAction(
                    icon: "arrow.uturn.backward",
                    title: "Undo",
                    color: .cnStatusWarning
                ) {
                    viewModel.toggleTaskCompletion(task)
                }
            ],
            trailing: [
                SwipeAction(
                    icon: "checkmark",
                    title: "Complete",
                    color: .cnStatusSuccess
                ) {
                    viewModel.toggleTaskCompletion(task)
                },
                SwipeAction(
                    icon: "trash",
                    title: "Delete",
                    color: .cnStatusError
                ) {
                    viewModel.deleteTask(task)
                }
            ]
        )
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

// MARK: - Swipeable Event Row

struct SwipeableEventRow: View {
    let event: CalendarEvent
    @ObservedObject var viewModel: CalendarViewModel
    
    var body: some View {
        SwipeActionContainer(
            content: {
                HStack(spacing: 12) {
                    // Time
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timeFormatter.string(from: event.startDate ?? Date()))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.cnPrimary)
                        
                        if let endDate = event.endDate {
                            Text(timeFormatter.string(from: endDate))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Event Details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.title ?? "Untitled Event")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        if let location = event.location, !location.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "location")
                                    .font(.caption2)
                                Text(location)
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    // Category Indicator
                    Circle()
                        .fill(categoryColor(event.category ?? "Other"))
                        .frame(width: 12, height: 12)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.cnBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(categoryColor(event.category ?? "Other"), lineWidth: 2)
                        )
                )
                .animatedListItem()
            },
            leading: [
                SwipeAction(
                    icon: "pencil",
                    title: "Edit",
                    color: .cnPrimary
                ) {
                    // Edit event logic
                }
            ],
            trailing: [
                SwipeAction(
                    icon: "trash",
                    title: "Delete",
                    color: .cnStatusError
                ) {
                    // Delete event logic
                }
            ]
        )
    }
    
    private func categoryColor(_ category: String) -> Color {
        switch category {
        case "Work": return .cnCategoryWork
        case "Personal": return .cnCategoryPersonal
        case "Health": return .cnCategoryHealth
        case "Education": return .cnCategoryEducation
        default: return .cnCategoryOther
        }
    }
}

// MARK: - Swipeable Note Row

struct SwipeableNoteRow: View {
    let note: Note
    @ObservedObject var viewModel: NotesViewModel
    
    var body: some View {
        SwipeActionContainer(
            content: {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(note.content ?? "")
                            .font(.body)
                            .lineLimit(3)
                            .foregroundColor(.primary)
                        
                        Spacer()
                    }
                    
                    HStack {
                        Text(note.createdDate?.formatted(date: .abbreviated, time: .shortened) ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let tags = note.tags, !tags.isEmpty {
                            Text(tags)
                                .font(.caption)
                                .foregroundColor(.cnPrimary)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.cnPrimary.opacity(0.1))
                                )
                        }
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.cnBackground)
                )
                .animatedListItem()
            },
            leading: [
                SwipeAction(
                    icon: "pencil",
                    title: "Edit",
                    color: .cnPrimary
                ) {
                    // Edit note logic
                }
            ],
            trailing: [
                SwipeAction(
                    icon: "trash",
                    title: "Delete",
                    color: .cnStatusError
                ) {
                    // Delete note logic
                }
            ]
        )
    }
}

// MARK: - Date Formatters

private let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "h:mm a"
    return formatter
}()

#Preview {
    SwipeableTaskRow(
        task: TodoItem(),
        viewModel: TasksViewModel()
    )
}
