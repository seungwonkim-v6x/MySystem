#!/usr/bin/env bash
# Pi-first local setup and health check.
# This intentionally performs no network updates, package installs, Git
# mutations, Claude/Codex parity work, or external-skill synchronization.

set -euo pipefail

ROOT=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
cd "$ROOT"

fail() {
  printf 'FAIL %s\n' "$*" >&2
  exit 1
}

command -v pi >/dev/null 2>&1 || fail "Pi is not on PATH"
command -v node >/dev/null 2>&1 || fail "Node.js is not on PATH"

[ -f AGENTS.override.md ] || fail "AGENTS.override.md is missing"
[ -f .pi/APPEND_SYSTEM.md ] || fail ".pi/APPEND_SYSTEM.md is missing"
[ -f .pi/settings.json ] || fail ".pi/settings.json is missing"
[ -f .pi/extensions/pi-safety.ts ] || fail "Pi safety extension is missing"

node --experimental-strip-types --check .pi/extensions/pi-safety.ts
node --input-type=module -e "import('./.pi/extensions/pi-safety.ts').then(() => console.log('PASS Pi extension load'))"
node -e "JSON.parse(require('fs').readFileSync('.pi/settings.json')); console.log('PASS Pi settings')"

printf 'PASS Pi %s\n' "$(pi --version)"
printf 'PASS no network or legacy runtime update performed\n'
printf 'Start with: pi --approve\n'
