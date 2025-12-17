//
//  HighlightEditorView.swift
//  CalendarNotes
//
//  View for editing highlight notes and color
//

import SwiftUI
import CoreData

struct HighlightEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: HighlightAnnotationViewModel
    
    let highlight: Highlight
    
    @State private var noteText: String
    @State private var selectedColor: String
    @State private var showingColorPicker = false
    
    init(highlight: Highlight, viewModel: HighlightAnnotationViewModel) {
        self.highlight = highlight
        self.viewModel = viewModel
        _noteText = State(initialValue: highlight.note ?? "")
        _selectedColor = State(initialValue: highlight.color ?? HighlightColor.yellow.rawValue)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Highlighted Text Preview
                Section(header: Text("Highlighted Text")) {
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(highlightColor)
                            .frame(width: 4)
                        
                        Text(highlight.selectedText ?? "")
                            .font(.body)
                            .foregroundColor(.primary)
                    }
                }
                
                // Note Section
                Section(header: Text("Note")) {
                    TextEditor(text: $noteText)
                        .frame(minHeight: 100)
                }
                
                // Color Section
                Section(header: Text("Color")) {
                    Button {
                        showingColorPicker = true
                    } label: {
                        HStack {
                            Text("Highlight Color")
                            Spacer()
                            Circle()
                                .fill(colorFor(selectedColor))
                                .frame(width: 24, height: 24)
                        }
                    }
                }
                
                // Actions
                Section {
                    Button(role: .destructive) {
                        try? viewModel.deleteHighlight(highlight)
                        dismiss()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Delete Highlight")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Edit Highlight")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        try? viewModel.updateHighlight(highlight, note: noteText, color: selectedColor)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingColorPicker) {
                HighlightColorPickerView(selectedColor: $selectedColor)
            }
        }
    }
    
    private var highlightColor: Color {
        colorFor(selectedColor)
    }
    
    private func colorFor(_ hex: String) -> Color {
        Color.hex(hex) ?? HighlightColor.yellow.displayColor
    }
}

// MARK: - Highlight Color Picker View

struct HighlightColorPickerView: View {
    @Binding var selectedColor: String
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(HighlightColor.allCases) { color in
                    Button {
                        selectedColor = color.rawValue
                        dismiss()
                    } label: {
                        HStack {
                            Circle()
                                .fill(color.displayColor)
                                .frame(width: 32, height: 32)
                            
                            Text(color.name)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if selectedColor == color.rawValue {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Select Color")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

