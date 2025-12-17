//
//  ConnectivityMonitor.swift
//  CalendarNotes
//
//  Created by Cursor AI on 08/11/25.
//

import Foundation
import Network
import Combine

final class ConnectivityMonitor {
    static let shared = ConnectivityMonitor()
    
    private let monitor: NWPathMonitor
    private let queue = DispatchQueue(label: "ConnectivityMonitorQueue")
    private let subject: CurrentValueSubject<NWPath?, Never>
    
    var publisher: AnyPublisher<NWPath, Never> {
        subject
            .compactMap { $0 }
            .eraseToAnyPublisher()
    }
    var currentPath: NWPath? {
        subject.value
    }
    
    private init() {
        monitor = NWPathMonitor()
        subject = CurrentValueSubject(nil)
#if canImport(Network)
        if #available(macOS 10.15, iOS 13.0, *) {
            subject.send(monitor.currentPath)
        }
#else
        subject.send(monitor.currentPath)
#endif
        monitor.pathUpdateHandler = { [weak self] path in
            self?.subject.send(path)
        }
        monitor.start(queue: queue)
    }
    
    deinit {
        monitor.cancel()
    }
}

extension NWPath {
    var connectionQuality: ConnectionQuality {
        guard status == .satisfied else { return .offline }
        if isConstrained {
            return .poor
        }
        if isExpensive {
            return .fair
        }
        if availableInterfaces.contains(where: { $0.type == .wifi }) {
            return .excellent
        }
        return .good
    }
}


