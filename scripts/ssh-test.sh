#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INVENTORY="${INVENTORY:-$HOME/.agents/inventory.yaml}"
NODE_ID="${1:-}"

if [[ -z "$NODE_ID" ]]; then
  echo "Usage: $0 <node-id>"
  echo "Nodes available:"
  yq '.nodes | keys | .[]' "$INVENTORY" 2>/dev/null || grep -E '^  [a-z0-9-]+:' "$INVENTORY" | sed 's/://g' | sed 's/^  /  - /'
  exit 1
fi

if [[ ! -f "$INVENTORY" ]]; then
  echo "ERROR: Inventory not found at $INVENTORY"
  exit 1
fi

# Extract fields with yq if available, fallback to crude grep
if command -v yq &>/dev/null; then
  HOST="$(yq ".nodes.${NODE_ID}.ssh.host" "$INVENTORY" 2>/dev/null || true)"
  USER="$(yq ".nodes.${NODE_ID}.ssh.user" "$INVENTORY" 2>/dev/null || true)"
  PORT="$(yq ".nodes.${NODE_ID}.ssh.port // 22" "$INVENTORY" 2>/dev/null || true)"
  KEY="$(yq ".nodes.${NODE_ID}.ssh.key" "$INVENTORY" 2>/dev/null || true)"
  SUDO_METHOD="$(yq ".nodes.${NODE_ID}.sudo.method // \"nopasswd\"" "$INVENTORY" 2>/dev/null || true)"
else
  # Crude fallback
  HOST="$(grep -A 10 "^  ${NODE_ID}:" "$INVENTORY" | grep 'host:' | head -1 | sed 's/.*host: *//' | tr -d ' ')"
  USER="$(grep -A 10 "^  ${NODE_ID}:" "$INVENTORY" | grep 'user:' | head -1 | sed 's/.*user: *//' | tr -d ' ')"
  PORT="$(grep -A 10 "^  ${NODE_ID}:" "$INVENTORY" | grep 'port:' | head -1 | sed 's/.*port: *//' | tr -d ' ')"
  PORT="${PORT:-22}"
  KEY="$(grep -A 10 "^  ${NODE_ID}:" "$INVENTORY" | grep 'key:' | head -1 | sed 's/.*key: *//' | tr -d ' ')"
  SUDO_METHOD="$(grep -A 5 "^  ${NODE_ID}:" "$INVENTORY" | grep -A 2 'sudo:' | grep 'method:' | head -1 | sed 's/.*method: *//' | tr -d ' ')"
  SUDO_METHOD="${SUDO_METHOD:-nopasswd}"
fi

if [[ -z "$HOST" || "$HOST" == "null" ]]; then
  echo "ERROR: Node '$NODE_ID' not found or has no ssh.host"
  exit 1
fi

KEY_ARG=""
if [[ -n "$KEY" && "$KEY" != "null" ]]; then
  KEY="${KEY/#\~/$HOME}"
  KEY_ARG="-i $KEY"
fi

echo "=== Testing SSH to $NODE_ID ($USER@$HOST:$PORT) ==="

# Test 1: key file permissions
if [[ -n "$KEY" && "$KEY" != "null" && -f "$KEY" ]]; then
  PERM="$(stat -f '%Lp' "$KEY" 2>/dev/null || stat -c '%a' "$KEY" 2>/dev/null || echo unknown)"
  if [[ "$PERM" != "600" && "$PERM" != "unknown" ]]; then
    echo "FAIL: SSH key $KEY has permissions $PERM (must be 600)"
    exit 1
  fi
  echo "PASS: SSH key permissions ($PERM)"
fi

# Test 2: basic connectivity
if ! ssh -o ConnectTimeout=5 -o BatchMode=yes -o StrictHostKeyChecking=accept-new -p "$PORT" $KEY_ARG "${USER}@${HOST}" echo "OK" 2>/dev/null; then
  echo "FAIL: SSH key auth failed"
  exit 1
fi
echo "PASS: SSH key auth"

# Test 2: sudo
if [[ "$SUDO_METHOD" == "nopasswd" ]]; then
  if ssh -o ConnectTimeout=5 -o BatchMode=yes -p "$PORT" $KEY_ARG "${USER}@${HOST}" "sudo -n true" 2>/dev/null; then
    echo "PASS: sudo (nopasswd)"
  else
    echo "WARN: sudo requires password (configured as nopasswd but failed)"
  fi
else
  echo "SKIP: sudo password check (method=$SUDO_METHOD) — manual verification required"
fi

echo "=== Done ==="
