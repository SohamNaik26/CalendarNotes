//
//  TasksListView.swift
//  CalendarNotes
//
//  Tasks view with sections and checkboxes
//

import SwiftUI
import CoreData

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct TasksListView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(
        sortDescriptors: [
            NSSortDescriptor(keyPath: \TodoItem.dueDate, ascending: true),
            NSSortDescriptor(keyPath: \TodoItem.title, ascending: true)
        ],
        animation: .default
    ) private var tasks: FetchedResults<TodoItem>
    @State private var searchText: String = ""
    
    var filteredTasks: [TodoItem] {
        if searchText.isEmpty {
            return Array(tasks)
        } else {
            return tasks.filter { task in
                let title = task.title ?? ""
                return title.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var groupedBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
        #else
        return Color(UIColor.systemGroupedBackground)
        #endif
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // "Tasks" title (34pt, bold) - improved spacing
            Text("Tasks")
                .font(.system(size: 34, weight: .bold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 4)
            
            // Search bar with placeholder "Search tasks..."
            SearchBar(text: $searchText, placeholder: "Search tasks...")
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 4)
            
            // Empty state or task list
            if filteredTasks.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    message: "No tasks"
                )
                .padding(.top, 60)
            } else {
                List {
                    ForEach(filteredTasks, id: \.objectID) { task in
                        TaskRow(task: task)
                            .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                            .listRowBackground(Color.clear)
                    }
                }
                #if os(macOS)
                .listStyle(.inset)
                #else
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                #endif
                .padding(.top, 8)
                .padding(.bottom, 100)
            }
        }
        .background(groupedBackgroundColor)
        .ignoresSafeArea(.all, edges: [.top, .bottom])
    }
}

// MARK: - Task Row Component

struct TaskRow: View {
    @ObservedObject var task: TodoItem
    @Environment(\.managedObjectContext) private var viewContext
    
    // Color for checkbox border - alternate between red and orange
    private var checkboxColor: Color {
        let hash = task.objectID.hashValue
        return hash % 2 == 0 ? Color.red : Color.orange
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // Square checkbox (24pt) with colored border
            Button(action: {
                withAnimation(.spring(response: 0.3)) {
                    task.isCompleted.toggle()
                    try? viewContext.save()
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .strokeBorder(checkboxColor, lineWidth: 2.5)
                        .frame(width: 24, height: 24)
                    
                    if task.isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(checkboxColor)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            .buttonStyle(.plain)
            
            // Task title and due date
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title ?? "Untitled Task")
                    .font(.system(size: 16, weight: task.isCompleted ? .medium : .semibold))
                    .foregroundColor(task.isCompleted ? .secondary : .primary)
                    .strikethrough(task.isCompleted)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                
                // Due date text
                if let dueDate = task.dueDate, !task.isCompleted {
                    Text(dueText(for: dueDate))
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .background(Color(white: 0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            // Swipe to delete
            Button(role: .destructive) {
                deleteTask()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
    
    private func dueText(for date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDate(date, inSameDayAs: now) {
            return "Due today"
        } else if calendar.isDateInTomorrow(date) {
            return "Due tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "Due \(formatter.string(from: date))"
        }
    }
    
    private func isOverdue(_ date: Date) -> Bool {
        date < Date()
    }
    
    private func deleteTask() {
        viewContext.delete(task)
        try? viewContext.save()
    }
}

#Preview {
    TasksListView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
