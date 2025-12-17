//
//  DeepLinkDocumentationView.swift
//  CalendarNotes
//

import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct DeepLinkDocumentationView: View {
    @Environment(\.dismiss) private var dismiss

    private let customSchemeItems: [DeepLinkDocItem] = [
        .init(
            title: "Open bookmarks",
            description: "Show the bookmarks tab.",
            example: "calendarnotes://bookmarks"
        ),
        .init(
            title: "Add bookmark",
            description: "Prefill the quick add sheet with a URL and optional collection.",
            example: "calendarnotes://add-bookmark?url=https%3A%2F%2Fexample.com&collection=Reading%20List"
        ),
        .init(
            title: "Search",
            description: "Jump to global search with the provided query.",
            example: "calendarnotes://search?query=meeting%20notes"
        ),
        .init(
            title: "Open collection",
            description: "Focus the bookmarks view on a collection.",
            example: "calendarnotes://collection/UUID-HERE"
        ),
        .init(
            title: "Open bookmark",
            description: "Show bookmark detail by UUID.",
            example: "calendarnotes://bookmark/UUID-HERE"
        ),
        .init(
            title: "Open tag",
            description: "Filter bookmarks by tag name.",
            example: "calendarnotes://tag/reading"
        ),
        .init(
            title: "Open random bookmark",
            description: "Opens a randomly suggested bookmark.",
            example: "calendarnotes://open-random"
        )
    ]

    private let universalLinkItems: [DeepLinkDocItem] = [
        .init(
            title: "Bookmark detail",
            description: "Universal link that mirrors the bookmark route.",
            example: "https://yourapp.com/bookmark/UUID-HERE"
        ),
        .init(
            title: "Collection",
            description: "Universal link to a collection by UUID.",
            example: "https://yourapp.com/collection/UUID-HERE"
        ),
        .init(
            title: "Search",
            description: "Universal link to perform a global search.",
            example: "https://yourapp.com/search?query=weekly%20review"
        ),
        .init(
            title: "Add bookmark",
            description: "Prefill quick add from the web.",
            example: "https://yourapp.com/add-bookmark?url=https%3A%2F%2Fswift.org"
        )
    ]

    private let callbackExample = "calendarnotes://add-bookmark?url=https%3A%2F%2Fexample.com&x-success=myapp%3A%2F%2Fdone&x-error=myapp%3A%2F%2Ferror&x-state=1234"

    var body: some View {
        NavigationView {
            List {
                Section("Overview") {
                    Text("CalendarNotes responds to custom URL schemes, universal links, and x-callback-url conventions. Links can be invoked from Safari extensions, Shortcuts, NFC tags, QR codes, and other apps.")
                    Text("Bookmark, collection, and tag identifiers are Core Data UUIDs. You can copy a bookmark's deep link from its detail view.")
                }

                Section("Custom Scheme: calendarnotes://") {
                    ForEach(customSchemeItems) { item in
                        DeepLinkDocRow(item: item, copyAction: copyToClipboard)
                    }
                }

                Section("x-callback-url") {
                    Text("Support for x-success, x-error, x-cancel, x-state, and optional x-next lets you build automations that react to success or failure.")
                    DeepLinkDocRow(
                        item: .init(
                            title: "x-callback example",
                            description: "Add bookmark, return to caller on success.",
                            example: callbackExample
                        ),
                        copyAction: copyToClipboard
                    )
                    Text("If the user closes the add bookmark sheet without saving, CalendarNotes triggers the x-cancel URL automatically.")
                    Text("Upon completion the app appends contextual data (for example the bookmark ID) to the callback URL.")
                }

                Section("Universal Links") {
                    Text("Add \"applinks:yourapp.com\" to the app entitlements and host an apple-app-site-association file at \".well-known/apple-app-site-association\" so iOS and macOS trust your domain.")
                    ForEach(universalLinkItems) { item in
                        DeepLinkDocRow(item: item, copyAction: copyToClipboard)
                    }
                    Text("If CalendarNotes is not installed, the link opens in the browser automatically.")
                }

                Section("Integration Tips") {
                    Label("Safari extension", systemImage: "safari")
                        .font(.headline)
                    Text("Use the \"Open in CalendarNotes\" action to send the current page to `calendarnotes://add-bookmark`.")

                    Label("Shortcuts", systemImage: "square.grid.3x3")
                        .font(.headline)
                    Text("Combine \"Get Contents of URL\" with the custom scheme to chain actions. Use the x-callback `x-next` parameter to trigger follow-up CalendarNotes links.")

                    Label("NFC & QR", systemImage: "wave.3.right")
                        .font(.headline)
                    Text("Encode universal links or custom schemes; iOS will route straight into CalendarNotes when installed.")
                }
            }
            .navigationTitle("Deep Link API")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }

    private func copyToClipboard(_ value: String) {
        #if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        #else
        UIPasteboard.general.string = value
        #endif
    }
}

private struct DeepLinkDocItem: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let example: String
}

private struct DeepLinkDocRow: View {
    let item: DeepLinkDocItem
    let copyAction: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.headline)
            Text(item.description)
                .font(.subheadline)
                .foregroundColor(.secondary)
            HStack {
                Text(item.example)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                Spacer()
                Button("Copy") {
                    copyAction(item.example)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
    }
}

