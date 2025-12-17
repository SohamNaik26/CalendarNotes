#!/bin/bash
echo "=== Nuclear Xcode Performance Fix ==="
echo ""

# Stop all Xcode processes
echo "1. Stopping Xcode processes..."
killall Xcode 2>/dev/null || true
killall com.apple.dt.SKAgent 2>/dev/null || true
killall sourcekitd 2>/dev/null || true
sleep 2

# Clean everything
echo "2. Cleaning all caches..."
rm -rf ~/Library/Developer/Xcode/DerivedData/*
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex
rm -rf ~/Library/Caches/com.apple.dt.Xcode
rm -rf ~/Library/Developer/Xcode/Archives
rm -rf ~/Library/Caches/org.swift.swiftpm
echo "   ✓ All caches cleaned"

# Disable indexing completely
echo "3. Disabling all indexing..."
defaults write com.apple.dt.Xcode IDEIndexDisableIndexingWhileBuilding -bool true
defaults write com.apple.dt.Xcode IDEIndexDisableIndexingWhileEditing -bool true
defaults write com.apple.dt.Xcode IDEIndexerActivityShowNumericProgress -bool true
defaults write com.apple.dt.Xcode ShowBuildOperationDuration -bool true
echo "   ✓ Indexing disabled"

# Optimize build settings
echo "4. Optimizing build settings recommendations..."
cat << SETTINGS
Manual Xcode Settings to Change:
1. Project Settings → Build Settings → Swift Compiler - Code Generation:
   - "Optimization Level" → Debug: None [-Onone]
   - "Compilation Mode" → Incremental
   - "Whole Module Optimization" → No for Debug

2. Project Settings → Build Settings → Build Options:
   - "Enable Index-While-Building Functionality" → No

3. Editor → Show Build Settings → Search for:
   - "SWIFT_OPTIMIZATION_LEVEL" → -Onone for Debug
SETTINGS

echo ""
echo "=== Done ==="
echo "Next: Restart Mac or wait 30 seconds, then reopen Xcode"
