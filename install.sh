#!/bin/bash

# Para Installation Script
# Builds Para CLI and Menu Bar App in release mode

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="para"
APP_NAME="Para"
APP_BUNDLE="$APP_NAME.app"

echo "🔨 Building Para CLI and Menu Bar App..."

# Clean any previous builds
if [ -d "$BUILD_DIR" ]; then
    echo "   Cleaning previous build..."
    rm -rf "$BUILD_DIR"
fi

# Get build number from git
echo "   Determining build information..."
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || date +%Y%m%d)
BUILD_TIMESTAMP=$(date -u "+%Y-%m-%d %H:%M:%S UTC")
echo "   Build number: $BUILD_NUMBER"
echo "   Build timestamp: $BUILD_TIMESTAMP"

# Replace build placeholders in source code
echo "   Injecting build information into source..."
CORE_SWIFT="$SCRIPT_DIR/para/ParaCore.swift"
if [ -f "$CORE_SWIFT" ]; then
    # Backup original source file
    cp "$CORE_SWIFT" "$CORE_SWIFT.backup"

    # Create a temporary copy with build info injected
    sed -e "s/PARA_BUILD_TIMESTAMP/$BUILD_TIMESTAMP/g" \
        -e "s/PARA_BUILD_NUMBER/$BUILD_NUMBER/g" \
        "$CORE_SWIFT" > "$CORE_SWIFT.tmp"
    mv "$CORE_SWIFT.tmp" "$CORE_SWIFT"
fi

# Also inject into ParaKit for menu bar app
VERSION_SWIFT="$SCRIPT_DIR/ParaKit/ParaVersion.swift"
if [ -f "$VERSION_SWIFT" ]; then
    cp "$VERSION_SWIFT" "$VERSION_SWIFT.backup"
    sed -e "s/PARA_BUILD_TIMESTAMP/$BUILD_TIMESTAMP/g" \
        -e "s/PARA_BUILD_NUMBER/$BUILD_NUMBER/g" \
        "$VERSION_SWIFT" > "$VERSION_SWIFT.tmp"
    mv "$VERSION_SWIFT.tmp" "$VERSION_SWIFT"
fi

# Build using Swift Package Manager
echo "   Building CLI with Swift Package Manager..."
swift build -c release --product para

# Build Menu Bar App
echo "   Building Menu Bar App..."
swift build -c release --product ParaMenuBar

# Find the built binaries (SPM uses architecture-specific directories)
CLI_BINARY=$(find "$BUILD_DIR" -name "para" -type f | grep "/release/para$" | grep -v "\.dSYM" | head -1)
MENUBAR_BINARY=$(find "$BUILD_DIR" -name "ParaMenuBar" -type f | grep "/release/ParaMenuBar$" | grep -v "\.dSYM" | head -1)

if [ ! -f "$CLI_BINARY" ]; then
    echo "❌ Error: Could not find CLI binary at $CLI_BINARY"
    exit 1
fi

if [ ! -f "$MENUBAR_BINARY" ]; then
    echo "❌ Error: Could not find Menu Bar binary at $MENUBAR_BINARY"
    exit 1
fi

echo "   CLI binary found at: $CLI_BINARY"
echo "   Menu Bar binary found at: $MENUBAR_BINARY"

# Create .app bundle for Menu Bar App
echo "   Creating .app bundle..."
APP_DIR="$BUILD_DIR/$APP_BUNDLE"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$MENUBAR_BINARY" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

# Create app icon from asset catalog
echo "   Creating app icon..."
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
mkdir -p "$ICONSET_DIR"
ASSETS_DIR="$SCRIPT_DIR/Assets.xcassets/AppIcon.appiconset"
if [ -d "$ASSETS_DIR" ]; then
    # Copy icons with correct names for iconutil
    cp "$ASSETS_DIR/mac16.png" "$ICONSET_DIR/icon_16x16.png" 2>/dev/null || true
    cp "$ASSETS_DIR/mac32.png" "$ICONSET_DIR/icon_16x16@2x.png" 2>/dev/null || true
    cp "$ASSETS_DIR/mac32.png" "$ICONSET_DIR/icon_32x32.png" 2>/dev/null || true
    cp "$ASSETS_DIR/mac64.png" "$ICONSET_DIR/icon_32x32@2x.png" 2>/dev/null || true
    cp "$ASSETS_DIR/mac128.png" "$ICONSET_DIR/icon_128x128.png" 2>/dev/null || true
    cp "$ASSETS_DIR/mac256.png" "$ICONSET_DIR/icon_128x128@2x.png" 2>/dev/null || true
    cp "$ASSETS_DIR/mac256.png" "$ICONSET_DIR/icon_256x256.png" 2>/dev/null || true
    cp "$ASSETS_DIR/mac512.png" "$ICONSET_DIR/icon_256x256@2x.png" 2>/dev/null || true
    cp "$ASSETS_DIR/mac512.png" "$ICONSET_DIR/icon_512x512.png" 2>/dev/null || true
    cp "$ASSETS_DIR/mac1024.png" "$ICONSET_DIR/icon_512x512@2x.png" 2>/dev/null || true

    # Create .icns file
    if iconutil -c icns "$ICONSET_DIR" -o "$APP_DIR/Contents/Resources/AppIcon.icns" 2>/dev/null; then
        echo "   ✅ App icon created"
    else
        echo "   ⚠️  Could not create .icns file"
    fi
    rm -rf "$ICONSET_DIR"
fi

# Create Info.plist
cat > "$APP_DIR/Contents/Info.plist" << 'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>Para</string>
	<key>CFBundleIdentifier</key>
	<string>com.para.menubar</string>
	<key>CFBundleIconFile</key>
	<string>AppIcon</string>
	<key>CFBundleName</key>
	<string>Para</string>
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
	<key>NSPrincipalClass</key>
	<string>NSApplication</string>
</dict>
</plist>
PLIST_EOF

# Code sign the binaries for distribution
echo "🔐 Code signing binaries..."

# Try different signing identities in order of preference
SIGNING_IDENTITIES=(
    "Developer ID Application"
    "Apple Development"
    "-"  # Ad-hoc signing as fallback
)

SIGNED=false
for identity in "${SIGNING_IDENTITIES[@]}"; do
    echo "   Trying to sign with: $identity"

    if [[ "$identity" == "-" ]]; then
        # Ad-hoc signing
        if codesign --sign "$identity" --force "$CLI_BINARY" 2>/dev/null && \
           codesign --sign "$identity" --force --deep "$APP_DIR" 2>/dev/null; then
            echo "   ✅ Ad-hoc code signature applied to both binaries"
            SIGNED=true
            break
        fi
    else
        # Try signing with the identity
        if codesign --sign "$identity" --force --options runtime "$CLI_BINARY" 2>/dev/null && \
           codesign --sign "$identity" --force --deep --options runtime "$APP_DIR" 2>/dev/null; then
            if codesign --verify --verbose "$CLI_BINARY" 2>/dev/null && \
               codesign --verify --verbose "$APP_DIR" 2>/dev/null; then
                echo "   ✅ Code signature verified with $identity"
                SIGNED=true
                break
            fi
        fi
    fi
done

if [[ "$SIGNED" == false ]]; then
    echo "   ⚠️  Could not sign binaries with any available identity"
    echo "   The binaries may be blocked by Gatekeeper on other machines"
    echo "   Consider running: xattr -d com.apple.quarantine /usr/local/bin/para"
    echo "   and: xattr -d com.apple.quarantine \"/Applications/$APP_BUNDLE\""
    echo "   after installation to remove quarantine attributes"
fi

# Check if we need sudo for installation
if [ ! -w "$INSTALL_DIR" ]; then
    echo "🔐 Requesting administrator privileges to install to $INSTALL_DIR..."
    SUDO_CMD="sudo"
else
    SUDO_CMD=""
fi

# Install the CLI binary
echo "📦 Installing Para CLI..."
$SUDO_CMD mkdir -p "$INSTALL_DIR"
$SUDO_CMD cp "$CLI_BINARY" "$INSTALL_DIR/$BINARY_NAME"
$SUDO_CMD chmod +x "$INSTALL_DIR/$BINARY_NAME"

# Install the Menu Bar App
echo "📦 Installing Para Menu Bar App..."
$SUDO_CMD cp -R "$APP_DIR" "/Applications/"

# Remove quarantine attributes to prevent Gatekeeper issues
echo "🧹 Removing quarantine attributes..."
$SUDO_CMD xattr -d com.apple.quarantine "$INSTALL_DIR/$BINARY_NAME" 2>/dev/null || true
$SUDO_CMD xattr -dr com.apple.quarantine "/Applications/$APP_BUNDLE" 2>/dev/null || true

# Verify installation
if [ -x "$INSTALL_DIR/$BINARY_NAME" ] && [ -d "/Applications/$APP_BUNDLE" ]; then
    VERSION_OUTPUT=$("$INSTALL_DIR/$BINARY_NAME" version 2>/dev/null || echo "")
    if [[ "$VERSION_OUTPUT" == *"Para version"* ]]; then
        echo "✅ Para CLI successfully installed!"
        echo "   Location: $INSTALL_DIR/$BINARY_NAME"
        echo "   Version: $("$INSTALL_DIR/$BINARY_NAME" version | head -1)"
        echo ""
        echo "✅ Para Menu Bar App successfully installed!"
        echo "   Location: /Applications/$APP_BUNDLE"
        echo ""
        echo "🚀 You can now:"
        echo "   • Use 'para' from anywhere in your terminal (para --help)"
        echo "   • Launch the menu bar app: open \"/Applications/$APP_BUNDLE\""
        echo "   • Add Para to login items for automatic startup"
        echo ""
        echo "📝 Setup: para environment"
    else
        echo "⚠️  Installation completed but verification failed."
        echo "   CLI installed at: $INSTALL_DIR/$BINARY_NAME"
        echo "   Menu Bar App installed at: /Applications/$APP_BUNDLE"
        echo "   Try running manually: $INSTALL_DIR/$BINARY_NAME --help"
    fi
else
    if [ ! -x "$INSTALL_DIR/$BINARY_NAME" ]; then
        echo "❌ CLI installation failed - binary not found at $INSTALL_DIR/$BINARY_NAME"
    fi
    if [ ! -d "/Applications/$APP_BUNDLE" ]; then
        echo "❌ Menu Bar App installation failed - app not found at /Applications/$APP_BUNDLE"
    fi
    exit 1
fi

# Clean up build directory
echo "🧹 Cleaning up build files..."
rm -rf "$BUILD_DIR"

# Restore original source files
echo "   Restoring original source files..."
if [ -f "$CORE_SWIFT.backup" ]; then
    mv "$CORE_SWIFT.backup" "$CORE_SWIFT"
fi
if [ -f "$VERSION_SWIFT.backup" ]; then
    mv "$VERSION_SWIFT.backup" "$VERSION_SWIFT"
fi

echo "✨ Installation complete! Both Para CLI and Menu Bar App are ready to use."