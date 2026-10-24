#!/bin/bash
# ═══════════════════════════════════════════════════════════
# AL2023 Kernel Upgrade / Downgrade (6.1 / 6.12 / 6.18)
# ═══════════════════════════════════════════════════════════
# Source: https://docs.aws.amazon.com/linux/al2023/ug/kernel-update.html
# - Default kernel changes 2026-08-17: 6.1 -> 6.18 for NEW instances
#   from al2023-ami-kernel-default-*. Running instances are NOT affected.
# - To pin a kernel, use version-specific AMIs:
#   al2023-ami-kernel-6.1-*, al2023-ami-kernel-6.12-*, al2023-ami-kernel-6.18-*
# - Every kernel change requires a REBOOT.
# Usage:
#   sudo bash kernel-upgrade.sh --target 6.18
#   sudo bash kernel-upgrade.sh --target 6.12
#   sudo bash kernel-upgrade.sh --target 6.1   (downgrade path)
#   sudo bash kernel-upgrade.sh --check        (show current + available)

set -euo pipefail
TARGET=""; CHECK_ONLY=false
while [[ $# -gt 0 ]]; do case "$1" in
  --target) TARGET="${2:-}"; shift 2;;
  --check) CHECK_ONLY=true; shift;;
  *) echo "Unknown arg: $1"; exit 1;;
esac; done

log() { echo "[$(date '+%H:%M:%S')] $*"; }
[[ "$(id -u)" -ne 0 ]] && { echo "Run as root (sudo)"; exit 1; }

CURRENT_KERNEL=$(uname -r)
log "Current kernel: $CURRENT_KERNEL"
log "FAQ: uname -r shows running kernel. Reboot required after any kernel change."

if $CHECK_ONLY; then
  echo "--- Installed kernels ---"; rpm -q kernel kernel6.12 kernel6.18 2>/dev/null || rpm -qa | grep -E '^kernel' | sort
  echo "--- Default grubby kernel ---"; grubby --default-kernel || true
  echo "--- SSM aliases (pin version to avoid surprise default change) ---"
  echo "  al2023-ami-kernel-6.1-x86_64 / -arm64 (+ -minimal- variants)"
  echo "  al2023-ami-kernel-6.12-x86_64 / -arm64"
  echo "  al2023-ami-kernel-6.18-x86_64 / -arm64"
  exit 0
fi

[[ -z "$TARGET" ]] && { echo "Usage: sudo bash kernel-upgrade.sh --target 6.18|6.12|6.1 | --check"; exit 1; }
# TARGET "" means 6.1 (package name is plain "kernel")
if [[ "$TARGET" == "6.1" ]]; then TARGET=""; fi

# Detect source version BEFORE upgrade (persist across reboot)
SOURCE_VERSION=""
if [[ "$CURRENT_KERNEL" == *"6.12"* ]]; then SOURCE_VERSION="6.12";
elif [[ "$CURRENT_KERNEL" == *"6.18"* ]]; then SOURCE_VERSION="6.18"; fi
echo "${SOURCE_VERSION}" > /var/lib/source_kernel_version
log "Source=${SOURCE_VERSION:-6.1} Target=${TARGET:-6.1}"

# Extra packages that must be swapped (per AWS docs)
swap_extras() {
  local src="$1" tgt="$2"
  for pkg in bpftool kernel-debuginfo kernel-debuginfo-common kernel-headers \
             kernel-modules-extra-common perf python3-perf; do
    local s t
    case "$pkg" in
      kernel-*) s="kernel${src}${pkg#kernel}"; t="kernel${tgt}${pkg#kernel}" ;;
      *)        s="${pkg}${src}";              t="${pkg}${tgt}" ;;
    esac
    if rpm -q "$s" &>/dev/null; then
      log "swap $s -> $t"
      dnf -y swap "$s" "$t" --allowerasing || dnf -y swap "$s" "$t"
    fi
  done
  if rpm -q "kernel${src}-tools" &>/dev/null; then
    dnf -y remove "kernel${src}-tools" "kernel${src}-tools-devel" || true
    dnf -y install "kernel${tgt}-tools" "kernel${tgt}-tools-devel"
  fi
}

if [[ -z "$SOURCE_VERSION" && -z "$TARGET" ]]; then log "Already on 6.1, nothing to do."; exit 0; fi
if [[ "$SOURCE_VERSION" == "$TARGET" ]]; then log "Already on target kernel."; exit 0; fi

# Upgrade path: install target first, set default, reboot, then remove source
log "Installing kernel${TARGET:-} ..."
dnf install -y "kernel${TARGET}"
version=$(rpm -q --qf '%{version}-%{release}.%{arch}\n' "kernel${TARGET}" | sort -V | tail -1)
log "Setting default to /boot/vmlinuz-$version"
grubby --set-default "/boot/vmlinuz-$version"

if [[ -n "$SOURCE_VERSION" || -n "$TARGET" ]]; then
  # For downgrade ordering AWS recommends swapping extras BEFORE installing target;
  # for upgrade, AFTER. We do a safe order: swap extras now for downgrade, after reboot for upgrade.
  if [[ -z "$TARGET" || "$TARGET" < "$SOURCE_VERSION" ]]; then
    swap_extras "$SOURCE_VERSION" "$TARGET"
  fi
fi

log "Reboot now: sudo reboot"
log "After reboot, finish with:"
log "  SOURCE=\$(cat /var/lib/source_kernel_version); sudo dnf remove -y kernel\${SOURCE}"
log "  then swap extras: sudo bash kernel-upgrade.sh --finish (or re-run with --target)"
log "FIPS note: only kernel 6.1 is FIPS 140-3 validated (Cert #5369). 6.12/6.18 validation in progress."
log "Fleet note: AWS recommends Systems Manager for patching many instances."
