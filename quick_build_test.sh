#!/bin/bash
echo "Testing build performance..."
echo ""

# Clean first
echo "Cleaning..."
rm -rf ~/Library/Developer/Xcode/DerivedData/CalendarNotes-*

# Try building with minimal output
echo "Building (this may take a while)..."
timeout 120 xcodebuild -project CalendarNotes.xcodeproj -scheme CalendarNotes -configuration Debug build 2>&1 | grep -E "(error:|warning:|BUILD|Compiling)" | head -20

echo ""
echo "If build completes, check above for errors."
