//
//  BookmarkTemplateService.swift
//  CalendarNotes
//
//  Created by Cursor AI on 09/11/25.
//

import Foundation
import Combine

@MainActor
final class BookmarkTemplateService: ObservableObject {
    typealias ObjectWillChangePublisher = ObservableObjectPublisher
    let objectWillChange = ObservableObjectPublisher()

    static let shared = BookmarkTemplateService()

    private let storageKey = "bookmark.templates.custom"
    private let defaults: UserDefaults

    @Published private(set) var customTemplates: [BookmarkTemplate] = []

    var templates: [BookmarkTemplate] {
        systemTemplates + customTemplates.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        loadCustomTemplates()
    }

    func template(withId id: UUID) -> BookmarkTemplate? {
        templates.first { $0.id == id }
    }

    func saveCustomTemplate(_ template: BookmarkTemplate) {
        if let index = customTemplates.firstIndex(where: { $0.id == template.id }) {
            customTemplates[index] = template
        } else {
            customTemplates.append(template)
        }
        persistCustomTemplates()
        objectWillChange.send()
    }

    func deleteCustomTemplate(_ template: BookmarkTemplate) {
        guard !template.isSystemTemplate else { return }
        customTemplates.removeAll { $0.id == template.id }
        persistCustomTemplates()
        objectWillChange.send()
    }

    func systemTemplate(for identifier: String) -> BookmarkTemplate? {
        systemTemplates.first { $0.name == identifier || $0.id.uuidString == identifier }
    }

    func createCustomTemplate(
        name: String,
        description: String = "",
        placeholderURL: String,
        defaultTitle: String? = nil,
        defaultCollection: String? = nil,
        defaultTags: [String] = [],
        noteTemplate: String = "",
        customFields: [BookmarkTemplate.CustomField] = [],
        systemImageName: String = "bookmark"
    ) -> BookmarkTemplate {
        let template = BookmarkTemplate(
            name: name,
            shortDescription: description,
            placeholderURL: placeholderURL,
            defaultTitle: defaultTitle,
            defaultCollection: defaultCollection,
            defaultTags: defaultTags,
            noteTemplate: noteTemplate,
            customFields: customFields,
            systemImageName: systemImageName,
            isSystemTemplate: false
        )
        saveCustomTemplate(template)
        return template
    }

    func resetCustomTemplates() {
        customTemplates = []
        defaults.removeObject(forKey: storageKey)
        objectWillChange.send()
    }

    // MARK: - Internal persistence

    private func loadCustomTemplates() {
        guard let data = defaults.data(forKey: storageKey) else {
            customTemplates = []
            return
        }
        if let decoded = try? JSONDecoder().decode([BookmarkTemplate].self, from: data) {
            customTemplates = decoded.filter { !$0.isSystemTemplate }
        } else {
            customTemplates = []
        }
    }

    private func persistCustomTemplates() {
        if let data = try? JSONEncoder().encode(customTemplates) {
            defaults.set(data, forKey: storageKey)
        }
    }

    // MARK: - System templates

    private var systemTemplates: [BookmarkTemplate] {
        [
            BookmarkTemplate(
                name: "Meeting Notes",
                shortDescription: "Prepare agenda, attendees, and action items",
                placeholderURL: "https://meet.company.com/meeting-id",
                defaultTitle: "Meeting with ...",
                defaultCollection: "Meetings",
                defaultTags: ["meeting", "notes", "team"],
                noteTemplate: """
                ## Agenda
                - Topic 1
                - Topic 2

                ## Notes
                -

                ## Action Items
                - [ ] Owner – Task – Due
                """,
                customFields: [
                    .init(key: "meetingDate", label: "Meeting Date", type: .date),
                    .init(key: "attendees", label: "Attendees", type: .longText, placeholder: "Jane, John, ..."),
                    .init(key: "followUp", label: "Follow up reminder", type: .toggle, defaultValue: "true")
                ],
                systemImageName: "person.3.sequence",
                isSystemTemplate: true
            ),
            BookmarkTemplate(
                name: "Article",
                shortDescription: "Capture key takeaways from an article",
                placeholderURL: "https://example.com/article",
                defaultTitle: "Article title",
                defaultCollection: "Read Later",
                defaultTags: ["article", "reading", "reference"],
                noteTemplate: """
                ## Summary
                -

                ## Key Points
                - Point 1
                - Point 2

                ## Follow-up
                -
                """,
                customFields: [
                    .init(key: "author", label: "Author", type: .text),
                    .init(key: "estimatedTime", label: "Estimated reading time (mins)", type: .number),
                    .init(key: "includeInDigest", label: "Include in reading digest", type: .toggle, defaultValue: "false")
                ],
                systemImageName: "doc.text",
                isSystemTemplate: true
            ),
            BookmarkTemplate(
                name: "Recipe",
                shortDescription: "Organise ingredients and cooking steps",
                placeholderURL: "https://example.com/recipe",
                defaultTitle: "Recipe name",
                defaultCollection: "Recipes",
                defaultTags: ["recipe", "cooking", "food"],
                noteTemplate: """
                ## Ingredients
                - Ingredient 1
                - Ingredient 2

                ## Instructions
                1.
                2.

                ## Notes
                -
                """,
                customFields: [
                    .init(key: "prepTime", label: "Prep time (mins)", type: .number),
                    .init(key: "cookTime", label: "Cook time (mins)", type: .number),
                    .init(key: "servings", label: "Servings", type: .number, defaultValue: "4"),
                    .init(key: "difficulty", label: "Difficulty", type: .text, placeholder: "Easy / Medium / Hard")
                ],
                systemImageName: "fork.knife",
                isSystemTemplate: true
            ),
            BookmarkTemplate(
                name: "Product",
                shortDescription: "Track product details for your wishlist",
                placeholderURL: "https://shop.example.com/product",
                defaultTitle: "Product name",
                defaultCollection: "Wishlist",
                defaultTags: ["product", "shopping", "wishlist"],
                noteTemplate: """
                ## Why I'm interested
                -

                ## Pros
                - Pro 1

                ## Cons
                - Con 1
                """,
                customFields: [
                    .init(key: "price", label: "Price", type: .number),
                    .init(key: "store", label: "Store", type: .text),
                    .init(key: "priority", label: "Priority", type: .text, placeholder: "High / Medium / Low"),
                    .init(key: "alreadyPurchased", label: "Purchased", type: .toggle, defaultValue: "false")
                ],
                systemImageName: "bag",
                isSystemTemplate: true
            ),
            BookmarkTemplate(
                name: "Place",
                shortDescription: "Save places to visit with helpful context",
                placeholderURL: "https://maps.apple.com/?address=...",
                defaultTitle: "Place name",
                defaultCollection: "Places",
                defaultTags: ["travel", "place", "visit"],
                noteTemplate: """
                ## Highlights
                -

                ## Tips
                -

                ## Logistics
                -
                """,
                customFields: [
                    .init(key: "locationName", label: "Location name", type: .text),
                    .init(key: "visitDate", label: "Target visit date", type: .date),
                    .init(key: "contact", label: "Contact / phone", type: .text),
                    .init(key: "bookmarkOnMap", label: "Add to offline map list", type: .toggle, defaultValue: "true")
                ],
                systemImageName: "mappin.and.ellipse",
                isSystemTemplate: true
            ),
            BookmarkTemplate(
                name: "Video",
                shortDescription: "Queue videos to watch with notes",
                placeholderURL: "https://youtube.com/watch?v=...",
                defaultTitle: "Video title",
                defaultCollection: "Watch Later",
                defaultTags: ["video", "watch", "media"],
                noteTemplate: """
                ## Summary
                -

                ## Key Moments
                - Timestamp — Note

                ## Actions
                -
                """,
                customFields: [
                    .init(key: "channel", label: "Channel / creator", type: .text),
                    .init(key: "duration", label: "Duration (mins)", type: .number),
                    .init(key: "transcribeHighlights", label: "Transcribe highlights", type: .toggle, defaultValue: "false")
                ],
                systemImageName: "play.rectangle",
                isSystemTemplate: true
            )
        ]
    }
}


