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
echo "   Determining build information..."
BUILD_NUMBER=$(git rev-list --count HEAD 2>/dev/null || date +%Y%m%d)
BUILD_TIMESTAMP=$(date -u "+%Y-%m-%d %H:%M:%S UTC")
echo "   Build number: $BUILD_NUMBER"
echo "   Build timestamp: $BUILD_TIMESTAMP"

# Replace build placeholders in source code
echo "   Injecting build information into source..."
MAIN_SWIFT="$SCRIPT_DIR/para/main.swift"
if [ -f "$MAIN_SWIFT" ]; then
    # Backup original source file
    cp "$MAIN_SWIFT" "$MAIN_SWIFT.backup"
    
    # Create a temporary copy with build info injected
    sed -e "s/PARA_BUILD_TIMESTAMP/$BUILD_TIMESTAMP/g" \
        -e "s/PARA_BUILD_NUMBER/$BUILD_NUMBER/g" \
        "$MAIN_SWIFT" > "$MAIN_SWIFT.tmp"
    mv "$MAIN_SWIFT.tmp" "$MAIN_SWIFT"
fi

# Build using Xcode in release configuration
echo "   Building with Xcode..."
xcodebuild -scheme para -configuration Release -derivedDataPath "$BUILD_DIR" build

# Find the built binary
BUILT_BINARY=$(find "$BUILD_DIR" -name "$BINARY_NAME" -type f -perm +111 | head -1)

if [ -z "$BUILT_BINARY" ]; then
    echo "❌ Error: Could not find built binary"
    exit 1
fi

echo "   Built binary found at: $BUILT_BINARY"

# Code sign the binary for distribution
echo "🔐 Code signing the binary..."

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
        if codesign --sign "$identity" --force "$BUILT_BINARY" 2>/dev/null; then
            echo "   ✅ Ad-hoc code signature applied"
            SIGNED=true
            break
        fi
    else
        # Try signing with the identity
        if codesign --sign "$identity" --force --options runtime "$BUILT_BINARY" 2>/dev/null; then
            if codesign --verify --verbose "$BUILT_BINARY" 2>/dev/null; then
                echo "   ✅ Code signature verified with $identity"
                SIGNED=true
                break
            fi
        fi
    fi
done

if [[ "$SIGNED" == false ]]; then
    echo "   ⚠️  Could not sign binary with any available identity"
    echo "   The binary may be blocked by Gatekeeper on other machines"
    echo "   Consider running: xattr -d com.apple.quarantine /usr/local/bin/para"
    echo "   after installation to remove quarantine attribute"
fi

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

# Remove quarantine attribute to prevent Gatekeeper issues
echo "🧹 Removing quarantine attributes..."
$SUDO_CMD xattr -d com.apple.quarantine "$INSTALL_DIR/$BINARY_NAME" 2>/dev/null || true

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
        echo "   Try running manually: $INSTALL_DIR/$BINARY_NAME --help"
    fi
else
    echo "❌ Installation failed - binary not found at $INSTALL_DIR/$BINARY_NAME"
    exit 1
fi

# Clean up build directory
echo "🧹 Cleaning up build files..."
rm -rf "$BUILD_DIR"

# Restore original source file
echo "   Restoring original source file..."
if [ -f "$MAIN_SWIFT.backup" ]; then
    mv "$MAIN_SWIFT.backup" "$MAIN_SWIFT"
fi

echo "✨ Installation complete!"