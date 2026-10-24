#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Amazon Linux 2023 — Safe Update Script
# ═══════════════════════════════════════════════════════════
# Performs a controlled update with rollback capability.
# Usage: sudo bash safe-update.sh [--auto]
#   --auto: Skip interactive confirmation (for CI/CD)

set -euo pipefail

AUTO_MODE=false
[[ "${1:-}" == "--auto" ]] && AUTO_MODE=true

LOGFILE="/var/log/al2023-update-$(date +%Y%m%d-%H%M%S).log"
SNAPSHOT_DIR="/var/lib/al2023-updates"
mkdir -p "$SNAPSHOT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOGFILE"
}

die() {
    log "${RED}ERROR: $*${NC}"
    exit 1
}

log "${BOLD}═══════════════════════════════════════════${NC}"
log "${BOLD}  AL2023 Safe Update Process${NC}"
log "${BOLD}═══════════════════════════════════════════${NC}"

# ─── Pre-flight checks ──────────────────────────────────
if [ "$(id -u)" -ne 0 ]; then
    die "This script must be run as root (use sudo)"
fi

if ! command -v dnf &>/dev/null; then
    die "dnf not found. Is this Amazon Linux 2023?"
fi

# ─── Step 1: Record current state ───────────────────────
log "${CYAN}Step 1/6: Recording current system state...${NC}"
current_version=$(cat /etc/os-release | grep VERSION_ID | cut -d= -f2 | tr -d '"')
log "  Current OS version: $current_version"
log "  Kernel: $(uname -r)"

# Save package snapshot
SNAPSHOT_FILE="$SNAPSHOT_DIR/packages-before-$(date +%Y%m%d-%H%M%S).txt"
rpm -qa --queryformat '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort > "$SNAPSHOT_FILE"
log "  Package snapshot saved: $SNAPSHOT_FILE"
log "  Total packages: $(wc -l < "$SNAPSHOT_FILE")"

# ─── Step 2: Check available updates ────────────────────
log "${CYAN}Step 2/6: Checking for available release updates...${NC}"
UPDATES=$(dnf check-release-update 2>&1) || true

if echo "$UPDATES" | grep -qi "no release update\|up to date\|newer release.*not"; then
    log "${GREEN}✅ System is already on the latest release. No updates needed.${NC}"
    exit 0
fi

echo "$UPDATES" | tee -a "$LOGFILE"

# ─── Step 3: Extract latest version ─────────────────────
log "${CYAN}Step 3/6: Identifying target version...${NC}"
LATEST=$(echo "$UPDATES" | grep -oP 'Version \K[0-9.]+' | tail -1)

if [ -z "$LATEST" ]; then
    die "Could not extract version from update check output"
fi

log "  Target version: ${GREEN}$LATEST${NC}"

# ─── Step 4: Dry run ────────────────────────────────────
log "${CYAN}Step 4/6: Performing dry-run analysis...${NC}"
DRY_RUN_OUTPUT=$(dnf upgrade --releasever="$LATEST" --assumeno 2>&1) || true
echo "$DRY_RUN_OUTPUT" | tee -a "$LOGFILE"

# Count packages to be updated
UPDATE_COUNT=$(echo "$DRY_RUN_OUTPUT" | grep -c "^  " 2>/dev/null || echo "0")
log "  Packages to update: approximately $UPDATE_COUNT"

# ─── Step 5: Confirmation ───────────────────────────────
log "${CYAN}Step 5/6: Confirmation...${NC}"

if [ "$AUTO_MODE" = false ]; then
    echo ""
    echo -e "${YELLOW}${BOLD}Review Summary:${NC}"
    echo -e "  Current version:  $current_version"
    echo -e "  Target version:   $LATEST"
    echo -e "  Packages to update: ~$UPDATE_COUNT"
    echo -e "  Package snapshot: $SNAPSHOT_FILE"
    echo ""
    read -p "$(echo -e ${YELLOW}"Proceed with upgrade to $LATEST? (y/N): "${NC})" CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        log "${RED}❌ Update cancelled by user.${NC}"
        exit 1
    fi
else
    log "  Auto-mode enabled, skipping confirmation."
fi

# ─── Step 6: Execute upgrade ────────────────────────────
log "${CYAN}Step 6/6: Executing upgrade to $LATEST...${NC}"

if dnf upgrade --releasever="$LATEST" -y 2>&1 | tee -a "$LOGFILE"; then
    log "${GREEN}${BOLD}✅ Upgrade to $LATEST completed successfully!${NC}"
else
    log "${RED}❌ Upgrade encountered errors. Check log: $LOGFILE${NC}"
    log "${YELLOW}To rollback, you can:"
    log "  1. Launch a new instance from a previous AMI"
    log "  2. Compare packages: diff $SNAPSHOT_FILE <(rpm -qa --queryformat '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort)"
    exit 1
fi

# ─── Post-update report ─────────────────────────────────
log ""
log "${BOLD}═══════════════════════════════════════════${NC}"
log "${BOLD}  Post-Update Report${NC}"
log "${BOLD}═══════════════════════════════════════════${NC}"

POST_SNAPSHOT="$SNAPSHOT_DIR/packages-after-$(date +%Y%m%d-%H%M%S).txt"
rpm -qa --queryformat '%{NAME}-%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort > "$POST_SNAPSHOT"

ADDED=$(comm -13 "$SNAPSHOT_FILE" "$POST_SNAPSHOT" | wc -l)
REMOVED=$(comm -23 "$SNAPSHOT_FILE" "$POST_SNAPSHOT" | wc -l)
log "  New packages:     $ADDED"
log "  Removed packages: $REMOVED"
log "  Total packages:   $(wc -l < "$POST_SNAPSHOT")"
log "  Log file:         $LOGFILE"

# Check if reboot is needed
if [ -f /var/run/reboot-required ] || dnf needs-restarting -r &>/dev/null; then
    log "${YELLOW}⚠ A reboot is recommended to complete the update.${NC}"
    if [ "$AUTO_MODE" = false ]; then
        read -p "Reboot now? (y/N): " REBOOT
        if [[ "$REBOOT" == "y" || "$REBOOT" == "Y" ]]; then
            log "Rebooting..."
            reboot
        fi
    fi
else
    log "${GREEN}✓ No reboot required.${NC}"
fi

log "${GREEN}${BOLD}Done!${NC}"
