//
//  QuickAddPresetStore.swift
//  CalendarNotes
//
//  Created by Cursor AI on 09/11/25.
//

import Foundation
import Combine

struct QuickAddPreset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var collectionName: String?
    var tags: [String]
    var isFavorite: Bool
    var templateId: UUID?

    init(
        id: UUID = UUID(),
        name: String,
        collectionName: String?,
        tags: [String],
        isFavorite: Bool,
        templateId: UUID? = nil
    ) {
        self.id = id
        self.name = name
        self.collectionName = collectionName
        self.tags = tags
        self.isFavorite = isFavorite
        self.templateId = templateId
    }
}

@MainActor
final class QuickAddPresetStore: ObservableObject {
    typealias ObjectWillChangePublisher = ObservableObjectPublisher
    let objectWillChange = ObservableObjectPublisher()

    static let shared = QuickAddPresetStore()

    private let storageKey = "bookmark.quickAdd.presets"
    private let defaults: UserDefaults

    @Published private(set) var presets: [QuickAddPreset] = []

    private init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
        load()
    }

    func createPreset(
        name: String,
        collectionName: String?,
        tags: [String],
        isFavorite: Bool,
        templateId: UUID?
    ) {
        var preset = QuickAddPreset(
            name: name,
            collectionName: collectionName,
            tags: tags,
            isFavorite: isFavorite,
            templateId: templateId
        )
        if let templateId, let template = BookmarkTemplateService.shared.template(withId: templateId) {
            preset.templateId = template.id
        }
        presets.append(preset)
        persist()
        objectWillChange.send()
    }

    func delete(_ preset: QuickAddPreset) {
        presets.removeAll { $0.id == preset.id }
        persist()
        objectWillChange.send()
    }

    func preset(withId id: UUID) -> QuickAddPreset? {
        presets.first { $0.id == id }
    }

    func reset() {
        presets = []
        defaults.removeObject(forKey: storageKey)
        objectWillChange.send()
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else {
            presets = []
            return
        }
        if let decoded = try? JSONDecoder().decode([QuickAddPreset].self, from: data) {
            presets = decoded
        } else {
            presets = []
        }
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(presets) {
            defaults.set(data, forKey: storageKey)
        }
    }
}


