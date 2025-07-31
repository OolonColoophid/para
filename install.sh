#!/bin/bash

# Para CLI Installation Script
# Builds Para in release mode and installs to /usr/local/bin

set -e  # Exit on any error

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/.build"
INSTALL_DIR="/usr/local/bin"
BINARY_NAME="para"

echo "🔨 Building Para CLI for release..."

# Clean any previous builds
if [ -d "$BUILD_DIR" ]; then
    echo "   Cleaning previous build..."
    rm -rf "$BUILD_DIR"
fi

# Get build number from git
echo "   Determining build number..."
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || date +%Y%m%d)
echo "   Build number: $BUILD_NUMBER"

# Replace build number placeholder in source code
echo "   Injecting build number into source..."
MAIN_SWIFT="$SCRIPT_DIR/para/main.swift"
if [ -f "$MAIN_SWIFT" ]; then
    # Create a temporary copy with build number injected
    sed "s/PARA_BUILD_NUMBER/$BUILD_NUMBER/g" "$MAIN_SWIFT" > "$MAIN_SWIFT.tmp"
    mv "$MAIN_SWIFT.tmp" "$MAIN_SWIFT"
fi

# Build using Xcode in release configuration
echo "   Building with Xcode..."
xcodebuild -scheme para -configuration Release -derivedDataPath "$BUILD_DIR" build

# Restore original source file
echo "   Restoring source file..."
git checkout "$MAIN_SWIFT" 2>/dev/null || true

# Find the built binary
BUILT_BINARY=$(find "$BUILD_DIR" -name "$BINARY_NAME" -type f -perm +111 | head -1)

if [ -z "$BUILT_BINARY" ]; then
    echo "❌ Error: Could not find built binary"
    exit 1
fi

echo "   Built binary found at: $BUILT_BINARY"

# Check if we need sudo for installation
if [ ! -w "$INSTALL_DIR" ]; then
    echo "🔐 Requesting administrator privileges to install to $INSTALL_DIR..."
    SUDO_CMD="sudo"
else
    SUDO_CMD=""
fi

# Install the binary
echo "📦 Installing Para CLI..."
$SUDO_CMD mkdir -p "$INSTALL_DIR"
$SUDO_CMD cp "$BUILT_BINARY" "$INSTALL_DIR/$BINARY_NAME"
$SUDO_CMD chmod +x "$INSTALL_DIR/$BINARY_NAME"

# Verify installation
if [ -x "$INSTALL_DIR/$BINARY_NAME" ]; then
    VERSION_OUTPUT=$("$INSTALL_DIR/$BINARY_NAME" version 2>/dev/null || echo "")
    if [[ "$VERSION_OUTPUT" == *"Para version"* ]]; then
        echo "✅ Para CLI successfully installed!"
        echo "   Location: $INSTALL_DIR/$BINARY_NAME"
        echo "   Version: $("$INSTALL_DIR/$BINARY_NAME" version | head -1)"
        echo ""
        echo "🚀 You can now use 'para' from anywhere in your terminal."
        echo "   Try: para --help"
        echo "   Setup: para environment"
    else
        echo "⚠️  Installation completed but verification failed."
        echo "   Binary installed at: $INSTALL_DIR/$BINARY_NAME"
    fi
else
    echo "❌ Installation failed - binary not found at $INSTALL_DIR/$BINARY_NAME"
    exit 1
fi

# Clean up build directory
echo "🧹 Cleaning up build files..."
rm -rf "$BUILD_DIR"

echo "✨ Installation complete!"