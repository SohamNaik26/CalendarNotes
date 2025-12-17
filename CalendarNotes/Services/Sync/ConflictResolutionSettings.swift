//
//  ConflictResolutionSettings.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation
import Combine

public enum DefaultConflictStrategy: String, CaseIterable, Identifiable, Codable {
    case lastWriteWins
    case clientWins
    case serverWins
    case alwaysAsk
    
    public var id: String { rawValue }
}

public struct ConflictResolutionSettings: Codable {
    public var defaultStrategy: DefaultConflictStrategy
    public var autoResolveEntityTypes: Set<ConflictEntityType>
    public var alwaysAskEntityTypes: Set<ConflictEntityType>
    public var autoMergeEntityTypes: Set<ConflictEntityType>
    
    public init(
        defaultStrategy: DefaultConflictStrategy = .alwaysAsk,
        autoResolveEntityTypes: Set<ConflictEntityType> = [],
        alwaysAskEntityTypes: Set<ConflictEntityType> = [.event, .task],
        autoMergeEntityTypes: Set<ConflictEntityType> = [.collection, .bookmark]
    ) {
        self.defaultStrategy = defaultStrategy
        self.autoResolveEntityTypes = autoResolveEntityTypes
        self.alwaysAskEntityTypes = alwaysAskEntityTypes
        self.autoMergeEntityTypes = autoMergeEntityTypes
    }
}

final class ConflictResolutionSettingsStore: ObservableObject {
    static let shared = ConflictResolutionSettingsStore()
    private init() {
        self.settings = Self.load()
    }
    
    @Published var settings: ConflictResolutionSettings
    
    private static let storageKey = "cn.conflict.settings"
    
    private static func load() -> ConflictResolutionSettings {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            return ConflictResolutionSettings()
        }
        return (try? JSONDecoder().decode(ConflictResolutionSettings.self, from: data)) ?? ConflictResolutionSettings()
    }
    
    func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}


