# CalendarNotes - Architecture Documentation

## Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [Data Layer](#data-layer)
4. [Business Logic Layer](#business-logic-layer)
5. [Presentation Layer](#presentation-layer)
6. [Key Features Implementation](#key-features-implementation)
7. [Data Flow](#data-flow)
8. [Technology Stack](#technology-stack)
9. [Detailed File-by-File Walkthrough](#detailed-file-by-file-walkthrough)
10. [Core Data Model Deep Dive](#core-data-model-deep-dive)
11. [ViewModels Detailed Implementation](#viewmodels-detailed-implementation)
12. [Services Layer Deep Dive](#services-layer-deep-dive)
13. [Complete Feature Implementation Guide](#complete-feature-implementation-guide)

## Overview

CalendarNotes is a macOS/iOS application built with SwiftUI that combines calendar management, note-taking, and task tracking in a unified interface. The app uses Core Data for local persistence and is designed with MVVM architecture patterns.

### Core Capabilities

- **Calendar Events Management**: Create, edit, and delete events with categories and recurring patterns
- **Note Taking**: Rich text notes with markdown support, voice transcription, and date linking
- **Task Management**: Todo items with priorities, due dates, and completion tracking
- **Cloud Sync**: iCloud integration for data synchronization across devices
- **Notifications**: Event reminders and task notifications
- **Sample Data Generator**: Testing utilities for demo and development

## System Architecture

### Architecture Pattern: MVVM (Model-View-ViewModel)

```
┌─────────────────────────────────────────────────────────────┐
│                     Presentation Layer                       │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │     Views    │  │   ViewModels │  │   Services   │      │
│  │   (SwiftUI)  │  │  (Observable)│  │  (Business)  │      │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘      │
└─────────┼─────────────────┼─────────────────┼───────────────┘
          │                 │                 │
          └─────────────────┴─────────────────┘
                            │
┌───────────────────────────┼───────────────────────────┐
│                    Data Layer                          │
│  ┌──────────────────────────────────────────────┐    │
│  │           Core Data Manager                  │    │
│  │  (Persistence, CRUD, Queries, Transactions)  │    │
│  └──────────────────────────────────────────────┘    │
│                          │                            │
│  ┌──────────────────────────────────────────────┐    │
│  │           Data Models (NSManagedObject)      │    │
│  │  - CalendarEvent  - Note  - TodoItem        │    │
│  └──────────────────────────────────────────────┘    │
└───────────────────────────┼───────────────────────────┘
                            │
                   ┌────────┴────────┐
                   │   CloudKit      │
                   │   (Sync)        │
                   └─────────────────┘
```

## Data Layer

### Core Data Manager (`CoreDataManager.swift`)

The Core Data Manager is the central component for all database operations. It follows a singleton pattern to ensure a single point of access to the persistent store.

#### Key Responsibilities:

1. **Container Management**: Initializes and manages the `NSPersistentCloudKitContainer`
2. **Context Management**: Provides both view context and background contexts for thread-safe operations
3. **CRUD Operations**: Generic fetch, save, update, and delete methods
4. **Query Methods**: Specialized queries for events, notes, and tasks
5. **Batch Operations**: Efficient bulk operations for data management

#### Core Implementation:

```swift
class CoreDataManager {
    static let shared = CoreDataManager()
    let persistentContainer: NSPersistentCloudKitContainer

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    // Generic fetch with support for predicates and sorting
    func fetch<T: NSManagedObject>(_ request: NSFetchRequest<T>) throws -> [T]

    // Background task execution
    func performBackgroundTask<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T
}
```

### Data Models

#### CalendarEvent

- **Properties**: title, startDate, endDate, category, location, notes, isRecurring, recurrenceRule
- **Relationships**: None (standalone events)
- **Features**: Supports recurring events with customizable rules

#### Note

- **Properties**: content, createdDate, linkedDate, tags
- **Relationships**: None
- **Features**: Optional date linking, tag support, markdown rendering

#### TodoItem

- **Properties**: title, priority, category, dueDate, isCompleted, isRecurring
- **Relationships**: None
- **Features**: Priority levels (Low, Medium, High, Urgent), completion tracking

## Business Logic Layer

### ViewModels

ViewModels act as the intermediary between Views and the data layer, handling:

- State management using `@Published` properties
- Business logic and validation
- User action handling
- Data transformation

#### Example: NoteEditorViewModel

```swift
@MainActor
class NoteEditorViewModel: ObservableObject {
    // Published properties for UI binding
    @Published var content: String = ""
    @Published var linkedDate: Date?
    @Published var tags: [String] = []

    // Formatting state
    @Published var isBoldActive: Bool = false
    @Published var isItalicActive: Bool = false

    // Actions
    func saveNote() async throws
    func toggleBold()
    func toggleItalic()
}
```

### Services Layer

#### NotificationManager

- Manages local notifications for events and tasks
- Schedules reminders based on user preferences
- Handles notification permissions

#### CalendarService

- Integrates with EventKit for system calendar sync
- Manages calendar permissions
- Performs bidirectional sync between app and iOS Calendar

#### CloudKitManager

- Handles iCloud synchronization
- Manages CloudKit records and zones
- Resolves sync conflicts

## Presentation Layer

### View Hierarchy

The app uses a tab-based navigation structure:

```
MainTabView
├── CalendarView (Calendar with events)
├── NotesView (List of notes)
├── TasksView (Task management)
└── SettingsView (App configuration)
```

### View Components

#### CalendarView

- **Purpose**: Display calendar with events
- **Key Features**:
  - Monthly, weekly, and daily views
  - Event creation and editing
  - Drag-and-drop event management
  - Quick event creation from empty slots

#### NotesView

- **Purpose**: Manage notes
- **Key Features**:
  - List and grid layouts
  - Search and filtering
  - Rich text editor
  - Voice recording integration

#### EnhancedTasksView

- **Purpose**: Task management
- **Key Features**:
  - Priority-based filtering
  - Due date sorting
  - Swipe actions (complete, delete)
  - Recurring task support

#### NoteEditorView

- **Purpose**: Rich text note editing
- **Key Features**:
  - Markdown formatting toolbar
  - Voice transcription
  - Date linking
  - Tag management

## Key Features Implementation

### 1. Rich Text Editing with Markdown

The app implements a custom markdown parser and renderer for formatting:

```swift
// Formatting is handled through markdown syntax:
**bold text** → Bold formatting
*italic text* → Italic formatting
- List item → Bullet list
1. Item → Numbered list
```

**Implementation**:

- Parses markdown during editing
- Stores as plain text with markdown syntax
- Renders formatted preview on demand

### 2. Voice Recording & Transcription

Uses Speech framework for voice-to-text conversion:

```swift
class SpeechRecognitionService: NSObject, ObservableObject {
    private let speechRecognizer = SFSpeechRecognizer()
    private let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()

    func startRecognition() async throws -> String
}
```

### 3. Calendar Event Sync with EventKit

Bidirectional sync with iOS Calendar:

```swift
class EventKitManager {
    private let eventStore = EKEventStore()

    func performFullSync() async throws -> SyncStats
    func createEvent(from appEvent: CalendarEvent) -> EKEvent
    func updateEvent(_ event: EKEvent, from appEvent: CalendarEvent)
}
```

### 4. Notification System

Smart notification scheduling:

```swift
class NotificationManager {
    func scheduleEventReminder(for event: CalendarEvent)
    func scheduleTaskReminder(for task: TodoItem)
    func scheduleDailySummary()
}
```

### 5. Sample Data Generator

Utility for testing and demos:

```swift
class SampleDataGenerator {
    func generateSampleData() throws {
        // 30 random events
        // 20 sample notes
        // 15 tasks with mixed priorities
    }
}
```

## Data Flow

### Creating a New Event

```
1. User taps "+" → CreateEventView appears
2. User fills event details → ViewModel captures input
3. User taps "Save" → ViewModel.save() called
4. ViewModel calls CoreDataManager.createEvent()
5. CoreDataManager saves to persistent store
6. Changes propagate to view context
7. UI updates automatically via @Published properties
8. CloudKit syncs to iCloud (if enabled)
```

### Editing a Note

```
1. User opens note → NoteEditorView loads
2. NoteEditorViewModel initializes with note data
3. User edits content → @Published properties update
4. Formatting buttons → Markdown syntax inserted
5. User taps "Save" → ViewModel updates Core Data
6. Changes saved to persistent store
7. UI reflects changes immediately
```

### Task Completion Flow

```
1. User swipes task → SwipeActions appear
2. User taps "Complete" → Action handler invoked
3. ViewModel updates isCompleted = true
4. CoreDataManager.save() persists change
5. View automatically removes from active list
6. Notification for task is cancelled (if pending)
7. Task moves to completed section
```

## Technology Stack

### Core Frameworks

- **SwiftUI**: UI framework for declarative interfaces
- **Core Data**: Object graph and persistence framework
- **CloudKit**: iCloud sync and storage
- **EventKit**: iOS calendar integration
- **Speech**: Voice recognition
- **UserNotifications**: Local notifications

### Design Patterns

- **MVVM**: Model-View-ViewModel architecture
- **Singleton**: CoreDataManager, NotificationManager
- **Repository**: Data access abstraction
- **Observer**: @Published properties for reactive UI
- **Factory**: Model creation helpers

### Key Design Principles

1. **Separation of Concerns**: Clear boundaries between layers
2. **Dependency Injection**: Services injected into ViewModels
3. **Single Responsibility**: Each class has one clear purpose
4. **DRY**: Shared utilities and helpers
5. **Testability**: ViewModels isolated from UI for testing

## File Structure

```
CalendarNotes/
├── Models/
│   ├── CalendarEventExtension.swift
│   ├── NoteExtension.swift
│   ├── TodoItemExtension.swift
│   └── NotificationExtensions.swift
├── ViewModels/
│   ├── CalendarViewModel.swift
│   ├── NoteEditorViewModel.swift
│   ├── SettingsViewModel.swift
│   └── TaskViewModel.swift
├── Views/
│   ├── CalendarView.swift
│   ├── NoteEditorView.swift
│   ├── NotesView.swift
│   ├── EnhancedTasksView.swift
│   └── SettingsView.swift
├── Services/
│   ├── NotificationManager.swift
│   ├── CalendarService.swift
│   └── EventKitManager.swift
├── Utilities/
│   ├── CoreDataManager.swift
│   ├── CloudKitManager.swift
│   ├── SampleDataGenerator.swift
│   └── ThemeManager.swift
└── CalendarNotes.xcdatamodeld/
    └── CalendarNotes.xcdatamodel
```

## End-to-End: Creating and Managing an Event

### Step 1: User Interaction

User navigates to Calendar tab and taps an empty time slot.

### Step 2: View Creation

`CalendarView` detects tap and presents `CreateEventView`.

### Step 3: Data Entry

User enters event details:

- Title: "Team Meeting"
- Start: Tomorrow 2:00 PM
- End: Tomorrow 3:00 PM
- Category: "Work"

### Step 4: ViewModel Processing

`CreateEventViewModel` captures input:

```swift
@Published var title: String = ""
@Published var startDate: Date = Date()
@Published var selectedCategory: String = "Work"
```

### Step 5: Validation

ViewModel validates:

- Title is not empty
- End date is after start date
- Category is valid

### Step 6: Persistence

On save:

```swift
let event = try CoreDataManager.shared.createEvent(
    title: title,
    startDate: startDate,
    endDate: endDate,
    category: category
)
```

### Step 7: Core Data Save

CoreDataManager saves to SQLite database.

### Step 8: CloudKit Sync (if enabled)

Changes pushed to iCloud and synced to other devices.

### Step 9: Notification Scheduling

If enabled, notification scheduled:

```swift
NotificationManager.shared.scheduleEventReminder(for: event)
```

### Step 10: UI Update

ViewContext updates trigger `@Published` properties.
`CalendarView` automatically re-renders to show new event.

## Performance Optimizations

1. **Lazy Loading**: Views load data on-demand
2. **Pagination**: Lists fetch in batches
3. **Background Contexts**: Heavy operations off main thread
4. **Batch Operations**: Efficient bulk updates
5. **Image Caching**: Asset caching for UI performance

## Testing Strategy

- **Unit Tests**: ViewModels and business logic
- **Integration Tests**: Core Data operations
- **UI Tests**: User workflows
- **Performance Tests**: Large dataset handling

## Future Enhancements

1. Widget support (iOS, macOS)
2. Siri Shortcuts integration
3. Apple Watch app
4. Collaborative sharing
5. Advanced recurring patterns
6. File attachments in notes
7. Export to PDF/Calendar formats

## Project Statistics & Status

### Current Project Statistics

- **Total Swift Files**: 70
- **Total Lines of Code**: ~30,224
- **Total View Code**: ~17,346 lines
- **Platform**: iOS 15.0+ / macOS 12.0+
- **Architecture**: MVVM (Model-View-ViewModel)
- **Build Status**: ✅ Clean (No errors or warnings)

### Code Quality Status

- **TODO Items**: 0 (All resolved)
- **FIXME Items**: 0
- **Compiler Warnings**: 0
- **Test Coverage**: Needs improvement (estimated < 5%)

### Critical Improvements Needed

#### 🔴 URGENT - Code Organization

1. **CalendarView.swift (3,921 lines)** - Needs splitting into separate files
2. **SettingsView.swift (1,283 lines)** - Should be split into sections
3. **EnhancedTaskEditorView.swift (1,106 lines)** - Extract subviews

#### 🟡 HIGH PRIORITY

1. **Service Duplication** - Multiple overlapping services need consolidation
2. **Naming Convention** - Remove "Enhanced" and "Optimized" prefixes
3. **State Management** - Move more state to ViewModels

#### 🟢 MEDIUM PRIORITY

1. **Unit Tests** - Add comprehensive test coverage (target: 70%+)
2. **Error Handling** - Implement comprehensive error handling
3. **Performance** - Add fetch limits, pagination, and caching

### Recent Accomplishments

- ✅ Fixed TODO: Task editor opens from calendar view
- ✅ Created launch screen with animations
- ✅ Implemented app icon design specifications
- ✅ Fixed all compiler warnings
- ✅ Clean build with no errors

### Quality Checklist

#### Navigation & Flow

- [x] Task editor opens from calendar view
- [ ] All navigation transitions tested
- [ ] Deep link handling implemented

#### Layout & Spacing

- [ ] Tested on all iPhone sizes (SE to Pro Max)
- [ ] Tested on iPad
- [ ] Safe area handling verified

#### Memory Management

- [ ] No retain cycles detected
- [ ] Weak/unowned captures verified
- [ ] Proper cleanup implemented

#### User Experience

- [x] Dark mode support
- [x] Smooth animations
- [ ] Accessibility (VoiceOver) tested
- [ ] Haptic feedback added

## Conclusion

CalendarNotes is a well-architected application with comprehensive features, modern Swift/SwiftUI implementation, and a solid MVVM architecture foundation. The app demonstrates good separation of concerns, proper data management, and an excellent user experience.

**Key Strengths**:

- Comprehensive feature set
- Modern Swift/SwiftUI implementation
- Good architecture foundation
- Rich user experience

**Critical Areas for Improvement**:

- Code organization (massive files)
- Service duplication
- Test coverage
- Documentation

**Next Steps**:

1. Refactor large files (CalendarView.swift, SettingsView.swift)
2. Consolidate duplicate services
3. Add comprehensive unit tests
4. Improve documentation

With focused refactoring and improvements, CalendarNotes can become a production-ready, maintainable, and scalable application.

## Detailed File-by-File Walkthrough

### Models Directory

#### CalendarEventExtension.swift

**File Location**: `CalendarNotes/Models/CalendarEventExtension.swift`  
**Purpose**: Core Data model for calendar events with convenience initializers and computed properties.

**Key Components**:

```swift
// CalendarNotes/Models/CalendarEventExtension.swift
extension CalendarEvent {
    convenience init(
        context: NSManagedObjectContext,
        title: String,
        startDate: Date,
        endDate: Date,
        category: String,
        location: String? = nil,
        notes: String? = nil,
        isRecurring: Bool = false,
        recurrenceRule: String? = nil
    ) {
        self.init(context: context)
        self.id = UUID()
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.category = category
        self.location = location
        self.notes = notes
        self.isRecurring = isRecurring
        self.recurrenceRule = recurrenceRule
    }
}
```

**Explanation**:

- Uses convenience initializer pattern for Core Data
- Automatically generates UUID for each event
- All parameters except location and notes are required
- Supports recurring events with customizable rules

#### NoteExtension.swift

**File Location**: `CalendarNotes/Models/NoteExtension.swift`  
**Purpose**: Note model with tagging support and computed properties.

**Key Components**:

```swift
// CalendarNotes/Models/NoteExtension.swift
extension Note {
    convenience init(
        context: NSManagedObjectContext,
        content: String,
        linkedDate: Date? = nil,
        tags: String? = nil
    ) {
        self.init(context: context)
        self.id = UUID()
        self.content = content
        self.createdDate = Date()
        self.linkedDate = linkedDate
        self.tags = tags
    }

    var tagArray: [String] {
        get {
            guard let tags = tags else { return [] }
            return tags.components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces) }
        }
        set {
            tags = newValue.joined(separator: ", ")
        }
    }
}
```

**Explanation**:

- Stores tags as comma-separated string in Core Data
- Provides computed property `tagArray` for array-based manipulation
- Automatically sets creation date on initialization
- Optional date linking for calendar integration

#### TodoItemExtension.swift

**File Location**: `CalendarNotes/Models/TodoItemExtension.swift`  
**Purpose**: Task management model with priority enum and convenience methods.

**Key Components**:

```swift
// CalendarNotes/Models/TodoItemExtension.swift
extension TodoItem {
    convenience init(
        context: NSManagedObjectContext,
        title: String,
        priority: String,
        category: String,
        dueDate: Date? = nil,
        isCompleted: Bool = false,
        isRecurring: Bool = false
    ) {
        self.init(context: context)
        self.id = UUID()
        self.title = title
        self.priority = priority
        self.category = category
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.isRecurring = isRecurring
    }

    enum Priority: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case urgent = "Urgent"
    }

    var priorityEnum: Priority {
        get { Priority(rawValue: priority ?? "Medium") ?? .medium }
        set { priority = newValue.rawValue }
    }
}
```

**Explanation**:

- Priority stored as String in Core Data for flexibility
- Provides type-safe `Priority` enum with computed property
- Supports recurring tasks
- Completion tracking with boolean flag

### ViewModels Directory

#### NoteEditorViewModel.swift

**File Location**: `CalendarNotes/ViewModels/NoteEditorViewModel.swift`  
**Purpose**: Manages note editing state, formatting, and persistence.

**Key Properties**:

```swift
// CalendarNotes/ViewModels/NoteEditorViewModel.swift
@MainActor
class NoteEditorViewModel: ObservableObject {
    @Published var content: String = ""
    @Published var linkedDate: Date?
    @Published var tags: [String] = []
    @Published var isBoldActive: Bool = false
    @Published var isItalicActive: Bool = false
    @Published var isBulletListActive: Bool = false
    @Published var isNumberedListActive: Bool = false
    @Published var isRecording: Bool = false
    @Published var canUndo: Bool = false
    @Published var canRedo: Bool = false
}
```

**Key Methods**:

```swift
// CalendarNotes/ViewModels/NoteEditorViewModel.swift
func toggleBold() {
    let currentText = content
    let selectedRange = selectedTextRange

    if isBoldActive {
        // Remove bold formatting
        content = currentText.replacingOccurrences(of: "**", with: "")
    } else {
        // Add bold formatting
        content = "**\(selectedText)** "
    }
    updateFormattingState()
}

func saveNote() async throws {
    guard !content.isEmpty else { return }

    let context = CoreDataManager.shared.viewContext

    let note = Note(
        context: context,
        content: content,
        linkedDate: linkedDate,
        tags: tags.joined(separator: ", ")
    )

    try CoreDataManager.shared.save(context: context)
}
```

**Explanation**:

- Uses `@MainActor` to ensure UI updates on main thread
- Tracks formatting state for toolbar buttons
- Implements undo/redo functionality
- Integrates with Speech framework for voice recording

#### SettingsViewModel.swift

**File Location**: `CalendarNotes/ViewModels/SettingsViewModel.swift`  
**Purpose**: Manages app settings, preferences, and data management.

**Key Properties**:

```swift
// CalendarNotes/ViewModels/SettingsViewModel.swift
@MainActor
class SettingsViewModel: ObservableObject {
    @AppStorage("userName") var userName: String = ""
    @AppStorage("userEmail") var userEmail: String = ""
    @AppStorage("defaultCalendarView") var defaultCalendarView: String = "Month"
    @AppStorage("notificationsEnabled") var notificationsEnabled: Bool = true
    @AppStorage("iCloudSyncEnabled") var iCloudSyncEnabled: Bool = false

    @Published var isExporting = false
    @Published var isGeneratingSampleData = false
    @Published var sampleDataMessage = ""
}
```

**Key Methods**:

```swift
// CalendarNotes/ViewModels/SettingsViewModel.swift
func generateSampleData() async {
    isGeneratingSampleData = true
    sampleDataMessage = ""

    do {
        let context = CoreDataManager.shared.viewContext
        try SampleDataGenerator.shared.generateSampleData(context: context)
        sampleDataMessage = "Sample data generated successfully!"
    } catch {
        sampleDataMessage = "Error: \(error.localizedDescription)"
    }

    isGeneratingSampleData = false
}

func exportData() async {
    isExporting = true
    let coreDataManager = CoreDataManager.shared

    let events = try coreDataManager.fetch(CalendarEvent.fetchRequest())
    let notes = try coreDataManager.fetch(Note.fetchRequest())
    let tasks = try coreDataManager.fetch(TodoItem.fetchRequest())

    // Convert to JSON and save
    let exportData: [String: Any] = [
        "exportDate": Date().ISO8601Format(),
        "events": events.map { eventToDict($0) },
        "notes": notes.map { noteToDict($0) },
        "tasks": tasks.map { taskToDict($0) }
    ]

    // Save to file
    let jsonData = try JSONSerialization.data(withJSONObject: exportData)
    // ... file handling
}
```

**Explanation**:

- Uses `@AppStorage` for persistent user preferences
- Manages async operations for data export/import
- Handles sample data generation with progress feedback
- Implements data serialization for backup

#### TasksViewModel.swift

**File Location**: `CalendarNotes/ViewModels/TasksViewModel.swift`  
**Purpose**: Manages task list state, filtering, and operations.

**Key Implementation**:

```swift
// CalendarNotes/ViewModels/TasksViewModel.swift
@MainActor
class TasksViewModel: ObservableObject {
    @Published var tasks: [TodoItem] = []
    @Published var selectedPriority: String? = nil
    @Published var selectedCategory: String? = nil
    @Published var showCompletedTasks: Bool = false
    @Published var searchText: String = ""

    func loadTasks() {
        let context = CoreDataManager.shared.viewContext
        let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()

        var predicates: [NSPredicate] = []

        if !showCompletedTasks {
            predicates.append(NSPredicate(format: "isCompleted == NO"))
        }

        if let priority = selectedPriority {
            predicates.append(NSPredicate(format: "priority == %@", priority))
        }

        if !searchText.isEmpty {
            predicates.append(NSPredicate(format: "title CONTAINS[cd] %@", searchText))
        }

        if !predicates.isEmpty {
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        }

        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \TodoItem.isCompleted, ascending: true),
            NSSortDescriptor(keyPath: \TodoItem.dueDate, ascending: true)
        ]

        do {
            tasks = try context.fetch(request)
        } catch {
            print("Failed to load tasks: \(error)")
        }
    }

    func toggleTaskCompletion(_ task: TodoItem) {
        task.isCompleted.toggle()
        try? CoreDataManager.shared.save()
        loadTasks()
    }
}
```

**Explanation**:

- Dynamic filtering with multiple predicates
- Search functionality with case-insensitive matching
- Sorting by completion status and due date
- Automatic refresh after state changes

### Utilities Directory

#### CoreDataManager.swift - Complete Walkthrough

**File Location**: `CalendarNotes/Utilities/CoreDataManager.swift`  
**Lines**: 508 total lines  
**Purpose**: Centralized Core Data management

**Section 1: Error Handling (Lines 1-45)**

```swift
// CalendarNotes/Utilities/CoreDataManager.swift (Lines 1-45)
enum CoreDataError: Error {
    case saveFailed(String)
    case fetchFailed(String)
    case updateFailed(String)
    case deleteFailed(String)
    case batchOperationFailed(String)
    case invalidContext
    case objectNotFound

    var localizedDescription: String {
        switch self {
        case .saveFailed(let message):
            return "Save failed: \(message)"
        // ... other cases
        }
    }
}
```

**Purpose**: Provides type-safe error handling with user-friendly messages.

**Section 2: Singleton Pattern (Lines 46-90)**

```swift
// CalendarNotes/Utilities/CoreDataManager.swift (Lines 46-90)
class CoreDataManager {
    static let shared = CoreDataManager()

    let persistentContainer: NSPersistentCloudKitContainer
    private let backgroundQueue = DispatchQueue(
        label: "com.calendarnotes.coredata.background",
        qos: .userInitiated
    )

    var viewContext: NSManagedObjectContext {
        persistentContainer.viewContext
    }

    @Published private(set) var isSyncing: Bool = false

    private init() {
        persistentContainer = NSPersistentCloudKitContainer(name: "CalendarNotes")
        configurePersistentStore()
        // ... initialization
    }
}
```

**Purpose**: Ensures single point of access to Core Data stack.

**Section 3: Context Management (Lines 140-170)**

```swift
// CalendarNotes/Utilities/CoreDataManager.swift (Lines 140-170)
func newBackgroundContext() -> NSManagedObjectContext {
    let context = persistentContainer.newBackgroundContext()
    context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    context.automaticallyMergesChangesFromParent = true
    return context
}

func performBackgroundTask<T>(
    _ block: @escaping (NSManagedObjectContext) throws -> T
) async throws -> T {
    try await withCheckedThrowingContinuation { continuation in
        persistentContainer.performBackgroundTask { context in
            do {
                let result = try block(context)
                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

**Purpose**: Provides thread-safe background operations.

**Section 4: CRUD Operations (Lines 180-250)**

```swift
// CalendarNotes/Utilities/CoreDataManager.swift (Lines 180-250)
func fetch<T: NSManagedObject>(
    _ request: NSFetchRequest<T>,
    context: NSManagedObjectContext? = nil
) throws -> [T] {
    let contextToUse = context ?? viewContext
    do {
        return try contextToUse.fetch(request)
    } catch {
        throw CoreDataError.fetchFailed(error.localizedDescription)
    }
}

func save(context: NSManagedObjectContext? = nil) throws {
    let contextToSave = context ?? viewContext
    guard contextToSave.hasChanges else { return }

    do {
        try contextToSave.save()
    } catch {
        throw CoreDataError.saveFailed(error.localizedDescription)
    }
}

func delete<T: NSManagedObject>(
    _ object: T,
    context: NSManagedObjectContext? = nil
) throws {
    let contextToUse = context ?? viewContext
    contextToUse.delete(object)
    try save(context: contextToUse)
}
```

**Purpose**: Generic CRUD operations with error handling.

**Section 5: Query Methods (Lines 320-450)**

```swift
// CalendarNotes/Utilities/CoreDataManager.swift (Lines 320-450)
func fetchEvents(
    from startDate: Date? = nil,
    to endDate: Date? = nil,
    context: NSManagedObjectContext? = nil
) throws -> [CalendarEvent] {
    let request: NSFetchRequest<CalendarEvent> = CalendarEvent.fetchRequest()

    var predicates: [NSPredicate] = []
    if let startDate = startDate {
        predicates.append(NSPredicate(format: "startDate >= %@", startDate as NSDate))
    }
    if let endDate = endDate {
        predicates.append(NSPredicate(format: "startDate <= %@", endDate as NSDate))
    }

    if !predicates.isEmpty {
        request.predicate = NSCompoundPredicate(
            andPredicateWithSubpredicates: predicates
        )
    }

    request.sortDescriptors = [
        NSSortDescriptor(keyPath: \CalendarEvent.startDate, ascending: true)
    ]

    return try fetch(request, context: context)
}

func fetchNotes(
    linkedToDate date: Date? = nil,
    context: NSManagedObjectContext? = nil
) throws -> [Note] {
    let request: NSFetchRequest<Note> = Note.fetchRequest()

    if let date = date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        request.predicate = NSPredicate(
            format: "linkedDate >= %@ AND linkedDate < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
    }

    request.sortDescriptors = [
        NSSortDescriptor(keyPath: \Note.createdDate, ascending: false)
    ]

    return try fetch(request, context: context)
}

func fetchTodoItems(
    completed: Bool? = nil,
    context: NSManagedObjectContext? = nil
) throws -> [TodoItem] {
    let request: NSFetchRequest<TodoItem> = TodoItem.fetchRequest()

    if let completed = completed {
        request.predicate = NSPredicate(
            format: "isCompleted == %@",
            NSNumber(value: completed)
        )
    }

    request.sortDescriptors = [
        NSSortDescriptor(keyPath: \TodoItem.isCompleted, ascending: true),
        NSSortDescriptor(keyPath: \TodoItem.dueDate, ascending: true)
    ]

    return try fetch(request, context: context)
}
```

**Purpose**: Specialized queries for each entity type with date range and status filtering.

**Section 6: Convenience Methods (Lines 460-508)**

```swift
// CalendarNotes/Utilities/CoreDataManager.swift (Lines 460-508)
@discardableResult
func createEvent(
    title: String,
    startDate: Date,
    endDate: Date,
    category: String,
    location: String? = nil,
    notes: String? = nil,
    isRecurring: Bool = false,
    recurrenceRule: String? = nil
) throws -> CalendarEvent {
    let event = CalendarEvent(
        context: viewContext,
        title: title,
        startDate: startDate,
        endDate: endDate,
        category: category,
        location: location,
        notes: notes,
        isRecurring: isRecurring,
        recurrenceRule: recurrenceRule
    )
    try save()
    return event
}

@discardableResult
func createNote(
    content: String,
    linkedDate: Date? = nil,
    tags: String? = nil
) throws -> Note {
    let note = Note(
        context: viewContext,
        content: content,
        linkedDate: linkedDate,
        tags: tags
    )
    try save()
    return note
}

@discardableResult
func createTodoItem(
    title: String,
    priority: String,
    category: String,
    dueDate: Date? = nil,
    isCompleted: Bool = false,
    isRecurring: Bool = false
) throws -> TodoItem {
    let todo = TodoItem(
        context: viewContext,
        title: title,
        priority: priority,
        category: category,
        dueDate: dueDate,
        isCompleted: isCompleted,
        isRecurring: isRecurring
    )
    try save()
    return todo
}
```

**Purpose**: High-level factory methods for creating entities with automatic save.

#### SampleDataGenerator.swift - Detailed Explanation

**File Location**: `CalendarNotes/Utilities/SampleDataGenerator.swift`  
**Purpose**: Generates realistic sample data for testing and demos.

**Data Structure**:

```swift
// CalendarNotes/Utilities/SampleDataGenerator.swift
class SampleDataGenerator {
    // Event data
    private let eventTitles = [
        "Team Meeting", "Client Presentation", "Lunch with Colleagues", ...
    ]

    // Location data
    private let locations = [
        "Conference Room A", "Starbucks", "Central Park", nil, nil, nil
    ]

    // Categories
    private let categories = [
        "Work", "Personal", "Health", "Social", "Family", "Education"
    ]

    // Note content templates
    private let noteContents = [
        "Great insights from today's meeting...",
        "Remember to follow up...",
        ...
    ]

    // Task titles
    private let taskTitles = [
        "Complete quarterly report",
        "Pay utility bills",
        ...
    ]
}
```

**Generation Logic**:

```swift
// CalendarNotes/Utilities/SampleDataGenerator.swift
func generateSampleData(context: NSManagedObjectContext) throws {
    let calendar = Calendar.current
    let now = Date()

    // Get current month range
    let startOfMonth = calendar.date(
        from: calendar.dateComponents([.year, .month], from: now)
    )!
    let endOfMonth = calendar.date(
        byAdding: DateComponents(month: 1, day: -1),
        to: startOfMonth
    )!
    let daysInMonth = calendar.dateComponents(
        [.day], from: startOfMonth, to: endOfMonth
    ).day ?? 30

    // Generate data
    try generateEvents(
        count: 30,
        startDate: startOfMonth,
        endDate: endOfMonth,
        daysInMonth: daysInMonth,
        context: context
    )

    try generateNotes(count: 20, context: context)
    try generateTasks(count: 15, context: context)

    try CoreDataManager.shared.save(context: context)
}

private func generateEvents(
    count: Int,
    startDate: Date,
    endDate: Date,
    daysInMonth: Int,
    context: NSManagedObjectContext
) throws {
    for _ in 0..<count {
        // Random day
        let randomDay = Int.random(in: 0..<daysInMonth)
        guard let eventDate = Calendar.current.date(
            byAdding: .day,
            value: randomDay,
            to: startDate
        ) else { continue }

        // Random hour between 8 AM and 8 PM
        let hour = Int.random(in: 8...20)
        let minute = [0, 15, 30, 45].randomElement()!
        guard let startDateTime = Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: eventDate
        ) else { continue }

        // Duration between 1 and 4 hours
        let durationHours = [1, 1.5, 2, 2.5, 3, 4].randomElement()!
        guard let endDateTime = Calendar.current.date(
            byAdding: .hour,
            value: Int(durationHours),
            to: startDateTime
        ) else { continue }

        // Random attributes
        let title = eventTitles.randomElement()!
        let category = categories.randomElement()!
        let location = locations.randomElement() ?? nil
        let notes = Bool.random() ? "Additional notes" : nil

        // 20% are recurring
        let isRecurring = Int.random(in: 0..<100) < 20
        let recurrenceRule = isRecurring ? generateRecurrenceRule() : nil

        _ = CalendarEvent(
            context: context,
            title: title,
            startDate: startDateTime,
            endDate: endDateTime,
            category: category,
            location: location,
            notes: notes,
            isRecurring: isRecurring,
            recurrenceRule: recurrenceRule
        )
    }
}
```

**Explanation**:

- Generates 30 events spread across current month
- Creates 20 notes with varied dates and content
- Produces 15 tasks with mixed priorities and completion states
- Some events/tasks are recurring (20% probability)
- Realistic time ranges and durations

### Services Directory

#### NotificationManager.swift

**File Location**: `CalendarNotes/Services/NotificationManager.swift`  
**Purpose**: Manages local notifications for events and tasks.

**Key Implementation**:

```swift
// CalendarNotes/Services/NotificationManager.swift
class NotificationManager {
    static let shared = NotificationManager()

    private let notificationCenter = UNUserNotificationCenter.current()
    private var notificationIdentifiers: [String] = []

    func requestPermission() async throws -> Bool {
        let settings = try await notificationCenter.requestAuthorization(
            options: [.alert, .sound, .badge]
        )
        return settings
    }

    func scheduleEventReminder(for event: CalendarEvent) {
        guard let title = event.title,
              let startDate = event.startDate else { return }

        // Schedule 15 minutes before
        let reminderDate = startDate.addingTimeInterval(-15 * 60)

        let content = UNMutableNotificationContent()
        content.title = "Event Reminder"
        content.body = "\(title) starts in 15 minutes"
        content.sound = .default
        content.categoryIdentifier = "EVENT_REMINDER"

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: reminderDate
            ),
            repeats: false
        )

        let identifier = "event_\(event.id?.uuidString ?? UUID().uuidString)"
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        notificationCenter.add(request)
        notificationIdentifiers.append(identifier)
    }
}
```

**Explanation**:

- Uses UNUserNotificationCenter for local notifications
- Schedules reminders 15 minutes before events
- Tracks notification IDs for cancellation
- Supports different notification types

## Core Data Model Deep Dive

### Entity Relationships

```
CalendarEvent
├── id: UUID
├── title: String
├── startDate: Date
├── endDate: Date
├── category: String
├── location: String (optional)
├── notes: String (optional)
├── isRecurring: Bool
└── recurrenceRule: String (optional)

Note
├── id: UUID
├── content: String
├── createdDate: Date
├── linkedDate: Date (optional)
└── tags: String (optional)

TodoItem
├── id: UUID
├── title: String
├── priority: String
├── category: String
├── dueDate: Date (optional)
├── isCompleted: Bool
└── isRecurring: Bool
```

### Data Validation

```swift
// In Core Data model
// CalendarEvent validation
- title: Required, maxLength: 100
- startDate: Required, must be before endDate
- category: Required, must be in allowed categories

// Note validation
- content: Required, minLength: 1
- createdDate: Auto-generated, required

// TodoItem validation
- title: Required, maxLength: 100
- priority: Required, must be "Low", "Medium", "High", or "Urgent"
```

## Complete Feature Implementation Guide

### Feature: Rich Text Note Editor

**Components Involved**:

1. `NoteEditorView.swift` - UI
2. `NoteEditorViewModel.swift` - Logic
3. `MarkdownParser.swift` - Formatting
4. `SpeechRecognitionService.swift` - Voice input

**Data Flow**:

```
User Input → TextField → @Published content
                ↓
    Formatting Buttons → Toggle Markdown Syntax
                ↓
    Voice Button → SpeechRecognition → Append Text
                ↓
    Save Button → ViewModel.saveNote()
                ↓
    CoreDataManager.createNote()
                ↓
    Save to Persistent Store
```

**Implementation Details**:

```swift
// CalendarNotes/ViewModels/NoteEditorViewModel.swift
// Markdown syntax insertion
func toggleBold() {
    let selected = getSelectedText()
    content = content.replacingOccurrences(
        of: selected,
        with: "**\(selected)**"
    )
    updateFormattingState()
}

// Voice transcription
func startVoiceRecording() async {
    let result = await speechService.startRecognition()
    content.append(result)
}
```

## Testing Strategy

### Unit Tests Example

```swift
// CalendarNotesTests/CoreDataManagerTests.swift
class CoreDataManagerTests: XCTestCase {
    func testEventCreation() throws {
        let event = try CoreDataManager.shared.createEvent(
            title: "Test Event",
            startDate: Date(),
            endDate: Date().addingTimeInterval(3600),
            category: "Work"
        )

        XCTAssertEqual(event.title, "Test Event")
        XCTAssertNotNil(event.id)
    }

    func testNoteFetching() throws {
        let notes = try CoreDataManager.shared.fetch(
            Note.fetchRequest()
        )
        XCTAssertGreaterThan(notes.count, 0)
    }
}
```

## Performance Optimizations

1. **Batch Fetching**: Use fetch limits and predicates
2. **Lazy Loading**: Load data on-demand
3. **Background Contexts**: Heavy operations off main thread
4. **Pagination**: Load items in chunks
5. **Caching**: Cache frequently accessed data
