# Quick Guide: Adding PostgreSQL Dependencies

## ⚡ Quick Steps

1. **Open Xcode** and open `CalendarNotes.xcodeproj`

2. **Select Project** → Click on **CalendarNotes** (blue icon) in Project Navigator

3. **Select Target** → Click **CalendarNotes** under TARGETS

4. **Go to Package Dependencies Tab** (top of the editor)

5. **Add Packages** (click **+** button for each):

   ```
   https://github.com/vapor/postgres-nio.git
   ```
   - Version: Up to Next Major: `1.20.0`
   - Product: **PostgresNIO** ✓

   ```
   https://github.com/apple/swift-nio-ssl.git
   ```
   - Version: Up to Next Major: `2.25.0`
   - Product: **NIOSSL** ✓

   ```
   https://github.com/apple/swift-log.git
   ```
   - Version: Up to Next Major: `1.5.0`
   - Product: **Logging** ✓

6. **Click Add Package** for each

7. **Build** (⌘B) to verify dependencies are resolved

## ✅ Verification

After adding packages, you should see them in:
- **Package Dependencies** tab
- **Frameworks, Libraries, and Embedded Content** section

The build errors should disappear once packages are added and resolved.

## 📝 Note

If Xcode shows "Resolving Package Graph", wait for it to complete. This may take a minute.

