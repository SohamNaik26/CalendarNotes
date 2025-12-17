//
//  CollectionsView.swift
//  CalendarNotes
//

import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct CollectionsView: View {
    @Environment(\.managedObjectContext) private var context
    @StateObject private var viewModel: CollectionsViewModel
    @State private var selection: CollectionsViewModel.Node?
    @State private var editName: String = ""
    @State private var showRename: Bool = false
    @State private var showEditor: Bool = false
    @State private var editingCollection: Collection? = nil
    @State private var search: String = ""

    init(context: NSManagedObjectContext) {
        _viewModel = StateObject(wrappedValue: CollectionsViewModel(context: context))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                TextField("Search collections", text: $search)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: search) { _, value in
                        viewModel.updateSearch(value)
                    }
                
                Button {
                    editingCollection = nil
                    showEditor = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .medium))
                }
                .buttonStyle(.bordered)
            }
            .padding(8)

            if viewModel.rootNodes.isEmpty || (viewModel.rootNodes.count == 1 && viewModel.rootNodes.first?.isSystem == true) {
                CollectionsEmptyState {
                    editingCollection = nil
                    showEditor = true
                }
            } else {
                List(selection: $selection) {
                    OutlineGroup(viewModel.rootNodes, children: \.childrenOptional) { node in
                        HStack {
                            Image(systemName: node.icon)
                                .foregroundColor(Color.hex(node.colorHex) ?? .gray)
                            Text(node.name)
                            Spacer()
                            Text("\(node.count)").foregroundColor(.cnSecondaryText)
                        }
                        .contextMenu { contextMenu(for: node) }
                        .onTapGesture {
                            if !node.isSystem {
                                openEditor(for: node)
                            }
                        }
                        .onDrag { NSItemProvider(object: NSString(string: node.name)) }
                        .onDrop(of: [UTType.text], isTargeted: nil) { _ in false }
                    }
                }
                .listStyle(SidebarListStyle())
            }
        }
        .task { await viewModel.reload() }
        .sheet(isPresented: $showRename) {
            renameSheet
        }
        .sheet(isPresented: $showEditor) {
            CollectionEditorView(context: context, collection: editingCollection)
                .onDisappear {
                    Task { await viewModel.reload() }
                }
        }
    }

    // nodeRow removed; using OutlineGroup above

    private func contextMenu(for node: CollectionsViewModel.Node) -> some View {
        Group {
            if !node.isSystem {
                Button("Edit") { openEditor(for: node) }
            }
            Button("Rename") { editName = node.name; selection = node; showRename = true }
            if !node.isSystem {
                Button("Add Sub-collection") { viewModel.addSubcollection(to: node, name: "New Folder"); Task { await viewModel.reload() } }
            }
            if !node.isSystem {
                Divider()
                Button("Delete", role: .destructive) { viewModel.delete(node); Task { await viewModel.reload() } }
            }
        }
    }
    
    private func openEditor(for node: CollectionsViewModel.Node) {
        guard !node.isSystem else { return }
        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", node.id as CVarArg)
        editingCollection = (try? context.fetch(request))?.first
        showEditor = true
    }

    private var renameSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rename Collection").font(.headline)
            TextField("Name", text: $editName)
            HStack {
                Spacer()
                Button("Cancel") { showRename = false }
                Button("Save") {
                    if let node = selection { viewModel.rename(node, to: editName) }
                    showRename = false
                    Task { await viewModel.reload() }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 320)
    }
}


