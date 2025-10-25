//
//  ThemeManager.swift
//  CalendarNotes
//
//  Global theme management for the entire app
//

import SwiftUI
import Combine

// MARK: - Theme Manager

@MainActor
class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var currentAppearanceMode: AppearanceMode {
        didSet {
            UserDefaults.standard.set(currentAppearanceMode.rawValue, forKey: "appearanceMode")
        }
    }
    
    private init() {
        // Load saved appearance mode from UserDefaults
        let savedMode = UserDefaults.standard.string(forKey: "appearanceMode") ?? AppearanceMode.system.rawValue
        self.currentAppearanceMode = AppearanceMode(rawValue: savedMode) ?? .system
    }
    
    func setAppearanceMode(_ mode: AppearanceMode) {
        print("🎨 Theme changed from \(currentAppearanceMode.displayName) to \(mode.displayName)")
        currentAppearanceMode = mode
    }
    
    var colorScheme: ColorScheme? {
        currentAppearanceMode.colorScheme
    }
}

// MARK: - Appearance Mode (defined in SettingsViewModel.swift)

// MARK: - Theme Environment

struct ThemeEnvironmentKey: EnvironmentKey {
    @MainActor static let defaultValue = ThemeManager.shared
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - Theme View Modifier

struct ThemeModifier: ViewModifier {
    @ObservedObject var themeManager: ThemeManager
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(themeManager.colorScheme)
            .environment(\.themeManager, themeManager)
    }
}

extension View {
    func withTheme() -> some View {
        self.modifier(ThemeModifier(themeManager: ThemeManager.shared))
    }
}
