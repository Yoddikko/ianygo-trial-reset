#!/bin/bash
# ==============================================================================
# iAnyGo Activation Server Blocker
# ==============================================================================
# Blocks iAnyGo activation/update servers via /etc/hosts to prevent server-side
# trial validation. Use this together with the trial reset script.
#
# The app phones home to:
#   - update.ianygo.com       (update + license check)
#   - update.tenorshare.com   (Tenorshare-branded update)
#   - account.tenorshare.com  (account/license validation)
#   - api.ianygo.com          (API endpoint)
#
# Usage:
#   sudo ./block_ianygo_hosts.sh          # Block servers
#   sudo ./block_ianygo_hosts.sh --remove # Unblock servers
#   ./block_ianygo_hosts.sh --status      # Check if servers are blocked
# ==============================================================================

HOSTS_FILE="/etc/hosts"
MARKER_START="# >>> iAnyGo Trial Reset — blocked servers >>>"
MARKER_END="# <<< iAnyGo Trial Reset — blocked servers <<<"

SERVERS=(
    "update.ianygo.com"
    "update.tenorshare.com"
    "account.tenorshare.com"
    "api.ianygo.com"
    "www.ianygo.com"
    "download.tenorshare.com"
    "license.tenorshare.com"
)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# ── Parse arguments ──────────────────────────────────────────────────────────

ACTION="block"
for arg in "$@"; do
    case "$arg" in
        --remove|-r|--unblock)
            ACTION="remove"
            ;;
        --status|-s)
            ACTION="status"
            ;;
        --help|-h)
            echo "iAnyGo Activation Server Blocker"
            echo ""
            echo "Usage: sudo $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  (default)    Block activation servers"
            echo "  --remove, -r Remove the block"
            echo "  --status, -s Check if servers are currently blocked"
            echo "  --help, -h   Show this help"
            exit 0
            ;;
    esac
done

# ── Status check ─────────────────────────────────────────────────────────────

if [ "$ACTION" = "status" ]; then
    echo "iAnyGo Activation Servers Status:"
    echo "================================="
    for server in "${SERVERS[@]}"; do
        if grep -q "0.0.0.0 $server" "$HOSTS_FILE" 2>/dev/null; then
            echo -e "  ${GREEN}✓ BLOCKED${NC} — $server → 0.0.0.0"
        else
            echo -e "  ${RED}✗ OPEN${NC}   — $server"
        fi
    done
    echo ""
    echo "Blocked via /etc/hosts:"
    if grep -q "$MARKER_START" "$HOSTS_FILE" 2>/dev/null; then
        echo "  Active (marker found)"
    else
        echo "  Not active (no marker found)"
    fi
    exit 0
fi

# ── Remove block ─────────────────────────────────────────────────────────────

if [ "$ACTION" = "remove" ]; then
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: Must run with sudo to modify /etc/hosts"
        echo "Usage: sudo $0 --remove"
        exit 1
    fi

    if grep -q "$MARKER_START" "$HOSTS_FILE" 2>/dev/null; then
        # Remove lines between markers
        sed -i '' "/$MARKER_START/,/$MARKER_END/d" "$HOSTS_FILE"
        echo -e "${GREEN}✓ Block removed. iAnyGo servers are now accessible.${NC}"
    else
        echo "No iAnyGo block marker found in /etc/hosts. Nothing to remove."
    fi

    # Flush DNS
    dscacheutil -flushcache 2>/dev/null
    killall -HUP mDNSResponder 2>/dev/null
    echo "DNS cache flushed."
    exit 0
fi

# ── Add block ────────────────────────────────────────────────────────────────

if [ "$ACTION" = "block" ]; then
    if [ "$(id -u)" -ne 0 ]; then
        echo "Error: Must run with sudo to modify /etc/hosts"
        echo "Usage: sudo $0"
        exit 1
    fi

    # Check if already blocked
    if grep -q "$MARKER_START" "$HOSTS_FILE" 2>/dev/null; then
        echo -e "${YELLOW}iAnyGo servers are already blocked.${NC}"
        echo "To remove: sudo $0 --remove"
        exit 0
    fi

    # Create backup
    cp "$HOSTS_FILE" "${HOSTS_FILE}.backup-$(date +%Y%m%d_%H%M%S)"
    echo "Backup of /etc/hosts created."

    # Add block entries
    {
        echo ""
        echo "$MARKER_START"
        for server in "${SERVERS[@]}"; do
            echo "0.0.0.0 $server"
        done
        echo "$MARKER_END"
    } >> "$HOSTS_FILE"

    echo -e "${GREEN}✓ iAnyGo activation servers blocked.${NC}"
    echo ""
    echo "Blocked servers:"
    for server in "${SERVERS[@]}"; do
        echo "  0.0.0.0 → $server"
    done

    # Flush DNS
    dscacheutil -flushcache 2>/dev/null
    killall -HUP mDNSResponder 2>/dev/null
    echo ""
    echo "DNS cache flushed."
    echo ""
    echo "To remove the block: sudo $0 --remove"
fi
