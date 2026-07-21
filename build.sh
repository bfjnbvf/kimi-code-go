#!/bin/bash
# Build script for Kimi Code Go
# Compiles the AppleScript into a macOS .app bundle with custom icon.

set -euo pipefail

APP_NAME="Kimi Code Go"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC="$SCRIPT_DIR/src/main.applescript"
ICON="$SCRIPT_DIR/assets/icon.icns"
BUILD_DIR="$SCRIPT_DIR/build"
APP_PATH="$BUILD_DIR/$APP_NAME.app"

echo "🔨 Building $APP_NAME..."

if [ ! -f "$SRC" ] || [ ! -f "$ICON" ]; then
    echo "Missing source script or icon asset." >&2
    exit 1
fi

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Compile AppleScript into app bundle (stay-open applet)
osacompile -o "$APP_PATH" -x "$SRC"

# Ensure stay-open behavior
/usr/libexec/PlistBuddy -c "Add :OSAAppletStayOpen bool true" "$APP_PATH/Contents/Info.plist" 2>/dev/null || \
/usr/libexec/PlistBuddy -c "Set :OSAAppletStayOpen true" "$APP_PATH/Contents/Info.plist"

# Set display name
/usr/libexec/PlistBuddy -c "Set :CFBundleName $APP_NAME" "$APP_PATH/Contents/Info.plist"

# Remove Asset Catalog (would override .icns)
rm -f "$APP_PATH/Contents/Resources/Assets.car"
/usr/libexec/PlistBuddy -c "Delete :CFBundleIconName" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true

# Replace icon
if [ -f "$ICON" ]; then
    cp "$ICON" "$APP_PATH/Contents/Resources/applet.icns"
    echo "  ✓ Custom icon applied"
fi

# Ad-hoc signing is suitable for local use only. Use a Developer ID identity
# and notarization before distributing this application.
codesign --force --sign - "$APP_PATH"

echo "✅ Built: $APP_PATH"
echo ""
echo "To install: cp -R \"$APP_PATH\" /Applications/"
