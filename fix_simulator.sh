#!/bin/bash

# Fix CoreSimulator service errors
# This script resets the iOS Simulator services to resolve "Failed to find service com.apple.CoreSimulator.host_support" errors

set -e

echo "🔧 Fixing CoreSimulator service errors..."

# Kill all simulator processes
echo "1. Killing all simulator processes..."
killall -9 Simulator 2>/dev/null || true
killall -9 com.apple.CoreSimulator.CoreSimulatorService 2>/dev/null || true
killall -9 com.apple.iphonesimulator 2>/dev/null || true

# Wait a moment for processes to fully terminate
sleep 2

# Reset CoreSimulator service
echo "2. Resetting CoreSimulator service..."
xcrun simctl shutdown all 2>/dev/null || true

# Kill any remaining CoreSimulator processes
pkill -9 -f CoreSimulator || true
pkill -9 -f Simulator || true

# Wait again
sleep 2

# Clear simulator service cache (if it exists)
echo "3. Clearing simulator service cache..."
SIMULATOR_CACHE_DIR="$HOME/Library/Caches/com.apple.CoreSimulator"
if [ -d "$SIMULATOR_CACHE_DIR" ]; then
    echo "   Found cache directory, clearing..."
    rm -rf "$SIMULATOR_CACHE_DIR"/* 2>/dev/null || true
fi

# Reset the specific device if provided, otherwise reset all
DEVICE_ID="${1:-}"
if [ -n "$DEVICE_ID" ]; then
    echo "4. Resetting device: $DEVICE_ID"
    xcrun simctl erase "$DEVICE_ID" 2>/dev/null || true
    xcrun simctl shutdown "$DEVICE_ID" 2>/dev/null || true
else
    echo "4. Listing available simulators..."
    xcrun simctl list devices available
fi

# Restart CoreSimulator service by booting a simulator (this will start the service)
echo "5. Restarting CoreSimulator service..."
# Try to boot the first available iPhone simulator to restart the service
FIRST_DEVICE=$(xcrun simctl list devices available | grep -i "iphone" | head -1 | grep -oE '[A-F0-9-]{36}' | head -1)

if [ -n "$FIRST_DEVICE" ]; then
    echo "   Booting device $FIRST_DEVICE to restart service..."
    xcrun simctl boot "$FIRST_DEVICE" 2>/dev/null || true
    sleep 2
    xcrun simctl shutdown "$FIRST_DEVICE" 2>/dev/null || true
else
    echo "   No available iPhone simulator found, service will restart on next Xcode launch"
fi

echo ""
echo "✅ Simulator service reset complete!"
echo ""
echo "Next steps:"
echo "1. Close Xcode completely (if open)"
echo "2. Wait 5-10 seconds"
echo "3. Reopen Xcode"
echo "4. Try running your app again"
echo ""
echo "If the issue persists, try:"
echo "  - Restart your Mac"
echo "  - Reset a specific simulator: ./fix_simulator.sh <DEVICE_ID>"
echo "  - Erase all simulators: xcrun simctl erase all"

