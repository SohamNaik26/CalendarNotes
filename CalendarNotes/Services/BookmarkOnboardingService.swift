//
//  BookmarkOnboardingService.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation
import Combine

@MainActor
final class BookmarkOnboardingService: ObservableObject {
    static let shared = BookmarkOnboardingService()

    @Published private(set) var steps: [BookmarkOnboardingStep]
    @Published private(set) var currentIndex: Int = 0
    @Published var hasCompletedOnboarding: Bool
    let objectWillChange = PassthroughSubject<Void, Never>()

    private let defaults = UserDefaults.standard
    private let completionKey = "bookmark.onboarding.completed"

    private init() {
        steps = BookmarkOnboardingStep.defaultSteps()
        hasCompletedOnboarding = defaults.bool(forKey: completionKey)
    }

    func startIfNeeded() {
        guard !hasCompletedOnboarding else { return }
        currentIndex = 0
    }

    func advance() {
        guard currentIndex < steps.count - 1 else {
            complete()
            return
        }
        currentIndex += 1
    }

    func goBack() {
        guard currentIndex > 0 else { return }
        currentIndex -= 1
    }

    func setCurrentIndex(_ index: Int) {
        guard steps.indices.contains(index) else { return }
        currentIndex = index
    }

    func complete() {
        hasCompletedOnboarding = true
        defaults.set(true, forKey: completionKey)
    }

    func resetForTesting() {
        hasCompletedOnboarding = false
        defaults.removeObject(forKey: completionKey)
        currentIndex = 0
    }

    func handleAction(_ action: BookmarkOnboardingAction) {
        switch action {
        case .openImport:
            NotificationCenter.default.post(name: .bookmarkOnboardingOpenImport, object: nil)
        case .createDefaultCollection:
            NotificationCenter.default.post(name: .bookmarkOnboardingCreateDefaultCollection, object: nil)
        case .openExtensionGuide:
            NotificationCenter.default.post(name: .bookmarkOnboardingOpenExtensionGuide, object: nil)
        }
    }
}

extension Notification.Name {
    static let bookmarkOnboardingOpenImport = Notification.Name("bookmarkOnboardingOpenImport")
    static let bookmarkOnboardingCreateDefaultCollection = Notification.Name("bookmarkOnboardingCreateDefaultCollection")
    static let bookmarkOnboardingOpenExtensionGuide = Notification.Name("bookmarkOnboardingOpenExtensionGuide")
}
