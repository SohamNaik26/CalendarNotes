//
//  ConflictHistoryStore.swift
//  CalendarNotes
//
//  Created by Cursor AI on 16/11/25.
//

import Foundation

public struct ResolvedConflictRecord: Identifiable, Codable {
    public let id: String
    public let conflict: SyncConflict
    public let resolvedAt: Date
    public let resolution: ConflictResolutionChoice
}

final class ConflictHistoryStore {
    static let shared = ConflictHistoryStore()
    private init() {}
    
    private let storageKey = "cn.conflict.history"
    private let queue = DispatchQueue(label: "cn.conflict.history.queue", qos: .utility)
    
    func load() -> [ResolvedConflictRecord] {
        let data = UserDefaults.standard.data(forKey: storageKey) ?? Data()
        guard !data.isEmpty else { return [] }
        do {
            return try JSONDecoder().decode([ResolvedConflictRecord].self, from: data)
        } catch {
            return []
        }
    }
    
    func append(_ record: ResolvedConflictRecord) {
        queue.async {
            var all = self.load()
            all.insert(record, at: 0)
            if let data = try? JSONEncoder().encode(all) {
                UserDefaults.standard.set(data, forKey: self.storageKey)
            }
        }
    }
}


