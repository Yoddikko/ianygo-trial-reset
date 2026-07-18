#!/bin/bash
# ==============================================================================
# iAnyGo Trial Reset Tool v1.1
# ==============================================================================
set -euo pipefail

DRY_RUN=false
FORCE=false
HOME_DIR="$HOME"
BACKUP_DIR="${HOME_DIR}/Desktop/iAnyGo-Trial-Backup-$(date +%Y%m%d_%H%M%S)"
DO_BACKUP=true
VERBOSE=true

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info()    { echo -e "${BLUE}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*"; }
header()  { echo -e "\n${BOLD}═══ $* ═══${NC}"; }

for arg in "$@"; do
    case "$arg" in
        --dry-run|-n) DRY_RUN=true; DO_BACKUP=false ;;
        --force|-f)   FORCE=true ;;
        --no-backup)  DO_BACKUP=false ;;
        --help|-h)
            echo "Usage: $0 [--dry-run] [--force] [--no-backup]"
            echo "  --dry-run  Show what would be deleted"
            echo "  --force    Skip confirmation prompt (for GUI/non-interactive use)"
            exit 0 ;;
    esac
done

# ── Safety check (skip if --force) ───────────────────────────────────────────

if [ "$DRY_RUN" = false ] && [ "$FORCE" = false ]; then
    echo -e "\n${YELLOW}${BOLD}WARNING: This will delete iAnyGo trial data${NC}\n"
    read -p "Continue? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi
fi

# ── Helpers ──────────────────────────────────────────────────────────────────

deleted_count=0
backed_up_count=0
skipped_count=0

delete_item() {
    local item="$1"
    local description="${2:-}"
    item="${item/#\~/$HOME_DIR}"

    if [ ! -e "$item" ] && [ ! -L "$item" ]; then
        [ "$VERBOSE" = true ] && [ -n "$description" ] && \
            warn "$description — not found: $item"
        ((skipped_count++)) || true
        return 0
    fi

    if [ "$DRY_RUN" = true ]; then
        info "[DRY-RUN] Would delete: $item"
        [ -n "$description" ] && info "         → $description"
        ((deleted_count++)) || true
        return 0
    fi

    if [ "$DO_BACKUP" = true ]; then
        local backup_path="$BACKUP_DIR/${item#$HOME_DIR/}"
        mkdir -p "$(dirname "$backup_path")"
        cp -R "$item" "$backup_path" 2>/dev/null && ((backed_up_count++)) || true
    fi

    if rm -rf "$item" 2>/dev/null; then
        success "${description:-Deleted: $item}"
        ((deleted_count++)) || true
    else
        error "FAILED: ${description:-$item}"
    fi
}

# ── Step 1: Kill processes ───────────────────────────────────────────────────

header "Step 1: Terminating iAnyGo processes"

for pname in "iAnyGo" "AnyGo" "AnyGoHelper" "AnyGoHelper2" "com.ianygo.ianygo2" "com.Tenorshare.ianygo2" "com.itoolab.AnyGo" "com.ultfone.ianygo2"; do
    pids=$(pgrep -f "$pname" 2>/dev/null || true)
    for pid in $pids; do
        if [ "$DRY_RUN" = true ]; then
            info "[DRY-RUN] Would kill: $pname (PID $pid)"
        else
            kill -9 "$pid" 2>/dev/null || true
            success "Killed: $pname (PID $pid)"
        fi
    done
done
[ "$DRY_RUN" = false ] && sleep 1

# ── Step 2: Preferences ──────────────────────────────────────────────────────

header "Step 2: Deleting preferences"

PREFS=(
    "~/Library/Preferences/com.ianygo.iAnyGo.plist"
    "~/Library/Preferences/com.ianygo.ianygo2.plist"
    "~/Library/Preferences/com.ianygo.www.iAnyGo.plist"
    "~/Library/Preferences/com.tenorshare.iAnyGo.plist"
    "~/Library/Preferences/com.tenorshare.www.iAnyGo.plist"
    "~/Library/Preferences/com.Tenorshare.ianygo2.plist"
    "~/Library/Preferences/com.itoolab.AnyGo.plist"
    "~/Library/Preferences/com.ultfone.ianygo2.plist"
    "~/Library/Preferences/com.ruanniu.iAnyGo.plist"
    "~/Library/Preferences/com.ruanniu.iAnyGoTimes.plist"
)
for pref in "${PREFS[@]}"; do delete_item "$pref" "Pref"; done

# ── Step 3: Application Support ──────────────────────────────────────────────

header "Step 3: Deleting Application Support"

APPSUP=(
    "~/Library/Application Support/iAnyGo"
    "~/Library/Application Support/iAnyGo_com_Mac"
    "~/Library/Application Support/Tenorshare_iAnyGo_Mac"
    "~/Library/Application Support/Tenorshare/iAnyGo"
    "~/Library/Application Support/Tenorshare"
    "~/Library/Application Support/com.ianygo.ianygo2"
    "~/Library/Application Support/com.Tenorshare.ianygo2"
    "~/Library/Application Support/com.itoolab.AnyGo"
    "~/Library/Application Support/com.ultfone.ianygo2"
    "~/Library/Application Support/AnyGo"
    "~/Library/Application Support/Logs/www.ianygo.com.iAnyGo"
)
for dir in "${APPSUP[@]}"; do delete_item "$dir" "AppSupport"; done

# ── Step 4: Caches (including ~/Library/Caches) ──────────────────────────────

header "Step 4: Deleting caches"

CACHES=(
    "~/Library/Caches/iAnyGo"
    "~/Library/Caches/iAnyGo_data"
    "~/Library/Caches/com.ianygo.ianygo2"
    "~/Library/Caches/com.Tenorshare.ianygo2"
    "~/Library/Caches/com.itoolab.AnyGo"
    "~/Library/Caches/com.ultfone.ianygo2"
    "~/Library/Caches/Tenorshare"
    "~/Library/Caches/com.plausiblelabs.crashreporter.data/com.ianygo.ianygo2"
    "~/Library/Caches/com.plausiblelabs.crashreporter.data/com.Tenorshare.ianygo2"
    "~/Library/Caches/com.plausiblelabs.crashreporter.data/com.itoolab.AnyGo"
    "~/Library/Caches/com.plausiblelabs.crashreporter.data/com.ultfone.ianygo2"
)
for dir in "${CACHES[@]}"; do delete_item "$dir" "Cache"; done

# ── Step 4b: Container caches (macOS sandbox) ────────────────────────────────

header "Step 4b: Deleting container caches (/var/folders)"

# macOS sandbox containers — these persist even when ~/Library is clean
CONTAINER_BUNDLES=(
    "com.Tenorshare.ianygo2"
    "com.ianygo.ianygo2"
    "com.itoolab.AnyGo"
    "com.ultfone.ianygo2"
)

for bundle in "${CONTAINER_BUNDLES[@]}"; do
    for container in /var/folders/*/C/"$bundle"; do
        [ -d "$container" ] && delete_item "$container" "Container($bundle)"
    done
done

# ── Step 4c: Temp folders ────────────────────────────────────────────────────

header "Step 4c: Deleting temp folders"

TEMP_PATHS=(
    "/var/folders/y8/qkx_w67n1wq2w9dzmw5nhhf80000gq/T/PoGoskill"
    "/var/folders/y8/qkx_w67n1wq2w9dzmw5nhhf80000gq/T/iAnyGo_com_Mac_iay"
)
# Also find any dynamically-named temp dirs
for pattern in "PoGoskill" "iAnyGo_com_Mac" "Tenorshare_iAnyGo"; do
    for found in /var/folders/*/T/*"$pattern"*; do
        [ -e "$found" ] && delete_item "$found" "Temp"
    done 2>/dev/null
done
for path in "${TEMP_PATHS[@]}"; do delete_item "$path" "Temp"; done

# ── Step 5: HTTP Storages ────────────────────────────────────────────────────

header "Step 5: Deleting HTTP storages"

HTTP=(
    "~/Library/HTTPStorages/com.ianygo.ianygo2"
    "~/Library/HTTPStorages/com.Tenorshare.ianygo2"
    "~/Library/HTTPStorages/com.itoolab.AnyGo"
    "~/Library/HTTPStorages/com.ultfone.ianygo2"
    "~/Library/HTTPStorages/com.ianygo.ianygo2.binarycookies"
    "~/Library/HTTPStorages/com.Tenorshare.ianygo2.binarycookies"
    "~/Library/HTTPStorages/com.itoolab.AnyGo.binarycookies"
    "~/Library/HTTPStorages/com.ultfone.ianygo2.binarycookies"
)
for item in "${HTTP[@]}"; do delete_item "$item" "HTTP"; done

# ── Step 6: Saved Application State ──────────────────────────────────────────

header "Step 6: Deleting saved state"

SAVED=(
    "~/Library/Saved Application State/com.Tenorshare.ianygo2.savedState"
    "~/Library/Saved Application State/com.ianygo.ianygo2.savedState"
    "~/Library/Saved Application State/com.itoolab.AnyGo.savedState"
    "~/Library/Saved Application State/com.ultfone.ianygo2.savedState"
)
for dir in "${SAVED[@]}"; do delete_item "$dir" "SavedState"; done

# ── Step 7: WebKit ───────────────────────────────────────────────────────────

header "Step 7: Deleting WebKit data"

WEBKIT=(
    "~/Library/WebKit/com.itoolab.AnyGo"
    "~/Library/WebKit/com.ianygo.ianygo2"
    "~/Library/WebKit/com.Tenorshare.ianygo2"
    "~/Library/WebKit/com.ultfone.ianygo2"
)
for dir in "${WEBKIT[@]}"; do delete_item "$dir" "WebKit"; done

# ── Step 8: Crash Reports ────────────────────────────────────────────────────

header "Step 8: Deleting crash reports"

for pattern in \
    "~/Library/Application Support/CrashReporter/AnyGo_*.plist" \
    "~/Library/Application Support/CrashReporter/iAnyGo_*.plist" \
    "~/Library/Application Support/CrashReporter/Tenorshare_iAnyGo_*.plist"; do
    for file in ${pattern/#\~/$HOME_DIR}; do
        [ -e "$file" ] && delete_item "$file" "CrashReport"
    done
done

# ── Step 9: Flush DNS ────────────────────────────────────────────────────────

header "Step 9: Flushing DNS cache"

if [ "$DRY_RUN" = true ]; then
    info "[DRY-RUN] Would flush DNS"
else
    sudo dscacheutil -flushcache 2>/dev/null && success "DNS flushed" || warn "DNS flush failed"
    sudo killall -HUP mDNSResponder 2>/dev/null && success "mDNSResponder restarted" || warn "mDNSResponder restart failed"
fi

# ── Summary ──────────────────────────────────────────────────────────────────

header "Reset Complete"

if [ "$DRY_RUN" = true ]; then
    echo "  [DRY-RUN] Would delete: $deleted_count | Skip: $skipped_count"
else
    echo "  Deleted:  $deleted_count"
    echo "  BackedUp: $backed_up_count → $BACKUP_DIR"
    echo "  Skipped:  $skipped_count"
fi

echo ""
echo "Next:"
echo "  1. sudo $0/../block_ianygo_hosts.sh   ← block activation servers"
echo "  2. REBOOT your Mac"
echo "  3. Launch iAnyGo — should be fresh"
[ "$DRY_RUN" = false ] && [ "$DO_BACKUP" = true ] && \
    echo -e "\n${YELLOW}Restore backup: cp -R $BACKUP_DIR/* ~/${NC}"
echo -e "\n${YELLOW}HW UUID: $(ioreg -d2 -c IOPlatformExpertDevice | awk -F\" '/IOPlatformUUID/{print $(NF-1)}')${NC}"
