//
//  TaskEditorView.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//
//  Legacy wrapper - uses EnhancedTaskEditorView for full functionality

import SwiftUI

struct TaskEditorView: View {
    @ObservedObject var viewModel: TasksViewModel
    let task: TodoItem?
    
    var body: some View {
        EnhancedTaskEditorView(viewModel: viewModel, task: task)
    }
}

#Preview {
    TaskEditorView(viewModel: TasksViewModel(), task: nil)
}

