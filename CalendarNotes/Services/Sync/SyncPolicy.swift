//
//  SyncPolicy.swift
//  CalendarNotes
//
//  Created by Cursor AI on 08/11/25.
//

import Combine
import Foundation

struct SyncPolicy: Equatable {
    enum Frequency: String, CaseIterable {
        case manual
        case hourly
        case twiceDaily
        case daily
    }
    
    var wifiOnly: Bool
    var frequency: Frequency
    var lowDataMode: Bool
    var backgroundSyncEnabled: Bool
    
    static let defaults = SyncPolicy(wifiOnly: false,
                                     frequency: .hourly,
                                     lowDataMode: false,
                                     backgroundSyncEnabled: true)
}

final class SyncPolicyStore: ObservableObject {
    static let shared = SyncPolicyStore()
    
    private let defaults = UserDefaults.standard
    
    @Published private(set) var policy: SyncPolicy
    
    private init() {
        policy = SyncPolicy(
            wifiOnly: defaults.bool(forKey: Keys.wifiOnly),
            frequency: SyncPolicy.Frequency(rawValue: defaults.string(forKey: Keys.frequency) ?? SyncPolicy.Frequency.hourly.rawValue) ?? .hourly,
            lowDataMode: defaults.bool(forKey: Keys.lowDataMode),
            backgroundSyncEnabled: defaults.object(forKey: Keys.backgroundSyncEnabled) as? Bool ?? true
        )
    }
    
    func update(_ mutate: (inout SyncPolicy) -> Void) {
        var copy = policy
        mutate(&copy)
        policy = copy
        persist(copy)
    }
    
    private func persist(_ policy: SyncPolicy) {
        defaults.set(policy.wifiOnly, forKey: Keys.wifiOnly)
        defaults.set(policy.frequency.rawValue, forKey: Keys.frequency)
        defaults.set(policy.lowDataMode, forKey: Keys.lowDataMode)
        defaults.set(policy.backgroundSyncEnabled, forKey: Keys.backgroundSyncEnabled)
    }
    
    private enum Keys {
        static let wifiOnly = "syncPolicyWifiOnly"
        static let frequency = "syncPolicyFrequency"
        static let lowDataMode = "syncPolicyLowDataMode"
        static let backgroundSyncEnabled = "syncPolicyBackgroundSync"
    }
}


