#!/bin/bash
# MySystem setup — run after cloning on a new machine
# Usage: cd ~/.claude && ./setup.sh

set -e

echo "=== MySystem Setup ==="
echo ""

# 1. Init gstack submodule
echo "[1/3] Initializing gstack submodule..."
git submodule update --init --recursive
echo "  ✓ gstack ready"

# 2. Check all symlinks referenced by agents
echo ""
echo "[2/3] Checking skill symlinks..."

BROKEN=0
TOTAL=0

for skill_dir in skills/*/; do
  skill_name=$(basename "$skill_dir")
  skill_file="$skill_dir/SKILL.md"

  # Skip gstack itself (it's the submodule, not a symlink)
  [ "$skill_name" = "gstack" ] && continue

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

if [ $BROKEN -eq 0 ]; then
  echo "  ✓ All $TOTAL skills OK"
else
  echo ""
  echo "  $BROKEN/$TOTAL skills have broken symlinks."
  echo "  This usually means gstack skills need to be linked."
  echo "  Running gstack skill sync..."

  # Recreate symlinks from gstack
  for gstack_skill in skills/gstack/*/; do
    name=$(basename "$gstack_skill")
    target_dir="skills/$name"
    target_file="$target_dir/SKILL.md"
    source_file="skills/gstack/$name/SKILL.md"

    if [ -f "$source_file" ] && [ ! -e "$target_file" ]; then
      mkdir -p "$target_dir"
      ln -sf "$(pwd)/$source_file" "$target_file"
      echo "  → Linked $name"
    fi
  done

  echo "  ✓ Symlinks restored"
fi

# 3. Verify agents can find their skills
echo ""
echo "[3/3] Verifying agent → skill mappings..."

ALL_OK=true
for agent_file in agents/*.md; do
  agent_name=$(basename "$agent_file" .md)
  skills=$(grep -A10 "^skills:" "$agent_file" 2>/dev/null | grep "  - " | sed 's/.*- //')

  for skill in $skills; do
    if [ ! -f "skills/$skill/SKILL.md" ]; then
      echo "  ✗ Agent '$agent_name' needs skill '$skill' — NOT FOUND"
      ALL_OK=false
    fi
  done
done

if $ALL_OK; then
  echo "  ✓ All agents have their required skills"
fi

echo ""
echo "=== Setup Complete ==="
echo "  Version: $(cat VERSION)"
echo "  Agents:  $(ls agents/*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "  Skills:  $TOTAL"
echo "  Hooks:   $(ls hooks/*.sh 2>/dev/null | wc -l | tr -d ' ')"
