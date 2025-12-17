//
//  QuickAddBookmarkViewModel.swift
//  CalendarNotes
//
//  Created by GPT-5 Codex on 12/11/25.
//

import Foundation
import Combine

@MainActor
final class QuickAddBookmarkViewModel: ObservableObject {
    let objectWillChange = PassthroughSubject<Void, Never>()

    @Published var urlString: String = ""
    @Published var title: String = ""
    @Published var descriptionText: String = ""
    @Published var selectedCollectionName: String = ""
    @Published var tagInput: String = ""
    @Published var notes: String = ""

    func reset(with url: URL? = nil) {
        urlString = url?.absoluteString ?? ""
        title = ""
        descriptionText = ""
        selectedCollectionName = ""
        tagInput = ""
        notes = ""
    }
}
