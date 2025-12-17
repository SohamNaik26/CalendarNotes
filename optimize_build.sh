#!/bin/bash
echo "Optimizing build settings..."

# Check if we can add build settings via command line
# These would normally be set in Xcode project settings

cat << 'SETTINGS'
To improve build performance, manually set these in Xcode:

1. Project Settings → Build Settings → Swift Compiler - Code Generation:
   - "Optimization Level" → Debug: None [-Onone]
   - "Compilation Mode" → Incremental

2. Build Settings → Swift Compiler - Language:
   - "Swift Language Version" → Swift 5
   - "Enable Incremental Compilation" → Yes

3. Build Settings → Build Options:
   - "Enable Index-While-Building Functionality" → No (for now)

4. Editor → Show Build Settings:
   - Search for "Whole Module Optimization" → Set to No for Debug

Alternative: Compile specific files to isolate the issue:
xcodebuild -project CalendarNotes.xcodeproj -scheme CalendarNotes -configuration Debug \
  -derivedDataPath ./DerivedData \
  build 2>&1 | tee build.log
SETTINGS

echo ""
echo "To see which file is taking longest, check build.log"
