//
//  TagInputView.swift
//  CalendarNotes
//
//  Tag input field with autocomplete and suggestions
//

import SwiftUI
import CoreData

struct TagInputView: View {
    @Binding var selectedTags: [String]
    @Environment(\.managedObjectContext) private var context
    
    @State private var tagInput: String = ""
    @State private var suggestions: [String] = []
    @State private var showingSuggestions: Bool = false
    @State private var popularTags: [Tag] = []
    @State private var recentTags: [Tag] = []
    
    let placeholder: String
    let maxSuggestions: Int
    
    init(selectedTags: Binding<[String]>, placeholder: String = "Add tags...", maxSuggestions: Int = 5) {
        self._selectedTags = selectedTags
        self.placeholder = placeholder
        self.maxSuggestions = maxSuggestions
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Tag Input Field
            HStack {
                TextField(placeholder, text: $tagInput)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: tagInput) { oldValue, newValue in
                        updateSuggestions(for: newValue)
                    }
                    .onSubmit {
                        addTag()
                    }
                
                Button {
                    addTag()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                .disabled(tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            // Suggestions Dropdown
            if showingSuggestions && !suggestions.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions.prefix(maxSuggestions), id: \.self) { suggestion in
                            Button {
                                tagInput = suggestion
                                addTag()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "tag.fill")
                                        .font(.caption)
                                    Text(suggestion)
                                        .font(.caption)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.1))
                                .foregroundColor(.accentColor)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
            
            // Popular Tags
            if !popularTags.isEmpty && tagInput.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Popular Tags")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(popularTags.prefix(10)) { tag in
                                tagChip(for: tag)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            
            // Recent Tags
            if !recentTags.isEmpty && tagInput.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Recent Tags")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(recentTags.prefix(10)) { tag in
                                tagChip(for: tag)
                            }
                        }
                        .padding(.horizontal, 4)
                    }
                }
            }
            
            // Selected Tags
            if !selectedTags.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selected Tags")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
                        ForEach(selectedTags, id: \.self) { tag in
                            TagChip(
                                name: tag,
                                isSelected: true,
                                action: {
                                    removeTag(tag)
                                }
                            )
                        }
                    }
                }
            }
        }
        .onAppear {
            loadPopularAndRecentTags()
        }
    }
    
    // MARK: - Private Methods
    
    private func updateSuggestions(for input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            showingSuggestions = false
            suggestions = []
            return
        }
        
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "usageCount", ascending: false),
            NSSortDescriptor(key: "name", ascending: true)
        ]
        
        if let allTags = try? context.fetch(request) {
            suggestions = allTags
                .compactMap { $0.name }
                .filter { tag in
                    tag.localizedCaseInsensitiveContains(trimmed) &&
                    !selectedTags.contains(where: { $0.caseInsensitiveCompare(tag) == .orderedSame })
                }
            showingSuggestions = !suggestions.isEmpty
        }
    }
    
    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Check if tag already exists
        if !selectedTags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            selectedTags.append(trimmed)
            
            // Create tag if it doesn't exist
            let request: NSFetchRequest<Tag> = Tag.fetchRequest()
            request.predicate = NSPredicate(format: "name ==[cd] %@", trimmed)
            if (try? context.fetch(request).first) == nil {
                _ = Tag(context: context, name: trimmed)
                try? context.save()
            }
        }
        
        tagInput = ""
        showingSuggestions = false
        loadPopularAndRecentTags()
    }
    
    private func toggleTag(_ tag: String) {
        if let index = selectedTags.firstIndex(where: { $0.caseInsensitiveCompare(tag) == .orderedSame }) {
            selectedTags.remove(at: index)
        } else {
            selectedTags.append(tag)
        }
    }
    
    private func removeTag(_ tag: String) {
        selectedTags.removeAll { $0.caseInsensitiveCompare(tag) == .orderedSame }
    }
    
    private func loadPopularAndRecentTags() {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(key: "usageCount", ascending: false),
            NSSortDescriptor(key: "name", ascending: true)
        ]
        
        if let allTags = try? context.fetch(request) {
            popularTags = Array(allTags.prefix(10))
            
            // Recent tags (by creation date, could be enhanced)
            let recentRequest: NSFetchRequest<Tag> = Tag.fetchRequest()
            recentRequest.sortDescriptors = [NSSortDescriptor(key: "id", ascending: false)]
            recentRequest.fetchLimit = 10
            recentTags = (try? context.fetch(recentRequest)) ?? []
        }
    }
    
    private func tagChip(for tag: Tag) -> some View {
        let tagName = tag.name ?? ""
        let isSelected = selectedTags.contains(where: { $0.caseInsensitiveCompare(tagName) == .orderedSame })
        
        return TagChip(
            name: tagName,
            color: tag.color,
            isSelected: isSelected,
            action: {
                toggleTag(tagName)
            }
        )
    }
}

// MARK: - Tag Chip

struct TagChip: View {
    let name: String
    var color: String? = nil
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                } else {
                    Image(systemName: "tag.fill")
                        .font(.caption2)
                }
                
                Text(name)
                    .font(.caption)
                
                if isSelected {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        Color.hex(color ?? "#999999") ?? (isSelected ? Color.accentColor : Color.clear),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .foregroundColor(isSelected ? .accentColor : .primary)
        }
        .buttonStyle(.plain)
    }
}


