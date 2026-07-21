#!/usr/bin/env bash
# Skill model overrides — pin a `model:` for skills whose SKILL.md is a
# symlink into an external checkout (gstack, sparse cherry-picks).
#
# Frontmatter can't be edited in those checkouts (session-start pulls would
# break on a dirty tree, and gstack's setup re-links SKILL.md every run), so
# this script — invoked by setup.sh AFTER the external installers — replaces
# the symlink with a generated wrapper: the source's frontmatter plus the
# pinned `model:`, and a body that defers to the source file (read live at
# invocation, so upstream skill updates still apply). Self-healing: external
# re-links get re-wrapped on the next run. Tracked user-owned skills pin
# `model:` directly in their own frontmatter and never appear in this table.
#
# Safe by construction: the source is resolved and validated BEFORE any
# mutation; every failure path leaves the installer-managed state untouched
# (or, for a wrapper whose recorded source vanished, removes the stale
# wrapper so the installer re-links on its next run).

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REPO_ROOT=${MYSYSTEM_REPO_ROOT:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
cd "$REPO_ROOT"

MODEL_OVERRIDES=(
  "ship|opus"
  "review|opus"
  "requesting-code-review|opus"
)

# Resolve a (possibly relative) symlink target against the link's parent dir
# to a physical, ..-free path. Falls back to a textual join when the parent
# can't be entered (the caller's -f check then fails cleanly).
canonicalize() {
  local base=$1 path=$2 joined
  case "$path" in
    /*) joined=$path ;;
    *)  joined=$base/$path ;;
  esac
  ( CDPATH= cd -- "$(dirname "$joined")" 2>/dev/null \
      && printf '%s/%s\n' "$(pwd -P)" "$(basename "$joined")" ) \
    || printf '%s\n' "$joined"
}

for entry in "${MODEL_OVERRIDES[@]}"; do
  IFS='|' read -r skill model <<< "$entry"
  target="skills/$skill"

  # Sweep temp files stranded by an interrupted earlier run (real dirs only —
  # never reach through a dir symlink into an external checkout), and recover
  # from an interrupted dir-symlink conversion: a real dir left with no
  # SKILL.md would otherwise be skipped as vendored by the sparse installer
  # forever. Removing it (empty-only) restores installer-managed re-linking.
  if [ -d "$target" ] && [ ! -L "$target" ]; then
    rm -f "$target"/.SKILL.md.* 2>/dev/null || true
    if [ ! -e "$target/SKILL.md" ]; then
      rmdir "$target" 2>/dev/null || true
      [ -e "$target" ] || echo "  ✗ $skill — empty override dir removed (installer re-links next run)"
    fi
  fi

  # Resolve the source SKILL.md this wrapper defers to. No mutation yet.
  real=""
  if [ -L "$target" ]; then
    real="$(canonicalize "$(dirname "$target")" "$(readlink "$target")")/SKILL.md"
  elif [ -L "$target/SKILL.md" ]; then
    real="$(canonicalize "$target" "$(readlink "$target/SKILL.md")")"
  elif [ -f "$target/SKILL.md" ]; then
    real=$(sed -n 's/^<!-- mysystem-model-override source=\(.*\) -->$/\1/p' "$target/SKILL.md" | head -1)
  fi

  if [ -z "$real" ] || [ ! -f "$real" ]; then
    if [ -f "$target/SKILL.md" ] && [ ! -L "$target/SKILL.md" ] \
       && grep -q '^<!-- mysystem-model-override source=' "$target/SKILL.md" 2>/dev/null; then
      # Stale wrapper whose recorded source vanished (upstream rename/removal):
      # remove it so the installer restores link-managed state on its next run,
      # instead of leaving a wrapper that defers to a nonexistent path. Also
      # remove the now-empty dir — for sparse installs the dir itself must go,
      # or the sparse installer's vendored-dir guard skips re-linking forever.
      rm -f "$target/SKILL.md"
      rmdir "$target" 2>/dev/null || true
      echo "  ✗ $skill — recorded source missing; stale wrapper removed (installer re-links next run)"
    else
      echo "  ✗ $skill — source SKILL.md not found (override skipped, original state untouched)"
    fi
    continue
  fi

  # Frontmatter must open on line 1 AND close before mutation — an
  # unterminated block would stream the whole body into the wrapper's
  # frontmatter and produce an unparseable skill.
  if [ "$(head -1 "$real")" != "---" ] \
     || ! awk 'NR>1 && /^---$/ {found=1; exit} END {exit !found}' "$real"; then
    echo "  ✗ $skill — source frontmatter missing or unterminated (override skipped, original state untouched)"
    continue
  fi

  # Source validated — only now convert a sparse dir-symlink to a real dir
  # (the sparse installer skips real dirs as vendored on later runs).
  if [ -L "$target" ]; then
    rm "$target"
    mkdir -p "$target"
  fi

  tmp=$(mktemp "$target/.SKILL.md.XXXXXX")
  {
    echo "---"
    # Source frontmatter minus any model: line, then the pinned model.
    awk 'NR==1 && /^---$/ {inside=1; next} inside && /^---$/ {exit} inside && !/^model:/ {print}' "$real"
    echo "model: $model"
    echo "---"
    echo "<!-- mysystem-model-override source=$real -->"
    echo ""
    echo "# $skill (model-pinned wrapper)"
    echo ""
    echo "MySystem pins this skill to \`$model\` (generated by scripts/apply-model-overrides.sh — edit MODEL_OVERRIDES there, not this file)."
    echo "The canonical skill body lives in the external checkout. Read"
    echo "$real"
    echo "now and execute everything AFTER its frontmatter as this skill's instructions, in full."
  } > "$tmp"
  rm -f "$target/SKILL.md"
  mv "$tmp" "$target/SKILL.md"
  echo "  ✓ $skill → model: $model (wraps $real)"
done
