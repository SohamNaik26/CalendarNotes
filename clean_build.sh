#!/bin/bash
# Clean build script for CalendarNotes

echo "🧹 Cleaning CalendarNotes build artifacts..."

# Remove derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/CalendarNotes-*

# Remove build folder
rm -rf build/

# Remove .swiftpm if exists
rm -rf .swiftpm/

# Clean Xcode build
if command -v xcodebuild &> /dev/null; then
    echo "Running xcodebuild clean..."
    xcodebuild clean -project CalendarNotes.xcodeproj -scheme CalendarNotes 2>/dev/null || true
fi

echo "✅ Clean complete! Please rebuild in Xcode (Cmd+B)"
echo "💡 If errors persist, try: Product → Clean Build Folder (Shift+Cmd+K)"

