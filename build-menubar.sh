#!/bin/bash

# Para Menu Bar App Builder
# Builds the menu bar app as a proper macOS .app bundle

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"
APP_NAME="Para Menu"
APP_BUNDLE="$APP_NAME.app"

echo "🔨 Building Para Menu Bar App..."

# Step 1: Build with SwiftPM
echo "  Building with Swift Package Manager..."
swift build -c release --product ParaMenuBar

# Step 2: Find the built binary
BUILT_BINARY="$BUILD_DIR/release/ParaMenuBar"

if [ ! -f "$BUILT_BINARY" ]; then
    echo "❌ Error: Could not find built binary at $BUILT_BINARY"
    exit 1
fi

echo "  Built binary found at: $BUILT_BINARY"

# Step 3: Create .app bundle structure
echo "  Creating .app bundle structure..."
APP_DIR="$BUILD_DIR/$APP_BUNDLE"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

# Step 4: Copy binary
cp "$BUILT_BINARY" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

# Step 5: Create Info.plist
echo "  Creating Info.plist..."
cat > "$APP_DIR/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleDevelopmentRegion</key>
	<string>en</string>
	<key>CFBundleExecutable</key>
	<string>Para Menu</string>
	<key>CFBundleIdentifier</key>
	<string>com.para.menubar</string>
	<key>CFBundleInfoDictionaryVersion</key>
	<string>6.0</string>
	<key>CFBundleName</key>
	<string>Para Menu</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>12.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHumanReadableCopyright</key>
	<string>Copyright © 2024. All rights reserved.</string>
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
EOF

# Step 6: Create a basic icon (optional - can be improved later)
echo "  Creating icon..."
# For now, we'll skip the icon creation as it requires additional tools
# The app will work without it, just won't have a custom icon

echo "✅ Para Menu Bar App built successfully!"
echo "   Location: $APP_DIR"
echo ""
echo "To install:"
echo "   cp -R \"$APP_DIR\" /Applications/"
echo ""
echo "To run:"
echo "   open \"$APP_DIR\""

