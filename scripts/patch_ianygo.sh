#!/bin/bash
# ==============================================================================
# iAnyGo Trial Reset — Binary Patcher & Launcher
# ==============================================================================
# Patches iAnyGo (v4.11.8) to bypass trial checks, then launches the app.
# Must be re-run after each iAnyGo update.
# ==============================================================================
set -euo pipefail

ORIGINAL="/Applications/iAnyGo.app"
PATCHED="/tmp/ianygo_patched.app"
BIN="$PATCHED/Contents/MacOS/iAnyGo_com_Mac"
TSLIB="$PATCHED/Contents/Frameworks/TSLibrary.framework/TSLibrary"

echo "=== iAnyGo Trial Reset Patcher ==="
echo ""

# ── Kill running instances ──────────────────────────────────────────────────
killall iAnyGo_com_Mac QtWebEngineProcess 2>/dev/null || true
sleep 1

# ── Clean stale state ──────────────────────────────────────────────────────
find /var/folders -name "iAnyGo_com_Mac_iay" -delete 2>/dev/null || true
rm -rf ~/Library/Preferences/com.tenorshare.iAnyGo.plist \
       ~/Library/Preferences/com.ianygo.iAnyGo.plist \
       ~/Library/Preferences/com.ianygo.www.iAnyGo.plist \
       ~/Library/Application\ Support/iAnyGo \
       ~/Library/Application\ Support/com.ianygo.ianygo2 \
       ~/Library/Caches/com.ianygo.ianygo2 \
       ~/Library/Caches/com.Tenorshare.ianygo2 2>/dev/null || true

# ── Build patched copy ─────────────────────────────────────────────────────
echo "Building patched copy..."
rm -rf "$PATCHED"
cp -R "$ORIGINAL" "$PATCHED"
codesign --remove-signature "$PATCHED" 2>/dev/null || true

# Clear Rosetta AOT cache (critical — patches won't work without this)
sudo rm -rf /private/var/db/oah 2>/dev/null || true

# ── Apply patches ──────────────────────────────────────────────────────────

echo "Applying patches..."

# Main binary patches (iAnyGo_com_Mac)
# ------------------------------------
# P1: isTrialHasTimes → always return true
#     cmpl $0x1, 0x80(%rdi) → cmpl $-1, 0x80(%rdi)
printf '\xff' | dd of="$BIN" bs=1 seek=$((0x31d2fc)) count=1 conv=notrunc 2>/dev/null

# P2: isTrialEndOfPositionModify → always return false (enable "Start" button)
printf '\x30\xc0\x90' | dd of="$BIN" bs=1 seek=$((0x318598)) count=3 conv=notrunc 2>/dev/null

# P3-6: isTrialEndOf{MultiPoint,Single,Joystick,Jump} → always false
for OFF in 0x318838 0x318ae0 0x318eac 0x3192c0; do
    printf '\x30\xc0\x90' | dd of="$BIN" bs=1 seek=$OFF count=3 conv=notrunc 2>/dev/null
done

# P7: handleResponseOfGet → add $127 to remaining time per server call
printf '\x83\x83\x84\x00\x00\x00\x7f' | dd of="$BIN" bs=1 seek=$((0x31bdbf)) count=7 conv=notrunc 2>/dev/null

# P8: getRemainingDurationSec → return 999999 (show positive countdown)
printf '\xB8\x3F\x42\x0F\x00\x90' | dd of="$BIN" bs=1 seek=$((0x31b1d4)) count=6 conv=notrunc 2>/dev/null

# P9-10: trialTextOfPositionModify → always show "277:46:39" (not "00:00")
printf '\xBE\x3F\x42\x0F\x00\x90\x90' | dd of="$BIN" bs=1 seek=$((0x31d08f)) count=7 conv=notrunc 2>/dev/null
printf '\xBE\x3F\x42\x0F\x00\x90\x90' | dd of="$BIN" bs=1 seek=$((0x31d0a0)) count=7 conv=notrunc 2>/dev/null

echo "  10 patches applied"
echo ""

# ── Launch ─────────────────────────────────────────────────────────────────
echo "Launching patched iAnyGo..."
open "$PATCHED"
sleep 3

if pgrep iAnyGo_com_Mac >/dev/null; then
    echo "✓ iAnyGo running — trial unlocked"
else
    echo "✗ Launch failed — try running: open $PATCHED"
fi
