#!/bin/bash
P="/tmp/ianygo_test.app"
B="$P/Contents/MacOS/iAnyGo_com_Mac"

if [ ! -f "$B" ]; then
    rm -rf "$P"
    cp -R /Applications/iAnyGo.app "$P"
    codesign --remove-signature "$P" 2>/dev/null || true
    sudo rm -rf /private/var/db/oah 2>/dev/null || true

    # isTrialHasTimes → always true
    printf '\xff' | dd of="$B" bs=1 seek=$((0x31d2fc)) count=1 conv=notrunc 2>/dev/null
    # handleResponseOfGet → addl $127
    printf '\x83\x83\x84\x00\x00\x00\x7f' | dd of="$B" bs=1 seek=$((0x31bdbf)) count=7 conv=notrunc 2>/dev/null
    # trialTextOfPositionModify → 999999
    printf '\xBE\x3F\x42\x0F\x00\x90\x90' | dd of="$B" bs=1 seek=$((0x31d08f)) count=7 conv=notrunc 2>/dev/null
    printf '\xBE\x3F\x42\x0F\x00\x90\x90' | dd of="$B" bs=1 seek=$((0x31d0a0)) count=7 conv=notrunc 2>/dev/null
    # getRemainingDurationSec → 999999
    printf '\xB8\x3F\x42\x0F\x00\x90' | dd of="$B" bs=1 seek=$((0x31b1d4)) count=6 conv=notrunc 2>/dev/null
    # All 5 isTrialEndOf* → always false
    for O in 0x318598 0x318838 0x318ae0 0x318eac 0x3192c0; do
        printf '\x30\xc0\x90' | dd of="$B" bs=1 seek=$O count=3 conv=notrunc 2>/dev/null
    done
fi

killall iAnyGo_com_Mac QtWebEngineProcess 2>/dev/null || true
sleep 1
find /var/folders -name "iAnyGo_com_Mac_iay" -delete 2>/dev/null
open "$P"
