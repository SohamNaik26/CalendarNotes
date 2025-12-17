//
//  ColorPickerView.swift
//  CalendarNotes
//
//  Color picker with 12 preset colors
//

import SwiftUI

struct ColorPickerView: View {
    @Binding var selectedColor: String
    @Environment(\.dismiss) private var dismiss
    
    // 12 preset colors
    private let presetColors: [ColorPreset] = [
        ColorPreset(name: "Red", hex: "#FF3B30"),
        ColorPreset(name: "Orange", hex: "#FF9500"),
        ColorPreset(name: "Yellow", hex: "#FFCC00"),
        ColorPreset(name: "Green", hex: "#34C759"),
        ColorPreset(name: "Mint", hex: "#00C7BE"),
        ColorPreset(name: "Teal", hex: "#30B0C7"),
        ColorPreset(name: "Cyan", hex: "#32ADE6"),
        ColorPreset(name: "Blue", hex: "#007AFF"),
        ColorPreset(name: "Indigo", hex: "#5856D6"),
        ColorPreset(name: "Purple", hex: "#AF52DE"),
        ColorPreset(name: "Pink", hex: "#FF2D92"),
        ColorPreset(name: "Brown", hex: "#A2845E")
    ]
    
    private let columns = [
        GridItem(.adaptive(minimum: 80), spacing: 16)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(presetColors) { preset in
                        ColorButton(
                            preset: preset,
                            isSelected: selectedColor == preset.hex,
                            action: {
                                selectedColor = preset.hex
                                dismiss()
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Color")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
}

// MARK: - Color Preset

struct ColorPreset: Identifiable {
    let id: String
    let name: String
    let hex: String
    
    init(name: String, hex: String) {
        self.name = name
        self.hex = hex
        self.id = hex
    }
}

// MARK: - Color Button

struct ColorButton: View {
    let preset: ColorPreset
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(Color.hex(preset.hex) ?? .gray)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(Color.primary.opacity(0.2), lineWidth: isSelected ? 3 : 1)
                    )
                    .overlay(
                        Group {
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .shadow(color: .black.opacity(0.3), radius: 2)
                            }
                        }
                    )
                
                Text(preset.name)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

