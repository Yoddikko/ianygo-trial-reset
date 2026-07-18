#!/bin/bash
# ==============================================================================
# Build Script — iAnyGo Trial Reset App
# ==============================================================================
# Compiles the SwiftUI app and packages it into a .app bundle.
# Requires: Xcode Command Line Tools (swiftc)
# ==============================================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="iAnyGo Trial Reset"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
SOURCES_DIR="$PROJECT_DIR/Sources"
RESOURCES_DIR="$APP_BUNDLE/Contents/Resources"
MACOS_DIR="$APP_BUNDLE/Contents/MacOS"
BINARY_PATH="$MACOS_DIR/iAnyGoTrialReset"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${GREEN}[BUILD]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }

echo ""
echo -e "${BOLD}Building iAnyGo Trial Reset App${NC}"
echo "================================="
echo ""

# ── Check prerequisites ──────────────────────────────────────────────────────

if ! command -v swiftc &>/dev/null; then
    error "swiftc not found. Please install Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

SWIFT_VERSION=$(swiftc --version | head -1)
info "Using: $SWIFT_VERSION"

# ── Create app bundle structure ──────────────────────────────────────────────

info "Creating app bundle structure..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# ── Compile Swift source ─────────────────────────────────────────────────────

SWIFT_SOURCE="$SOURCES_DIR/iAnyGoTrialReset.swift"

if [ ! -f "$SWIFT_SOURCE" ]; then
    error "Swift source not found: $SWIFT_SOURCE"
    exit 1
fi

info "Compiling Swift source..."
swiftc \
    -parse-as-library \
    -o "$BINARY_PATH" \
    -sdk "$(xcrun --show-sdk-path --sdk macosx)" \
    -framework SwiftUI \
    -framework AppKit \
    -framework Security \
    -target arm64-apple-macosx14.0 \
    -O \
    "$SWIFT_SOURCE"

# Check for universal binary (optional: add x86_64 if desired)
if [ "$(uname -m)" = "arm64" ]; then
    info "Compiled for Apple Silicon (arm64)"
fi

info "Binary size: $(du -h "$BINARY_PATH" | cut -f1)"

# ── Copy scripts and resources ───────────────────────────────────────────────

info "Copying scripts to app bundle..."
cp "$PROJECT_DIR/reset_ianygo_trial.sh" "$RESOURCES_DIR/" && \
    chmod +x "$RESOURCES_DIR/reset_ianygo_trial.sh"
cp "$PROJECT_DIR/block_ianygo_hosts.sh" "$RESOURCES_DIR/" && \
    chmod +x "$RESOURCES_DIR/block_ianygo_hosts.sh"

# ── Copy Info.plist (if updated) ─────────────────────────────────────────────

if [ -f "$PROJECT_DIR/Info.plist" ]; then
    cp "$PROJECT_DIR/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
fi

# ── Verify bundle ────────────────────────────────────────────────────────────

info "Verifying bundle..."

if [ ! -f "$BINARY_PATH" ]; then
    error "Binary missing!"
    exit 1
fi

if [ ! -f "$APP_BUNDLE/Contents/Info.plist" ]; then
    error "Info.plist missing!"
    exit 1
fi

# ── Code sign (ad-hoc) ───────────────────────────────────────────────────────

info "Applying ad-hoc code signature..."
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null && \
    info "Ad-hoc signature applied." || \
    warn "Code signing not available (app will still work)."

# ── Clean quarantine attribute ───────────────────────────────────────────────

xattr -dr com.apple.quarantine "$APP_BUNDLE" 2>/dev/null || true

# ── Done ─────────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}${GREEN}✓ Build complete!${NC}"
echo ""
echo "App bundle: $APP_BUNDLE"
echo ""
echo "To run:"
echo "  open \"$APP_BUNDLE\""
echo ""
echo "Or double-click the app in Finder:"
echo "  $PROJECT_DIR/$APP_NAME.app"
echo ""
echo -e "${YELLOW}Note:${NC} If macOS shows a security warning on first launch,"
echo "  go to System Settings → Privacy & Security → scroll down"
echo "  and click 'Open Anyway' for iAnyGo Trial Reset."
