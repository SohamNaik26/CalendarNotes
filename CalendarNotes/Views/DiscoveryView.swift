//
//  DiscoveryView.swift
//  CalendarNotes
//

import SwiftUI
import CoreData

struct DiscoveryView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    private let service = BookmarkDiscoveryService.shared
    
    @State private var trending: [Bookmark] = []
    @State private var domains: [(String, Int)] = []
    @State private var rising: [(String, Int)] = []
    @State private var gems: [Bookmark] = []
    @State private var onThisDay: [Bookmark] = []
    @State private var randomPick: Bookmark?
    
    var body: some View {
        #if os(macOS)
        ZStack {
            Color.cnBackground.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Text("Discover").font(.headline)
                    Spacer()
                    Button("Done") { dismiss() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.cnSecondaryBackground)

                Divider()

                List {
                    if let pick = randomPick { sectionRandom(pick) }
                    sectionTrending
                    sectionDomains
                    sectionRisingTags
                    sectionGems
                    sectionOnThisDay
                }
                .frame(minWidth: 640, minHeight: 420)
            }
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.cnSecondaryBackground)
                    .shadow(radius: 20)
            )
            .padding(24)
        }
        .onAppear(perform: load)
        #else
        NavigationView {
            List {
                if let pick = randomPick { sectionRandom(pick) }
                sectionTrending
                sectionDomains
                sectionRisingTags
                sectionGems
                sectionOnThisDay
            }
            .navigationTitle("Discover")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        .onAppear(perform: load)
        #endif
    }
    
    private func load() {
        trending = service.trending(limit: 10)
        domains = service.popularDomains(limit: 8)
        rising = service.risingTags(limit: 8)
        gems = service.forgottenGems(limit: 8)
        onThisDay = service.onThisDay()
        randomPick = service.randomSuggestion()
    }
    
    private var sectionTrending: some View {
        Section(header: Text("Trending")) {
            if trending.isEmpty { Text("No trending bookmarks yet").foregroundColor(.secondary) }
            ForEach(trending, id: \.objectID) { b in
                BookmarkRowMini(bookmark: b)
            }
        }
    }
    
    private var sectionDomains: some View {
        Section(header: Text("Popular Domains")) {
            ForEach(domains, id: \.0) { d in
                HStack {
                    Image(systemName: "globe")
                    Text(d.0)
                    Spacer()
                    Text("\(d.1)").foregroundColor(.secondary)
                }
            }
        }
    }
    
    private var sectionRisingTags: some View {
        Section(header: Text("Rising Tags")) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(rising, id: \.0) { r in
                        HStack(spacing: 6) {
                            Image(systemName: "tag.fill")
                            Text(r.0)
                        }
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.cnTertiaryBackground)
                        .clipShape(Capsule())
                    }
                }
                .padding(.vertical, 6)
            }
        }
    }
    
    private var sectionGems: some View {
        Section(header: Text("Forgotten Gems")) {
            if gems.isEmpty { Text("None yet").foregroundColor(.secondary) }
            ForEach(gems, id: \.objectID) { b in
                BookmarkRowMini(bookmark: b)
            }
        }
    }
    
    private var sectionOnThisDay: some View {
        Section(header: Text("On This Day")) {
            if onThisDay.isEmpty { Text("No memories for today").foregroundColor(.secondary) }
            ForEach(onThisDay, id: \.objectID) { b in
                BookmarkRowMini(bookmark: b)
            }
        }
    }
    
    private func sectionRandom(_ b: Bookmark) -> some View {
        Section(header: Text("Random Pick")) {
            BookmarkRowMini(bookmark: b)
        }
    }
}

// Minimal bookmark row used across discovery sections
private struct BookmarkRowMini: View {
    let bookmark: Bookmark
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bookmark")
                .foregroundColor(.cnAccent)
            VStack(alignment: .leading, spacing: 2) {
                Text(bookmark.title ?? bookmark.url ?? "Untitled").lineLimit(1)
                Text(URL(string: bookmark.url ?? "")?.host ?? "").font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
    }
}


