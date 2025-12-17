//
//  HighlightExportView.swift
//  CalendarNotes
//
//  View for exporting highlights
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers
#if os(iOS)
import UIKit
#endif

struct HighlightExportView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: HighlightAnnotationViewModel
    
    let bookmark: Bookmark
    
    @State private var showingShareSheet = false
    @State private var showingCalendarEvent = false
    @State private var calendarEventTitle = ""
    @State private var calendarEventDate = Date()
    @State private var exportText = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Export Options")) {
                    Button {
                        exportToNote()
                    } label: {
                        HStack {
                            Image(systemName: "note.text")
                            Text("Export to Note")
                        }
                    }
                    
                    Button {
                        prepareShareText()
                        showingShareSheet = true
                    } label: {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("Share Highlights")
                        }
                    }
                }
                
                Section(header: Text("Calendar Event")) {
                    Button {
                        showingCalendarEvent = true
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                            Text("Create Calendar Event")
                        }
                    }
                }
            }
            .navigationTitle("Export Highlights")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingCalendarEvent) {
                CreateCalendarEventView(
                    viewModel: viewModel,
                    bookmark: bookmark,
                    onDismiss: { showingCalendarEvent = false }
                )
            }
            #if os(iOS)
            .sheet(isPresented: $showingShareSheet) {
                ShareSheet(activityItems: [exportText])
            }
            #endif
        }
    }
    
    private func exportToNote() {
        do {
            _ = try viewModel.exportHighlightsToNote(bookmark: bookmark)
            dismiss()
            // Note content has been added to bookmark's notes field
            // TODO: Navigate to note view or show success message
        } catch {
            // TODO: Show error alert
            print("Error exporting highlights: \(error)")
        }
    }
    
    private func prepareShareText() {
        let request: NSFetchRequest<Highlight> = Highlight.fetchRequest()
        request.predicate = NSPredicate(format: "bookmark == %@", bookmark)
        request.sortDescriptors = [NSSortDescriptor(key: "createdDate", ascending: true)]
        
        let highlights = (try? context.fetch(request)) ?? []
        
        var text = "Highlights from: \(bookmark.title ?? "Bookmark")\n"
        text += "\(bookmark.url ?? "")\n\n"
        
        for (index, highlight) in highlights.enumerated() {
            text += "\(index + 1). \(highlight.selectedText ?? "")\n"
            if let note = highlight.note, !note.isEmpty {
                text += "   Note: \(note)\n"
            }
            text += "\n"
        }
        
        exportText = text
    }
}

// MARK: - Create Calendar Event View

struct CreateCalendarEventView: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: HighlightAnnotationViewModel
    
    let bookmark: Bookmark
    let onDismiss: () -> Void
    
    @State private var eventTitle = ""
    @State private var eventDate = Date()
    @State private var selectedHighlight: Highlight?
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Event Details")) {
                    TextField("Event Title", text: $eventTitle)
                    
                    DatePicker("Date", selection: $eventDate, displayedComponents: [.date, .hourAndMinute])
                }
                
                Section(header: Text("Select Highlight")) {
                    Picker("Highlight", selection: $selectedHighlight) {
                        Text("None").tag(Highlight?.none)
                        ForEach(viewModel.highlights) { highlight in
                            Text(highlight.selectedText ?? "")
                                .tag(Highlight?.some(highlight))
                        }
                    }
                }
                
                if let highlight = selectedHighlight {
                    Section(header: Text("Preview")) {
                        Text(highlight.selectedText ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Create Event")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        if let highlight = selectedHighlight {
                            do {
                                let eventDescription = try viewModel.createCalendarEvent(
                                    from: highlight,
                                    title: eventTitle.isEmpty ? "Reading Highlight" : eventTitle,
                                    date: eventDate
                                )
                                // TODO: Open system calendar or EventKit to create event
                                print("Event created: \(eventDescription)")
                            } catch {
                                print("Error creating calendar event: \(error)")
                            }
                        }
                        onDismiss()
                        dismiss()
                    }
                    .disabled(selectedHighlight == nil)
                }
            }
        }
    }
}

// MARK: - Share Sheet (iOS only)

#if os(iOS)
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

