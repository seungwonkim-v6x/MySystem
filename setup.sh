#!/usr/bin/env bash
# MySystem setup — idempotent bootstrap for ~/.claude
# Usage: cd ~/.claude && ./setup.sh
#
# What this does:
#   1. Clone or update external skill repos (gstack)
#   2. Run gstack's own setup (symlinks 20+ skills into ~/.claude/skills/)
#   3. Register gstack-installed skill dirs in .git/info/exclude
#      (so the ignore list tracks gstack's current release without
#       hardcoding names in the tracked .gitignore)
#   4. Validate skill symlinks + agent → skill mappings

set -euo pipefail

cd "$(dirname "$0")"
REPO_ROOT="$(pwd)"

echo "=== MySystem Setup ==="
echo ""

# ── External skill repositories ──────────────────────────────
# Format: "name|url|branch"
# Adding a new external dependency? Also update README.md "External
# dependencies" table and keep the clone target under skills/.
EXTERNAL_REPOS=(
  "gstack|https://github.com/garrytan/gstack.git|main"
)

clone_or_pull() {
  local name="$1" url="$2" branch="$3"
  local dest="skills/$name"

  if [ -d "$dest/.git" ]; then
    echo "  pulling skills/$name..."
    if ! ( cd "$dest" && git pull --ff-only origin "$branch" 2>&1 | sed 's/^/    /' ); then
      echo "  ✗ skills/$name: pull failed (uncommitted changes?)."
      echo "    Fix manually: cd skills/$name && git stash || git reset --hard origin/$branch"
      exit 1
    fi
  else
    echo "  cloning skills/$name from $url..."
    [ -e "$dest" ] && rm -rf "$dest"
    git clone --branch "$branch" "$url" "$dest" 2>&1 | sed 's/^/    /'
  fi
}

echo "[1/4] Syncing external skill repos..."
for entry in "${EXTERNAL_REPOS[@]}"; do
  IFS='|' read -r name url branch <<< "$entry"
  clone_or_pull "$name" "$url" "$branch"
done
echo "  ✓ external repos ready"

# ── Run gstack's own setup (installs its skills into ~/.claude/skills/) ──
echo ""
echo "[2/4] Running gstack setup..."
if [ -x "skills/gstack/setup" ]; then
  ( cd skills/gstack && ./setup 2>&1 | sed 's/^/  /' )
  echo "  ✓ gstack skills installed"
else
  echo "  ✗ skills/gstack/setup not found or not executable"
  exit 1
fi

# ── Validate symlinks + agent → skill mappings ───────────────
# External skills (gstack + what it installs) are ignored by default via
# .gitignore's allow-list pattern — user-owned skills whitelisted explicitly,
# everything else in skills/ stays ignored.
echo ""
echo "[3/3] Validating..."

BROKEN=0
TOTAL=0
for skill_dir in skills/*/; do
  skill_name=$(basename "$skill_dir")
  [ "$skill_name" = "gstack" ] && continue
  skill_file="$skill_dir/SKILL.md"

  if [ -L "$skill_file" ]; then
    TOTAL=$((TOTAL + 1))
    if [ ! -e "$skill_file" ]; then
      echo "  ✗ $skill_name — broken symlink: $(readlink "$skill_file")"
      BROKEN=$((BROKEN + 1))
    fi
  elif [ -f "$skill_file" ]; then
    TOTAL=$((TOTAL + 1))
  fi
done

if [ "$BROKEN" -eq 0 ]; then
  echo "  ✓ $TOTAL skills OK"
else
  echo "  ✗ $BROKEN/$TOTAL skills broken — try re-running ./setup.sh"
  exit 1
fi

# Agent → skill mapping
ALL_OK=true
if [ -d agents ]; then
  for agent_file in agents/*.md; do
    [ -f "$agent_file" ] || continue
    agent_name=$(basename "$agent_file" .md)
    skills=$(grep -A10 "^skills:" "$agent_file" 2>/dev/null | grep "  - " | sed 's/.*- //' || true)
    for skill in $skills; do
      if [ ! -f "skills/$skill/SKILL.md" ]; then
        echo "  ✗ agent '$agent_name' needs skill '$skill' — NOT FOUND"
        ALL_OK=false
      fi
    done
  done
fi
$ALL_OK && echo "  ✓ all agents have required skills"

echo ""
echo "=== Setup Complete ==="
echo "  Version: $(cat VERSION 2>/dev/null || echo "?")"
echo "  Agents:  $(ls agents/*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "  Skills:  $TOTAL"
echo "  Hooks:   $(ls hooks/*.sh 2>/dev/null | wc -l | tr -d ' ')"
echo ""
echo "Start a new Claude Code session to pick up changes."
