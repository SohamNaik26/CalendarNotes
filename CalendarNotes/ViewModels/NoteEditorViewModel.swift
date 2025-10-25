//
//  NoteEditorViewModel.swift
//  CalendarNotes
//
//  Created by Soham Mahesh Naik on 21/10/25.
//

import Foundation
import SwiftUI
import Combine
import Speech
#if os(iOS)
import UIKit
#endif

class NoteEditorViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var content: String = ""
    @Published var hasLinkedDate: Bool = false
    @Published var linkedDate: Date = Date()
    @Published var tagsText: String = ""
    @Published var showPreview: Bool = false
    @Published var lastSaved: Date?
    @Published var showVoiceRecordingPanel: Bool = false
    
    // Formatting States
    @Published var isBoldActive: Bool = false
    @Published var isItalicActive: Bool = false
    @Published var isBulletListActive: Bool = false
    @Published var isNumberedListActive: Bool = false
    
    // Undo/Redo
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
    
    // Speech Recognition Service
    let speechRecognitionService = SpeechRecognitionService()
    
    // MARK: - Computed Properties
    var characterCount: Int {
        content.count
    }
    
    var wordCount: Int {
        let words = content.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        return words.count
    }
    
    var parsedTags: [String] {
        tagsText
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { $0.hasPrefix("#") ? String($0.dropFirst()) : $0 }
    }
    
    var isEditing: Bool {
        existingNote != nil
    }
    
    var isRecording: Bool {
        speechRecognitionService.isRecording
    }
    
    // MARK: - Private Properties
    private var existingNote: Note?
    private let coreDataService: CoreDataService
    private var autoSaveTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // Undo/Redo Stack
    private var undoStack: [String] = []
    private var redoStack: [String] = []
    private var isUndoRedoOperation = false
    
    // MARK: - Initialization
    init(note: Note?, coreDataService: CoreDataService = CoreDataService()) {
        self.existingNote = note
        self.coreDataService = coreDataService
        
        if let note = note {
            self.content = note.content ?? ""
            self.hasLinkedDate = note.linkedDate != nil
            self.linkedDate = note.linkedDate ?? Date()
            self.tagsText = note.tags ?? ""
        }
        
        setupAutoSave()
    }
    
    // MARK: - Auto-Save
    private func setupAutoSave() {
        autoSaveTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            self?.autoSave()
        }
    }
    
    private func autoSave() {
        guard !content.isEmpty else { return }
        
        if isEditing {
            updateExistingNote()
        }
        
        lastSaved = Date()
    }
    
    // MARK: - Text Change Handling
    func handleTextChange() {
        if !isUndoRedoOperation {
            // Save current state to undo stack
            if !content.isEmpty && (undoStack.isEmpty || undoStack.last != content) {
                undoStack.append(content)
                if undoStack.count > 50 { // Limit stack size
                    undoStack.removeFirst()
                }
                redoStack.removeAll() // Clear redo stack on new change
            }
        }
        
        updateUndoRedoState()
        updateFormattingState()
    }
    
    private func updateUndoRedoState() {
        canUndo = undoStack.count > 1
        canRedo = !redoStack.isEmpty
    }
    
    private func updateFormattingState() {
        // Simple detection - can be enhanced
        isBoldActive = content.contains("**")
        isItalicActive = content.contains("*") && !content.contains("**")
        isBulletListActive = content.contains("- ") || content.contains("* ")
        isNumberedListActive = content.range(of: "\\d+\\. ", options: .regularExpression) != nil
    }
    
    // MARK: - Undo/Redo
    func undo() {
        guard canUndo, let _ = undoStack.popLast() else { return }
        
        redoStack.append(content)
        isUndoRedoOperation = true
        content = undoStack.last ?? ""
        isUndoRedoOperation = false
        
        updateUndoRedoState()
    }
    
    func redo() {
        guard canRedo, let nextState = redoStack.popLast() else { return }
        
        undoStack.append(content)
        isUndoRedoOperation = true
        content = nextState
        isUndoRedoOperation = false
        
        updateUndoRedoState()
    }
    
    // MARK: - Formatting Actions
    func toggleBold() {
        let selection = getSelectedText()
        if !selection.isEmpty {
            content = content.replacingOccurrences(of: selection, with: "**\(selection)**")
        } else {
            content += "**bold text**"
        }
    }
    
    func toggleItalic() {
        let selection = getSelectedText()
        if !selection.isEmpty {
            content = content.replacingOccurrences(of: selection, with: "*\(selection)*")
        } else {
            content += "*italic text*"
        }
    }
    
    func toggleBulletList() {
        let lines = content.components(separatedBy: .newlines)
        let newLines = lines.map { line -> String in
            if line.hasPrefix("- ") {
                return String(line.dropFirst(2))
            } else if !line.isEmpty {
                return "- \(line)"
            }
            return line
        }
        content = newLines.joined(separator: "\n")
    }
    
    func toggleNumberedList() {
        let lines = content.components(separatedBy: .newlines)
        var index = 1
        let newLines = lines.map { line -> String in
            if line.range(of: "^\\d+\\. ", options: .regularExpression) != nil {
                return line.replacingOccurrences(of: "^\\d+\\. ", with: "", options: .regularExpression)
            } else if !line.isEmpty {
                let numbered = "\(index). \(line)"
                index += 1
                return numbered
            }
            return line
        }
        content = newLines.joined(separator: "\n")
    }
    
    private func getSelectedText() -> String {
        // In a real implementation, you'd track cursor position
        // For now, return empty to append formatting at the end
        return ""
    }
    
    // MARK: - Tag Management
    func removeTag(_ tag: String) {
        let tags = parsedTags.filter { $0 != tag }
        tagsText = tags.joined(separator: ", ")
    }
    
    // MARK: - Save Note
    func saveNote() {
        if isEditing {
            updateExistingNote()
        } else {
            createNewNote()
        }
    }
    
    private func createNewNote() {
        do {
            try coreDataService.createNote(
                content: content,
                linkedDate: hasLinkedDate ? linkedDate : nil,
                tags: tagsText.isEmpty ? nil : tagsText
            )
        } catch {
            print("Error creating note: \(error)")
        }
    }
    
    private func updateExistingNote() {
        guard let note = existingNote else { return }
        
        note.content = content
        note.linkedDate = hasLinkedDate ? linkedDate : nil
        note.tags = tagsText.isEmpty ? nil : tagsText
        
        do {
            try coreDataService.save()
        } catch {
            print("Error updating note: \(error)")
        }
    }
    
    // MARK: - Share
    func shareNote() {
        #if os(iOS)
        let activityViewController = UIActivityViewController(
            activityItems: [content],
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            // Find the topmost view controller
            var topController = rootViewController
            while let presentedViewController = topController.presentedViewController {
                topController = presentedViewController
            }
            
            topController.present(activityViewController, animated: true)
        }
        #else
        // macOS sharing
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
        print("Note content copied to clipboard")
        #endif
    }
    
    // MARK: - Speech Recognition
    func requestSpeechAuthorization() {
        Task {
            let _ = await speechRecognitionService.requestAuthorization()
        }
    }
    
    func toggleVoiceRecording() {
        showVoiceRecordingPanel.toggle()
    }
    
    func appendTranscribedText(_ text: String) {
        if content.isEmpty {
            content = text
        } else {
            // Add space or newline depending on context
            if content.hasSuffix("\n") {
                content += text
            } else {
                content += " " + text
            }
        }
    }
    
    func startVoiceRecognition() {
        showVoiceRecordingPanel = true
    }
    
    // MARK: - Cleanup
    func cleanup() {
        autoSaveTimer?.invalidate()
        autoSaveTimer = nil
        speechRecognitionService.cleanup()
    }
    
    deinit {
        cleanup()
    }
}

