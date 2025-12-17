//
//  OfflineQueue.swift
//  CalendarNotes
//
//  Created by Cursor AI on 08/11/25.
//

import Foundation

final class OfflineQueue {
    static let shared = OfflineQueue()
    
    private let storageURL: URL
    private let queue = DispatchQueue(label: "OfflineQueueStorage", qos: .utility)
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        storageURL = directory.appendingPathComponent("offline_queue.json")
        if !FileManager.default.fileExists(atPath: storageURL.deletingLastPathComponent().path) {
            try? FileManager.default.createDirectory(at: storageURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        }
    }
    
    func load() -> [OfflineOperation] {
        queue.sync {
            guard let data = try? Data(contentsOf: storageURL) else { return [] }
            return (try? decoder.decode([OfflineOperation].self, from: data)) ?? []
        }
    }
    
    func save(_ operations: [OfflineOperation]) {
        queue.async {
            let data = (try? self.encoder.encode(operations)) ?? Data()
            try? data.write(to: self.storageURL, options: .atomic)
        }
    }
    
    func append(_ operation: OfflineOperation) {
        queue.async {
            let data = (try? Data(contentsOf: self.storageURL)) ?? Data()
            var operations = (try? self.decoder.decode([OfflineOperation].self, from: data)) ?? []
            operations.append(operation)
            let newData = (try? self.encoder.encode(operations)) ?? Data()
            try? newData.write(to: self.storageURL, options: .atomic)
        }
    }
    
    func removeAll() {
        queue.async {
            try? FileManager.default.removeItem(at: self.storageURL)
        }
    }
}


