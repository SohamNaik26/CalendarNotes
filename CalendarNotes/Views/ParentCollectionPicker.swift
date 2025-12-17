//
//  ParentCollectionPicker.swift
//  CalendarNotes
//
//  Picker for selecting a parent collection (nested structure)
//

import SwiftUI
import CoreData

struct ParentCollectionPicker: View {
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedParent: Collection?
    let excluding: Collection?
    
    @State private var collections: [Collection] = []
    
    var body: some View {
        NavigationView {
            List {
                // None option
                Button {
                    selectedParent = nil
                    dismiss()
                } label: {
                    HStack {
                        Text("None")
                        Spacer()
                        if selectedParent == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                
                // Collections list
                ForEach(collections, id: \.objectID) { collection in
                    Button {
                        selectedParent = collection
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: collection.icon ?? "folder")
                                .foregroundColor(Color.hex(collection.color ?? "#999999") ?? .gray)
                            
                            Text(collection.name ?? "Unnamed")
                            
                            Spacer()
                            
                            if selectedParent?.id == collection.id {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Parent Collection")
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
            .onAppear {
                loadCollections()
            }
        }
    }
    
    private func loadCollections() {
        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        if let all = try? context.fetch(request) {
            // Filter out self and any descendants
            collections = all.filter { collection in
                guard let excludingId = excluding?.id else { return true }
                return collection.id != excludingId && !isDescendant(of: excludingId, in: collection)
            }
        }
    }
    
    private func isDescendant(of ancestorId: UUID, in collection: Collection) -> Bool {
        var current: Collection? = collection
        while let parent = current?.parent {
            if parent.id == ancestorId {
                return true
            }
            current = parent
        }
        return false
    }
}

