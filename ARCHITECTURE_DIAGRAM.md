# CalendarNotes Swift Architecture - Quick Reference

## 📊 Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      PRESENTATION LAYER                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐           │
│  │   Views     │  │  ViewModels │  │  Widgets    │           │
│  │ (SwiftUI)   │←→│  (Combine)  │←→│  (iOS/macOS)│           │
│  └─────────────┘  └─────────────┘  └─────────────┘           │
└─────────────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────────┐
│                     BUSINESS LOGIC LAYER                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │   Services   │  │  Repositories│  │  Managers    │        │
│  │ (Domain)     │←→│  (API/Data)  │←→│  (State)     │        │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
└─────────────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────────┐
│                       DATA ACCESS LAYER                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │ CoreDataMgr  │  │  APIClient   │  │ KeychainMgr  │        │
│  │  (Local DB)  │  │  (Network)   │  │  (Secure)    │        │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
└─────────────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────────────┐
│                      PERSISTENCE LAYER                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │   CoreData   │  │   CloudKit   │  │   Keychain   │        │
│  │  (SQLite)    │  │  (iCloud)    │  │  (Tokens)    │        │
│  └──────────────┘  └──────────────┘  └──────────────┘        │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🔄 Data Flow Example: Creating a Bookmark

```
User Action (BookmarksGridView)
    ↓
ViewModel (BookmarksViewModel.createBookmark())
    ↓
Service (BookmarkService.create())
    ↓
Repository (BookmarkAPIRepository.create())
    ↓
APIClient (APIClient.post(.bookmarks))
    ↓
Network (URLSession)
    ↓
Response → Repository → Service → ViewModel → View Update
    ↓
CoreDataManager.save() (local persistence)
    ↓
SyncManager.enqueueOperation() (queue for sync)
```

---

## 📁 File Structure Quick Reference

### **App Level (1 file)**

- `CalendarNotesApp.swift` - Entry point, dependency injection

### **Views (~110 files)**

- `ContentView.swift` - Main navigation
- `CalendarMainView.swift` - Calendar UI
- `BookmarksGridView.swift` - Bookmarks UI
- `NotesListView.swift` - Notes UI
- `TasksListView.swift` - Tasks UI
- `SettingsView.swift` - Settings UI

### **ViewModels (~17 files)**

- `BookmarksViewModel.swift` - Bookmarks logic
- `CalendarViewModel.swift` - Calendar logic
- `NotesViewModel.swift` - Notes logic
- `TasksViewModel.swift` - Tasks logic
- `SettingsViewModel.swift` - Settings logic

### **Services (~70 files)**

- `APIClient.swift` - HTTP client
- `AuthService.swift` + `AuthManager.swift` - Authentication
- `SyncManager.swift` - Sync orchestration
- `BookmarkService.swift` - Bookmark domain logic
- `BookmarkAPIRepository.swift` - Bookmark API access
- `CoreDataService.swift` - CoreData operations
- `NotificationManager.swift` - Push notifications
- `EventKitManager.swift` - Calendar integration
- `CloudKitManager.swift` - iCloud sync

### **Models (~32 files)**

- Core Data entities (auto-generated)
- Extensions (custom logic)
- Domain models (DTOs, ViewModels)

### **Utilities (~45 files)**

- `CoreDataManager.swift` - Database stack
- `KeychainManager.swift` - Secure storage
- Helpers, extensions, constants

---

## 🎯 Key Patterns Used

### **1. Singleton Pattern**

```swift
static let shared = CoreDataManager()
static let shared = APIClient()
static let shared = AuthManager.shared
```

**Purpose**: Single instance shared across app

### **2. Repository Pattern**

```swift
protocol BookmarkRepository {
    func fetchBookmarks() async throws -> [Bookmark]
}
class BookmarkAPIRepository: BookmarkRepository { ... }
```

**Purpose**: Abstract data sources (API vs. CoreData)

### **3. MVVM Pattern**

```swift
View → ViewModel → Service → Repository → Data Source
```

**Purpose**: Separate UI from business logic

### **4. Dependency Injection**

```swift
.environmentObject(AuthManager.shared)
@EnvironmentObject var authManager: AuthManager
```

**Purpose**: Views get dependencies automatically

### **5. Observer Pattern (Combine)**

```swift
@Published var state: SyncState
$state.sink { newState in ... }
```

**Purpose**: Reactive state updates

---

## 💾 Code Footprint Reduction Summary

| Strategy               | Savings                   |
| ---------------------- | ------------------------- |
| Shared CoreDataManager | ~9,000 lines              |
| Shared APIClient       | ~2,500 lines              |
| Shared AuthManager     | ~2,800 lines              |
| Shared SyncManager     | ~900 lines                |
| Shared Utilities       | ~2,000 lines              |
| MVVM Pattern           | ~2,000 lines (better org) |
| Generics & Protocols   | ~5,000 lines              |
| **Total Estimated**    | **~23,200 lines**         |

**Actual Codebase**: 99,518 lines
**Without Architecture**: ~150,000+ lines
**Reduction**: ~33% smaller + better quality

---

## 🚀 Key Swift Features Leveraged

1. **@MainActor** - Thread safety for UI updates
2. **async/await** - Modern concurrency
3. **@Published** - Reactive state (Combine)
4. **Generics** - Type-safe reusable code
5. **Protocols** - Polymorphism without inheritance
6. **Extensions** - Add functionality without modification
7. **Property Wrappers** - Reduce boilerplate
8. **Result Builders** - SwiftUI declarative syntax

---

## 🔐 Critical Paths

### **App Launch Sequence:**

1. `CalendarNotesApp.init()` - Initialize managers
2. `CoreDataManager.init()` - Load database
3. `AuthManager.appLaunched()` - Check authentication
4. `RootView` - Show appropriate UI (auth vs. content)
5. `ContentView` - Show main tabs

### **Authentication Flow:**

1. User enters credentials
2. `AuthManager.login()` → `AuthService.login()`
3. `APIClient.post(.login)` - API call
4. Tokens stored in Keychain
5. `AuthManager.authState` → `.authenticated`
6. View automatically updates (reactive)

### **Sync Flow:**

1. User action creates/updates entity
2. Saved to CoreData (local)
3. `SyncManager.enqueueOperation()` - Queue for sync
4. When online: `SyncManager.autoSyncIfPermitted()`
5. Operations sent via `APIClient`
6. Response updates CoreData
7. UI updates via ViewModel observers

---

## 📊 Statistics

- **Total Swift Files**: 378
- **Total Lines**: ~99,518
- **Largest File**: CalendarView.swift (4,280 lines)
- **Average File**: ~263 lines
- **ViewModels**: 17 files
- **Services**: ~70 files
- **Utilities**: ~45 files
- **Models**: ~32 files
- **Views**: ~110 files

---

## ✅ Architecture Benefits

1. **Maintainability**: Changes localized to specific layers
2. **Testability**: Each layer testable independently
3. **Scalability**: Easy to add new features
4. **Code Reuse**: Shared infrastructure eliminates duplication
5. **Type Safety**: Compile-time error checking
6. **Performance**: Efficient memory management (ARC)
7. **Reliability**: Strong typing prevents runtime errors
