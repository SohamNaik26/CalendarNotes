//
//  ReadingListView.swift
//  CalendarNotes
//

import SwiftUI
import CoreData

struct ReadingListView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    
    @State private var items: [Bookmark] = []
    @State private var rescheduleTarget: Bookmark?
    @State private var newDate: Date = Date()
    
    var body: some View {
        NavigationView {
            Group {
                if items.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bookmark.slash")
                            .font(.system(size: 42))
                            .foregroundColor(.cnSecondaryText)
                        Text("No scheduled reading items yet")
                            .font(.headline)
                        Text("Link bookmarks to calendar dates to see them here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(items, id: \.objectID) { b in
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: "bookmark")
                                    .foregroundColor(.cnAccent)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(b.title ?? b.url ?? "Untitled").font(.body)
                                    if let d = b.linkedCalendarDate { Text(dateString(d)).font(.caption).foregroundColor(.secondary) }
                                }
                                Spacer()
                                Menu {
                                    Button("Mark as Read") { markRead(b) }
                                    Button("Reschedule") { rescheduleTarget = b; newDate = b.linkedCalendarDate ?? Date() }
                                    Button("Open") {
                                        if let s = b.url, let u = URL(string: s) {
                                            #if os(macOS)
                                            NSWorkspace.shared.open(u)
                                            #else
                                            UIApplication.shared.open(u)
                                            #endif
                                        }
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Reading List")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
        #if os(macOS)
        .frame(minWidth: 480, minHeight: 420)
        #else
        .frame(minWidth: 360, minHeight: 420)
        #endif
        .onAppear(perform: load)
        .sheet(item: $rescheduleTarget) { _ in
            NavigationView {
                Form {
                    DatePicker("New Date", selection: $newDate, displayedComponents: [.date, .hourAndMinute])
                }
                .navigationTitle("Reschedule")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { rescheduleTarget = nil } }
                    ToolbarItem(placement: .confirmationAction) { Button("Save") { saveReschedule() } }
                }
            }
        }
    }
    
    private func load() {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let end = Calendar.current.date(byAdding: .day, value: 60, to: Date())!
        items = BookmarkCalendarLinkService.shared.bookmarks(on: Date())
        // Fetch range
        let req: NSFetchRequest<Bookmark> = Bookmark.fetchRequest()
        req.predicate = NSPredicate(format: "linkedCalendarDate >= %@ AND linkedCalendarDate <= %@", start as NSDate, end as NSDate)
        req.sortDescriptors = [NSSortDescriptor(key: "linkedCalendarDate", ascending: true)]
        items = (try? context.fetch(req)) ?? []
    }
    
    private func markRead(_ b: Bookmark) {
        b.isArchived = true
        b.linkedCalendarDate = nil
        try? context.save()
        load()
    }
    
    private func saveReschedule() {
        if let target = rescheduleTarget { target.linkedCalendarDate = newDate; try? context.save() }
        rescheduleTarget = nil
        load()
    }
    
    private func dateString(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .short; return f.string(from: d)
    }
}




