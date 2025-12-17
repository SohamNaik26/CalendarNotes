//
//  LayoutSettingsView.swift
//  CalendarNotes
//

import SwiftUI

struct LayoutSettingsView: View {
    @Binding var layoutMode: BookmarksViewModel.LayoutMode
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Layout").font(.headline)
            Picker("Layout", selection: $layoutMode) {
                Text("Grid").tag(BookmarksViewModel.LayoutMode.grid)
                Text("List").tag(BookmarksViewModel.LayoutMode.list)
            }
            .pickerStyle(.segmented)
        }
    }
}


