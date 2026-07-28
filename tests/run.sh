#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

fail() { echo "FAIL: $*" >&2; exit 1; }

for term in "development environment" device tool node service; do
  rg -qi "$term" "$ROOT/SKILL.md" || fail "SKILL.md does not cover $term"
done

cat > "$TMP/valid.yaml" <<'YAML'
environments:
  local-shell:
    name: Local shell
    type: shell
    node: mac-local
devices:
  apple-gpu:
    name: Apple GPU
    type: gpu
    node: mac-local
tools:
  nodejs:
    name: Node.js
    type: runtime
    environments: [local-shell]
nodes:
  mac-local:
    name: Local Mac
    role: development-workstation
    purpose: Local development
services:
  github:
    name: GitHub
    type: git-host
YAML
"$ROOT/scripts/validate.sh" "$TMP/valid.yaml" >/dev/null || fail "valid general development inventory was rejected"

cat > "$TMP/invalid.yaml" <<'YAML'
tools:
  broken:
    type: runtime
YAML
if "$ROOT/scripts/validate.sh" "$TMP/invalid.yaml" >/dev/null 2>&1; then
  fail "tool without a name was accepted"
fi

echo "PASS: infrastructure-inventory regression suite"
