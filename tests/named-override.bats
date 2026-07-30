#!/usr/bin/env bats
#
# Watchdog for the ADR-0019 named override.
#
# CLAUDE.md's Request Lock explicitly names two pieces of gstack prose it
# supersedes: the `Completeness Principle — Boil the Ocean` section and the
# `0-10 Rating Method` self-scoring loop. Naming them is what makes the
# override stronger than a generic precedence rule — but it also means a gstack
# upgrade that rewords or removes that prose leaves the override pointing at
# text that no longer exists, silently.
#
# Two halves, deliberately gated differently:
#   - The gstack-side tests need gstack installed, so they skip without it.
#   - The CLAUDE.md-side tests need nothing external, so they always run.
# Do NOT hoist the skip into setup(): CI has no gstack, and skipping the whole
# file there would mean CI never checks that the override text is still present,
# which is the half CI can actually verify.

SOURCE_REPO="$BATS_TEST_DIRNAME/.."

gstack_root() {
  for candidate in \
    "$SOURCE_REPO/skills/gstack" \
    "$HOME/.claude/skills/gstack" \
    "$HOME/.agents/skills/gstack"
  do
    if [ -d "$candidate" ] && [ -f "$candidate/SKILL.md" ]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

setup() {
  GSTACK_ROOT="$(gstack_root || true)"
  export GSTACK_ROOT
}

require_gstack() {
  [ -n "$GSTACK_ROOT" ] || skip "gstack is not installed"
}

# Assert a phrase still exists in gstack's skill prose.
#
# Scoped to SKILL.md and its templates on purpose: the gstack checkout is ~1.2GB
# (725MB of it node_modules), and an unscoped `grep -r` both walked all of it and
# exited 2 on the first unreadable sibling path even when matches existed, which
# made this file flake in the full suite. Asserting on non-empty output rather
# than grep's exit status keeps a read error on some unrelated file from being
# reported as "the override went stale".
assert_gstack_prose() {
  local phrase=$1 hits
  hits=$(grep -rl --include='SKILL.md' --include='*.tmpl' -- "$phrase" "$GSTACK_ROOT" 2>/dev/null | head -3)
  if [ -z "$hits" ]; then
    printf 'gstack no longer contains the phrase the ADR-0019 override names:\n  %s\nUpdate the named override in CLAUDE.md alongside the gstack upgrade.\n' "$phrase" >&2
    return 1
  fi
}

@test "gstack still ships the Boil the Ocean section the override names" {
  require_gstack
  assert_gstack_prose 'Completeness Principle — Boil the Ocean'
}

@test "gstack still ships the 'only thing out of scope' wording the override quotes" {
  require_gstack
  assert_gstack_prose 'only thing out of scope is genuinely unrelated work'
}

@test "gstack still ships the 0-10 Rating Method loop the override disables" {
  require_gstack
  assert_gstack_prose 'The 0-10 Rating Method'
}

@test "gstack still ships the repeat-until-10 termination the override replaces" {
  require_gstack
  assert_gstack_prose 'repeat until 10'
}

@test "CLAUDE.md carries the named override for each phrase it disables" {
  claude_md="$SOURCE_REPO/CLAUDE.md"
  grep -q 'Boil the Ocean' "$claude_md"
  grep -q 'only thing out of scope is genuinely unrelated work' "$claude_md"
  grep -q 'The 0-10 Rating Method' "$claude_md"
  grep -q 'repeat until 10' "$claude_md"
}

@test "CLAUDE.md keeps Confusion Protocol explicitly exempt from the override" {
  run grep -q 'Confusion Protocol' "$SOURCE_REPO/CLAUDE.md"
  [ "$status" -eq 0 ]
}

@test "CLAUDE.md still names codex/workflow-contract.md as the other surface" {
  run grep -q 'codex/workflow-contract.md' "$SOURCE_REPO/CLAUDE.md"
  [ "$status" -eq 0 ]
}
