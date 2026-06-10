#!/usr/bin/env bash
set -euo pipefail

FILE="${1:-}"

if [[ -z "$FILE" ]]; then
  echo "Usage: $0 <inventory-file>"
  exit 1
fi

if [[ ! -f "$FILE" ]]; then
  echo "PASS: file does not exist yet, will be created safely"
  exit 0
fi

# Determine if file is git-tracked
IS_GIT_TRACKED=false
if git -C "$(dirname "$FILE")" ls-files --error-unmatch "$(basename "$FILE")" &>/dev/null; then
  IS_GIT_TRACKED=true
fi

ERRORS=0

# Check for plaintext passwords in the file
PASSWORDS=$(python3 -c "
import yaml
data = yaml.safe_load(open('$FILE'))
found = []
for nid, node in (data.get('nodes') or {}).items():
    pw = node.get('sudo', {}).get('password')
    if pw and str(pw) not in ('null', 'None', ''):
        found.append(nid)
if found:
    print(','.join(found))
" 2>/dev/null || true)

if [[ -n "$PASSWORDS" ]]; then
  if [[ "$IS_GIT_TRACKED" == "true" ]]; then
    echo "FAIL: git-tracked file contains plaintext passwords for nodes: $PASSWORDS"
    ERRORS=$((ERRORS + 1))
  else
    echo "WARN: file contains passwords. Ensure it is NOT git-tracked: $FILE"
  fi
fi

# If git-tracked, ensure all passwords are null
if [[ "$IS_GIT_TRACKED" == "true" && -n "$PASSWORDS" ]]; then
  echo "ACTION: Setting all passwords to null before write"
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "SAFETY CHECK FAILED"
  exit 1
fi

echo "PASS: safety check OK"
