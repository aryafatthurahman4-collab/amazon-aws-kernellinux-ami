#!/bin/bash
# ═══════════════════════════════════════════════════════════
# Docker + Amazon Linux Container Setup Script
# ═══════════════════════════════════════════════════════════
# Installs Docker on AL2023 and pulls Amazon Linux container images.
# Usage: sudo bash container-setup.sh

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

log() { echo -e "${GREEN}[$(date '+%H:%M:%S')]${NC} $*"; }

log "${BOLD}🐳 Docker + Amazon Linux Container Setup${NC}"
echo ""

# ─── Install Docker ──────────────────────────────────────
if command -v docker &>/dev/null; then
    log "Docker is already installed: $(docker --version)"
else
    log "${CYAN}Installing Docker...${NC}"
    dnf install -y docker
    log "Docker installed: $(docker --version)"
fi

# ─── Enable & Start Docker ──────────────────────────────
log "${CYAN}Enabling Docker service...${NC}"
systemctl enable --now docker

# ─── Add user to docker group ───────────────────────────
CURRENT_USER="${SUDO_USER:-ec2-user}"
if id "$CURRENT_USER" &>/dev/null; then
    if ! groups "$CURRENT_USER" | grep -q docker; then
        usermod -aG docker "$CURRENT_USER"
        log "Added $CURRENT_USER to docker group"
    else
        log "$CURRENT_USER is already in docker group"
    fi
fi

# ─── Login to ECR Public ────────────────────────────────
log "${CYAN}Authenticating with ECR Public...${NC}"
if command -v aws &>/dev/null; then
    aws ecr-public get-login-password --region us-east-1 2>/dev/null \
        | docker login --username AWS --password-stdin public.ecr.aws 2>/dev/null \
        || log "${YELLOW}ECR login skipped (AWS credentials may not be configured)${NC}"
else
    log "${YELLOW}AWS CLI not found, skipping ECR authentication${NC}"
fi

# ─── Pull Amazon Linux Images ───────────────────────────
log "${CYAN}Pulling Amazon Linux container images...${NC}"

images=(
    "public.ecr.aws/amazonlinux/amazonlinux:2023"
    "public.ecr.aws/amazonlinux/amazonlinux:2027-minimal"
)

for img in "${images[@]}"; do
    log "  Pulling $img ..."
    docker pull "$img" 2>/dev/null && \
        log "  ${GREEN}✓ $img${NC}" || \
        log "  ${YELLOW}⚠ Failed to pull $img${NC}"
done

# ─── Verify ──────────────────────────────────────────────
echo ""
log "${BOLD}📦 Available Amazon Linux images:${NC}"
docker images | grep -E "amazonlinux|REPOSITORY" | while read line; do echo "  $line"; done

# ─── Quick Reference ────────────────────────────────────
echo ""
log "${BOLD}🎉 Setup Complete! Quick Reference:${NC}"
echo ""
echo "  # Run AL2023 container:"
echo "  docker run --rm -it public.ecr.aws/amazonlinux/amazonlinux:2023 /bin/bash"
echo ""
echo "  # Run AL2027 Preview container:"
echo "  docker run --rm -it public.ecr.aws/amazonlinux/amazonlinux:2027-minimal /bin/bash"
echo ""
echo "  # Build from Dockerfile:"
echo "  docker build -t my-al2023-app ."
echo ""
echo "  # Docker Hub alternative:"
echo "  docker pull amazonlinux:2023"
echo ""
if [ "$CURRENT_USER" != "root" ]; then
    echo -e "  ${YELLOW}NOTE: Log out and back in for docker group to take effect.${NC}"
fi
