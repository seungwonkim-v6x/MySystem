#!/usr/bin/env bash
# MySystem setup — idempotent bootstrap for Claude Code and Codex.
# Usage: cd ~/.claude && ./setup.sh [command]
#
# What this does:
#   1. Clone or update full external skill repos (gstack)
#   2. Run gstack's own setup (symlinks 20+ skills into ~/.claude/skills/)
#   3. Sparse cherry-pick individual skills from other repos (cache + symlink),
#      then register external skill dirs in .git/info/exclude so the tracked
#      .gitignore stays small.
#   3.5. Apply skill model overrides (scripts/apply-model-overrides.sh —
#      wraps designated external skills with a pinned `model:` frontmatter)
#   4. Validate skill symlinks
#   5. Install and diagnose Codex behavioral-parity links

set -euo pipefail

cd "$(dirname "$0")"
REPO_ROOT="$(pwd)"
SETUP_STARTED=$SECONDS

setup_fail() {
  local id=$1 subject=$2 problem=$3 cause=$4 fix=$5 anchor=$6
  printf 'FAIL %s subject=%s Problem=%s Cause=%s Fix=%s Docs=SETUP.md#%s\n' \
    "$id" "$subject" "$problem" "$cause" "$fix" "$anchor" >&2
}

print_timing() {
  printf 'TIMING stage=%s seconds=%s\n' "$1" "$2"
}

usage() {
  cat <<'EOF'
Usage: ./setup.sh [command] [options]

Commands:
  (none)                 update external skills and install Codex parity
  --check                read-only Codex parity check
  --parity-only          render/install Codex parity without network updates
  doctor                 read-only diagnostics; accepts --require/--json/--verbose
  --recover              restore the latest approved legacy-path backup
  --codex-home PATH      include an additional existing Codex home (repeatable)
  --help                 show this help
EOF
}

PARITY_ARGS_FILE=$(mktemp "${TMPDIR:-/tmp}/mysystem-setup-homes.XXXXXX")
trap 'rm -f "$PARITY_ARGS_FILE"' EXIT HUP INT TERM
SETUP_MODE=full
case "${1:-}" in
  doctor)
    shift
    "$REPO_ROOT/scripts/codex-parity-doctor.sh" "$@"
    exit $?
    ;;
  --check)
    SETUP_MODE=check
    shift
    ;;
  --parity-only)
    SETUP_MODE=parity
    shift
    ;;
  --recover)
    SETUP_MODE=recover
    shift
    ;;
  --session-start)
    SETUP_MODE=session-start
    shift
    ;;
  --help|-h)
    usage
    exit 0
    ;;
esac

while [ "$#" -gt 0 ]; do
  case "$1" in
    --codex-home)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      printf '%s\n' "$2" >> "$PARITY_ARGS_FILE"
      shift 2
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

run_parity() {
  local command=$1 home
  shift
  set -- "$command" "$@"
  while IFS= read -r home; do
    [ -n "$home" ] || continue
    set -- "$@" --codex-home "$home"
  done < "$PARITY_ARGS_FILE"
  "$@"
}

case "$SETUP_MODE" in
  check) if run_parity "$REPO_ROOT/scripts/install-codex-parity.sh" --check; then status=0; else status=$?; fi; print_timing total "$((SECONDS - SETUP_STARTED))"; exit "$status" ;;
  parity) if run_parity "$REPO_ROOT/scripts/install-codex-parity.sh"; then status=0; else status=$?; fi; print_timing total "$((SECONDS - SETUP_STARTED))"; exit "$status" ;;
  recover) if run_parity "$REPO_ROOT/scripts/install-codex-parity.sh" --recover; then status=0; else status=$?; fi; print_timing total "$((SECONDS - SETUP_STARTED))"; exit "$status" ;;
esac

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
  # Step 7 — pre-v0.37.0 baseline (unpinned per ADR-0005 original convention).
  # Entry kept even though stage 3.5 converts the install to a model-override
  # wrapper dir: the cache refresh below is what keeps the wrapped body fresh.
  "requesting-code-review|https://github.com/obra/superpowers.git|main|skills/requesting-code-review"
  # Step 2 — deep-research is now VENDORED (tracked at skills/deep-research/, ADR-0011),
  # removed from sparse cherry-pick so it can be owned + customized locally (provider-pluggable).

  # v0.37.0 adds — obra/superpowers (Iron Law skills)
  # Autonomous (Step 5 augment) — pinned
  "verification-before-completion|https://github.com/obra/superpowers.git|main|skills/verification-before-completion|f2cbfbefebbf"

  # v0.44.0 prune: 7 of the 9 v0.37.0 sparse skills were removed after zero
  # invocations across ~99 sessions / 1 month of transcripts (May 12 – Jun 11 2026):
  #   test-driven-development, diagnose, grill-with-docs, prototype, triage,
  #   zoom-out, handoff
  # Re-adding any of them is one line here + ./setup.sh — upstream repos unchanged.
)

clone_or_pull() {
  local dest="$1" url="$2" branch="$3" actual_url

  if [ -d "$dest/.git" ]; then
    actual_url=$(git -C "$dest" remote get-url origin 2>/dev/null || true)
    if [ "$actual_url" != "$url" ]; then
      setup_fail EXTERNAL_ORIGIN_MISMATCH "$dest" "External checkout origin is unexpected" "actual=$actual_url expected=$url" "Inspect or move the checkout before retrying" parity-contract
      exit 1
    fi
    echo "  pulling $dest..."
    if ! ( cd "$dest" && git pull --ff-only origin "$branch" 2>&1 | sed 's/^/    /' ); then
      setup_fail EXTERNAL_PULL_FAILED "$dest" "External checkout update failed" "The branch may contain local changes or network fetch failed" "Inspect the checkout and resolve it manually" parity-contract
      exit 1
    fi
  else
    echo "  cloning $dest from $url..."
    if [ -e "$dest" ] || [ -L "$dest" ]; then
      setup_fail EXTERNAL_PATH_CONFLICT "$dest" "External checkout path contains unknown content" "The path is not the expected owned Git checkout" "Inspect and move it aside manually" parity-contract
      exit 1
    fi
    git clone --branch "$branch" "$url" "$dest" 2>&1 | sed 's/^/    /'
  fi
}

# ── [1/5] Full external repos ────────────────────────────────
echo "[1/5] Syncing full external skill repos..."
STAGE_STARTED=$SECONDS
for entry in "${EXTERNAL_REPOS[@]}"; do
  IFS='|' read -r name url branch <<< "$entry"
  clone_or_pull "skills/$name" "$url" "$branch"
done
echo "  ✓ external repos ready"
print_timing external-sync "$((SECONDS - STAGE_STARTED))"

# ── [2/5] Run gstack's own setup ─────────────────────────────
echo ""
echo "[2/5] Running gstack setup..."
STAGE_STARTED=$SECONDS
if [ -x "skills/gstack/setup" ]; then
  ( cd skills/gstack && ./setup 2>&1 | sed 's/^/  /' )
  # Codex scans skill roots recursively. gstack's source checkout can contain
  # generated skill exports for other agent hosts; those are useful artifacts
  # for their hosts, but in Codex they duplicate the real workflow skills and
  # consume the skills context budget. Keep the source runtime + direct gstack
  # skills, prune only generated host-export directories after setup.
  for host_export in .agents .cursor .factory .gbrain .hermes .kiro .openclaw .opencode .slate; do
    if [ -d "skills/gstack/$host_export" ]; then
      rm -rf "skills/gstack/$host_export"
    fi
  done
  # Keep Codex/Claude skill discovery aligned with the mandatory workflow.
  # Non-whitelisted gstack skills can still be restored by running gstack setup
  # directly, but they should not be auto-exposed in every MySystem session.
  WORKFLOW_TOP_SKILLS=" gstack gstack-upgrade office-hours investigate deep-research autoplan verify-test qa-only design-review verification-before-completion review requesting-code-review ship ai-review-loop aside-qa "
  for skill_dir in skills/*; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    case "$WORKFLOW_TOP_SKILLS" in
      *" $skill_name "*) ;;
      *) rm -rf "$skill_dir" ;;
    esac
  done
  echo "  ✓ gstack skills installed"
else
  setup_fail GSTACK_SETUP_MISSING skills/gstack/setup "Gstack setup entrypoint is unavailable" "The external checkout is incomplete or non-executable" "Restore gstack and rerun full setup" gstack-skills
  exit 1
fi
print_timing gstack-setup "$((SECONDS - STAGE_STARTED))"

# ── [3/5] Sparse cherry-pick skills ──────────────────────────
echo ""
echo "[3/5] Installing sparse cherry-pick skills..."
STAGE_STARTED=$SECONDS
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
      if [ -e "$cache_dir" ] || [ -L "$cache_dir" ]; then
        setup_fail SPARSE_CACHE_CONFLICT "$cache_dir" "Sparse-skill cache contains unknown content" "The path is not an owned Git checkout" "Inspect and move it aside manually" portable-skills
        exit 1
      fi
      git clone --branch "$branch" "$url" "$cache_dir" 2>&1 | sed 's/^/    /'
    else
      echo "  fetching $cache_dir (pinned)..."
      actual_url=$(git -C "$cache_dir" remote get-url origin 2>/dev/null || true)
      if [ "$actual_url" != "$url" ]; then
        setup_fail SPARSE_ORIGIN_MISMATCH "$cache_dir" "Sparse-skill origin is unexpected" "actual=$actual_url expected=$url" "Inspect or replace the cache manually" portable-skills
        exit 1
      fi
      # Explicit refspec so refs/remotes/origin/<branch> advances (not just
      # FETCH_HEAD). ADR-0007's refresh workflow relies on `git log <SHA>..origin/main`
      # showing the real diff window; FETCH_HEAD alone would make that stale.
      # Also handles the case where the entry's branch field was renamed —
      # if the remote doesn't have that branch, the fetch fails loudly here
      # instead of producing a cryptic checkout error.
      if ! ( cd "$cache_dir" && git fetch origin "$branch:refs/remotes/origin/$branch" --quiet 2>&1 | sed 's/^/    /' ); then
        setup_fail SPARSE_FETCH_FAILED "$skill_name" "Sparse-skill fetch failed" "Branch $branch is unavailable or the network failed" "Verify the upstream branch and retry" portable-skills
        exit 1
      fi
    fi
    if ! ( cd "$cache_dir" && git checkout --quiet "$sha" 2>&1 ); then
      setup_fail SPARSE_PIN_UNREACHABLE "$skill_name" "Pinned sparse-skill commit is unreachable" "SHA $sha is unavailable on $branch" "Review upstream history before updating the pin" portable-skills
      exit 1
    fi
    echo "  pinned $cache_dir to $sha"
  else
    # Unpinned path (ADR-0005 original convention): clone or pull branch tip.
    clone_or_pull "$cache_dir" "$url" "$branch"
  fi

  if [ ! -e "$abs_source" ]; then
    setup_fail SPARSE_SUBPATH_MISSING "$skill_name" "Sparse-skill source path is missing" "Subpath $subpath is absent from the checkout" "Verify the declared upstream layout" portable-skills
    exit 1
  fi

  # Defense-in-depth (ADR-0011): never clobber a vendored (real-dir) skill. For most skills the
  # real protection is removing the SPARSE_SKILLS entry (so this loop never iterates it). Since
  # v0.51.0 this guard is ALSO load-bearing for model-override skills (requesting-code-review):
  # they keep their SPARSE_SKILLS entry so the external cache refreshes, and stage 3.5's
  # dir-symlink→real-dir conversion relies on this skip every subsequent run.
  # Require a real directory (-d && ! -L): a stray regular file at the target then gets re-linked
  # rather than silently treated as vendored, and ! -L still excludes a valid symlink-to-dir
  # (which should be re-linked normally).
  if [ -d "$link_target" ] && [ ! -L "$link_target" ]; then
    echo "  ✓ $skill_name vendored (real dir) — skipping symlink"
    continue
  fi

  # Replace only a symlink. Unknown real files are preserved and fail closed.
  if [ -L "$link_target" ]; then
    rm "$link_target"
  elif [ -e "$link_target" ]; then
    setup_fail SPARSE_LINK_CONFLICT "$link_target" "Sparse-skill link target contains unknown content" "A real path occupies the managed link destination" "Inspect and move it aside manually" portable-skills
    exit 1
  fi
  ln -s "$abs_source" "$link_target"
  if [ -n "${sha:-}" ]; then
    echo "  ✓ $skill_name → $cache_dir/$subpath (pinned $sha)"
  else
    echo "  ✓ $skill_name → $cache_dir/$subpath"
  fi
done
print_timing sparse-skills "$((SECONDS - STAGE_STARTED))"

# Sparse repos can contain many sibling skills. Only expose the specific
# cherry-picked skill directories that the workflow declares.
for skill_dir in external-skills/requesting-code-review/skills/*; do
  [ -d "$skill_dir" ] || continue
  [ "$(basename "$skill_dir")" = "requesting-code-review" ] || rm -rf "$skill_dir"
done
for skill_dir in external-skills/verification-before-completion/skills/*; do
  [ -d "$skill_dir" ] || continue
  [ "$(basename "$skill_dir")" = "verification-before-completion" ] || rm -rf "$skill_dir"
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
      aside-qa) continue ;;       # tracked user-owned skill (was missing — new files were vanishing from git status)
      ai-review-loop) continue ;; # tracked user-owned skill (Step 9, v0.46.0)
      gstack) continue ;;         # already listed above
    esac
    echo "skills/$name/"
  done
} > "$EXCLUDE_FILE"

# ── [3.5/5] Skill model overrides ────────────────────────────
# Wrapper generation lives in scripts/apply-model-overrides.sh (the
# MODEL_OVERRIDES table is declared there; contract tests in
# tests/model-overrides.bats). Runs AFTER the external installers so it can
# re-wrap whatever they re-linked this session (self-healing by design).
echo ""
echo "[3.5/5] Applying skill model overrides..."
STAGE_STARTED=$SECONDS
bash scripts/apply-model-overrides.sh
print_timing model-overrides "$((SECONDS - STAGE_STARTED))"

# ── [4/5] Validate ───────────────────────────────────────────
echo ""
echo "[4/5] Validating..."
STAGE_STARTED=$SECONDS
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
  setup_fail SKILL_LINKS_BROKEN skills "Skill validation found $BROKEN broken links" "External or sparse installation is incomplete" "Rerun full setup and inspect earlier failures" core-skill-missing
  exit 1
fi
print_timing skill-validation "$((SECONDS - STAGE_STARTED))"

# ── [5/5] Codex behavioral parity ───────────────────────────
echo ""
echo "[5/5] Codex behavioral parity..."
STAGE_STARTED=$SECONDS
if [ "$SETUP_MODE" = session-start ]; then
  run_parity "$REPO_ROOT/scripts/install-codex-parity.sh" --check
else
  run_parity "$REPO_ROOT/scripts/install-codex-parity.sh"
fi
print_timing codex-parity "$((SECONDS - STAGE_STARTED))"

# Final Codex context-budget cleanup. The parity installer may refresh
# ~/.agents/skills after the earlier gstack setup cleanup, so prune the
# user-skill surface last as well.
WORKFLOW_USER_SKILLS=" gstack gstack-upgrade office-hours investigate deep-research autoplan verify-test qa-only design-review verification-before-completion review requesting-code-review ship ai-review-loop aside-qa "
if [ -d "$HOME/.agents/skills" ]; then
  for skill_dir in "$HOME"/.agents/skills/*; do
    [ -d "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    case "$WORKFLOW_USER_SKILLS" in
      *" $skill_name "*) ;;
      *) rm -rf "$skill_dir" ;;
    esac
  done
fi

if [ -d "$HOME/.agents/skills/gstack" ] && [ ! -d "$HOME/.agents/skills/gstack/.git" ]; then
  for host_export in .agents .cursor .factory .gbrain .hermes .kiro .openclaw .opencode .slate; do
    if [ -d "$HOME/.agents/skills/gstack/$host_export" ]; then
      rm -rf "$HOME/.agents/skills/gstack/$host_export"
    fi
  done
  WORKFLOW_AGENT_GSTACK_SKILLS=" SKILL.md bin browse review qa ETHOS.md gstack gstack-upgrade office-hours investigate autoplan qa-only design-review review ship "
  for skill_dir in "$HOME"/.agents/skills/gstack/*; do
    [ -e "$skill_dir" ] || continue
    skill_name=$(basename "$skill_dir")
    case "$WORKFLOW_AGENT_GSTACK_SKILLS" in
      *" $skill_name "*) ;;
      *) rm -rf "$skill_dir" ;;
    esac
  done
fi

for plugin_cache_dir in \
  "$HOME/.codex/plugins/cache/openai-primary-runtime/documents" \
  "$HOME/.codex/plugins/cache/openai-primary-runtime/pdf" \
  "$HOME/.codex/plugins/cache/openai-primary-runtime/presentations" \
  "$HOME/.codex/plugins/cache/openai-primary-runtime/spreadsheets" \
  "$HOME/.codex/plugins/cache/openai-bundled/browser" \
  "$HOME/.codex/plugins/cache/openai-bundled/sites" \
  "$HOME/.codex/plugins/cache/learning-opportunities/learning-opportunities-auto" \
  "$HOME/.codex/plugins/cache/learning-opportunities/learning-opportunities" \
  "$HOME/.codex/plugins/cache/learning-opportunities/orient" \
  "$HOME/.codex/plugins/cache/openai-curated-remote/notion" \
  "$HOME/.codex/plugins/cache/openai-curated-remote/openai-templates" \
  "$HOME/.codex/plugins/cache/chatgpt-global/notion" \
  "$HOME/.codex/plugins/cache/claude-plugins-official/code-review" \
  "$HOME/.codex/plugins/cache/claude-plugins-official/plugin-install-iagkOH"; do
  [ -e "$plugin_cache_dir" ] && rm -rf "$plugin_cache_dir"
done

echo ""
echo "=== Setup Complete ==="
echo "  Version: $(cat VERSION 2>/dev/null || echo "?")"
echo "  Skills:  $TOTAL"
echo "  Hooks:   $(ls hooks/*.sh 2>/dev/null | wc -l | tr -d ' ')"
print_timing total "$((SECONDS - SETUP_STARTED))"
echo ""
echo "Start a new Claude Code or Codex session to pick up changes."
