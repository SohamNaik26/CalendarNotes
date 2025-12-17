#!/bin/bash
echo "Fixing Xcode indexing issues..."

# 1. Clean DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/CalendarNotes-*
echo "✓ Cleaned DerivedData"

# 2. Clean Module Cache
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex
echo "✓ Cleaned Module Cache"

# 3. Clean Xcode cache
rm -rf ~/Library/Caches/com.apple.dt.Xcode
echo "✓ Cleaned Xcode cache"

# 4. Restart Xcode indexing
defaults write com.apple.dt.Xcode IDEIndexDisableIndexingWhileBuilding -bool false
defaults write com.apple.dt.Xcode IDEIndexerActivityShowNumericProgress -bool true
echo "✓ Reset Xcode indexing preferences"

echo ""
echo "Done! Please:"
echo "1. Quit Xcode completely"
echo "2. Reopen the project"
echo "3. Wait for indexing to complete (check status bar)"
