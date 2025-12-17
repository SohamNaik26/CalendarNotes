//
//  BookmarkTemplate.swift
//  CalendarNotes
//
//  Created by Cursor AI on 09/11/25.
//

import Foundation

/// Describes a reusable bookmark template that can prefill fields when creating a bookmark.
struct BookmarkTemplate: Identifiable, Codable, Hashable {
    struct CustomField: Identifiable, Codable, Hashable {
        enum FieldType: String, Codable, CaseIterable {
            case text
            case longText
            case toggle
            case number
            case date
            case url
        }

        var id: UUID
        var key: String
        var label: String
        var type: FieldType
        var placeholder: String?
        var defaultValue: String?

        init(
            id: UUID = UUID(),
            key: String,
            label: String,
            type: FieldType,
            placeholder: String? = nil,
            defaultValue: String? = nil
        ) {
            self.id = id
            self.key = key
            self.label = label
            self.type = type
            self.placeholder = placeholder
            self.defaultValue = defaultValue
        }
    }

    var id: UUID
    var name: String
    var shortDescription: String
    var placeholderURL: String
    var defaultTitle: String?
    var defaultCollection: String?
    var defaultTags: [String]
    var noteTemplate: String
    var customFields: [CustomField]
    var systemImageName: String
    var isSystemTemplate: Bool

    init(
        id: UUID = UUID(),
        name: String,
        shortDescription: String,
        placeholderURL: String,
        defaultTitle: String? = nil,
        defaultCollection: String? = nil,
        defaultTags: [String] = [],
        noteTemplate: String = "",
        customFields: [CustomField] = [],
        systemImageName: String = "bookmark",
        isSystemTemplate: Bool = false
    ) {
        self.id = id
        self.name = name
        self.shortDescription = shortDescription
        self.placeholderURL = placeholderURL
        self.defaultTitle = defaultTitle
        self.defaultCollection = defaultCollection
        self.defaultTags = defaultTags
        self.noteTemplate = noteTemplate
        self.customFields = customFields
        self.systemImageName = systemImageName
        self.isSystemTemplate = isSystemTemplate
    }
}

extension BookmarkTemplate.CustomField {
    /// Returns the default value normalised to the field type.
    func resolvedDefaultValue() -> BookmarkTemplateFieldValue {
        BookmarkTemplateFieldValue.from(string: defaultValue, type: type)
    }
}

/// Value wrapper used when collecting template custom field answers.
enum BookmarkTemplateFieldValue: Hashable {
    case text(String)
    case toggle(Bool)
    case number(Double?)
    case date(Date?)
    case url(String)

    static func from(string: String?, type: BookmarkTemplate.CustomField.FieldType) -> BookmarkTemplateFieldValue {
        let cleaned = string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch type {
        case .text, .longText:
            return .text(cleaned)
        case .toggle:
            return .toggle((cleaned as NSString).boolValue)
        case .number:
            return .number(Double(cleaned))
        case .date:
            if let iso = ISO8601DateFormatter().date(from: cleaned) {
                return .date(iso)
            }
            return .date(nil)
        case .url:
            return .url(cleaned)
        }
    }

    func stringValue() -> String {
        switch self {
        case .text(let string):
            return string
        case .toggle(let flag):
            return flag ? "true" : "false"
        case .number(let number):
            if let number {
                return String(number)
            }
            return ""
        case .date(let date):
            if let date {
                return ISO8601DateFormatter().string(from: date)
            }
            return ""
        case .url(let url):
            return url
        }
    }
}


