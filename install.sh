#!/usr/bin/env bash
# Pi-first bootstrap for a fresh checkout.
# Existing Claude Code/Codex installation state is never copied or removed.

set -euo pipefail

REPO_URL="https://github.com/seungwonkim-v6x/MySystem.git"
TARGET="${MYSYSTEM_TARGET:-$HOME/MySystem}"

for required in git node pi; do
  command -v "$required" >/dev/null 2>&1 || {
    printf 'FAIL required command is missing: %s\n' "$required" >&2
    exit 1
  }
done

if [ -e "$TARGET" ] || [ -L "$TARGET" ]; then
  printf 'Refusing to replace existing %s. Set MYSYSTEM_TARGET to a new path or install manually.\n' "$TARGET" >&2
  exit 1
fi

echo "Cloning Pi configuration into $TARGET"
git clone "$REPO_URL" "$TARGET"
cd "$TARGET"
./setup.sh

echo "Done. Start Pi with: cd $TARGET && pi --approve"
