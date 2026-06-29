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

# Collect any plaintext secrets in the file
SECRETS=$(python3 -c "
import yaml
data = yaml.safe_load(open('$FILE'))
found = []
for nid, node in (data.get('nodes') or {}).items():
    pw = node.get('sudo', {}).get('password')
    if pw and str(pw) not in ('null', 'None', ''):
        found.append(f'node.{nid}.sudo.password')
    for svc in node.get('services', []):
        creds = svc.get('credentials', {})
        for k, v in creds.items():
            if v and str(v) not in ('null', 'None', ''):
                found.append(f'node.{nid}.service.{svc.get(\"name\", \"?\")}.{k}')
for sid, svc in (data.get('services') or {}).items():
    creds = svc.get('credentials', {})
    for k, v in creds.items():
        if v and str(v) not in ('null', 'None', ''):
            found.append(f'service.{sid}.{k}')
if found:
    print(','.join(found))
" 2>/dev/null || true)

if [[ -n "$SECRETS" ]]; then
  if [[ "$IS_GIT_TRACKED" == "true" ]]; then
    echo "FAIL: git-tracked file contains plaintext secrets: $SECRETS"
    ERRORS=$((ERRORS + 1))
  else
    echo "WARN: file contains secrets. Ensure it is NOT git-tracked: $FILE"
  fi
fi

if [[ "$ERRORS" -gt 0 ]]; then
  echo "SAFETY CHECK FAILED"
  exit 1
fi

echo "PASS: safety check OK"
