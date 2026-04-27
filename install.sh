#!/usr/bin/env bash
# MySystem one-shot installer for a fresh machine.
# Usage:
#   bash <(curl -fsSL https://raw.githubusercontent.com/seungwonkim-v6x/MySystem/main/install.sh)
#
# What this does:
#   1. Preflight: require git
#   2. If ~/.claude exists, move it to ~/.claude.backup.<timestamp>
#   3. git clone MySystem into ~/.claude
#   4. Run ~/.claude/setup.sh

set -euo pipefail

REPO_URL="https://github.com/seungwonkim-v6x/MySystem.git"
TARGET="$HOME/.claude"

echo "=== MySystem Installer ==="

if ! command -v git >/dev/null 2>&1; then
  echo "✗ git not found. Install git first, then re-run this script."
  exit 1
fi

if [ -e "$TARGET" ]; then
  BACKUP="${TARGET}.backup.$(date +%Y%m%d-%H%M%S)"
  echo "! $TARGET already exists → backing up to $BACKUP"
  mv "$TARGET" "$BACKUP"
fi

echo "cloning $REPO_URL → $TARGET"
git clone "$REPO_URL" "$TARGET"

cd "$TARGET"
./setup.sh

echo ""
echo "✓ Done. Start Claude Code and you're ready."
