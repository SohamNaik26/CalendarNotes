#!/bin/bash
echo "=== Xcode Performance Fix Script ==="
echo ""

# 1. Clean DerivedData
echo "1. Cleaning DerivedData..."
rm -rf ~/Library/Developer/Xcode/DerivedData/CalendarNotes-*
echo "   ✓ DerivedData cleaned"

# 2. Clean Module Cache
echo "2. Cleaning Module Cache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex
echo "   ✓ Module Cache cleaned"

# 3. Clean Xcode Caches
echo "3. Cleaning Xcode Caches..."
rm -rf ~/Library/Caches/com.apple.dt.Xcode
echo "   ✓ Xcode Caches cleaned"

# 4. Disable indexing temporarily
echo "4. Disabling indexing temporarily..."
defaults write com.apple.dt.Xcode IDEIndexDisableIndexingWhileBuilding -bool true
defaults write com.apple.dt.Xcode IDEIndexDisableIndexingWhileEditing -bool false
echo "   ✓ Indexing disabled while building"

echo ""
echo "=== Next Steps ==="
echo "1. Quit Xcode completely (Cmd+Q)"
echo "2. Wait 5 seconds"
echo "3. Reopen Xcode and the project"
echo "4. Wait for indexing to complete (check status bar)"
echo ""
echo "To re-enable indexing later:"
echo "  defaults write com.apple.dt.Xcode IDEIndexDisableIndexingWhileBuilding -bool false"
