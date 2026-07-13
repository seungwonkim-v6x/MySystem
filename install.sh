#!/usr/bin/env bash
# MySystem one-shot installer for a fresh machine.
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/seungwonkim-v6x/MySystem/main/install.sh)
#
# What this does:
#   1. Preflight: require git, jq, python3, and Bash
#   2. If ~/.claude exists, move it to ~/.claude.backup.<timestamp>
#   3. git clone MySystem into ~/.claude
#   4. Run ~/.claude/setup.sh

set -euo pipefail

REPO_URL="https://github.com/seungwonkim-v6x/MySystem.git"
TARGET="$HOME/.claude"

echo "=== MySystem Installer ==="

for required in git jq python3 bash; do
  if ! command -v "$required" >/dev/null 2>&1; then
    printf 'FAIL INSTALL_PREREQUISITE_MISSING subject=%s Problem=Required installer dependency is missing Cause=%s-is-not-on-PATH Fix=Install-the-prerequisites-and-retry Docs=SETUP.md#parity-contract\n' "$required" "$required" >&2
    exit 1
  fi
done

if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
  BACKUP="${TARGET}.backup.$(date +%Y%m%d-%H%M%S).$$"
  echo "! $TARGET already exists → backing up to $BACKUP"
  mv "$TARGET" "$BACKUP"
fi

echo "cloning $REPO_URL → $TARGET"
git clone "$REPO_URL" "$TARGET"

cd "$TARGET"
./setup.sh

echo ""
echo "✓ Done. Start a new Claude Code or Codex session."
