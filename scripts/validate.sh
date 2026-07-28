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

# Check each inventory entity has its minimal identifying fields.
ENTITIES=$(python3 -c "
import yaml
data = yaml.safe_load(open('$INVENTORY'))
requirements = {
    'environments': ['name', 'type'],
    'devices': ['name', 'type'],
    'tools': ['name', 'type'],
    'nodes': ['name', 'role', 'purpose'],
    'services': ['name', 'type'],
}
for section, required in requirements.items():
    for item_id, item in (data.get(section) or {}).items():
        missing = [field for field in required if not item.get(field)]
        label = section[:-1]
        if missing:
            print(f'FAIL: {label} {item_id} missing fields: {missing}')
        else:
            print(f'PASS: {label} {item_id}')
" 2>/dev/null)

while IFS= read -r line; do
  echo "$line"
  if [[ "$line" == FAIL* ]]; then
    ERRORS=$((ERRORS + 1))
  fi
done <<< "$ENTITIES"

# Security check: warn if any plaintext secret is in a git-tracked file
if git -C "$(dirname "$INVENTORY")" ls-files --error-unmatch "$(basename "$INVENTORY")" &>/dev/null; then
  SECRETS=$(python3 -c "
import yaml
data = yaml.safe_load(open('$INVENTORY'))
found = []
for nid, node in (data.get('nodes') or {}).items():
    pw = node.get('sudo', {}).get('password')
    if pw and pw != 'null':
        found.append(f'node.{nid}.sudo.password')
    for svc in node.get('services', []):
        creds = svc.get('credentials', {})
        for k, v in creds.items():
            if v and v != 'null':
                found.append(f'node.{nid}.service.{svc.get(\"name\", \"?\")}.credential.{k}')
for sid, svc in (data.get('services') or {}).items():
    creds = svc.get('credentials', {})
    for k, v in creds.items():
        if v and v != 'null':
            found.append(f'service.{sid}.credential.{k}')
if found:
    print(','.join(found))
" 2>/dev/null)
  if [[ -n "$SECRETS" ]]; then
    echo "WARN: plaintext secrets stored in git-tracked file: $SECRETS"
    echo "      Move secrets to ~/.agents/inventory.yaml (gitignored) only"
  fi
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "=== Validation FAILED ($ERRORS errors) ==="
  exit 1
fi

echo "=== Validation PASSED ==="
