<h1>
  <img src="https://github.com/user-attachments/assets/832c6a8f-f6b1-4332-aa59-f1048f064a34"
       alt="iAnyGo Trial Reset"
       width="64"
       align="absmiddle">
  iAnyGo Trial Reset
</h1>

Bypasses iAnyGo v4.11.8 free trial via binary patching.

## What it does

- **10 binary patches** to `iAnyGo_com_Mac` and `TSLibrary`
- Unlocks all buttons ("Start", joystick, multi-point, etc.)
- Shows positive countdown instead of "00:00"
- Clears trial state files & Rosetta AOT cache
- Works on Apple Silicon (Rosetta 2 x86_64 binary)




## Quick Start

```bash
cd scripts
./patch_ianygo.sh
```

Relaunch after reboot or app update with:

```bash
./scripts/patch_ianygo.sh
```

## Files

```
ianygo-trial-reset/
├── README.md
├── scripts/
│   ├── patch_ianygo.sh          # Main: apply patches + launch
│   ├── reset_ianygo_trial.sh    # File cleanup only (no binary patches)
│   ├── build_app.sh             # Compile SwiftUI wrapper app
│   └── block_ianygo_hosts.sh    # Block activation servers in /etc/hosts
├── src/
│   └── iAnyGoTrialReset.swift   # SwiftUI GUI wrapper
└── tools/
    └── gcj_fix.py               # GCJ-02 ↔ WGS-84 coordinate converter
```

## How it works

iAnyGo's trial check lives in 5 `isTrialEndOf*` functions and `isTrialHasTimes`.
Each returns `bool` — `true` means "trial ended, block feature."

The patches flip all of them to `false`.

Rosetta 2 caches x86_64→arm64 translations in `/private/var/db/oah/`.
The script clears this cache, otherwise patches are invisible.

## Requirements

- iAnyGo v4.11.8 installed in `/Applications/iAnyGo.app`
- macOS 14+ (Apple Silicon)

## Disclaimer

Educational/research purposes only. Binary patching violates iAnyGo's EULA.
The GCJ-02 converter approximates the official algorithm; expect <5m residual error.
