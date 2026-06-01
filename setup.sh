#!/usr/bin/env bash
# MySystem setup — idempotent bootstrap for ~/.claude
# Usage: cd ~/.claude && ./setup.sh
#
# What this does:
#   1. Clone or update full external skill repos (gstack)
#   2. Run gstack's own setup (symlinks 20+ skills into ~/.claude/skills/)
#   3. Sparse cherry-pick individual skills from other repos (cache + symlink)
#   4. Register external skill dirs in .git/info/exclude so the tracked
#      .gitignore stays small.
#   5. Validate skill symlinks
#   6. Verify RTK presence (voyagerx internal token-compression proxy)

set -euo pipefail

cd "$(dirname "$0")"
REPO_ROOT="$(pwd)"

echo "=== MySystem Setup ==="
echo ""

# ── Full external skill repositories ─────────────────────────
# Format: "name|url|branch"
# These repos run their own setup script that installs many skills.
EXTERNAL_REPOS=(
  "gstack|https://github.com/garrytan/gstack.git|main"
)

# ── Sparse cherry-pick skills ────────────────────────────────
# Format: "skill-name|url|branch|subpath-in-repo[|commit-SHA]"
# Clones the repo into external-skills/<skill-name>/ (cache, not tracked)
# and symlinks <subpath> as skills/<skill-name>/.
#
# Optional 5th field: short-SHA (8-12 hex chars). When present, setup.sh
# checks out that commit after clone instead of tracking branch tip.
# Pin autonomous (workflow-whitelisted) skills; leave user-invoked skills
# unpinned per ADR-0005 amendment in ADR-0007 (v0.37.0).
SPARSE_SKILLS=(
  # Step 7 — pre-v0.37.0 baseline (unpinned per ADR-0005 original convention)
  "requesting-code-review|https://github.com/obra/superpowers.git|main|skills/requesting-code-review"
  # Step 2 — deep-research is now VENDORED (tracked at skills/deep-research/, ADR-0011),
  # removed from sparse cherry-pick so it can be owned + customized locally (provider-pluggable).

  # v0.37.0 adds — obra/superpowers (Iron Law skills)
  # Autonomous (Step 5 augment) — pinned
  "verification-before-completion|https://github.com/obra/superpowers.git|main|skills/verification-before-completion|f2cbfbefebbf"
  # User-invoked only — unpinned (manual invocation = user sees content)
  "test-driven-development|https://github.com/obra/superpowers.git|main|skills/test-driven-development"

  # v0.37.0 adds — mattpocock/skills (engineering bucket)
  # Autonomous (debug alternate) — pinned
  "diagnose|https://github.com/mattpocock/skills.git|main|skills/engineering/diagnose|e74f0061bb67"
  # Autonomous (pre-Step-3 option) — pinned
  "grill-with-docs|https://github.com/mattpocock/skills.git|main|skills/engineering/grill-with-docs|e74f0061bb67"
  # User-invoked only — unpinned
  "prototype|https://github.com/mattpocock/skills.git|main|skills/engineering/prototype"
  "triage|https://github.com/mattpocock/skills.git|main|skills/engineering/triage"
  "zoom-out|https://github.com/mattpocock/skills.git|main|skills/engineering/zoom-out"

  # v0.37.0 adds — mattpocock/skills (productivity bucket)
  # Autonomous (cross-agent handoff after /context-save fails) — pinned
  "handoff|https://github.com/mattpocock/skills.git|main|skills/productivity/handoff|e74f0061bb67"
)

clone_or_pull() {
  local dest="$1" url="$2" branch="$3"

  if [ -d "$dest/.git" ]; then
    echo "  pulling $dest..."
    if ! ( cd "$dest" && git pull --ff-only origin "$branch" 2>&1 | sed 's/^/    /' ); then
      echo "  ✗ $dest: pull failed (uncommitted changes?)."
      echo "    Fix manually: cd $dest && git stash || git reset --hard origin/$branch"
      exit 1
    fi
  else
    echo "  cloning $dest from $url..."
    [ -e "$dest" ] && rm -rf "$dest"
    git clone --branch "$branch" "$url" "$dest" 2>&1 | sed 's/^/    /'
  fi
}

# ── [1/5] Full external repos ────────────────────────────────
echo "[1/5] Syncing full external skill repos..."
for entry in "${EXTERNAL_REPOS[@]}"; do
  IFS='|' read -r name url branch <<< "$entry"
  clone_or_pull "skills/$name" "$url" "$branch"
done
echo "  ✓ external repos ready"

# ── [2/5] Run gstack's own setup ─────────────────────────────
echo ""
echo "[2/5] Running gstack setup..."
if [ -x "skills/gstack/setup" ]; then
  ( cd skills/gstack && ./setup 2>&1 | sed 's/^/  /' )
  echo "  ✓ gstack skills installed"
else
  echo "  ✗ skills/gstack/setup not found or not executable"
  exit 1
fi

# ── [3/5] Sparse cherry-pick skills ──────────────────────────
echo ""
echo "[3/5] Installing sparse cherry-pick skills..."
mkdir -p external-skills
for entry in "${SPARSE_SKILLS[@]}"; do
  IFS='|' read -r skill_name url branch subpath sha <<< "$entry"
  cache_dir="external-skills/$skill_name"
  link_target="skills/$skill_name"
  abs_source="$REPO_ROOT/$cache_dir/$subpath"

  if [ -n "${sha:-}" ]; then
    # Pinned path (ADR-0007): clone if missing, then fetch + checkout SHA.
    # Don't use `git pull --ff-only` because HEAD is detached at the pinned
    # SHA after the first install — pull would fail on subsequent runs.
    if [ ! -d "$cache_dir/.git" ]; then
      echo "  cloning $cache_dir from $url..."
      [ -e "$cache_dir" ] && rm -rf "$cache_dir"
      git clone --branch "$branch" "$url" "$cache_dir" 2>&1 | sed 's/^/    /'
    else
      echo "  fetching $cache_dir (pinned)..."
      # Explicit refspec so refs/remotes/origin/<branch> advances (not just
      # FETCH_HEAD). ADR-0007's refresh workflow relies on `git log <SHA>..origin/main`
      # showing the real diff window; FETCH_HEAD alone would make that stale.
      # Also handles the case where the entry's branch field was renamed —
      # if the remote doesn't have that branch, the fetch fails loudly here
      # instead of producing a cryptic checkout error.
      if ! ( cd "$cache_dir" && git fetch origin "$branch:refs/remotes/origin/$branch" --quiet 2>&1 | sed 's/^/    /' ); then
        echo "  ✗ $skill_name: fetch failed — branch '$branch' may not exist upstream anymore."
        echo "    Fix: check upstream's default branch and update the entry in setup.sh."
        exit 1
      fi
    fi
    if ! ( cd "$cache_dir" && git checkout --quiet "$sha" 2>&1 ); then
      echo "  ✗ $skill_name: pinned SHA '$sha' not reachable on $branch"
      echo "    Repo may have rewritten history. Fix: update SHA in setup.sh"
      echo "    (after reading upstream diff) or remove the pin to track branch tip."
      exit 1
    fi
    echo "  pinned $cache_dir to $sha"
  else
    # Unpinned path (ADR-0005 original convention): clone or pull branch tip.
    clone_or_pull "$cache_dir" "$url" "$branch"
  fi

  if [ ! -e "$abs_source" ]; then
    echo "  ✗ $skill_name: subpath '$subpath' not found in repo"
    exit 1
  fi

  # Defense-in-depth (ADR-0011): never clobber a vendored (real-dir) skill. The real protection
  # is removing a vendored skill's SPARSE_SKILLS entry (so this loop never iterates it) — this is
  # clobber-defense for any FUTURE vendored-from-sparse skill, NOT a true idempotency promise.
  # Require a real directory (-d && ! -L): a stray regular file at the target then gets re-linked
  # rather than silently treated as vendored, and ! -L still excludes a valid symlink-to-dir
  # (which should be re-linked normally).
  if [ -d "$link_target" ] && [ ! -L "$link_target" ]; then
    echo "  ✓ $skill_name vendored (real dir) — skipping symlink"
    continue
  fi

  # Replace any existing target (file, dir, or stale symlink)
  if [ -e "$link_target" ] || [ -L "$link_target" ]; then
    rm -rf "$link_target"
  fi
  ln -s "$abs_source" "$link_target"
  if [ -n "${sha:-}" ]; then
    echo "  ✓ $skill_name → $cache_dir/$subpath (pinned $sha)"
  else
    echo "  ✓ $skill_name → $cache_dir/$subpath"
  fi
done

# Register external dirs in local-only ignore so they don't pollute git status
EXCLUDE_FILE=".git/info/exclude"
{
  echo "# Auto-generated by setup.sh — external skill + reference dirs"
  echo "external-skills/"
  for entry in "${EXTERNAL_REPOS[@]}"; do
    IFS='|' read -r name _ _ <<< "$entry"
    echo "skills/$name/"
  done
  # Also exclude any gstack-installed skill dir that isn't whitelisted in .gitignore.
  # gstack symlinks land directly under skills/. We register each non-whitelisted
  # skill dir found post-install so `git status` stays clean.
  for d in skills/*/; do
    name=$(basename "$d")
    case "$name" in
      verify-test) continue ;;    # tracked user-owned skill
      deep-research) continue ;;  # vendored user-owned skill (ADR-0011) — never re-exclude
      gstack) continue ;;         # already listed above
    esac
    echo "skills/$name/"
  done
} > "$EXCLUDE_FILE"

# ── [4/5] Validate ───────────────────────────────────────────
echo ""
echo "[4/5] Validating..."
BROKEN=0
TOTAL=0
for skill_dir in skills/*/; do
  skill_name=$(basename "$skill_dir")
  [ "$skill_name" = "gstack" ] && continue
  skill_file="$skill_dir/SKILL.md"

  if [ -L "$skill_dir" ] || [ -L "$skill_file" ]; then
    TOTAL=$((TOTAL + 1))
    if [ ! -e "$skill_file" ]; then
      echo "  ✗ $skill_name — broken symlink"
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

# ── [5/5] RTK ────────────────────────────────────────────────
if command -v rtk >/dev/null 2>&1; then
  echo "  ✓ rtk present ($(rtk --version 2>/dev/null | head -1 || echo unknown))"
else
  echo "  ⚠ rtk not on PATH — see RTK.md for install (token compression hook will no-op)"
fi

echo ""
echo "=== Setup Complete ==="
echo "  Version: $(cat VERSION 2>/dev/null || echo "?")"
echo "  Skills:  $TOTAL"
echo "  Hooks:   $(ls hooks/*.sh 2>/dev/null | wc -l | tr -d ' ')"
echo ""
echo "Start a new Claude Code session to pick up changes."
