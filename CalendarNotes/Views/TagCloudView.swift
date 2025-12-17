//
//  TagCloudView.swift
//  CalendarNotes
//
//  Tag cloud visualization
//

import SwiftUI
import CoreData

struct TagCloudView: View {
    @Environment(\.managedObjectContext) private var context
    @State private var tags: [Tag] = []
    @State private var tagStats: [TagStat] = []
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    ForEach(tagStats) { stat in
                        TagCloudItem(stat: stat)
                    }
                }
                .padding()
            }
            .navigationTitle("Tag Cloud")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.large)
            #endif
            .onAppear {
                loadTags()
            }
        }
    }
    
    private func loadTags() {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "usageCount", ascending: false)]
        
        if let fetchedTags = try? context.fetch(request) {
            tags = fetchedTags
            
            let bookmarkRequest: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
            let totalBookmarks = (try? context.fetch(bookmarkRequest)).map { $0.count } ?? 0
            
            tagStats = fetchedTags.map { tag in
                let count = tag.usageCount
                let percentage = totalBookmarks > 0 ? Double(count) / Double(totalBookmarks) : 0
                return TagStat(tag: tag, count: Int(count), percentage: percentage)
            }
        }
    }
}

struct TagStat: Identifiable {
    let id: UUID
    let tag: Tag
    let count: Int
    let percentage: Double
    
    init(tag: Tag, count: Int, percentage: Double) {
        self.id = tag.id ?? UUID()
        self.tag = tag
        self.count = count
        self.percentage = percentage
    }
    
    var fontSize: CGFloat {
        // Scale font size based on usage
        let baseSize: CGFloat = 12
        let maxSize: CGFloat = 32
        return baseSize + (maxSize - baseSize) * CGFloat(min(percentage / 10, 1.0))
    }
    
    var opacity: Double {
        // Scale opacity based on usage
        return 0.5 + (0.5 * Double(min(percentage / 10, 1.0)))
    }
}

struct TagCloudItem: View {
    let stat: TagStat
    
    var body: some View {
        HStack(spacing: 12) {
            // Color indicator
            Circle()
                .fill(Color.hex(stat.tag.color ?? "#999999") ?? .gray)
                .frame(width: 16, height: 16)
            
            // Tag name with dynamic size
            Text(stat.tag.name ?? "Unnamed")
                .font(.system(size: stat.fontSize, weight: .medium))
                .foregroundColor(.primary)
                .opacity(stat.opacity)
            
            Spacer()
            
            // Usage count
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(stat.count)")
                    .font(.headline)
                Text("bookmarks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondary.opacity(0.1))
        )
    }
}

