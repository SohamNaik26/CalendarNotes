//
//  AutomationRuleBuilderView.swift
//  CalendarNotes
//

import SwiftUI
import CoreData

struct AutomationRuleBuilderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    
    let onSave: (AutomationRule) -> Void
    let onCancel: () -> Void
    
    @State private var name: String
    @State private var isEnabled: Bool
    @State private var trigger: Trigger
    @State private var actions: [Action]
    
    init(rule: AutomationRule? = nil, onSave: @escaping (AutomationRule) -> Void, onCancel: @escaping () -> Void) {
        if let rule = rule {
            _name = State(initialValue: rule.name)
            _isEnabled = State(initialValue: rule.isEnabled)
            _trigger = State(initialValue: rule.trigger)
            _actions = State(initialValue: rule.actions)
        } else {
            _name = State(initialValue: "")
            _isEnabled = State(initialValue: true)
            _trigger = State(initialValue: .taggedWith(""))
            _actions = State(initialValue: [])
        }
        self.onSave = onSave
        self.onCancel = onCancel
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Rule Details")) {
                    TextField("Rule Name", text: $name)
                    Toggle("Enabled", isOn: $isEnabled)
                }
                
                Section(header: Text("Trigger")) {
                    TriggerBuilderView(trigger: $trigger)
                }
                
                Section(header: Text("Actions")) {
                    ActionsBuilderView(actions: $actions)
                }
            }
            .navigationTitle(name.isEmpty ? "New Rule" : name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel(); dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let rule = AutomationRule(
                            name: name,
                            isEnabled: isEnabled,
                            trigger: trigger,
                            actions: actions
                        )
                        onSave(rule)
                        dismiss()
                    }
                    .disabled(name.isEmpty || actions.isEmpty)
                }
            }
        }
    }
}

private struct TriggerBuilderView: View {
    @Binding var trigger: Trigger
    @State private var triggerType: TriggerType = .taggedWith
    
    enum TriggerType: String, CaseIterable {
        case addedToCollection = "Added to Collection"
        case taggedWith = "Tagged With"
        case fromDomain = "From Domain"
        case savedAtTime = "Saved at Time"
        case notOpenedInDays = "Not Opened In Days"
    }
    
    var body: some View {
        Picker("Trigger Type", selection: $triggerType) {
            ForEach(TriggerType.allCases, id: \.self) { type in
                Text(type.rawValue).tag(type)
            }
        }
        .onChange(of: triggerType) { _, newType in
            updateTrigger(for: newType)
        }
        
        switch trigger {
        case .addedToCollection:
            CollectionTriggerView(trigger: $trigger)
        case .taggedWith:
            TagTriggerView(trigger: $trigger)
        case .fromDomain:
            DomainTriggerView(trigger: $trigger)
        case .savedAtTime:
            TimeTriggerView(trigger: $trigger)
        case .notOpenedInDays:
            DaysTriggerView(trigger: $trigger)
        case .matchesAll, .matchesAny:
            EmptyView()
        }
    }
    
    private func updateTrigger(for type: TriggerType) {
        switch type {
        case .addedToCollection:
            trigger = .addedToCollection("")
        case .taggedWith:
            trigger = .taggedWith("")
        case .fromDomain:
            trigger = .fromDomain("")
        case .savedAtTime:
            trigger = .savedAtTime(.timeRange(startHour: 9, startMinute: 0, endHour: 17, endMinute: 0))
        case .notOpenedInDays:
            trigger = .notOpenedInDays(30)
        }
    }
}

private struct CollectionTriggerView: View {
    @Binding var trigger: Trigger
    @Environment(\.managedObjectContext) private var context
    @State private var selectedCollection: String = ""
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Collection.name, ascending: true)],
        animation: .default
    ) private var collections: FetchedResults<Collection>
    
    var body: some View {
        Picker("Collection", selection: $selectedCollection) {
            ForEach(collections, id: \.objectID) { collection in
                Text(collection.name ?? "Unnamed").tag(collection.name ?? "")
            }
        }
        .onChange(of: selectedCollection) { _, newValue in
            trigger = .addedToCollection(newValue)
        }
        .onAppear {
            if case .addedToCollection(let name) = trigger {
                selectedCollection = name
            }
        }
    }
}

private struct TagTriggerView: View {
    @Binding var trigger: Trigger
    @State private var tagName: String = ""
    
    var body: some View {
        TextField("Tag Name", text: $tagName)
            .onChange(of: tagName) { _, newValue in
                trigger = .taggedWith(newValue)
            }
            .onAppear {
                if case .taggedWith(let tag) = trigger {
                    tagName = tag
                }
            }
    }
}

private struct DomainTriggerView: View {
    @Binding var trigger: Trigger
    @State private var domain: String = ""
    
    var body: some View {
        TextField("Domain (e.g., example.com)", text: $domain)
            .onChange(of: domain) { _, newValue in
                trigger = .fromDomain(newValue)
            }
            .onAppear {
                if case .fromDomain(let d) = trigger {
                    domain = d
                }
            }
    }
}

private struct TimeTriggerView: View {
    @Binding var trigger: Trigger
    @State private var startHour: Int = 9
    @State private var startMinute: Int = 0
    @State private var endHour: Int = 17
    @State private var endMinute: Int = 0
    
    var body: some View {
        DatePicker("Start Time", selection: Binding(
            get: {
                let components = DateComponents(hour: startHour, minute: startMinute)
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                startHour = components.hour ?? 9
                startMinute = components.minute ?? 0
                updateTrigger()
            }
        ), displayedComponents: .hourAndMinute)
        
        DatePicker("End Time", selection: Binding(
            get: {
                let components = DateComponents(hour: endHour, minute: endMinute)
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { date in
                let components = Calendar.current.dateComponents([.hour, .minute], from: date)
                endHour = components.hour ?? 17
                endMinute = components.minute ?? 0
                updateTrigger()
            }
        ), displayedComponents: .hourAndMinute)
    }
    
    private func updateTrigger() {
        trigger = .savedAtTime(.timeRange(startHour: startHour, startMinute: startMinute, endHour: endHour, endMinute: endMinute))
    }
}

private struct DaysTriggerView: View {
    @Binding var trigger: Trigger
    @State private var days: Int = 30
    
    var body: some View {
        Stepper("Days: \(days)", value: $days, in: 1...365)
            .onChange(of: days) { _, newValue in
                trigger = .notOpenedInDays(newValue)
            }
            .onAppear {
                if case .notOpenedInDays(let d) = trigger {
                    days = d
                }
            }
    }
}

private struct ActionsBuilderView: View {
    @Binding var actions: [Action]
    @State private var showingAddAction = false
    
    var body: some View {
        ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
            ActionRow(action: action, index: index, actions: $actions)
        }
        .onDelete { indices in
            actions.remove(atOffsets: indices)
        }
        
        Button {
            showingAddAction = true
        } label: {
            Label("Add Action", systemImage: "plus.circle")
        }
        .sheet(isPresented: $showingAddAction) {
            AddActionView { newAction in
                actions.append(newAction)
            }
        }
    }
}

private struct ActionRow: View {
    let action: Action
    let index: Int
    @Binding var actions: [Action]
    
    var body: some View {
        HStack {
            Text(actionDescription(action))
            Spacer()
            Button {
                actions.remove(at: index)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
        }
    }
    
    private func actionDescription(_ action: Action) -> String {
        switch action {
        case .moveToCollection(let name):
            return "Move to: \(name)"
        case .addTags(let tags):
            return "Add tags: \(tags.joined(separator: ", "))"
        case .removeTags(let tags):
            return "Remove tags: \(tags.joined(separator: ", "))"
        case .markAsFavorite(let favorite):
            return favorite ? "Mark as favorite" : "Unmark as favorite"
        case .archive(let archived):
            return archived ? "Archive" : "Unarchive"
        case .delete:
            return "Delete"
        case .sendNotification(let message):
            return "Notify: \(message)"
        case .createTask(let title):
            return "Create task: \(title ?? "Read bookmark")"
        case .createCalendarEvent(let title, _):
            return "Create event: \(title ?? "Reading")"
        case .addNote:
            return "Add note"
        }
    }
}

private struct AddActionView: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (Action) -> Void
    @State private var actionType: ActionType = .moveToCollection
    
    enum ActionType: String, CaseIterable {
        case moveToCollection = "Move to Collection"
        case addTags = "Add Tags"
        case removeTags = "Remove Tags"
        case markAsFavorite = "Mark as Favorite"
        case archive = "Archive"
        case delete = "Delete"
        case sendNotification = "Send Notification"
        case createTask = "Create Task"
        case createCalendarEvent = "Create Calendar Event"
        case addNote = "Add Note"
    }
    
    var body: some View {
        NavigationView {
            Form {
                Picker("Action Type", selection: $actionType) {
                    ForEach(ActionType.allCases, id: \.self) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                
                actionInputView
            }
            .navigationTitle("Add Action")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        if let action = buildAction() {
                            onAdd(action)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var actionInputView: some View {
        switch actionType {
        case .moveToCollection:
            CollectionActionView { name in
                onAdd(.moveToCollection(name))
                dismiss()
            }
        case .addTags, .removeTags:
            TagsActionView(isAdd: actionType == .addTags) { tags in
                onAdd(actionType == .addTags ? .addTags(tags) : .removeTags(tags))
                dismiss()
            }
        case .markAsFavorite:
            FavoriteActionView { favorite in
                onAdd(.markAsFavorite(favorite))
                dismiss()
            }
        case .archive:
            ArchiveActionView { archived in
                onAdd(.archive(archived))
                dismiss()
            }
        case .delete:
            Text("This will delete matching bookmarks. Are you sure?")
            Button("Confirm Delete Action") {
                onAdd(.delete)
                dismiss()
            }
            .foregroundColor(.red)
        case .sendNotification:
            NotificationActionView { message in
                onAdd(.sendNotification(message))
                dismiss()
            }
        case .createTask:
            TaskActionView { title in
                onAdd(.createTask(title))
                dismiss()
            }
        case .createCalendarEvent:
            CalendarEventActionView { title, date in
                onAdd(.createCalendarEvent(title, date))
                dismiss()
            }
        case .addNote:
            NoteActionView { note in
                onAdd(.addNote(note))
                dismiss()
            }
        }
    }
    
    private func buildAction() -> Action? {
        // Actions are built in their respective views
        return nil
    }
}

// MARK: - Action Input Views

private struct CollectionActionView: View {
    @Environment(\.managedObjectContext) private var context
    let onSelect: (String) -> Void
    @State private var selectedCollection: String = ""
    
    var body: some View {
        let request: NSFetchRequest<Collection> = Collection.fetchRequest()
        let collections = (try? context.fetch(request)) ?? []
        
        Picker("Collection", selection: $selectedCollection) {
            ForEach(collections, id: \.objectID) { collection in
                Text(collection.name ?? "Unnamed").tag(collection.name ?? "")
            }
        }
        .onChange(of: selectedCollection) { _, newValue in
            if !newValue.isEmpty {
                onSelect(newValue)
            }
        }
    }
}

private struct TagsActionView: View {
    let isAdd: Bool
    let onSave: ([String]) -> Void
    @State private var tagText: String = ""
    
    var body: some View {
        TextField("Tags (comma-separated)", text: $tagText)
        Button("Save") {
            let tags = tagText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            onSave(Array(tags))
        }
    }
}

private struct FavoriteActionView: View {
    let onSave: (Bool) -> Void
    @State private var favorite: Bool = true
    
    var body: some View {
        Toggle("Mark as favorite", isOn: $favorite)
        Button("Save") {
            onSave(favorite)
        }
    }
}

private struct ArchiveActionView: View {
    let onSave: (Bool) -> Void
    @State private var archived: Bool = true
    
    var body: some View {
        Toggle("Archive", isOn: $archived)
        Button("Save") {
            onSave(archived)
        }
    }
}

private struct NotificationActionView: View {
    let onSave: (String) -> Void
    @State private var message: String = ""
    
    var body: some View {
        TextField("Notification message", text: $message)
        Button("Save") {
            onSave(message)
        }
    }
}

private struct TaskActionView: View {
    let onSave: (String?) -> Void
    @State private var title: String = ""
    @State private var useDefault: Bool = true
    
    var body: some View {
        Toggle("Use default title", isOn: $useDefault)
        if !useDefault {
            TextField("Task title", text: $title)
        }
        Button("Save") {
            onSave(useDefault ? nil : (title.isEmpty ? nil : title))
        }
    }
}

private struct CalendarEventActionView: View {
    let onSave: (String?, Date?) -> Void
    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var useDefaultTitle: Bool = true
    @State private var useDefaultDate: Bool = true
    
    var body: some View {
        Toggle("Use default title", isOn: $useDefaultTitle)
        if !useDefaultTitle {
            TextField("Event title", text: $title)
        }
        Toggle("Use default date (now)", isOn: $useDefaultDate)
        if !useDefaultDate {
            DatePicker("Event date", selection: $date)
        }
        Button("Save") {
            onSave(useDefaultTitle ? nil : (title.isEmpty ? nil : title), useDefaultDate ? nil : date)
        }
    }
}

private struct NoteActionView: View {
    let onSave: (String) -> Void
    @State private var note: String = ""
    
    var body: some View {
        TextEditor(text: $note)
            .frame(height: 200)
        Button("Save") {
            onSave(note)
        }
    }
}


