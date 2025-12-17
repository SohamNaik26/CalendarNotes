# CalendarNotes - Project Overview & Documentation

## 📱 Project Overview

**CalendarNotes** is a comprehensive iOS and macOS application built with SwiftUI that combines calendar management, note-taking, task tracking, and bookmark management into a single, unified platform. The app features a modern, gradient-based UI design with purple accents and supports cross-platform functionality.

---

## 🏗️ Architecture

### **Architecture Pattern**
- **MVVM (Model-View-ViewModel)**: The app follows the MVVM pattern for clean separation of concerns
- **SwiftUI**: Modern declarative UI framework
- **Core Data**: Local data persistence
- **Combine**: Reactive programming for state management
- **Environment Objects**: Shared state management across views

### **Key Components**
1. **App Entry Point**: `CalendarNotesApp.swift`
2. **Root Router**: `RootView.swift` - Handles authentication state routing
3. **Main Views**: Platform-specific main views (iOS: `MainTabBarView`, macOS: `MacRootSplitView`, iPad: `IPadMainView`)
4. **Services Layer**: Authentication, Sync, CloudKit, EventKit integration
5. **ViewModels**: Business logic and state management
6. **Design System**: Centralized styling and theming

---

## 🎨 UI Components & File Mapping

### **1. App Launch & Authentication Flow**

#### **Launch Screen**
- **File**: `CalendarNotes/Views/LaunchScreenView.swift`
- **Container**: `CalendarNotes/Views/LaunchScreenContainer.swift`
- **Description**: Displays app logo and loading state during initialization
- **UI**: Gradient background with app branding

#### **Authentication Views**
- **Main Container**: `CalendarNotes/CalendarNotes/Views/Auth/AuthenticationView.swift`
  - Wraps login and register views in a `TabView`
  - Provides full-screen gradient background
  - Handles tab switching between login/register

- **Login View**: `CalendarNotes/Views/Auth/AuthLoginView.swift`
  - Email/password input fields with custom placeholders
  - "Continue with Google" button
  - Platform-specific text colors for visibility
  - Custom input field borders

- **Register View**: `CalendarNotes/Views/Auth/AuthRegisterView.swift`
  - Full name, email, password fields
  - "Sign up with Google" button
  - Similar styling to login view

- **Onboarding**: `CalendarNotes/Views/Auth/OnboardingView.swift`
  - First-time user experience
  - Feature introduction

---

### **2. Main Application Views**

#### **Root View Router**
- **File**: `CalendarNotes/Views/RootView.swift`
- **Function**: Routes between authentication and main app based on `AuthManager.authState`
- **States Handled**:
  - `.idle`, `.loading` → `LaunchScreenContainer`
  - `.unauthenticated`, `.error` → `AuthenticationView`
  - `.authenticated` → Platform-specific main view

#### **Mobile View (iPhone)**
- **File**: `CalendarNotes/Views/MainTabBarView.swift`
- **Description**: Main tab bar with 5 tabs and floating action button
- **Tabs**:
  1. **Calendar** → `CalendarMainViewWrapper()` → `CalendarMainView`
  2. **Notes** → `NotesMainView()` → `NotesListView`
  3. **Tasks** → `TasksMainView()` → `TasksListView`
  4. **Bookmarks** → `BookmarksMainView()` → `BookmarksGridView`
  5. **Settings** → `SettingsMainView()` → `SettingsView`
- **Floating Action Button**: Central "+" button that opens `AddItemActionSheet`
- **Custom Tab Bar**: `CustomTabBarView` with blur material background

#### **iPad View**
- **File**: `CalendarNotes/Views/iPad/iPadMainView.swift`
- **Description**: Optimized layout for iPad's larger screen
- **Features**: Split view, sidebar navigation

#### **macOS View**
- **File**: `CalendarNotes/Views/Mac/MacRootSplitView.swift`
- **Description**: Native macOS interface with sidebar and detail views
- **Features**: Menu bar integration, keyboard shortcuts

---

### **3. Tab-Specific Views**

#### **Calendar Tab**
- **Main View**: `CalendarNotes/Views/Calendar/CalendarMainView.swift`
  - Header with "Calendar" title (34pt bold)
  - View selector (Day, Week, Month, Year)
  - White card container for calendar content

- **Sub-Views**:
  - **Day View**: `CalendarNotes/Views/Calendar/CalendarDayView.swift`
    - Timeline view with hourly slots
    - Event blocks with gradient backgrounds
  - **Week View**: `CalendarNotes/Views/Calendar/CalendarWeekView.swift`
    - 7-day grid layout
    - Day cards with shadows
  - **Month View**: `CalendarNotes/Views/Calendar/CalendarMonthView.swift`
    - Traditional calendar grid
    - Today highlighted with gradient
    - Event indicators on dates
  - **Year View**: `CalendarNotes/Views/Calendar/CalendarYearView.swift`
    - 12 mini-month grids
    - Navigation between years

#### **Notes Tab**
- **Main View**: `CalendarNotes/Views/Notes/NotesListView.swift`
  - "Notes" title (34pt bold)
  - Search bar with visible border
  - List of note cards or empty state
  - Each note shows: date/time, content preview, tags

- **Note Card**: `NoteCard` component within `NotesListView.swift`
  - White card with shadow
  - Date/time stamp (12pt, gray)
  - Content preview with markdown support
  - Tags display

- **Note Editor**: `CalendarNotes/Views/NoteEditorView.swift`
  - Full-screen editor for creating/editing notes
  - Markdown support
  - Tag management

#### **Tasks Tab**
- **Main View**: `CalendarNotes/Views/Tasks/TasksListView.swift`
  - "Tasks" title (34pt bold)
  - Search bar with visible border
  - List of task rows or empty state

- **Task Row**: `TaskRow` component within `TasksListView.swift`
  - Circular checkbox (28pt, purple gradient when completed)
  - Task title with strikethrough for completed tasks
  - Due date display
  - Card styling with shadow

- **Task Editor**: `CalendarNotes/Views/EnhancedTaskEditorView.swift`
  - Full-screen editor for creating/editing tasks
  - Due date picker
  - Priority selection
  - Notes field

#### **Bookmarks Tab**
- **Main View**: `CalendarNotes/Views/Bookmarks/BookmarksGridView.swift`
  - "Bookmarks" title (34pt bold)
  - Search bar with visible border
  - Grid layout of bookmark cards or empty state

- **Bookmark Card**: `BookmarkCard` component within `BookmarksGridView.swift`
  - Large icon section with gradient background
  - Title and URL display
  - Tags and metadata
  - White card with shadow

- **Bookmark Editor**: `CalendarNotes/Views/QuickAddBookmarkSheet.swift`
  - Sheet for adding new bookmarks
  - URL input
  - Collection selection

#### **Settings Tab**
- **Main View**: `CalendarNotes/Views/SettingsView.swift`
  - Comprehensive settings interface
  - Account management
  - Sync settings
  - Appearance preferences
  - Data management

---

### **4. Shared Components**

#### **Search Bar**
- **File**: `CalendarNotes/Views/Components/SearchBarView.swift`
- **Component**: `SearchBar`
- **Features**:
  - Magnifying glass icon
  - Custom placeholder text (visible on all platforms)
  - Visible border (1.5pt, gray)
  - Platform-specific styling

#### **Empty State**
- **File**: `CalendarNotes/Views/Components/EmptyStateView.swift`
- **Component**: `EmptyStateView`
- **Features**:
  - Large icon (56pt)
  - Message text
  - Used when lists are empty

#### **Custom Tab Bar**
- **File**: `CalendarNotes/Views/CustomTabBar.swift`
- **Component**: `CustomTabBar`
- **Features**:
  - 5 tab buttons with icons and labels
  - Central floating action button
  - Blur material background
  - Haptic feedback on iOS

#### **Add Item Action Sheet**
- **File**: `CalendarNotes/Views/AddItemActionSheet.swift`
- **Component**: `AddItemActionSheet`
- **Features**:
  - Presents `CreateMenuView` with options:
    - New Event
    - New Note
    - New Task
    - Add Bookmark
  - Uses callback pattern to trigger parent sheet presentation

---

### **5. Design System**

- **File**: `CalendarNotes/Utilities/DesignSystem.swift`
- **Colors**:
  - `accentColor`: Purple (#667eea)
  - `accentColorDark`: Dark purple (#764ba2)
  - `accentGradient`: Linear gradient from accent to dark
- **Typography**:
  - Large title: 34pt, bold
  - Header: 24pt, bold
  - Body: 16pt, regular
  - Caption: 13pt, regular
- **Spacing & Layout**:
  - Corner radius: 16pt (cards), 12pt (search bars)
  - Tab bar height: 83pt
  - Floating button size: 56pt
- **Shadows**:
  - Card shadow: 8pt radius, black 8% opacity
  - Floating button shadow: 12pt radius, purple 40% opacity

---

## 🔄 Working Process & Flow

### **1. App Launch Flow**

```
CalendarNotesApp.swift (App Entry)
    ↓
RootView.swift
    ↓
Checks AuthManager.authState:
    ├─ .idle/.loading → LaunchScreenContainer
    ├─ .unauthenticated/.error → AuthenticationView
    └─ .authenticated → Platform-specific main view
```

### **2. Authentication Flow**

```
RootView detects .unauthenticated
    ↓
AuthenticationView displayed
    ├─ Tab 0: AuthLoginView (Login)
    └─ Tab 1: AuthRegisterView (Register)
    ↓
User enters credentials
    ↓
AuthManager.appLaunched() called
    ↓
AuthService validates credentials
    ↓
On success: AuthManager.authState = .authenticated(user)
    ↓
RootView switches to MainTabBarView
```

### **3. Main App Flow (Mobile)**

```
MainTabBarView
    ↓
User selects tab (Calendar/Notes/Tasks/Bookmarks/Settings)
    ↓
CustomTabBarView updates selectedTab
    ↓
Switch statement renders corresponding view:
    ├─ Calendar → CalendarMainView
    ├─ Notes → NotesListView
    ├─ Tasks → TasksListView
    ├─ Bookmarks → BookmarksGridView
    └─ Settings → SettingsView
```

### **4. Add Item Flow**

```
User taps floating "+" button
    ↓
AddItemActionSheet presented (sheet)
    ↓
CreateMenuView shows options
    ↓
User selects option (Event/Note/Task/Bookmark)
    ↓
onSelect callback triggered
    ↓
AddItemActionSheet dismissed
    ↓
Parent view (MainTabBarView) shows corresponding editor sheet:
    ├─ Event → AddEventView
    ├─ Note → NoteEditorView
    ├─ Task → EnhancedTaskEditorView
    └─ Bookmark → QuickAddBookmarkSheet
```

### **5. Data Flow**

```
View (UI)
    ↓
ViewModel (Business Logic)
    ↓
Service Layer (API/Network)
    ↓
Core Data (Local Persistence)
    ↓
CloudKit/Sync Services (Cloud Sync)
```

---

## 📱 Platform & Simulator Support

### **Supported Platforms**

1. **iOS (iPhone)**
   - **Simulators**: All iOS simulators (iPhone SE, iPhone 15, iPhone 15 Pro Max, etc.)
   - **Minimum iOS Version**: iOS 15.0+
   - **UI**: `MainTabBarView` with bottom tab bar
   - **Features**: Haptic feedback, full gesture support

2. **iPad**
   - **Simulators**: All iPad simulators (iPad Air, iPad Pro, etc.)
   - **UI**: `IPadMainView` with optimized layout
   - **Features**: Split view, sidebar navigation, larger screen utilization

3. **macOS**
   - **Simulators**: macOS simulators
   - **UI**: `MacRootSplitView` with native macOS interface
   - **Features**: Menu bar integration, keyboard shortcuts, window management

### **Platform-Specific Code**

The app uses conditional compilation for platform-specific features:

```swift
#if os(iOS)
    // iOS-specific code
#elseif os(macOS)
    // macOS-specific code
#endif
```

### **Key Platform Differences**

1. **Colors**:
   - iOS: `UIColor` system colors
   - macOS: `NSColor` system colors
   - Both use platform-specific computed properties

2. **Text Visibility**:
   - macOS requires explicit color definitions for text visibility
   - iOS uses system defaults with adjustments

3. **Window Management**:
   - iOS: Single window, full-screen
   - macOS: Multiple windows, menu bar

4. **Haptic Feedback**:
   - iOS: `UIImpactFeedbackGenerator`, `UISelectionFeedbackGenerator`
   - macOS: Not available

---

## 📂 File Structure

```
CalendarNotes/
├── CalendarNotes/
│   ├── CalendarNotesApp.swift          # App entry point
│   ├── App/
│   │   └── CalendarNotesAppDelegate.swift  # App delegate
│   ├── Views/
│   │   ├── RootView.swift              # Main router
│   │   ├── MainTabBarView.swift        # Mobile main view
│   │   ├── ContentView.swift           # View wrappers
│   │   ├── LaunchScreenView.swift      # Launch screen
│   │   ├── Auth/
│   │   │   ├── AuthenticationView.swift
│   │   │   ├── AuthLoginView.swift
│   │   │   ├── AuthRegisterView.swift
│   │   │   └── OnboardingView.swift
│   │   ├── Calendar/
│   │   │   ├── CalendarMainView.swift
│   │   │   ├── CalendarDayView.swift
│   │   │   ├── CalendarWeekView.swift
│   │   │   ├── CalendarMonthView.swift
│   │   │   └── CalendarYearView.swift
│   │   ├── Notes/
│   │   │   └── NotesListView.swift
│   │   ├── Tasks/
│   │   │   └── TasksListView.swift
│   │   ├── Bookmarks/
│   │   │   └── BookmarksGridView.swift
│   │   ├── Components/
│   │   │   ├── SearchBarView.swift
│   │   │   └── EmptyStateView.swift
│   │   ├── CustomTabBar.swift
│   │   ├── AddItemActionSheet.swift
│   │   ├── iPad/
│   │   │   └── iPadMainView.swift
│   │   └── Mac/
│   │       └── MacRootSplitView.swift
│   ├── Services/
│   │   ├── Auth/
│   │   │   ├── AuthManager.swift
│   │   │   └── AuthService.swift
│   │   └── Sync/
│   │       └── SyncManager.swift
│   ├── ViewModels/
│   │   ├── CalendarViewModel.swift
│   │   └── TasksViewModel.swift
│   ├── Utilities/
│   │   └── DesignSystem.swift
│   └── Models/
│       └── (Core Data models)
└── CalendarNotes.xcodeproj/
```

---

## 🎯 Key Features

### **1. Authentication**
- Email/password authentication
- Google Sign-In integration
- Token-based session management
- Biometric authentication support
- Secure keychain storage

### **2. Calendar**
- Day, Week, Month, Year views
- Event creation and management
- EventKit integration
- Visual event indicators
- Today highlighting with gradient

### **3. Notes**
- Rich text notes with markdown support
- Tag system
- Search functionality
- Date/time stamps
- Card-based list view

### **4. Tasks**
- Task creation with due dates
- Checkbox completion
- Priority levels
- Search and filtering
- Strikethrough for completed tasks

### **5. Bookmarks**
- URL bookmarking
- Collection organization
- Tag system
- Grid layout
- Icon-based visual cards

### **6. Settings**
- Account management
- Sync preferences (CloudKit, EventKit)
- Appearance settings
- Data management
- Import/Export functionality

---

## 🔧 Technical Details

### **State Management**
- `@StateObject`: View-specific state
- `@EnvironmentObject`: Shared state (AuthManager, SyncManager)
- `@Published`: Observable properties in ViewModels
- `@AppStorage`: User preferences

### **Data Persistence**
- **Core Data**: Local database
- **CloudKit**: Cloud sync
- **Keychain**: Secure token storage
- **UserDefaults**: App preferences

### **Networking**
- RESTful API integration
- WebSocket for real-time sync
- Background sync manager
- Error handling and retry logic

### **UI/UX Features**
- Gradient backgrounds
- Card-based layouts
- Smooth animations
- Haptic feedback (iOS)
- Pull-to-refresh
- Swipe actions
- Custom tab bar with floating button

---

## 🚀 Build & Run

### **Prerequisites**
- Xcode 15.0+
- iOS 15.0+ SDK
- macOS 12.0+ SDK (for macOS target)

### **Build Commands**
```bash
# Clean build
xcodebuild clean -project CalendarNotes.xcodeproj -scheme CalendarNotes

# Build for iOS Simulator
xcodebuild -project CalendarNotes.xcodeproj -scheme CalendarNotes -sdk iphonesimulator

# Build for macOS
xcodebuild -project CalendarNotes.xcodeproj -scheme CalendarNotes -sdk macosx
```

### **Run in Simulator**
1. Open `CalendarNotes.xcodeproj` in Xcode
2. Select target device/simulator
3. Press `Cmd + R` to build and run

---

## 📝 Notes for Developers

### **Platform-Specific Considerations**
1. **Text Colors**: Always use computed properties for platform-specific colors
2. **Safe Areas**: Use `.ignoresSafeArea()` appropriately
3. **Window Background**: Set window background color early in app lifecycle
4. **Sheet Presentation**: Present sheets from parent views, not nested sheets

### **Common Patterns**
1. **View Wrappers**: Use wrapper views for consistency (e.g., `CalendarMainViewWrapper`)
2. **Empty States**: Always provide empty state views for lists
3. **Loading States**: Show loading indicators during async operations
4. **Error Handling**: Gracefully handle errors with user-friendly messages

### **Design System Usage**
- Always use `DesignSystem` constants for colors, fonts, spacing
- Apply `.cardStyle()` or `.subtleCardStyle()` for card components
- Use `DesignSystem.accentGradient` for gradient backgrounds

---

## 🔍 Debugging Tips

1. **Black Screen Issues**: Check window background color in `CalendarNotesApp.swift`
2. **Invisible Text**: Verify platform-specific color definitions
3. **Sheet Not Opening**: Ensure sheets are presented from parent views
4. **Tab Not Showing**: Check `TabItem` enum and `tabs` array in `CustomTabBarView`
5. **Search Bar Border**: Verify `SearchBar` component has `overlay` with `strokeBorder`

---

## 📚 Additional Resources

- **Design System**: `CalendarNotes/Utilities/DesignSystem.swift`
- **Auth Service**: `CalendarNotes/Services/Auth/AuthService.swift`
- **Core Data Models**: `CalendarNotes/CalendarNotes.xcdatamodeld/`
- **Project Configuration**: `CalendarNotes.xcodeproj/`

---

## 🎨 UI Reference

### **Color Palette**
- **Primary Purple**: #667eea (RGB: 0.4, 0.49, 0.92)
- **Dark Purple**: #764ba2 (RGB: 0.46, 0.29, 0.64)
- **White**: #FFFFFF
- **Gray (Search Bar)**: System gray 6
- **Border Gray**: RGB(0.7, 0.7, 0.7) on macOS, White 0.8 on iOS

### **Typography Scale**
- **Large Title**: 34pt, Bold
- **Header**: 24pt, Bold
- **Body**: 16pt, Regular
- **Caption**: 13pt, Regular
- **Tab Label**: 10pt, Medium

### **Spacing**
- **Card Padding**: 16pt
- **Screen Padding**: 20pt
- **Tab Bar Height**: 83pt
- **Floating Button**: 56pt diameter

---

**Last Updated**: December 2024
**Version**: 1.0.0
**Platforms**: iOS 15.0+, macOS 12.0+

