//
//  BookmarkOnboardingModels.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation

struct BookmarkOnboardingStep: Identifiable, Codable, Hashable {
    enum StepType: String, Codable {
        case welcome
        case featureHighlight
        case importPrompt
        case defaultCollection
        case extensionGuide
    }

    let id: UUID
    var title: String
    var description: String
    var iconSystemName: String
    var stepType: StepType
    var action: BookmarkOnboardingAction?

    init(id: UUID = UUID(), title: String, description: String, iconSystemName: String, stepType: StepType, action: BookmarkOnboardingAction? = nil) {
        self.id = id
        self.title = title
        self.description = description
        self.iconSystemName = iconSystemName
        self.stepType = stepType
        self.action = action
    }

    static func defaultSteps() -> [BookmarkOnboardingStep] {
        [
            BookmarkOnboardingStep(
                title: "Welcome to Bookmarks",
                description: "Save, organize, and revisit web content across CalendarNotes.",
                iconSystemName: "bookmark.fill",
                stepType: .welcome
            ),
            BookmarkOnboardingStep(
                title: "Collections & Tags",
                description: "Group bookmarks by project or topic and discover them faster with tags.",
                iconSystemName: "square.grid.2x2.fill",
                stepType: .featureHighlight
            ),
            BookmarkOnboardingStep(
                title: "Import Existing Bookmarks",
                description: "Bring in bookmarks from Safari, Chrome, Firefox, or Pocket.",
                iconSystemName: "square.and.arrow.down",
                stepType: .importPrompt,
                action: .openImport
            ),
            BookmarkOnboardingStep(
                title: "Default Collection",
                description: "Create a default collection to keep new bookmarks organized.",
                iconSystemName: "folder.fill",
                stepType: .defaultCollection,
                action: .createDefaultCollection
            ),
            BookmarkOnboardingStep(
                title: "Install Browser Extension",
                description: "Save bookmarks from Safari with one click using our extension.",
                iconSystemName: "safari",
                stepType: .extensionGuide,
                action: .openExtensionGuide
            )
        ]
    }
}

enum BookmarkOnboardingAction: String, Codable {
    case openImport
    case createDefaultCollection
    case openExtensionGuide
}
