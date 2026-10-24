#!/bin/bash
# ═══════════════════════════════════════════════════════════
# EC2 Key Pair Management for Amazon Linux / Ubuntu
# ═══════════════════════════════════════════════════════════
# Usage:
#   bash manage-keypairs.sh create --name my-key --type rsa --format pem
#   bash manage-keypairs.sh info --name my-key
#   bash manage-keypairs.sh connect --key ./my-key.pem --host 13.214.194.43 --user ec2-user
#
# Covers: RSA vs ED25519, .pem (OpenSSH) vs .ppk (PuTTY),
# AWS console + CLI creation, permissions, Ubuntu vs AL2023 users.

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; CYAN='\033[0;36m'; NC='\033[0m'
log() { echo -e "${GREEN}[keypair]${NC} $*"; }
warn() { echo -e "${YELLOW}[warn]${NC} $*"; }
die() { echo -e "${RED}[error]${NC} $*"; exit 1; }

CMD="${1:-help}"; shift || true

usage() {
cat <<'EOF'
Usage: manage-keypairs.sh <command> [options]

Commands:
  create  --name NAME [--type rsa|ed25519] [--format pem|ppk] [--region ap-southeast-1]
          Create key pair via AWS CLI (recommended). Downloads private key once.
  local   --name NAME [--type rsa|ed25519]
          Generate key locally with ssh-keygen (no AWS API call), then import.
  info    --name NAME [--region ap-southeast-1]
          Describe key pair fingerprint.
  connect --key KEY.pem --host PUBLIC_IP [--user ec2-user|ubuntu]
          SSH with correct permissions (chmod 400).
  help    Show this help.

Key type guide (matches EC2 console dialog in your screenshots):
  RSA     - RSA encrypted private and public key pair (broadest compatibility)
  ED25519 - ED25519 encrypted key pair (smaller, faster, modern; not supported by old PuTTY)
Format guide:
  .pem - For use with OpenSSH (Linux/macOS ssh, EC2 Instance Connect)
  .ppk - For use with PuTTY (Windows)

Default users:
  Amazon Linux 2023 / AL2 / AL2027 : ec2-user
  Ubuntu AMIs                        : ubuntu
EOF
}

get_arg() { # get_arg --name default
  local key="$1" def="${2:-}" val="$def" args=("$@");
  for ((i=1;i<${#args[@]};i++)); do
    if [[ "${args[$i]}" == "$key" && $((i+1)) -lt ${#args[@]} ]]; then val="${args[$((i+1))]}"; fi
  done
  echo "$val";
}

case "$CMD" in
  create)
    NAME=$(get_arg --name "" "$@"); [[ -z "$NAME" ]] && die "--name required"
    TYPE=$(get_arg --type "rsa" "$@")
    FORMAT=$(get_arg --format "pem" "$@")
    REGION=$(get_arg --region "ap-southeast-1" "$@")
    [[ "$TYPE" != "rsa" && "$TYPE" != "ed25519" ]] && die "--type must be rsa|ed25519"
    [[ "$FORMAT" != "pem" && "$FORMAT" != "ppk" ]] && die "--format must be pem|ppk"
    OUTFILE="./${NAME}.${FORMAT}"
    log "Creating key pair '$NAME' type=$TYPE format=$FORMAT region=$REGION ..."
    # AWS CLI v2: --key-type rsa|ed25519, --key-format pem|ppk
    aws ec2 create-key-pair --key-name "$NAME" --key-type "$TYPE" \
      --key-format "$FORMAT" --region "$REGION" \
      --query 'KeyMaterial' --output text > "$OUTFILE"
    chmod 400 "$OUTFILE"
    log "Saved to $OUTFILE (chmod 400). STORE SAFELY — AWS will not show it again."
    log "Fingerprint:"; aws ec2 describe-key-pairs --key-names "$NAME" --region "$REGION" \
      --query 'KeyPairs[0].KeyFingerprint' --output text
    echo ""; echo -e "${CYAN}Next: select '$NAME' from Key pair name dropdown, then Launch instance.${NC}"
    ;;
  local)
    NAME=$(get_arg --name "" "$@"); [[ -z "$NAME" ]] && die "--name required"
    TYPE=$(get_arg --type "rsa" "$@")
    if [[ "$TYPE" == "rsa" ]]; then
      ssh-keygen -t rsa -b 2048 -f "./${NAME}" -N "" -C "${NAME}-$(date +%F)"
    else
      ssh-keygen -t ed25519 -f "./${NAME}" -N "" -C "${NAME}-$(date +%F)"
    fi
    chmod 400 "./${NAME}"
    log "Local key created: ./${NAME} (private) + ./${NAME}.pub (public)"
    log "Import to AWS: aws ec2 import-key-pair --key-name $NAME --public-key-material fileb://./${NAME}.pub"
    ;;
  info)
    NAME=$(get_arg --name "" "$@"); [[ -z "$NAME" ]] && die "--name required"
    REGION=$(get_arg --region "ap-southeast-1" "$@")
    aws ec2 describe-key-pairs --key-names "$NAME" --region "$REGION"
    ;;
  connect)
    KEY=$(get_arg --key "" "$@"); [[ -z "$KEY" ]] && die "--key required"
    HOST=$(get_arg --host "" "$@"); [[ -z "$HOST" ]] && die "--host required"
    USER=$(get_arg --user "ec2-user" "$@")
    [[ -f "$KEY" ]] || die "key file not found: $KEY"
    chmod 400 "$KEY"
    log "Connecting as $USER@$HOST (if 'Permission denied', check username: ec2-user for AL2023, ubuntu for Ubuntu)..."
    exec ssh -i "$KEY" "${USER}@${HOST}"
    ;;
  *) usage; ;;
esac
