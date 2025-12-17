//
//  HighlightMenuView.swift
//  CalendarNotes
//
//  Menu that appears when text is selected for highlighting
//

import SwiftUI

struct HighlightMenuView: View {
    let selectedText: String
    @Binding var selectedColor: String
    let onHighlight: (String) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Selected Text Preview
                VStack(alignment: .leading, spacing: 12) {
                    Text("Selected Text")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(selectedText)
                        .font(.body)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
                
                Divider()
                
                // Color Selection
                VStack(alignment: .leading, spacing: 12) {
                    Text("Choose Color")
                        .font(.headline)
                        .padding(.horizontal)
                        .padding(.top)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(HighlightColor.allCases) { color in
                            Button {
                                selectedColor = color.rawValue
                                onHighlight(color.rawValue)
                            } label: {
                                VStack(spacing: 8) {
                                    Circle()
                                        .fill(color.displayColor)
                                        .frame(width: 50, height: 50)
                                        .overlay(
                                            Circle()
                                                .stroke(selectedColor == color.rawValue ? Color.accentColor : Color.clear, lineWidth: 3)
                                        )
                                    
                                    Text(color.name)
                                        .font(.caption)
                                        .foregroundColor(.primary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
                
                Spacer()
            }
            .navigationTitle("Highlight Text")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
        }
    }
}

