#!/bin/bash

# Script to help fix package linking issues

echo "🔍 Checking package status..."
echo ""

# Check if packages are resolved
echo "1. Checking package resolution..."
xcodebuild -resolvePackageDependencies -project CalendarNotes.xcodeproj 2>&1 | grep -E "Resolved|postgres-nio|swift-nio-ssl|swift-log" | head -5

echo ""
echo "2. Cleaning build artifacts..."
rm -rf ~/Library/Developer/Xcode/DerivedData/CalendarNotes-*
rm -rf ~/Library/Caches/org.swift.swiftpm

echo ""
echo "✅ Cleanup complete!"
echo ""
echo "📋 Next steps in Xcode:"
echo "   1. Open CalendarNotes.xcodeproj"
echo "   2. Select CalendarNotes target"
echo "   3. Go to Build Phases tab"
echo "   4. Expand 'Link Binary With Libraries'"
echo "   5. Click + button"
echo "   6. Add: PostgresNIO, NIOSSL, Logging"
echo "   7. Build (⌘B)"
echo ""
echo "If packages don't appear in the dialog:"
echo "   - Go to Package Dependencies tab"
echo "   - Verify packages are listed"
echo "   - Re-add them if needed, making sure CalendarNotes target is checked"

