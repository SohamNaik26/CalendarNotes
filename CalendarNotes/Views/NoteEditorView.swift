//
//  NoteEditorView.swift
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
import Speech

struct NoteEditorView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: NoteEditorViewModel
    
    private var systemBackgroundColor: Color {
        #if os(macOS)
        return Color(NSColor.controlBackgroundColor)
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
    @FocusState private var isTextEditorFocused: Bool
    
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
                    Text("Note Details")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    if viewModel.isEditing {
                        Text("Edit existing note")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Create a new note")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.saveNote()
                        dismiss()
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.isEditing ? "checkmark" : "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text(viewModel.isEditing ? "Save" : "Create")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: viewModel.content.isEmpty ? [.gray, .gray] : [.cnPrimary, .cnAccent]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .scaleEffect(viewModel.content.isEmpty ? 0.95 : 1.0)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.content.isEmpty)
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
                    // MARK: - Note Content
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "doc.text.fill")
                                .foregroundColor(.cnPrimary)
                                .font(.title3)
                            Text("Note Content")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Write your note")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                if !viewModel.content.isEmpty {
                                    Text("\(viewModel.characterCount) characters")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            if viewModel.showPreview {
                                // Markdown Preview
                                ScrollView {
                                    MarkdownPreviewView(text: viewModel.content)
                                        .padding(12)
                                }
                                .frame(minHeight: 120)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(systemBackgroundColor)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.cnPrimary.opacity(0.3), lineWidth: 1)
                                        )
                                )
                            } else {
                                // Text Editor
                                ZStack(alignment: .topLeading) {
                                    TextEditor(text: $viewModel.content)
                                        .frame(minHeight: 120)
                                        .padding(12)
                                        .focused($isTextEditorFocused)
                                        .onChange(of: viewModel.content) { oldValue, newValue in
                                            viewModel.handleTextChange()
                                        }
                                        .background(Color.clear)
                                    
                                    // Placeholder text when content is empty
                                    if viewModel.content.isEmpty {
                                        Text("Start writing your note...")
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 16)
                                            .padding(.vertical, 12)
                                            .allowsHitTesting(false)
                                    }
                                }
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(systemBackgroundColor)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(viewModel.content.isEmpty ? Color.gray.opacity(0.3) : Color.cnPrimary.opacity(0.3), lineWidth: 1)
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
                    
                    // MARK: - Formatting Tools
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "textformat")
                                .foregroundColor(.cnPrimary)
                                .font(.title3)
                            Text("Formatting")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        FormattingToolbar(viewModel: viewModel)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(controlBackgroundColor)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                    )
                    
                    // MARK: - Voice Recording
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.cnPrimary)
                                .font(.title3)
                            Text("Voice Recording")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Button(action: { viewModel.toggleVoiceRecording() }) {
                                HStack {
                                    Image(systemName: viewModel.showVoiceRecordingPanel ? "waveform.slash" : "waveform")
                                        .foregroundColor(viewModel.isRecording ? .red : .cnPrimary)
                                    Text(viewModel.showVoiceRecordingPanel ? "Hide Recording" : "Voice Recording")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
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
                            
                            if viewModel.showVoiceRecordingPanel {
                                VoiceRecordingPanel(
                                    speechService: viewModel.speechRecognitionService,
                                    onTranscriptionUpdate: { text in
                                        viewModel.appendTranscribedText(text)
                                    }
                                )
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
                    
                    // MARK: - Note Options
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundColor(.cnPrimary)
                                .font(.title3)
                            Text("Note Options")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            // Date Picker Section
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.cnPrimary)
                                        .font(.title3)
                                    
                                    Toggle("Link to Date", isOn: $viewModel.hasLinkedDate)
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                                
                                if viewModel.hasLinkedDate {
                                    DatePicker("Select Date", selection: $viewModel.linkedDate, displayedComponents: .date)
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
                            }
                            
                            // Tags Input Section
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "tag")
                                        .foregroundColor(.cnPrimary)
                                        .font(.title3)
                                    
                                    Text("Tags")
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                }
                                
                                TextField("Enter tags separated by commas", text: $viewModel.tagsText)
                                    .textFieldStyle(.plain)
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
                                    #if os(iOS)
                                    .autocapitalization(.none)
                                    #endif
                                
                                if !viewModel.parsedTags.isEmpty {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 6) {
                                            ForEach(viewModel.parsedTags, id: \.self) { tag in
                                                TagChip(tag: tag) {
                                                    viewModel.removeTag(tag)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(controlBackgroundColor)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                    )
                    
                    // MARK: - Footer Stats
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "chart.bar")
                                .foregroundColor(.cnPrimary)
                                .font(.title3)
                            Text("Note Statistics")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Characters")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(viewModel.characterCount)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.cnPrimary)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Words")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(viewModel.wordCount)")
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.cnAccent)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Last Saved")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text(viewModel.lastSaved?.formatted(date: .abbreviated, time: .shortened) ?? "Never")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                }
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
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(controlBackgroundColor)
                            .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 1)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: 600, maxHeight: 700)
        .onAppear {
            viewModel.requestSpeechAuthorization()
        }
        .onDisappear {
            viewModel.cleanup()
        }
    }
}

// MARK: - Formatting Toolbar

struct FormattingToolbar: View {
    @ObservedObject var viewModel: NoteEditorViewModel
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                // Undo/Redo
                HStack(spacing: 8) {
                    ToolbarButton(icon: "arrow.uturn.backward", isEnabled: viewModel.canUndo) {
                        viewModel.undo()
                    }
                    
                    ToolbarButton(icon: "arrow.uturn.forward", isEnabled: viewModel.canRedo) {
                        viewModel.redo()
                    }
                }
                
                Divider()
                    .frame(height: 24)
                
                // Text Formatting
                ToolbarButton(icon: "bold", isActive: viewModel.isBoldActive) {
                    viewModel.toggleBold()
                }
                
                ToolbarButton(icon: "italic", isActive: viewModel.isItalicActive) {
                    viewModel.toggleItalic()
                }
                
                Divider()
                    .frame(height: 24)
                
                // Lists
                ToolbarButton(icon: "list.bullet", isActive: viewModel.isBulletListActive) {
                    viewModel.toggleBulletList()
                }
                
                ToolbarButton(icon: "list.number", isActive: viewModel.isNumberedListActive) {
                    viewModel.toggleNumberedList()
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        #if os(iOS)
        .background(Color(.systemGray6).opacity(0.5))
        #else
        .background(Color(.controlBackgroundColor))
        #endif
    }
}

struct ToolbarButton: View {
    let icon: String
    var isActive: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(buttonForegroundColor)
                .frame(width: 32, height: 32)
                .background(buttonBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(buttonStrokeColor, lineWidth: isActive ? 2 : 0)
                )
                .cornerRadius(8)
        }
        .disabled(!isEnabled)
    }
    
    private var buttonForegroundColor: Color {
        if !isEnabled {
            return .secondary
        }
        if isActive {
            return .cnPrimary
        }
        return .primary
    }
    
    private var buttonBackgroundColor: Color {
        if isActive {
            return Color.cnPrimary.opacity(0.2)
        }
        #if os(macOS)
        return colorScheme == .dark ? Color(white: 0.2) : Color(white: 0.95)
        #else
        return Color.clear
        #endif
    }
    
    private var buttonStrokeColor: Color {
        isActive ? .cnPrimary : .clear
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let tag: String
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text("#\(tag)")
                .font(.caption)
                .fontWeight(.medium)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .foregroundColor(.cnAccent)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.cnAccent.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Editor Footer

struct EditorFooter: View {
    let characterCount: Int
    let wordCount: Int
    let lastSaved: Date?
    
    var body: some View {
        HStack {
            Text("\(wordCount) words • \(characterCount) characters")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            if let lastSaved = lastSaved {
                Text("Saved \(lastSaved.timeAgo())")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        #if os(iOS)
        .background(Color(.systemGray6).opacity(0.3))
        #else
        .background(Color(.controlBackgroundColor))
        #endif
    }
}

// MARK: - Markdown Preview

struct MarkdownPreviewView: View {
    let text: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(parseMarkdown(text), id: \.id) { element in
                renderElement(element)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private func renderElement(_ element: MarkdownElement) -> some View {
        switch element.type {
        case .heading1:
            Text(element.content)
                .font(.title)
                .fontWeight(.bold)
        case .heading2:
            Text(element.content)
                .font(.title2)
                .fontWeight(.semibold)
        case .heading3:
            Text(element.content)
                .font(.title3)
                .fontWeight(.semibold)
        case .bold:
            Text(element.content)
                .fontWeight(.bold)
        case .italic:
            Text(element.content)
                .italic()
        case .bulletList:
            HStack(alignment: .top, spacing: 8) {
                Text("•")
                Text(element.content)
            }
            .padding(.leading, 8)
        case .numberedList:
            HStack(alignment: .top, spacing: 8) {
                Text("\(element.index ?? 1).")
                Text(element.content)
            }
            .padding(.leading, 8)
        case .normal:
            Text(element.content)
        }
    }
    
    private func parseMarkdown(_ text: String) -> [MarkdownElement] {
        var elements: [MarkdownElement] = []
        let lines = text.components(separatedBy: .newlines)
        var listIndex = 1
        
        for line in lines {
            if line.hasPrefix("# ") {
                elements.append(MarkdownElement(type: .heading1, content: String(line.dropFirst(2))))
            } else if line.hasPrefix("## ") {
                elements.append(MarkdownElement(type: .heading2, content: String(line.dropFirst(3))))
            } else if line.hasPrefix("### ") {
                elements.append(MarkdownElement(type: .heading3, content: String(line.dropFirst(4))))
            } else if line.hasPrefix("**") && line.hasSuffix("**") {
                let content = String(line.dropFirst(2).dropLast(2))
                elements.append(MarkdownElement(type: .bold, content: content))
            } else if line.hasPrefix("*") && line.hasSuffix("*") && !line.hasPrefix("**") {
                let content = String(line.dropFirst(1).dropLast(1))
                elements.append(MarkdownElement(type: .italic, content: content))
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
                elements.append(MarkdownElement(type: .bulletList, content: String(line.dropFirst(2))))
            } else if let firstChar = line.first, firstChar.isNumber, line.contains(". ") {
                let content = line.components(separatedBy: ". ").dropFirst().joined(separator: ". ")
                elements.append(MarkdownElement(type: .numberedList, content: content, index: listIndex))
                listIndex += 1
            } else if !line.isEmpty {
                elements.append(MarkdownElement(type: .normal, content: line))
                listIndex = 1
            }
        }
        
        return elements
    }
}

struct MarkdownElement: Identifiable {
    let id = UUID()
    let type: MarkdownType
    let content: String
    var index: Int?
}

enum MarkdownType {
    case heading1, heading2, heading3
    case bold, italic
    case bulletList, numberedList
    case normal
}

// MARK: - Date Extension

extension Date {
    func timeAgo() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }
}

#Preview {
    NoteEditorView(viewModel: NoteEditorViewModel(note: nil))
}


