//
//  IconPickerView.swift
//  CalendarNotes
//
//  SF Symbols icon picker with grid layout
//

import SwiftUI

struct IconPickerView: View {
    @Binding var selectedIcon: String
    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""
    
    // Curated list of 100+ SF Symbols icons (static to reduce compile-time work)
    private static let allIcons: [String] = [
        // Folders & Collections
        "folder", "folder.fill", "folder.badge.plus", "folder.badge.minus",
        "folder.badge.person.crop", "folder.badge.gearshape", "folder.badge.questionmark",
        
        // Documents
        "doc", "doc.fill", "doc.text", "doc.text.fill", "doc.badge.plus",
        "doc.badge.ellipsis", "doc.on.doc", "doc.on.clipboard",
        
        // Bookmarks & Favorites
        "bookmark", "bookmark.fill", "bookmark.circle", "bookmark.circle.fill",
        "star", "star.fill", "star.circle", "star.circle.fill",
        
        // Lists & Collections
        "list.bullet", "list.bullet.rectangle", "list.number", "list.star",
        "list.clipboard", "list.bullet.circle", "list.triangle",
        
        // Tags & Labels
        "tag", "tag.fill", "tag.circle", "tag.circle.fill",
        "label", "label.fill",
        
        // Categories & Groups
        "square.grid.2x2", "square.grid.3x2", "square.grid.3x3",
        "rectangle.grid.1x2", "rectangle.grid.2x2",
        
        // Files & Archives
        "archivebox", "archivebox.fill", "archivebox.circle", "archivebox.circle.fill",
        "tray", "tray.fill", "tray.2", "tray.2.fill",
        
        // Time & Dates
        "calendar", "calendar.badge.plus", "calendar.badge.minus",
        "calendar.badge.exclamationmark", "clock", "clock.fill",
        "clock.badge", "clock.badge.checkmark", "clock.badge.xmark",
        
        // Work & Productivity
        "briefcase", "briefcase.fill", "laptopcomputer", "desktopcomputer",
        "iphone", "ipad", "applewatch", "macpro.gen3",
        
        // Communication
        "envelope", "envelope.fill", "envelope.badge", "envelope.badge.fill",
        "message", "message.fill", "bubble.left", "bubble.left.fill",
        
        // Media
        "photo", "photo.fill", "camera", "camera.fill",
        "video", "video.fill", "music.note", "music.note.list",
        
        // Shopping & E-commerce
        "cart", "cart.fill", "cart.badge.plus", "cart.badge.minus",
        "bag", "bag.fill", "bag.badge.plus", "bag.badge.minus",
        
        // Finance
        "dollarsign.circle", "dollarsign.circle.fill",
        "creditcard", "creditcard.fill", "banknote", "banknote.fill",
        
        // Health & Fitness
        "heart", "heart.fill", "heart.circle", "heart.circle.fill",
        "figure.walk", "figure.run", "bicycle", "dumbbell.fill",
        
        // Education
        "book", "book.fill", "book.closed", "book.closed.fill",
        "graduationcap", "graduationcap.fill", "pencil", "pencil.circle",
        
        // Travel
        "airplane", "car", "car.fill", "tram.fill",
        "map", "map.fill", "location", "location.fill",
        
        // Home & Living
        "house", "house.fill", "house.circle", "house.circle.fill",
        "bed.double.fill", "sofa.fill", "refrigerator.fill",
        
        // Food & Dining
        "fork.knife", "cup.and.saucer.fill", "takeoutbag.and.cup.and.straw.fill",
        
        // Sports & Recreation
        "sportscourt.fill", "figure.tennis", "figure.skiing.crosscountry",
        
        // Weather
        "sun.max", "sun.max.fill", "cloud", "cloud.fill",
        "cloud.rain", "cloud.rain.fill", "snowflake",
        
        // Technology
        "wifi", "wifi.slash", "antenna.radiowaves.left.and.right",
        "server.rack", "externaldrive", "externaldrive.fill",
        
        // Symbols & Shapes
        "circle", "circle.fill", "square", "square.fill",
        "triangle", "triangle.fill", "diamond", "diamond.fill",
        "hexagon", "hexagon.fill", "pentagon", "pentagon.fill",
        
        // Arrows & Navigation
        "arrow.up", "arrow.down", "arrow.left", "arrow.right",
        "arrow.up.right", "arrow.down.right", "arrow.triangle.2.circlepath",
        
        // Actions
        "plus", "minus", "checkmark", "xmark",
        "pencil", "trash", "trash.fill", "arrow.clockwise",
        
        // Settings & Tools
        "gearshape", "gearshape.fill", "slider.horizontal.3",
        "wrench.and.screwdriver", "wrench.and.screwdriver.fill",
        
        // People
        "person", "person.fill", "person.2", "person.2.fill",
        "person.3", "person.3.fill", "person.circle", "person.circle.fill",
        
        // Security
        "lock", "lock.fill", "lock.shield", "lock.shield.fill",
        "eye", "eye.fill", "eye.slash", "eye.slash.fill",
        
        // Entertainment
        "tv", "tv.fill", "gamecontroller", "gamecontroller.fill",
        "theatermasks.fill", "paintpalette.fill",
        
        // Miscellaneous
        "sparkles", "sparkles.rectangle.stack", "wand.and.stars",
        "puzzlepiece.extension", "puzzlepiece.extension.fill",
        "bolt", "bolt.fill", "flame", "flame.fill"
    ]
    
    private var filteredIcons: [String] {
        if searchText.isEmpty {
            return Self.allIcons
        }
        return Self.allIcons.filter { icon in
            icon.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 60), spacing: 12)
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                IconSearchBar(text: $searchText)
                    .padding(.horizontal)
                    .padding(.top, 8)
                
                // Icon Grid
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(filteredIcons, id: \.self) { icon in
                            IconButton(
                                icon: icon,
                                isSelected: selectedIcon == icon,
                                action: {
                                    selectedIcon = icon
                                    dismiss()
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Choose Icon")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                #if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #else
                ToolbarItem(placement: .automatic) {
                    Button("Done") {
                        dismiss()
                    }
                }
                #endif
            }
        }
    }
}

// MARK: - Icon Button

struct IconButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : .primary)
                    .frame(width: 50, height: 50)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
                    )
                
                Text(icon)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(width: 60)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Icon Search Bar

struct IconSearchBar: View {
    @Binding var text: String
    
    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            
            TextField("Search icons", text: $text)
                .textFieldStyle(.plain)
            
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(10)
    }
}

