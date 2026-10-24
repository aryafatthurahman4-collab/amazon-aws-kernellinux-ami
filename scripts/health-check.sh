#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Amazon Linux 2023 — System Health Check Script
# ═══════════════════════════════════════════════════════════
# Usage: sudo bash health-check.sh
# Outputs a comprehensive system health report.

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

hr() { echo -e "${BLUE}═══════════════════════════════════════════════════${NC}"; }
section() { echo -e "\n${CYAN}${BOLD}$1${NC}"; }

hr
echo -e "${BOLD}  Amazon Linux System Health Report${NC}"
echo -e "  $(date '+%Y-%m-%d %H:%M:%S %Z')"
hr

# ─── OS Information ──────────────────────────────────────
section "📌 OS Information"
if [ -f /etc/os-release ]; then
    source /etc/os-release
    echo -e "  Name:    ${GREEN}$NAME${NC}"
    echo -e "  Version: ${GREEN}${VERSION:-N/A}${NC}"
    echo -e "  ID:      ${GREEN}$ID${NC}"
else
    echo -e "  ${RED}Cannot read /etc/os-release${NC}"
fi

# ─── Kernel ──────────────────────────────────────────────
section "🔧 Kernel"
echo -e "  Version: ${GREEN}$(uname -r)${NC}"
echo -e "  Arch:    $(uname -m)"

# ─── Uptime & Load ──────────────────────────────────────
section "⏱️  Uptime & Load"
uptime_info=$(uptime)
echo "  $uptime_info"

# Check load average vs CPU count
load=$(cat /proc/loadavg | awk '{print $1}')
cpus=$(nproc)
load_int=$(echo "$load" | awk '{printf "%d", $1}')
if [ "$load_int" -gt "$cpus" ]; then
    echo -e "  ${RED}⚠ Load ($load) exceeds CPU count ($cpus)${NC}"
else
    echo -e "  ${GREEN}✓ Load ($load) is healthy for $cpus CPUs${NC}"
fi

# ─── Memory ──────────────────────────────────────────────
section "💾 Memory Usage"
free -h | head -2 | while read line; do echo "  $line"; done
mem_percent=$(free | awk '/^Mem:/ {printf "%.0f", $3/$2 * 100}')
if [ "$mem_percent" -gt 90 ]; then
    echo -e "  ${RED}⚠ Memory usage is at ${mem_percent}%${NC}"
elif [ "$mem_percent" -gt 75 ]; then
    echo -e "  ${YELLOW}⚡ Memory usage is at ${mem_percent}%${NC}"
else
    echo -e "  ${GREEN}✓ Memory usage is at ${mem_percent}%${NC}"
fi

# ─── Disk ────────────────────────────────────────────────
section "💿 Disk Usage"
df -h / | tail -1 | awk '{printf "  Root: %s used of %s (%s)\n", $3, $2, $5}'
disk_percent=$(df / | tail -1 | awk '{gsub(/%/,""); print $5}')
if [ "$disk_percent" -gt 90 ]; then
    echo -e "  ${RED}⚠ Disk usage is critical (${disk_percent}%)${NC}"
elif [ "$disk_percent" -gt 75 ]; then
    echo -e "  ${YELLOW}⚡ Disk usage is elevated (${disk_percent}%)${NC}"
else
    echo -e "  ${GREEN}✓ Disk usage is healthy (${disk_percent}%)${NC}"
fi

# ─── EBS Volume Type ────────────────────────────────────
section "📀 EBS Volume Info"
if command -v lsblk &>/dev/null; then
    lsblk -d -o NAME,SIZE,TYPE 2>/dev/null | while read line; do echo "  $line"; done
fi

# ─── Release Update Check ───────────────────────────────
section "🔒 Release Update Check"
if command -v dnf &>/dev/null; then
    update_check=$(dnf check-release-update 2>&1) || true
    if echo "$update_check" | grep -qi "newer release"; then
        echo -e "  ${YELLOW}⚡ Updates available:${NC}"
        echo "$update_check" | grep "Version " | while read line; do echo "  → $line"; done
    else
        echo -e "  ${GREEN}✓ System is on the latest release version.${NC}"
    fi
else
    echo -e "  ${YELLOW}dnf not found (not AL2023?)${NC}"
fi

# ─── Security Updates ───────────────────────────────────
section "🛡️  Security Updates"
if command -v dnf &>/dev/null; then
    sec_updates=$(dnf updateinfo list --security 2>/dev/null | grep -c "ALAS" || echo "0")
    if [ "$sec_updates" -gt 0 ]; then
        echo -e "  ${RED}⚠ $sec_updates security advisories applicable${NC}"
    else
        echo -e "  ${GREEN}✓ No outstanding security advisories${NC}"
    fi
fi

# ─── Network Interfaces ─────────────────────────────────
section "🌐 Network Interfaces"
if command -v networkctl &>/dev/null; then
    networkctl 2>/dev/null | grep -E "ether|loopback" | while read line; do echo "  $line"; done
else
    ip addr show 2>/dev/null | grep "inet " | while read line; do echo "  $line"; done
fi

# ─── DNS Resolution ─────────────────────────────────────
section "🔍 DNS Resolution"
if command -v resolvectl &>/dev/null; then
    resolvectl status 2>/dev/null | grep -E "DNS Servers|DNS Domain" | head -4 | while read line; do echo "  $line"; done
fi

# ─── Failed Services ────────────────────────────────────
section "❌ Failed Services"
failed=$(systemctl --failed --no-pager --no-legend 2>/dev/null || true)
if [ -z "$failed" ]; then
    echo -e "  ${GREEN}✓ No failed services${NC}"
else
    echo -e "  ${RED}$failed${NC}"
fi

# ─── Running Services Count ─────────────────────────────
section "⚙️  Services Summary"
total_services=$(systemctl list-units --type=service --no-pager --no-legend 2>/dev/null | wc -l)
running_services=$(systemctl list-units --type=service --state=running --no-pager --no-legend 2>/dev/null | wc -l)
echo "  Total: $total_services | Running: $running_services"

# ─── Docker Status ───────────────────────────────────────
section "🐳 Docker Status"
if command -v docker &>/dev/null; then
    docker_status=$(systemctl is-active docker 2>/dev/null || echo "not-installed")
    echo -e "  Docker service: ${GREEN}$docker_status${NC}"
    if [ "$docker_status" = "active" ]; then
        containers=$(docker ps -q 2>/dev/null | wc -l)
        echo "  Running containers: $containers"
    fi
else
    echo "  Docker is not installed"
fi

# ─── Instance Metadata ──────────────────────────────────
section "☁️  EC2 Instance Metadata"
TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 60" 2>/dev/null) || true

if [ -n "$TOKEN" ]; then
    HEADER="X-aws-ec2-metadata-token: $TOKEN"
    instance_type=$(curl -s -H "$HEADER" http://169.254.169.254/latest/meta-data/instance-type 2>/dev/null || echo "N/A")
    az=$(curl -s -H "$HEADER" http://169.254.169.254/latest/meta-data/placement/availability-zone 2>/dev/null || echo "N/A")
    instance_id=$(curl -s -H "$HEADER" http://169.254.169.254/latest/meta-data/instance-id 2>/dev/null || echo "N/A")
    ami_id=$(curl -s -H "$HEADER" http://169.254.169.254/latest/meta-data/ami-id 2>/dev/null || echo "N/A")

    echo "  Instance Type: $instance_type"
    echo "  AZ:            $az"
    echo "  Instance ID:   $instance_id"
    echo "  AMI ID:        $ami_id"
else
    echo "  Not running on EC2 or IMDS unavailable"
fi

hr
echo -e "${GREEN}${BOLD}  Health check complete!${NC}"
hr
