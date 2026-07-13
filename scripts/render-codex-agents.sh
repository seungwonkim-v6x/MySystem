#!/usr/bin/env bash
# Deterministically project marked canonical MySystem instructions into Codex AGENTS files.

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REPO_ROOT=${MYSYSTEM_REPO_ROOT:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
CONTRACT="$REPO_ROOT/codex/parity-contract.json"
MODE=render

render_fail() {
  local id=$1 subject=$2 problem=$3 cause=$4 fix=$5 anchor=$6
  printf 'FAIL %s subject=%s Problem=%s Cause=%s Fix=%s Docs=SETUP.md#%s\n' \
    "$id" "$subject" "$problem" "$cause" "$fix" "$anchor" >&2
}

usage() {
  cat <<'EOF'
Usage: scripts/render-codex-agents.sh [--check|--validate-contract]

Without arguments, atomically refreshes the tracked Codex projections.
--check is read-only and exits 1 when a projection is stale or invalid.
--validate-contract checks only the contract model and canonical hook inventory.
EOF
}

case "${1:-}" in
  "") ;;
  --check) MODE=check ;;
  --validate-contract) MODE=validate-contract ;;
  --help|-h) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
[ "$#" -le 1 ] || { usage >&2; exit 2; }

command -v jq >/dev/null 2>&1 || { render_fail RENDER_JQ_MISSING jq "Renderer dependency is missing" "jq is not on PATH" "Install jq, then rerun setup" parity-contract; exit 1; }
command -v python3 >/dev/null 2>&1 || { render_fail RENDER_PYTHON_MISSING python3 "Renderer dependency is missing" "python3 is not on PATH" "Install Python 3, then rerun setup" parity-contract; exit 1; }
[ -f "$CONTRACT" ] || { render_fail CONTRACT_MISSING "$CONTRACT" "Parity contract is missing" "The checkout is incomplete" "Restore the contract from the reviewed release" parity-contract; exit 1; }
jq -e '.schema_version == 1 and .generator_version == "1"' "$CONTRACT" >/dev/null || {
  render_fail CONTRACT_SCHEMA_UNSUPPORTED "$CONTRACT" "Parity contract schema is unsupported" "The renderer does not recognize this schema/generator" "Use the renderer from the same reviewed release" parity-contract
  exit 1
}

validate_contract_model() {
  jq -e '
    . as $contract |
    .skills as $skills |
    ($skills | map(.name)) as $names |
    (.profiles | keys) as $profile_names |
    ([.profiles | keys[]] | sort) == (["browser","core","figma","material-ui"] | sort) and
    ($names | length) == ($names | unique | length) and
    all($skills[];
      (.mode == "gstack-generated" or .mode == "portable-local" or .mode == "portable-sparse" or .mode == "plugin-profile") and
      (.profiles | type == "array") and
      all(.profiles[]; . as $profile | ($profile_names | index($profile)) != null)) and
    all(.profiles | to_entries[];
      .key as $profile |
      all(.value.skills[]?; . as $name | any($skills[]; .name == $name and (.profiles | index($profile)))) and
      all(.value.plugins[]?; . as $plugin | any($skills[]; .mode == "plugin-profile" and .plugin == $plugin and (.profiles | index($profile))))) and
    (([$skills[] | select(.profiles | index("core")) | select(.mode != "plugin-profile") | .name] | sort) == (.profiles.core.skills | sort)) and
    .projections.global.output == "codex/AGENTS.global.md" and
    .projections.project.output == "codex/AGENTS.project.md" and
    .managed_paths.project_agents == "AGENTS.md" and
    .managed_paths.default_agents == "$HOME/.codex/AGENTS.md" and
    .managed_paths.default_hooks == "$HOME/.codex/hooks" and
    .managed_paths.default_hook_registration == "$HOME/.codex/hooks.json" and
    .managed_paths.user_skills == "$HOME/.agents/skills" and
    (.compatibility.codex_cli_observed | strings | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) and
    (.compatibility.orca_observed | strings | test("^[0-9]+\\.[0-9]+\\.[0-9]+$")) and
    (.budgets.global_max_bytes | type == "number" and . == floor) and
    (.budgets.global_reserve_bytes | type == "number" and . == floor) and
    (.budgets.project_max_bytes | type == "number" and . == floor) and
    .budgets.global_max_bytes > .budgets.global_reserve_bytes and
    .budgets.global_reserve_bytes >= 4096 and
    .budgets.project_max_bytes > 0 and
    ([.hooks[] | [.event,.matcher,.script,.requiredness]] | sort) ==
      ([
        ["PreToolUse","Bash","dangerous-command-blocker.py","safety"],
        ["PreToolUse","Bash","secret-scanner.py","safety"],
        ["PreToolUse","Bash","block-dangerous-git.sh","safety"],
        ["PreToolUse","Write|Edit|MultiEdit","env-file-protection.py","safety"],
        ["PostToolUse","Write|Edit|MultiEdit","render-md.sh","convenience"],
        ["SessionStart","","update-skills.sh","convenience"],
        ["Stop","","preview-stop.sh","convenience"]
      ] | sort) and
    ([.hooks[] | [.event,.matcher,.script]] | length) == ([.hooks[] | [.event,.matcher,.script]] | unique | length) and
    (.approved_migrations.files | type == "object") and
    (.approved_migrations.trees | type == "object") and
    (.approved_migrations.identities | type == "object") and
    ((.approved_migrations.identities | keys | sort) == (((.approved_migrations.files | keys) + (.approved_migrations.trees | keys)) | unique | sort)) and
    all(.approved_migrations.files[]; type == "array" and length > 0 and length == (unique | length) and all(.[]; test("^[0-9a-f]{64}$"))) and
    all(.approved_migrations.trees[]; type == "array" and length > 0 and length == (unique | length) and all(.[]; test("^[0-9a-f]{64}$"))) and
    all(.approved_migrations.identities[]; type == "array" and length > 0 and length == (unique | length) and all(.[]; test("^[0-9a-f]{64}$"))) and
    all($contract.approved_migrations.files | keys[]; . as $kind | $contract.approved_migrations.files[$kind] == $contract.approved_migrations.identities[$kind])
  ' "$CONTRACT" >/dev/null || {
    render_fail CONTRACT_MODEL_INVALID "$CONTRACT" "Parity contract declarations are inconsistent" "Profile, ownership, output, or managed-path closure failed" "Correct the narrow contract and regenerate" parity-contract
    return 1
  }
}

validate_hook_registration() {
  python3 - "$CONTRACT" "$REPO_ROOT/codex/hooks.json" "$HOME/.codex/hooks" <<'PY'
import json
import os
import shlex
import sys

contract_path, hooks_path, hooks_root = sys.argv[1:]
with open(contract_path, encoding="utf-8") as source:
    contract = json.load(source)
with open(hooks_path, encoding="utf-8") as source:
    registration = json.load(source)

actual = []
for event, groups in registration.get("hooks", {}).items():
    if not isinstance(groups, list):
        raise SystemExit("hook event groups must be arrays")
    for group in groups:
        matcher = group.get("matcher", "")
        for hook in group.get("hooks", []):
            if hook.get("type") != "command" or not isinstance(hook.get("command"), str):
                raise SystemExit("hook registration contains a non-command entry")
            argv = [os.path.expanduser(os.path.expandvars(arg)) for arg in shlex.split(hook["command"])]
            actual.append((event, matcher, argv))

expected = []
for hook in contract["hooks"]:
    script = hook["script"]
    path = os.path.join(hooks_root, script)
    if script.endswith(".py"):
        argv = ["python3", path]
    elif script == "update-skills.sh":
        argv = [path]
    else:
        argv = ["bash", path]
    expected.append((hook["event"], hook["matcher"], argv))

normalize = lambda rows: sorted((event, matcher, tuple(argv)) for event, matcher, argv in rows)
if normalize(actual) != normalize(expected):
    raise SystemExit("canonical hook registration does not match the contract")
PY
}

if locale -a 2>/dev/null | grep -Eiq '^en_US\.UTF-?8$'; then
  export LC_ALL=en_US.UTF-8
elif locale -a 2>/dev/null | grep -Eiq '^C\.UTF-?8$'; then
  export LC_ALL=C.UTF-8
else
  export LC_ALL=C
fi

hash_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

validate_source() {
  local source=$1
  [ -f "$source" ] || { render_fail SOURCE_MISSING "$source" "Canonical instruction source is missing" "A declared projection source is absent" "Restore the source and regenerate" generated-projections; return 1; }
  if LC_ALL=C grep -q $'\r' "$source"; then
    render_fail SOURCE_CRLF "$source" "Canonical source uses CRLF" "Deterministic projections require LF" "Convert the source to LF and regenerate" generated-projections
    return 1
  fi
  if [ "$(tail -c 1 "$source" | od -An -tuC | tr -d ' ')" != "10" ]; then
    render_fail SOURCE_FINAL_NEWLINE "$source" "Canonical source lacks a final newline" "The projection byte contract requires one final newline" "Add the newline and regenerate" generated-projections
    return 1
  fi
  if grep -Eq '^@(import|include)[[:space:]]|^@[^[:space:]]+\.md[[:space:]]*$' "$source"; then
    render_fail SOURCE_INCLUDE_UNCLASSIFIED "$source" "Canonical source contains an unclassified include" "The renderer cannot prove transitive instruction closure" "Classify or remove the include" generated-projections
    return 1
  fi
}

extract_section() {
  local source=$1 id=$2 start end starts ends
  start="<!-- mysystem:section $id:start -->"
  end="<!-- mysystem:section $id:end -->"
  starts=$(grep -Fxc "$start" "$source" || true)
  ends=$(grep -Fxc "$end" "$source" || true)
  if [ "$starts" -ne 1 ] || [ "$ends" -ne 1 ]; then
    render_fail SECTION_MARKER_COUNT "$source#$id" "Projection marker count is invalid" "Expected one start and end marker; found start=$starts end=$ends" "Repair the canonical markers and regenerate" generated-projections
    return 1
  fi
  if ! awk -v start="$start" -v end="$end" '
    $0 == start { if (seen_start) exit 41; seen_start=1; active=1; next }
    $0 == end { if (!active) exit 42; active=0; seen_end=1; next }
    active && $0 !~ /^<!-- mysystem:/ { print; if ($0 !~ /^[[:space:]]*$/) has_content=1 }
    END { if (!seen_start || !seen_end || active) exit 43; if (!has_content) exit 44 }
  ' "$source"; then
    render_fail SECTION_EXTRACTION_INVALID "$source#$id" "Projection section is reversed, malformed, or empty" "The marked canonical block cannot be extracted safely" "Repair the section boundaries and content" generated-projections
    return 1
  fi
}

declared_skills() {
  local marker=$1 start end
  start="<!-- mysystem:$marker:start -->"
  end="<!-- mysystem:$marker:end -->"
  awk -v start="$start" -v end="$end" '
    $0 == start { active=1; next }
    $0 == end { active=0; next }
    active { print }
  ' "$REPO_ROOT/CLAUDE.md" \
    | grep -oE '`/[A-Za-z0-9][A-Za-z0-9-]*`' \
    | tr -d '`/' \
    | LC_ALL=C sort -u
}

compare_skill_declarations() {
  local declared expected
  declared=$(mktemp "${TMPDIR:-/tmp}/mysystem-declared.XXXXXX")
  expected=$(mktemp "${TMPDIR:-/tmp}/mysystem-expected.XXXXXX")
  trap 'rm -f "$declared" "$expected" ${GLOBAL_TMP:-} ${PROJECT_TMP:-}' EXIT HUP INT TERM

  declared_skills core-skills > "$declared"
  jq -r '.profiles.core.skills[]' "$CONTRACT" | LC_ALL=C sort -u > "$expected"
  if ! cmp -s "$declared" "$expected"; then
    render_fail SKILL_DECLARATION_MISMATCH core "Core skill declarations differ" "Canonical prose and parity contract are out of sync" "Update both declarations together" parity-contract
    diff -u "$expected" "$declared" >&2 || true
    return 1
  fi

  declared_skills conditional-skills > "$declared"
  jq -r '.skills[] | select(.mode == "plugin-profile") | .name' "$CONTRACT" | LC_ALL=C sort -u > "$expected"
  if ! cmp -s "$declared" "$expected"; then
    render_fail SKILL_DECLARATION_MISMATCH conditional "Conditional skill declarations differ" "Canonical prose and parity contract are out of sync" "Update both declarations together" parity-contract
    diff -u "$expected" "$declared" >&2 || true
    return 1
  fi
  rm -f "$declared" "$expected"
  trap 'rm -f ${GLOBAL_TMP:-} ${PROJECT_TMP:-}' EXIT HUP INT TERM
}

validate_contract_sources() {
  local rel source
  jq -r '[.projections.global.header] + [.projections.global.sections[].source] + [.projections.project.sections[].source] | .[]' "$CONTRACT" \
    | while IFS= read -r rel; do
        case "$rel" in
          /*|*..*) render_fail SOURCE_PATH_UNSAFE "$rel" "Projection source path is unsafe" "Absolute or parent-traversal paths are forbidden" "Keep sources inside the repository" parity-contract; exit 1 ;;
        esac
        source="$REPO_ROOT/$rel"
        validate_source "$source"
      done

  for source in "$REPO_ROOT"/rules/*.md; do
    rel=${source#"$REPO_ROOT/"}
    jq -e --arg rel "$rel" '
      any(.projections.global.sections[]; .source == $rel) or
      any(.projections.project.sections[]; .source == $rel)
    ' "$CONTRACT" >/dev/null || {
      render_fail SOURCE_CLOSURE_UNCLASSIFIED "$rel" "Canonical rule is unclassified" "The rule is absent from global and project projections" "Classify it explicitly in the contract" generated-projections
      return 1
    }
  done
}

render_projection() {
  local projection=$1 destination=$2 header rel id source hash
  {
    printf '<!-- GENERATED by scripts/render-codex-agents.sh; DO NOT EDIT.\n'
    printf 'schema=%s generator=%s projection=%s\n' \
      "$(jq -r '.schema_version' "$CONTRACT")" \
      "$(jq -r '.generator_version' "$CONTRACT")" "$projection"
    jq -r --arg p "$projection" '
      ([.projections[$p].header] + [.projections[$p].sections[].source])[] | select(. != null)
    ' "$CONTRACT" | while IFS= read -r rel; do
      hash=$(hash_file "$REPO_ROOT/$rel")
      printf 'source-sha256 %s %s\n' "$hash" "$rel"
    done
    printf -- '-->\n\n'

    header=$(jq -r --arg p "$projection" '.projections[$p].header // empty' "$CONTRACT")
    if [ -n "$header" ]; then
      cat "$REPO_ROOT/$header"
      printf '\n'
    fi

    jq -c --arg p "$projection" '.projections[$p].sections[]' "$CONTRACT" \
      | while IFS= read -r section; do
          rel=$(printf '%s' "$section" | jq -r '.source')
          id=$(printf '%s' "$section" | jq -r '.id')
          source="$REPO_ROOT/$rel"
          extract_section "$source" "$id"
          printf '\n'
        done
  } > "$destination"
}

validate_contract_model
if ! validate_hook_registration; then
  render_fail CONTRACT_HOOK_REGISTRATION_INVALID "$REPO_ROOT/codex/hooks.json" "Canonical hook registration differs from the parity contract" "A hook tuple, matcher, type, executable, or argv is missing or unexpected" "Restore the reviewed hook contract and registration together" hook-registration
  exit 1
fi
if [ "$MODE" = validate-contract ]; then
  printf 'PASS CONTRACT_MODEL_VALID\n'
  exit 0
fi
validate_contract_sources
compare_skill_declarations

GLOBAL_OUTPUT=$(jq -r '.projections.global.output' "$CONTRACT")
PROJECT_OUTPUT=$(jq -r '.projections.project.output' "$CONTRACT")
GLOBAL_TMP=$(mktemp "$REPO_ROOT/codex/.AGENTS.global.XXXXXX")
PROJECT_TMP=$(mktemp "$REPO_ROOT/codex/.AGENTS.project.XXXXXX")
trap 'rm -f "$GLOBAL_TMP" "$PROJECT_TMP"' EXIT HUP INT TERM

render_projection global "$GLOBAL_TMP"
render_projection project "$PROJECT_TMP"

GLOBAL_BYTES=$(wc -c < "$GLOBAL_TMP" | tr -d ' ')
PROJECT_BYTES=$(wc -c < "$PROJECT_TMP" | tr -d ' ')
GLOBAL_MAX=$(jq -r '.budgets.global_max_bytes' "$CONTRACT")
GLOBAL_RESERVE=$(jq -r '.budgets.global_reserve_bytes' "$CONTRACT")
PROJECT_MAX=$(jq -r '.budgets.project_max_bytes' "$CONTRACT")
GLOBAL_PAYLOAD_MAX=$((GLOBAL_MAX - GLOBAL_RESERVE))

if [ "$GLOBAL_BYTES" -gt "$GLOBAL_PAYLOAD_MAX" ]; then
  render_fail GLOBAL_BUDGET_EXCEEDED "$GLOBAL_OUTPUT" "Global projection exceeds its payload budget" "bytes=$GLOBAL_BYTES limit=$GLOBAL_PAYLOAD_MAX reserve=$GLOBAL_RESERVE" "Reduce conditional weight without dropping invariants" generated-projections
  exit 1
fi
if [ "$PROJECT_BYTES" -gt "$PROJECT_MAX" ]; then
  render_fail PROJECT_BUDGET_EXCEEDED "$PROJECT_OUTPUT" "Project projection exceeds its document budget" "bytes=$PROJECT_BYTES limit=$PROJECT_MAX" "Reduce project-only instruction weight" generated-projections
  exit 1
fi

if [ "$MODE" = check ]; then
  stale=0
  cmp -s "$GLOBAL_TMP" "$REPO_ROOT/$GLOBAL_OUTPUT" || { render_fail STALE_PROJECTION "$GLOBAL_OUTPUT" "Generated projection is stale" "Canonical source hashes or bytes changed" "Run ./setup.sh --parity-only" generated-projections; stale=1; }
  cmp -s "$PROJECT_TMP" "$REPO_ROOT/$PROJECT_OUTPUT" || { render_fail STALE_PROJECTION "$PROJECT_OUTPUT" "Generated projection is stale" "Canonical source hashes or bytes changed" "Run ./setup.sh --parity-only" generated-projections; stale=1; }
  [ "$stale" -eq 0 ] || exit 1
  printf 'PASS PROJECTIONS_CURRENT global_bytes=%s global_headroom=%s project_bytes=%s\n' \
    "$GLOBAL_BYTES" "$((GLOBAL_MAX - GLOBAL_BYTES))" "$PROJECT_BYTES"
  exit 0
fi

python3 - "$GLOBAL_TMP" "$REPO_ROOT/$GLOBAL_OUTPUT" "$PROJECT_TMP" "$REPO_ROOT/$PROJECT_OUTPUT" <<'PY'
import os
import sys

for source, destination in ((sys.argv[1], sys.argv[2]), (sys.argv[3], sys.argv[4])):
    os.chmod(source, 0o644)
    os.replace(source, destination)
PY
trap - EXIT HUP INT TERM
printf 'Rendered Codex projections: global_bytes=%s global_headroom=%s project_bytes=%s\n' \
  "$GLOBAL_BYTES" "$((GLOBAL_MAX - GLOBAL_BYTES))" "$PROJECT_BYTES"
