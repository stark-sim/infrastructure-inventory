#!/usr/bin/env bash
set -euo pipefail

INVENTORY="${1:-$HOME/.agents/inventory.yaml}"

if [[ ! -f "$INVENTORY" ]]; then
  echo "ERROR: Inventory not found at $INVENTORY"
  exit 1
fi

echo "=== Validating $INVENTORY ==="

ERRORS=0

# Check YAML is parseable
if ! python3 -c "import yaml; yaml.safe_load(open('$INVENTORY'))" 2>/dev/null; then
  echo "FAIL: YAML parse error"
  exit 1
fi
echo "PASS: YAML syntax"

# Check each node has required fields
NODES=$(python3 -c "
import yaml
data = yaml.safe_load(open('$INVENTORY'))
for nid, node in (data.get('nodes') or {}).items():
    missing = []
    for req in ['name', 'role', 'purpose']:
        if not node.get(req):
            missing.append(req)
    if missing:
        print(f'FAIL: node {nid} missing fields: {missing}')
    else:
        print(f'PASS: node {nid}')
" 2>/dev/null)

while IFS= read -r line; do
  echo "$line"
  if [[ "$line" == FAIL* ]]; then
    ERRORS=$((ERRORS + 1))
  fi
done <<< "$NODES"

# Security check: warn if password is non-null in a git-tracked file
if git -C "$(dirname "$INVENTORY")" ls-files --error-unmatch "$(basename "$INVENTORY")" &>/dev/null; then
  PASSWORDS=$(python3 -c "
import yaml
data = yaml.safe_load(open('$INVENTORY'))
found = []
for nid, node in (data.get('nodes') or {}).items():
    pw = node.get('sudo', {}).get('password')
    if pw and pw != 'null':
        found.append(nid)
if found:
    print(','.join(found))
" 2>/dev/null)
  if [[ -n "$PASSWORDS" ]]; then
    echo "WARN: sudo passwords stored in git-tracked file for nodes: $PASSWORDS"
    echo "      Move passwords to ~/.agents/inventory.yaml (gitignored) only"
  fi
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "=== Validation FAILED ($ERRORS errors) ==="
  exit 1
fi

echo "=== Validation PASSED ==="
