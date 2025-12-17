//
//  OrientationManager.swift
//  CalendarNotes
//
//  Lightweight orientation observer for adaptive layouts.
//

import SwiftUI
import Combine

#if os(iOS)
import UIKit

@MainActor
final class OrientationManager: ObservableObject {
    @Published var orientation: UIDeviceOrientation
    
    init() {
        orientation = UIDevice.current.orientation
        NotificationCenter.default.addObserver(
            forName: UIDevice.orientationDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.orientation = UIDevice.current.orientation
            }
        }
    }
    
    var isLandscape: Bool {
        orientation.isValidInterfaceOrientation && orientation.isLandscape
    }
}
#endif


