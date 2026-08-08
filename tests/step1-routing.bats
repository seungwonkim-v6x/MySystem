#!/usr/bin/env bats
#
# Watchdog for the ADR-0023 Step-1 rewiring.
#
# Step 1 used to route every Feature / Bug Fix / Refactoring request to
# gstack's /office-hours, whose own body scopes it to "a new product idea …
# something that doesn't exist yet … before any code is written". The map
# pointed at a socket that refuses the plug, and Step 1 stopped running.
#
# These tests do NOT assert byte-identity between the two instruction surfaces
# the way mandatory-invocation.bats does. The Step-1 rows are deliberately
# worded per surface. What must hold is the routing invariant: both surfaces
# name all three Step-1 skills, and neither reverts to /office-hours as the
# sole default. Asserting wording here would fail on a harmless rephrase and
# teach the next person to delete the test.
#
# Assertions are chained with `|| return 1`. bats 1.13.0 does not fail a test
# on a bare non-final `[[ ]]`, so an unchained mid-test assertion silently
# asserts nothing (standing TODO in TODOS.md).

SOURCE_REPO="$BATS_TEST_DIRNAME/.."
CLAUDE_MD="$SOURCE_REPO/CLAUDE.md"
CONTRACT_MD="$SOURCE_REPO/codex/workflow-contract.md"
CONTRACT_JSON="$SOURCE_REPO/codex/parity-contract.json"
SKILL="$SOURCE_REPO/skills/scope-check/SKILL.md"

STEP1_SKILLS=(scope-check office-hours investigate)

# The exact row ADR-0023 replaced. Its return in either surface is the
# regression this file exists to catch.
OLD_ROW='| 1. Validate idea / problem | `/office-hours` | gstack |'

@test "the scope-check skill exists and declares its own name" {
  [ -s "$SKILL" ] || {
    echo "missing or empty: $SKILL" >&2
    return 1
  }
  run grep -m1 '^name:' "$SKILL"
  [ "$status" -eq 0 ] || return 1
  [ "$output" = "name: scope-check" ] || {
    echo "frontmatter name must match the directory: got '$output'" >&2
    return 1
  }
}

@test "scope-check is a tracked user-owned skill, not gitignored" {
  run git -C "$SOURCE_REPO" check-ignore -q skills/scope-check/SKILL.md
  [ "$status" -ne 0 ] || {
    echo "skills/scope-check/SKILL.md is ignored; .gitignore needs both whitelist lines" >&2
    return 1
  }
}

@test "the parity contract carries scope-check as a core portable-local skill" {
  run jq -e '
    (.skills[] | select(.name == "scope-check")
      | .mode == "portable-local"
      and .source == "skills/scope-check"
      and (.profiles | index("core") != null))
    and (.profiles.core.skills | index("scope-check") != null)
  ' "$CONTRACT_JSON"
  [ "$status" -eq 0 ] || {
    echo "contract must list scope-check in skills[] AND profiles.core.skills" >&2
    return 1
  }
}

@test "setup.sh prune whitelists cover every core-profile skill" {
  # Both whitelists are hardcoded strings that setup.sh uses to `rm -rf` anything
  # not listed — WORKFLOW_TOP_SKILLS over `skills/*` (tracked working-tree files)
  # and WORKFLOW_USER_SKILLS over `$HOME/.agents/skills/*` (the links the parity
  # installer just made). Neither is derived from the contract, so adding a core
  # skill without editing both silently arms a destructive prune: the next
  # ./setup.sh deletes the skill, the parity stage aborts on
  # MANAGED_SOURCE_MISSING, and every portable link goes with it. Found exactly
  # that way when scope-check was added (ADR-0023).
  local core missing=() name list
  core=$(jq -r '.profiles.core.skills[]' "$CONTRACT_JSON") || return 1
  for list in WORKFLOW_TOP_SKILLS WORKFLOW_USER_SKILLS; do
    local value
    value=$(grep -m1 "^ *$list=" "$SOURCE_REPO/setup.sh" | sed 's/^[^=]*=//; s/^"//; s/"$//')
    [ -n "$value" ] || {
      echo "could not read $list from setup.sh — the guard cannot guard" >&2
      return 1
    }
    while IFS= read -r name; do
      [ -n "$name" ] || continue
      case "$value" in
        *" $name "*) ;;
        *) missing+=("$list:$name") ;;
      esac
    done <<< "$core"
  done
  [ "${#missing[@]}" -eq 0 ] || {
    printf 'core-profile skills missing from a setup.sh prune whitelist:\n' >&2
    printf '  %s\n' "${missing[@]}" >&2
    printf 'Add them, or the next ./setup.sh deletes the skill and breaks the parity install.\n' >&2
    return 1
  }
}

@test "both surfaces name every Step-1 skill" {
  local surface skill
  for surface in "$CLAUDE_MD" "$CONTRACT_MD"; do
    for skill in "${STEP1_SKILLS[@]}"; do
      grep -qF -- "/$skill" "$surface" || {
        echo "$(basename "$surface") does not name /$skill" >&2
        return 1
      }
    done
  done
}

# Every Step-1 row of the Step → Skill mapping table, on one surface.
# Scoped to rows so wording is free but the ROUTING is not: a whole-file grep is
# satisfied by the `## Skills` whitelist line alone, which is how the first
# version of this file let a reworded revert of both surfaces pass all 134 tests.
step1_rows() {
  awk '
    /^\| 1\./ { inside = 1; print; next }
    inside && /^\|    \(/ { print; next }
    inside { inside = 0 }
  ' "$1"
}

@test "the Step-1 mapping rows route to all three skills on both surfaces" {
  local surface rows skill
  for surface in "$CLAUDE_MD" "$CONTRACT_MD"; do
    rows=$(step1_rows "$surface")
    [ -n "$rows" ] || {
      echo "$(basename "$surface"): found no '| 1.' mapping row to check" >&2
      return 1
    }
    for skill in "${STEP1_SKILLS[@]}"; do
      case "$rows" in
        *"/$skill"*) ;;
        *)
          printf '%s Step-1 mapping rows do not route to /%s:\n%s\n' \
            "$(basename "$surface")" "$skill" "$rows" >&2
          printf 'Reword freely, but every Step-1 skill must appear in the mapping (ADR-0023).\n' >&2
          return 1
          ;;
      esac
    done
  done
}

@test "scope-check is the DEFAULT Step 1 on both surfaces, not merely present" {
  # Presence is not the invariant; precedence is. Two earlier versions of this
  # file asserted presence and both passed a revert: the first through a
  # byte-identical one, the second through a semantic one that made
  # /office-hours the default again and demoted /scope-check to a "rare" row
  # while still naming all three skills. The mapping table is ordered, so the
  # first Step-1 row IS the default — assert that row, not the set.
  local surface rows first
  for surface in "$CLAUDE_MD" "$CONTRACT_MD"; do
    grep -qFx -- "$OLD_ROW" "$surface" && {
      echo "$(basename "$surface") reverted to the pre-ADR-0023 Step-1 row:" >&2
      echo "  $OLD_ROW" >&2
      return 1
    }
    rows=$(step1_rows "$surface")
    first=$(printf '%s\n' "$rows" | head -1)
    case "$first" in
      *'/scope-check'*) ;;
      *)
        printf '%s: the first Step-1 row must name /scope-check as the default.\n' \
          "$(basename "$surface")" >&2
        printf 'Got:\n  %s\nFull mapping:\n%s\n' "$first" "$rows" >&2
        printf 'ADR-0023 makes /scope-check the default; demoting it is the revert.\n' >&2
        return 1
        ;;
    esac
  done

  # Same property in the one line both surfaces carry verbatim: whichever skill
  # is named first there is the one a reader takes as the default.
  local line
  line=$(grep -m1 -F -- 'Step 1 is exactly one of' "$CONTRACT_MD") || return 1
  case "${line#*Step 1 is exactly one of }" in
    '`/scope-check`'*) ;;
    *)
      printf 'the disambiguation line no longer names /scope-check first:\n  %s\n' "$line" >&2
      return 1
      ;;
  esac
}

@test "the disambiguation rule is verbatim on both surfaces and in the projection" {
  # The mapping table lists three skills; this one line is what resolves them,
  # including the case that reinstates the old failure if it goes missing — a new
  # file inside an existing codebase is /scope-check, not /office-hours.
  # CLAUDE.md's *Detailed Rules* requires both surfaces to change together, and it
  # is only operative on the Codex side once it reaches the generated projection.
  # Not asserted through mandatory-invocation.bats's helper: that one additionally
  # requires the line to sit inside `## Critical Workflow Rules`, and this line
  # belongs with the mapping table.
  local line surface
  line=$(grep -m1 -F -- 'Step 1 is exactly one of' "$CONTRACT_MD") || {
    echo "codex/workflow-contract.md no longer carries the Step-1 disambiguation rule" >&2
    return 1
  }
  for surface in "$CLAUDE_MD" "$SOURCE_REPO/codex/AGENTS.global.md"; do
    [ "$(grep -cFx -- "$line" "$surface")" = "1" ] || {
      printf '%s must carry this line verbatim exactly once:\n  %s\n' \
        "$(basename "$surface")" "$line" >&2
      printf 'Regenerate the projection, or update both surfaces together.\n' >&2
      return 1
    }
  done
  # The clause that settles "add feature X" — the request shape that broke before.
  case "$line" in
    *'not a new file'*) ;;
    *)
      echo "the rule lost the new-file clause; 'add feature X' becomes ambiguous again" >&2
      return 1
      ;;
  esac
}

@test "the CLAUDE.md autonomous-invocation whitelist includes scope-check" {
  run awk '/^## Skills$/ { inside = 1; next } inside && /^## / { exit } inside { print }' "$CLAUDE_MD"
  [ "$status" -eq 0 ] || return 1
  [[ "$output" == *'`/scope-check`'* ]] || {
    echo "scope-check missing from the ## Skills whitelist; an unlisted skill is not autonomously invocable" >&2
    return 1
  }
}

@test "the Codex core-skills declaration includes scope-check" {
  # The renderer greps this marker region and compares it against
  # profiles.core.skills (compare_skill_declarations). A miss here fails the
  # contract, but assert it directly so the failure names the cause.
  run awk '
    /<!-- mysystem:core-skills:start -->/ { inside = 1; next }
    /<!-- mysystem:core-skills:end -->/ { exit }
    inside { print }
  ' "$CONTRACT_MD"
  [ "$status" -eq 0 ] || return 1
  [[ "$output" == *'`/scope-check`'* ]] || {
    echo "core-skills marker region must list /scope-check" >&2
    return 1
  }
}

@test "scope-check routes ordinary changes to itself and new ideas elsewhere" {
  # The skill's whole reason for existing is the routing table. If that table
  # loses the /office-hours boundary, the mis-wire this ADR fixed comes back
  # wearing a different name.
  grep -qF -- '/office-hours' "$SKILL" || {
    echo "scope-check must say when to route to /office-hours instead" >&2
    return 1
  }
  grep -qF -- '/investigate' "$SKILL" || {
    echo "scope-check must say when to route to /investigate instead" >&2
    return 1
  }
}

@test "the Step-1 measurement script runs and reports buckets" {
  local script="$SOURCE_REPO/scripts/measure-step1.py"
  [ -x "$script" ] || {
    echo "$script must be executable — ADR-0019/0020/0021 kill criteria cite a script that vanished" >&2
    return 1
  }
  # Empty projects dir: must exit 0 and still print its header, not traceback.
  run python3 "$script" --projects "$BATS_TEST_TMPDIR" --json
  [ "$status" -eq 0 ] || {
    echo "measure-step1.py failed on an empty corpus: $output" >&2
    return 1
  }
  run bash -c "python3 '$script' --projects '$BATS_TEST_TMPDIR' --json | jq -e '.scanned == 0 and (.buckets | type == \"array\")'"
  [ "$status" -eq 0 ] || {
    echo "measure-step1.py --json must emit scanned + buckets: $output" >&2
    return 1
  }
}

@test "the measurement script rejects a malformed boundary instead of guessing" {
  run python3 "$SOURCE_REPO/scripts/measure-step1.py" --boundary 'bad=not-a-date' --projects "$BATS_TEST_TMPDIR"
  [ "$status" -eq 2 ] || {
    echo "expected exit 2 on a bad --boundary, got $status: $output" >&2
    return 1
  }
}
