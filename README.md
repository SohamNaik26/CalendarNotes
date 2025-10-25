# 📅 CalendarNotes

> A beautiful, native iOS/macOS app that seamlessly combines calendar management, note-taking, and task tracking in one powerful tool.

![Platform](https://img.shields.io/badge/platform-iOS%20%7C%20macOS-blue)
![Swift](https://img.shields.io/badge/Swift-5.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## ✨ Features

### 📆 Calendar Management

- **Full-featured Calendar**: Create, edit, and manage events with an intuitive interface
- **Multiple Views**: Switch between month, week, and day views
- **Recurring Events**: Set up recurring events with customizable patterns
- **Categories**: Organize events with color-coded categories
- **EventKit Sync**: Bidirectional sync with iOS Calendar app
- **Quick Creation**: Tap any empty time slot to create events instantly

### 📝 Rich Note Taking

- **Markdown Support**: Format text with bold, italic, lists, and more
- **Voice Transcription**: Convert speech to text with built-in recording
- **Date Linking**: Link notes to specific dates for better organization
- **Tags**: Organize notes with custom tags
- **Search**: Find notes quickly with full-text search
- **Preview Mode**: See formatted markdown in real-time

### ✅ Task Management

- **Priority Levels**: Organize tasks with Low, Medium, High, and Urgent priorities
- **Due Dates**: Never miss a deadline with due date tracking
- **Completion Tracking**: Mark tasks as complete and archive them
- **Recurring Tasks**: Automatically repeat tasks on schedule
- **Swipe Actions**: Complete or delete tasks with intuitive gestures
- **Categories**: Group tasks by project or context

### 🔔 Smart Notifications

- **Event Reminders**: Get notified before events start
- **Task Alerts**: Reminders for upcoming deadlines
- **Daily Summary**: Receive a daily summary of your schedule
- **Customizable**: Set reminder times and notification preferences
- **Silent Hours**: Configure quiet hours for notifications

### ☁️ Cloud Sync

- **iCloud Integration**: Automatic sync across all your devices
- **Real-time Updates**: Changes appear instantly on all devices
- **Offline Support**: Use the app offline, sync when online
- **Privacy First**: Your data stays secure and private

### 🎨 Beautiful UI

- **Dark Mode**: Full dark mode support for comfortable viewing
- **Modern Design**: Clean, intuitive interface following Apple's design guidelines
- **Adaptive Layout**: Optimized for iPhone, iPad, and Mac
- **Smooth Animations**: Fluid transitions and interactions
- **Accessibility**: Full VoiceOver and accessibility support

#### 🧪 Developer Tools

- **Sample Data Generator**: Quick way to populate the app for demos and testing
- **Export/Import**: Backup and restore your data
- **Developer Mode**: Useful tools for testing and development

### 🎯 App Icon & Launch Screen

- **Custom App Icon**: Beautiful calendar icon with note overlay
- **Animated Launch Screen**: Smooth startup experience with branding
- **Dark Mode Support**: App icon adapts to light/dark appearance

## 🖥️ Requirements

- iOS 15.0+ / macOS 12.0+
- Xcode 14.0+
- Swift 5.7+

## 🚀 Installation

### Prerequisites

- macOS with Xcode installed
- Apple Developer account (for device deployment)

### Build from Source

1. **Clone the repository**

   ```bash
   git clone https://github.com/yourusername/CalendarNotes.git
   cd CalendarNotes
   ```

2. **Open in Xcode**

   ```bash
   open CalendarNotes.xcodeproj
   ```

3. **Configure Signing**

   - Select the CalendarNotes target
   - Go to "Signing & Capabilities"
   - Select your development team

4. **Build and Run**
   - Press `Cmd + R` to build and run
   - Or select Product → Run from the menu

### Running on a Device

1. Connect your iOS device or Mac
2. Select your device from the scheme selector in Xcode
3. Ensure your Apple ID is configured in Xcode settings
4. Build and run the project

## 📱 Usage

### Creating Events

1. Open the Calendar tab
2. Tap on any empty time slot
3. Enter event details (title, time, category, etc.)
4. Tap "Create" to save

### Taking Notes

1. Navigate to the Notes tab
2. Tap the "+" button or "Add Note"
3. Enter your note content
4. Use formatting buttons for bold, italic, lists
5. Optionally link the note to a date
6. Add tags for organization
7. Tap "Create" to save

### Managing Tasks

1. Go to the Tasks tab
2. Tap "+ New Task"
3. Enter task title and details
4. Set priority and due date
5. Assign category
6. Tap "Create" to save
7. Swipe left to complete or delete

### Using Sample Data

1. Open Settings
2. Scroll to "Data Management"
3. Find "Sample Data" section
4. Tap "Generate Sample Data"
5. Wait for confirmation

## 📊 Project Statistics

- **Total Swift Files**: 70
- **Total Lines of Code**: ~30,224
- **View Code**: ~17,346 lines
- **Platform**: iOS 15.0+ / macOS 12.0+
- **Architecture**: MVVM (Model-View-ViewModel)
- **Build Status**: ✅ Clean (No errors or warnings)
- **Code Quality**: No TODOs, No FIXMEs, 0 Compiler Warnings

## 🏗️ Architecture

This app follows the **MVVM (Model-View-ViewModel)** architecture pattern:

- **Models**: Core Data entities for CalendarEvent, Note, and TodoItem
- **Views**: SwiftUI views for the UI layer
- **ViewModels**: Observable objects that manage view state and business logic
- **Services**: Helper classes for notifications, cloud sync, and more

For detailed architecture documentation, see [ARCHITECTURE.md](ARCHITECTURE.md).

## 📁 Project Structure

```
CalendarNotes/
├── CalendarNotes/
│   ├── Models/           # Core Data models and extensions
│   ├── ViewModels/       # MVVM view models
│   ├── Views/            # SwiftUI views
│   ├── Services/         # Business logic services
│   ├── Utilities/        # Helper classes and managers
│   ├── Assets.xcassets/  # Images and colors
│   └── CalendarNotes.xcdatamodeld/  # Core Data model
├── CalendarNotesTests/   # Unit tests
├── CalendarNotesUITests/ # UI tests
├── ARCHITECTURE.md       # Architecture documentation
└── README.md            # This file
```

## 🔧 Configuration

### Setting Up iCloud Sync

1. Open Settings in the app
2. Navigate to "iCloud & Backup"
3. Toggle "iCloud Sync" on
4. Grant necessary permissions when prompted

### Configuring Notifications

1. Go to Settings → Notifications
2. Enable notifications for events and/or tasks
3. Set reminder times
4. Configure daily summary if desired

## 🧪 Testing

The project includes:

- **Unit Tests**: For ViewModels and business logic
- **Integration Tests**: For Core Data operations
- **UI Tests**: For user workflows

Run tests with `Cmd + U` in Xcode.

### Running Sample Data Generator

Perfect for testing and demos:

```swift
// In Settings → Data Management
// Tap "Generate Sample Data"
// This creates:
// - 30 random events
// - 20 sample notes
// - 15 tasks with mixed priorities
```

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

### Code Style

- Follow Swift API design guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions focused and single-purpose
- Write unit tests for new features

## 🎯 Current Status

### ✅ Completed
- [x] Core functionality (Calendar, Notes, Tasks)
- [x] CloudKit synchronization
- [x] EventKit integration
- [x] Rich text note editor
- [x] Voice transcription
- [x] Dark mode support
- [x] Launch screen implementation
- [x] App icon design specifications
- [x] Sample data generator
- [x] All TODO items fixed
- [x] Clean build (0 errors, 0 warnings)

### 🚧 In Progress
- [ ] Comprehensive unit tests (target: 70% coverage)
- [ ] Accessibility improvements
- [ ] Additional localization

### 📋 Known Issues & Improvements
- Large file refactoring needed (CalendarView.swift: 3,921 lines)
- Service consolidation (remove duplicate services)
- Test coverage improvement needed

See `ARCHITECTURE.md` for detailed information about the codebase.

## 📝 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- Built with [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- Uses [Core Data](https://developer.apple.com/documentation/coredata) for persistence
- Icons from [SF Symbols](https://developer.apple.com/sf-symbols/)

## 📸 Screenshots

### Calendar View

![Calendar View](screenshots/calendar.png)

### Notes View

![Notes View](screenshots/notes.png)

### Tasks View

![Tasks View](screenshots/tasks.png)

### Dark Mode

![Dark Mode](screenshots/dark-mode.png)

## 🐛 Known Issues

- CloudKit sync requires paid Apple Developer account
- Voice recognition requires network connection
- Some features may differ between iOS and macOS

## 🔮 Future Enhancements

- [ ] Apple Watch companion app
- [ ] Widget support for home screen
- [ ] Siri Shortcuts integration
- [ ] Collaboration and sharing features
- [ ] Advanced recurring event patterns
- [ ] File attachments in notes
- [ ] Export to PDF/iCal formats
- [ ] Multiple calendar support
- [ ] Geolocation features for events
- [ ] Integration with third-party services

## 📞 Support

If you encounter any issues or have questions:

1. Check the [Issues](https://github.com/yourusername/CalendarNotes/issues) page
2. Search for existing solutions
3. Create a new issue if needed
4. Contact the maintainer

## ⭐ Star History

If you find this project helpful, please consider giving it a star!

[![Star History Chart](https://api.star-history.com/svg?repos=yourusername/CalendarNotes&type=Date)](https://star-history.com/#yourusername/CalendarNotes&Date)

## 📊 Statistics

![GitHub stars](https://img.shields.io/github/stars/yourusername/CalendarNotes)
![GitHub forks](https://img.shields.io/github/forks/yourusername/CalendarNotes)
![GitHub issues](https://img.shields.io/github/issues/yourusername/CalendarNotes)
![GitHub license](https://img.shields.io/github/license/yourusername/CalendarNotes)

---

Made with ❤️ using SwiftUI
# CalendarNotes
