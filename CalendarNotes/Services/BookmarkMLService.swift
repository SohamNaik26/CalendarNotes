//
//  BookmarkMLService.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation
import Combine
import SwiftUI

#if canImport(CoreML)
import CoreML
import NaturalLanguage
#endif

@MainActor
final class BookmarkMLService: ObservableObject {
    static let shared = BookmarkMLService()

    @Published private(set) var smartCategorizationEnabled: Bool
    private let defaults = UserDefaults.standard
    private let smartCategorizationKey = "bookmark.ml.smartCategorization"
    private let featureAvailabilityKey = "bookmark.ml.featureAvailability"

#if canImport(CoreML)
    private var categorizationModel: NLModel?
    private var keywordTokenizer = NLTokenizer(unit: .word)
#endif

    private init() {
        #if os(iOS) || os(macOS)
        if #available(iOS 17.0, macOS 14.0, *) {
            let enabled = defaults.object(forKey: smartCategorizationKey) as? Bool ?? true
            smartCategorizationEnabled = enabled
            if enabled {
                loadModelsIfNeeded()
            }
        } else {
            smartCategorizationEnabled = false
        }
        #else
        smartCategorizationEnabled = false
        #endif
    }

    func setSmartCategorizationEnabled(_ enabled: Bool) {
        smartCategorizationEnabled = enabled
        defaults.set(enabled, forKey: smartCategorizationKey)
    }

    func reset() {
        smartCategorizationEnabled = false
        defaults.set(false, forKey: smartCategorizationKey)
    }

    func suggestedMetadata(for bookmark: BookmarkInput) async -> BookmarkMLSuggestion? {
        guard smartCategorizationEnabled else { return nil }
        #if canImport(CoreML)
        guard let text = bookmark.combinedText else { return nil }
        if #available(iOS 17.0, macOS 14.0, *) {
            do {
                let category = try await predictCategory(from: text)
                let keywords = extractKeywords(from: text)
                return BookmarkMLSuggestion(suggestedCollection: category, suggestedTags: keywords)
            } catch {
                return nil
            }
        } else {
            return nil
        }
        #else
        return nil
        #endif
    }

#if canImport(CoreML)
    @available(iOS 17.0, macOS 14.0, *)
    private func loadModelsIfNeeded() {
        guard smartCategorizationEnabled else { return }
        if categorizationModel == nil {
            if let url = Bundle.main.url(forResource: "BookmarkCategorizer", withExtension: "mlmodelc"),
               let model = try? NLModel(contentsOf: url) {
                categorizationModel = model
            }
        }
    }

    @available(iOS 17.0, macOS 14.0, *)
    private func predictCategory(from text: String) async throws -> String? {
        if categorizationModel == nil {
            loadModelsIfNeeded()
        }
        return categorizationModel?.predictedLabel(for: text)
    }

    private func extractKeywords(from text: String, maxCount: Int = 5) -> [String] {
        keywordTokenizer.string = text
        var tokens: [String] = []
        keywordTokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { tokenRange, _ in
            let token = String(text[tokenRange]).lowercased()
            if token.count > 3 {
                tokens.append(token)
            }
            return tokens.count < maxCount
        }
        return tokens
    }
#endif
}

struct BookmarkInput {
    var title: String?
    var description: String?
    var contentSnippet: String?

    var combinedText: String? {
        let components = [title, description, contentSnippet].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        let combined = components.joined(separator: "\n")
        return combined.isEmpty ? nil : combined
    }
}

struct BookmarkMLSuggestion {
    var suggestedCollection: String?
    var suggestedTags: [String]
}

extension BookmarkMLSuggestion {
    var hasContent: Bool {
        let hasCollection = (suggestedCollection?.isEmpty == false)
        let hasTags = !suggestedTags.isEmpty
        return hasCollection || hasTags
    }
}
