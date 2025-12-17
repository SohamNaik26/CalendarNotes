#!/bin/bash
echo "Disabling Xcode indexing to prevent pauses..."

# Disable indexing while building
defaults write com.apple.dt.Xcode IDEIndexDisableIndexingWhileBuilding -bool true

# Disable automatic indexing
defaults write com.apple.dt.Xcode IDEIndexDisableIndexingWhileEditing -bool true

# Reduce indexing scope
defaults write com.apple.dt.Xcode IDEIndexerActivityShowNumericProgress -bool true

echo "✓ Indexing disabled"
echo ""
echo "To re-enable later, run:"
echo "defaults write com.apple.dt.Xcode IDEIndexDisableIndexingWhileBuilding -bool false"
echo "defaults write com.apple.dt.Xcode IDEIndexDisableIndexingWhileEditing -bool false"
