# PostgreSQL Database Setup for CalendarNotes

## Swift Package Manager Dependencies

To use the PostgreSQL database connection layer, you need to add the following Swift Package Manager dependencies to your Xcode project.

### Required Packages

1. **PostgresNIO** - PostgreSQL client library for Swift
   - URL: `https://github.com/vapor/postgres-nio.git`
   - Version: `1.20.0` or later

2. **NIOSSL** - SwiftNIO SSL support
   - URL: `https://github.com/apple/swift-nio-ssl.git`
   - Version: `2.25.0` or later

3. **Logging** - Swift logging framework
   - URL: `https://github.com/apple/swift-log.git`
   - Version: `1.5.0` or later

## Step-by-Step: Adding Dependencies in Xcode

### Method 1: Using Xcode UI (Recommended)

1. **Open your Xcode project**
   - Open `CalendarNotes.xcodeproj` in Xcode

2. **Select the project**
   - In the Project Navigator (left sidebar), click on the **CalendarNotes** project (blue icon at the top)

3. **Select the target**
   - In the main editor area, select the **CalendarNotes** target (under TARGETS)

4. **Go to Package Dependencies tab**
   - Click on the **Package Dependencies** tab at the top

5. **Add PostgresNIO**
   - Click the **+** button at the bottom left
   - Paste: `https://github.com/vapor/postgres-nio.git`
   - Click **Add Package**
   - Select version: **Up to Next Major Version** with `1.20.0`
   - Make sure **PostgresNIO** is checked
   - Click **Add Package**

6. **Add NIOSSL**
   - Click the **+** button again
   - Paste: `https://github.com/apple/swift-nio-ssl.git`
   - Click **Add Package**
   - Select version: **Up to Next Major Version** with `2.25.0`
   - Make sure **NIOSSL** is checked
   - Click **Add Package**

7. **Add Logging**
   - Click the **+** button again
   - Paste: `https://github.com/apple/swift-log.git`
   - Click **Add Package**
   - Select version: **Up to Next Major Version** with `1.5.0`
   - Make sure **Logging** is checked
   - Click **Add Package**

8. **Verify dependencies**
   - Go to the **Package Dependencies** tab
   - You should see all three packages listed
   - Xcode will automatically resolve and download them

### Method 2: Using Xcode's File Menu

1. In Xcode, go to **File → Add Package Dependencies...**
2. Enter the package URL and click **Add Package**
3. Repeat for each package

Alternatively, you can add them via Package.swift if you're using Swift Package Manager directly.

## Package.swift Example

If you're using a Package.swift file, add these dependencies:

```swift
dependencies: [
    .package(url: "https://github.com/vapor/postgres-nio.git", from: "1.20.0"),
    .package(url: "https://github.com/apple/swift-nio-ssl.git", from: "2.25.0"),
    .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0")
],
targets: [
    .target(
        name: "CalendarNotes",
        dependencies: [
            .product(name: "PostgresNIO", package: "postgres-nio"),
            .product(name: "NIOSSL", package: "swift-nio-ssl"),
            .product(name: "Logging", package: "swift-log")
        ]
    )
]
```

## Usage

After adding the dependencies, you can use the database layer:

```swift
import Foundation

// Configure database connection
DatabaseConfig.shared.configure(
    host: "localhost",
    port: 5432,
    database: "calendarnotes_db",
    username: "calendarnotes_user",
    password: "secure_password_here"
)

// Connect to database
Task {
    do {
        try await DatabaseManager.shared.connect()
        print("Connected to database")
    } catch {
        print("Connection failed: \(error)")
    }
}

// Use repositories
let userRepo = UserRepository()
let eventRepo = EventRepository()
let noteRepo = NoteRepository()
let todoRepo = TodoRepository()
let bookmarkRepo = BookmarkRepository()
```

## Notes

- The database layer uses async/await for all operations
- Network reachability is checked before database operations
- Failed operations are queued for offline execution
- Connection status is monitored and published via Combine

