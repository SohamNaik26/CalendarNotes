//
//  NetworkReachability.swift
//  CalendarNotes
//
//  Created on [Date]
//

import Foundation
import Network
import Combine

/// Network reachability monitor for checking network availability
class NetworkReachability: ObservableObject {
    static let shared = NetworkReachability()
    
    @Published var isReachable: Bool = false
    @Published var connectionType: ConnectionType = .none
    
    enum ConnectionType {
        case wifi
        case cellular
        case ethernet
        case none
    }
    
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkReachabilityQueue")
    
    private init() {
        startMonitoring()
    }
    
    func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isReachable = path.status == .satisfied
                self?.connectionType = self?.getConnectionType(from: path) ?? .none
            }
        }
        monitor.start(queue: queue)
    }
    
    func stopMonitoring() {
        monitor.cancel()
    }
    
    private func getConnectionType(from path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .none
        }
    }
    
    func checkReachability() -> Bool {
        return isReachable
    }
}

