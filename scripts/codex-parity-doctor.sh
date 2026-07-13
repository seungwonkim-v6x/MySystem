#!/usr/bin/env bash
# Read-only structural diagnostics for MySystem Codex behavioral parity.

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REPO_ROOT=${MYSYSTEM_REPO_ROOT:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
CONTRACT="$REPO_ROOT/codex/parity-contract.json"
RENDERER="$REPO_ROOT/scripts/render-codex-agents.sh"
# shellcheck source=scripts/codex-parity-lib.sh
. "$REPO_ROOT/scripts/codex-parity-lib.sh"

OUTPUT=jsonl
PROFILE=core
VERBOSE=0
DOCTOR_STARTED=$SECONDS
HOMES_FILE=$(mktemp "${TMPDIR:-/tmp}/mysystem-doctor-homes.XXXXXX")
EXPLICIT_HOMES_FILE=$(mktemp "${TMPDIR:-/tmp}/mysystem-doctor-explicit.XXXXXX")
CHECKS_FILE=$(mktemp "${TMPDIR:-/tmp}/mysystem-doctor-checks.XXXXXX")
PROBE_FILE=$(mktemp "${TMPDIR:-/tmp}/mysystem-doctor-probe.XXXXXX")
trap 'rm -f "$HOMES_FILE" "$EXPLICIT_HOMES_FILE" "$CHECKS_FILE" "$PROBE_FILE"' EXIT HUP INT TERM
FAIL_COUNT=0
WARN_COUNT=0
PASS_COUNT=0

usage() {
  cat <<'EOF'
Usage: scripts/codex-parity-doctor.sh [options]

Options:
  --require PROFILE    core, material-ui, browser, or figma
  --codex-home PATH    inspect an additional existing Codex home (repeatable)
  --json               emit one JSON document
  --verbose            run optional structural CLI inventories
  --help               show this help
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --require)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      PROFILE=$2
      shift 2
      ;;
    --codex-home)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      printf '%s\n' "$2" >> "$EXPLICIT_HOMES_FILE"
      shift 2
      ;;
    --json) OUTPUT=json; shift ;;
    --verbose) VERBOSE=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

case "$PROFILE" in core|material-ui|browser|figma) ;; *) usage >&2; exit 2 ;; esac
command -v jq >/dev/null 2>&1 || { echo "FAIL DOCTOR_JQ_MISSING: jq is required" >&2; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "FAIL DOCTOR_PYTHON_MISSING: python3 is required" >&2; exit 1; }

emit() {
  local status=$1 id=$2 subject=$3 problem=$4 cause=$5 fix=$6 anchor=$7
  case "$status" in
    PASS) PASS_COUNT=$((PASS_COUNT + 1)) ;;
    WARN) WARN_COUNT=$((WARN_COUNT + 1)) ;;
    FAIL) FAIL_COUNT=$((FAIL_COUNT + 1)) ;;
  esac
  if [ "$OUTPUT" = json ]; then
    jq -nc \
      --arg status "$status" --arg check_id "$id" --arg subject "$subject" \
      --arg problem "$problem" --arg cause "$cause" --arg fix "$fix" --arg docs_anchor "$anchor" \
      '{status:$status,check_id:$check_id,subject:$subject,problem:$problem,cause:$cause,fix:$fix,docs:("SETUP.md#"+$docs_anchor)}' \
      >> "$CHECKS_FILE"
  fi
  if [ "$OUTPUT" = jsonl ] && { [ "$status" != PASS ] || [ "$VERBOSE" = 1 ]; }; then
    printf '%s %s subject=%s Problem=%s Cause=%s Fix=%s Docs=SETUP.md#%s\n' \
      "$status" "$id" "$subject" "$problem" "$cause" "$fix" "$anchor"
  fi
}

finish_doctor() {
  local elapsed=$((SECONDS - DOCTOR_STARTED)) exit_code=0
  [ "$FAIL_COUNT" -eq 0 ] || exit_code=1
  if [ "$OUTPUT" = json ]; then
    jq -s \
      --arg profile "$PROFILE" \
      --argjson elapsed "$elapsed" \
      --argjson pass "$PASS_COUNT" --argjson warn "$WARN_COUNT" --argjson fail "$FAIL_COUNT" \
      '{profile:$profile,checks:.,summary:{pass:$pass,warn:$warn,fail:$fail,exit_code:(if $fail > 0 then 1 else 0 end),elapsed_seconds:$elapsed}}' \
      "$CHECKS_FILE"
  else
    printf 'SUMMARY profile=%s PASS=%s WARN=%s FAIL=%s exit=%s elapsed_seconds=%s\n' \
      "$PROFILE" "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT" "$exit_code" "$elapsed"
  fi
  return "$exit_code"
}

add_home() {
  local path=$1 kind=$2 normalized existing
  if ! parity_validate_home "$path" "$REPO_ROOT" 0 2>/dev/null; then
    emit FAIL CODEX_HOME_UNSAFE "$path" \
      "Codex home is not safe to inspect" \
      "The path is missing, protected, symlinked, unowned, or world-writable" \
      "Pass an existing user-owned Codex home" codex-home-unsafe
    return 0
  fi
  normalized=$(python3 - "$path" <<'PY'
import os
import sys
print(os.path.normpath(os.path.abspath(sys.argv[1])))
PY
)
  existing=$(awk -F '\t' -v path="$normalized" '$1 == path { print $1; exit }' "$HOMES_FILE")
  [ -n "$existing" ] || printf '%s\t%s\n' "$normalized" "$kind" >> "$HOMES_FILE"
}

discover_homes() {
  local default_home orca_home explicit
  default_home="$HOME/.codex"
  if [ -d "$default_home" ]; then
    add_home "$default_home" default
  else
    emit FAIL DEFAULT_CODEX_HOME_MISSING "$default_home" \
      "Default Codex home is absent" "Parity links have not been installed" \
      "Run ./setup.sh --parity-only" default-codex-home-missing
  fi
  if [ -n "${CODEX_HOME:-}" ] && [ "$CODEX_HOME" != "$default_home" ]; then
    add_home "$CODEX_HOME" alternate
  fi
  orca_home="$HOME/Library/Application Support/orca/codex-runtime-home/home"
  if [ -d "$(dirname "$orca_home")" ] && [ -d "$orca_home" ]; then
    add_home "$orca_home" orca
  fi
  while IFS= read -r explicit; do
    [ -n "$explicit" ] || continue
    add_home "$explicit" alternate
  done < "$EXPLICIT_HOMES_FILE"
}

check_link() {
  local id=$1 destination=$2 target=$3 required=${4:-1}
  if parity_link_matches "$destination" "$target"; then
    emit PASS "$id" "$destination" "Managed link is current" "Destination resolves to the canonical target" "No action required" managed-links
  elif [ "$required" = 1 ]; then
    emit FAIL "$id" "$destination" "Managed link is missing or points elsewhere" "Parity installation is stale or incomplete" "Run ./setup.sh --parity-only" managed-links
  else
    emit WARN "$id" "$destination" "Optional managed link is missing or stale" "This host does not expose the optional surface" "Run the matching profile setup before use" managed-links
  fi
}

registration_has() {
  local file=$1 event=$2 matcher=$3 script=$4
  python3 - "$file" "$event" "$matcher" "$script" "$HOME/.codex/hooks" <<'PY'
import json
import os
import shlex
import sys

path, event, required_matcher, script, hooks_root = sys.argv[1:]
with open(path, encoding="utf-8") as source:
    payload = json.load(source)
required = {token for token in required_matcher.split("|") if token}
expected_path = os.path.join(hooks_root, script)
if script.endswith(".py"):
    expected = ["python3", expected_path]
elif script == "update-skills.sh":
    expected = [expected_path]
else:
    expected = ["bash", expected_path]

for group in payload.get("hooks", {}).get(event, []):
    actual = {token for token in group.get("matcher", "").split("|") if token}
    if not required.issubset(actual):
        continue
    for hook in group.get("hooks", []):
        if hook.get("type") != "command" or not isinstance(hook.get("command"), str):
            continue
        try:
            argv = shlex.split(hook["command"])
        except ValueError:
            continue
        argv = [os.path.expanduser(os.path.expandvars(arg)) for arg in argv]
        if argv == expected:
            raise SystemExit(0)
raise SystemExit(1)
PY
}

check_registration() {
  local file=$1 host_kind=$2 event matcher script requiredness requiredness_id missing_safety=0
  if [ ! -f "$file" ] || ! jq -e '.hooks | type == "object"' "$file" >/dev/null 2>&1; then
    if [ "$host_kind" = default ]; then
      emit FAIL HOOK_REGISTRATION_MALFORMED "$file" "Hook registration is absent or malformed" "Codex cannot dispatch the canonical hook inventory" "Run ./setup.sh --parity-only" hook-registration
    elif [ "$host_kind" = orca ]; then
      emit FAIL HOST_HOOKS_UNVERIFIABLE "$file" "Orca hook registration cannot be inspected" "The supported Orca host has no valid merged hook inventory" "Start a new Orca Codex session, then rerun doctor" host-hooks
    else
      emit WARN HOST_HOOKS_UNVERIFIABLE "$file" "Host hook registration cannot be inspected" "The alternate host may not support merged hooks" "Check the host hook UI before tool use" host-hooks
    fi
    return
  fi

  while IFS=$'\x1f' read -r event matcher script requiredness; do
    if registration_has "$file" "$event" "$matcher" "$script"; then
      requiredness_id=$(printf '%s' "$requiredness" | tr '[:lower:]' '[:upper:]')
      emit PASS "HOOK_${requiredness_id}_PRESENT" "$file:$event:$script" "Hook tuple is registered" "Registration contains the canonical semantic tuple" "No action required" hook-registration
    elif [ "$requiredness" = safety ]; then
      missing_safety=1
      if [ "$host_kind" = default ]; then
        emit FAIL HOOK_SAFETY_MISSING "$file:$event:$script" "Required safety hook is missing" "Default Codex registration is stale" "Run ./setup.sh --parity-only" hook-safety-missing
      else
        emit FAIL HOST_REFRESH_REQUIRED "$file:$event:$script" "Required safety hook is missing from the host merge" "The host-owned registration has not refreshed" "Start a new Codex session from Orca, then rerun doctor" host-refresh-required
      fi
    else
      emit WARN HOST_CONVENIENCE_DEGRADED "$file:$event:$script" "Convenience hook is missing" "The host may not support or has not merged this event" "Refresh the host or continue without the convenience behavior" host-convenience-degraded
    fi
  done < <(jq -r '.hooks[] | [.event,.matcher,.script,.requiredness] | join("\u001f")' "$CONTRACT")
  : "$missing_safety"
}

check_skills() {
  local name mode source path user_skills
  user_skills=$(parity_managed_path "$CONTRACT" user_skills "$REPO_ROOT")
  while IFS=$'\t' read -r name mode source; do
    path="$user_skills/$name"
    if [ ! -s "$path/SKILL.md" ]; then
      emit FAIL CORE_SKILL_MISSING "$path" "Required workflow skill is missing" "The core profile is incomplete" "Run ./setup.sh, then rerun doctor" core-skill-missing
      continue
    fi
    case "$mode" in
      portable-local|portable-sparse)
        if [ -L "$path" ] && [ "$(readlink "$path")" = "$REPO_ROOT/$source" ]; then
          emit PASS PORTABLE_SKILL_CURRENT "$path" "Portable skill is linked to its canonical source" "The complete skill directory resolves into MySystem" "No action required" portable-skills
        else
          emit FAIL PORTABLE_SKILL_DRIFT "$path" "Portable skill is not linked to its canonical source" "An independent copy can drift from Claude behavior" "Run ./setup.sh --parity-only" portable-skills
        fi
        ;;
      gstack-generated)
        if [ -L "$path/SKILL.md" ] && [ "$(readlink "$path/SKILL.md")" = "$user_skills/gstack/$name/SKILL.md" ]; then
          emit PASS GSTACK_SKILL_PRESENT "$path" "Generated Codex skill is present" "The skill resolves to gstack's provider-native directory" "Refresh with ./setup.sh when gstack changes" gstack-skills
        else
          emit FAIL GSTACK_SKILL_UNOWNED "$path" "Generated Codex skill ownership cannot be proven" "SKILL.md does not resolve to gstack's generated source" "Run full ./setup.sh, then rerun doctor" gstack-skills
        fi
        ;;
    esac
  done < <(jq -r '.skills[] | select(.profiles | index("core")) | select(.mode != "plugin-profile") | [.name,.mode,(.source // "")] | @tsv' "$CONTRACT")
}

check_hook_sources() {
  local script requiredness path
  while IFS=$'\x1f' read -r script requiredness; do
    path="$REPO_ROOT/hooks/$script"
    if [ -x "$path" ]; then
      emit PASS HOOK_SOURCE_EXECUTABLE "$path" "Canonical hook source is executable" "Default and host registrations resolve through the shared source" "No action required" hook-registration
    elif [ "$requiredness" = safety ]; then
      emit FAIL HOOK_SAFETY_SOURCE_INVALID "$path" "Required safety hook source is missing or not executable" "The registered command cannot enforce the safety contract" "Restore the executable bit from the reviewed release" hook-safety-missing
    else
      emit WARN HOOK_CONVENIENCE_SOURCE_INVALID "$path" "Convenience hook source is missing or not executable" "The optional behavior cannot dispatch" "Restore the executable bit or continue without the convenience behavior" host-convenience-degraded
    fi
  done < <(jq -r '.hooks[] | [.script,.requiredness] | join("\u001f")' "$CONTRACT")
}

probe_plugin() {
  local home=$1 plugin=$2 required=$3
  if ! command -v codex >/dev/null 2>&1 || ! CODEX_HOME="$home" codex plugin list --json > "$PROBE_FILE" 2>/dev/null || ! jq -e '.installed | type == "array"' "$PROBE_FILE" >/dev/null 2>&1; then
    if [ "$required" = 1 ]; then
      emit FAIL UNSUPPORTED_PLUGIN_PROBE "$plugin" "Plugin inventory is unavailable" "Installed Codex does not expose a compatible JSON probe" "Upgrade Codex or inspect /plugins before continuing" unsupported-probe
    else
      emit WARN UNSUPPORTED_PLUGIN_PROBE "$plugin" "Plugin inventory is unavailable" "Optional structure cannot be verified" "Use --require with a supported Codex version before the workflow" unsupported-probe
    fi
    return
  fi
  if jq -e --arg plugin "$plugin" 'any(.installed[]; .name == $plugin and .installed == true and .enabled == true)' "$PROBE_FILE" >/dev/null; then
    emit PASS PROFILE_PLUGIN_PRESENT "$plugin" "Required plugin is installed and enabled" "Codex JSON inventory confirms structural registration" "Perform the live tool check in the current session" capability-profiles
  elif [ "$required" = 1 ]; then
    emit FAIL PROFILE_PLUGIN_MISSING "$plugin" "Required plugin is missing or disabled" "The selected capability profile is incomplete" "Install and enable the plugin, start a new session, then rerun doctor" capability-profiles
  else
    emit WARN OPTIONAL_PLUGIN_MISSING "$plugin" "Optional plugin is missing or disabled" "The core workflow does not require this plugin" "Install it before selecting its conditional profile" capability-profiles
  fi
}

probe_mcp() {
  local home=$1 mcp=$2 required=$3 fallback=${4:-}
  local orca_home="$HOME/Library/Application Support/orca/codex-runtime-home/home"
  if ! command -v codex >/dev/null 2>&1 || ! CODEX_HOME="$home" codex mcp list --json > "$PROBE_FILE" 2>/dev/null || ! jq -e 'type == "array"' "$PROBE_FILE" >/dev/null 2>&1; then
    if [ "$required" = 1 ] && [ "$home" = "$orca_home" ] && [ -n "$fallback" ] && command -v "$fallback" >/dev/null 2>&1; then
      emit WARN PROFILE_MCP_CLI_FALLBACK "$mcp@$home" "Orca will use the documented CLI fallback" "The host-owned MCP inventory does not retain custom Aside registration" "Perform the non-mutating CLI live check before browser use" capability-profiles
    elif [ "$required" = 1 ]; then
      emit FAIL UNSUPPORTED_MCP_PROBE "$mcp" "MCP inventory is unavailable" "Installed Codex does not expose a compatible JSON probe" "Upgrade Codex or inspect /mcp before continuing" unsupported-probe
    else
      emit WARN UNSUPPORTED_MCP_PROBE "$mcp" "MCP inventory is unavailable" "Optional structure cannot be verified" "Use --require with a supported Codex version before the workflow" unsupported-probe
    fi
    return
  fi
  if jq -e --arg mcp "$mcp" 'any(.[]; .name == $mcp and .enabled == true)' "$PROBE_FILE" >/dev/null; then
    emit PASS PROFILE_MCP_CONFIGURED "$mcp" "Required MCP is configured and enabled" "Codex JSON inventory confirms structural registration" "Perform the non-mutating live tool check in the current session" capability-profiles
    emit WARN LIVE_AUTH_UNVERIFIABLE "$mcp" "Live MCP execution is not proven" "Structural inventory cannot prove current-session auth or tool execution" "Call one documented non-mutating tool operation before relying on it" live-capability-check
  elif [ "$required" = 1 ] && [ "$home" = "$orca_home" ] && [ -n "$fallback" ] && command -v "$fallback" >/dev/null 2>&1; then
    emit WARN PROFILE_MCP_CLI_FALLBACK "$mcp@$home" "Orca will use the documented CLI fallback" "The host-owned MCP inventory does not retain custom Aside registration" "Perform the non-mutating CLI live check before browser use" capability-profiles
  elif [ "$required" = 1 ]; then
    emit FAIL PROFILE_MCP_MISSING "$mcp" "Required MCP is missing or disabled" "The selected capability profile is incomplete" "Register and authenticate the MCP, start a new session, then rerun doctor" capability-profiles
  else
    emit WARN OPTIONAL_MCP_MISSING "$mcp" "Optional MCP is missing or disabled" "The core workflow has a documented fallback" "Register it before selecting its conditional profile" capability-profiles
  fi
}

check_runtime_compatibility() {
  local observed actual raw
  observed=$(jq -r '.compatibility.codex_cli_observed' "$CONTRACT")
  if ! command -v codex >/dev/null 2>&1; then
    emit WARN CODEX_RUNTIME_UNAVAILABLE codex "Codex runtime version is unavailable" "The binary is not on PATH" "Install Codex before live parity verification" unsupported-probe
    return
  fi
  raw=$(codex --version 2>/dev/null || true)
  actual=$(printf '%s' "$raw" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)
  if [ -z "$actual" ]; then
    emit WARN CODEX_VERSION_UNPARSEABLE "$raw" "Codex runtime version could not be parsed" "The installed binary returned an unknown version format" "Verify compatibility manually before release" unsupported-probe
  elif [ "$actual" = "$observed" ]; then
    emit PASS CODEX_VERSION_OBSERVED "$actual" "Codex runtime matches the observed baseline" "The structural contract was verified against this version" "No action required" parity-contract
  else
    emit WARN CODEX_VERSION_UNTESTED "$actual" "Codex runtime is outside the observed baseline" "The contract was last verified with $observed" "Run the bounded live conformance suite before claiming parity" unsupported-probe
  fi
}

check_orca_compatibility() {
  local observed actual= plist= candidate
  local orca_home="$HOME/Library/Application Support/orca/codex-runtime-home/home"
  observed=$(jq -r '.compatibility.orca_observed' "$CONTRACT")
  for candidate in "$HOME/Applications/Orca.app/Contents/Info.plist" "/Applications/Orca.app/Contents/Info.plist"; do
    if [ -f "$candidate" ]; then
      plist=$candidate
      break
    fi
  done
  if [ -z "$plist" ]; then
    if [ -d "$orca_home" ]; then
      emit WARN ORCA_VERSION_UNAVAILABLE "$orca_home" "Orca runtime is present but its app version is unavailable" "No readable Orca Info.plist was found" "Verify the host version manually before release" unsupported-probe
    fi
    return
  fi
  actual=$(python3 - "$plist" <<'PY'
import plistlib
import sys

try:
    with open(sys.argv[1], "rb") as source:
        value = plistlib.load(source).get("CFBundleShortVersionString", "")
except (OSError, plistlib.InvalidFileException):
    value = ""
print(value if isinstance(value, str) else "")
PY
)
  if [ -z "$actual" ]; then
    emit WARN ORCA_VERSION_UNPARSEABLE "$plist" "Orca app version could not be parsed" "The app metadata has no valid short version" "Verify compatibility manually before release" unsupported-probe
  elif [ "$actual" = "$observed" ]; then
    emit PASS ORCA_VERSION_OBSERVED "$actual" "Orca runtime matches the observed baseline" "The host integration was verified against this version" "No action required" parity-contract
  else
    emit WARN ORCA_VERSION_UNTESTED "$actual" "Orca runtime is outside the observed baseline" "The contract was last verified with $observed" "Run the bounded live conformance suite before claiming parity" unsupported-probe
  fi
}

probe_profile() {
  local home=$1 profile=$2 required=$3 plugin mcp fallback
  while IFS= read -r plugin; do
    [ -n "$plugin" ] || continue
    probe_plugin "$home" "$plugin" "$required"
  done < <(jq -r --arg profile "$profile" '.profiles[$profile].plugins[]?' "$CONTRACT")
  while IFS= read -r mcp; do
    [ -n "$mcp" ] || continue
    fallback=$(jq -r --arg profile "$profile" --arg mcp "$mcp" '.profiles[$profile].orca_cli_fallbacks[$mcp] // empty' "$CONTRACT")
    probe_mcp "$home" "$mcp" "$required" "$fallback"
  done < <(jq -r --arg profile "$profile" '.profiles[$profile].mcps[]?' "$CONTRACT")
}

if ! jq -e '.schema_version == 1' "$CONTRACT" >/dev/null 2>&1; then
  emit FAIL CONTRACT_INVALID "$CONTRACT" "Parity contract is absent or unsupported" "The checkout is incomplete or uses an unknown schema" "Restore codex/parity-contract.json from the release" contract-invalid
  if finish_doctor; then status=0; else status=$?; fi
  exit "$status"
fi
if contract_output=$("$RENDERER" --validate-contract 2>&1); then
  emit PASS CONTRACT_VALID "$CONTRACT" "Parity contract model is supported" "$contract_output" "No action required" parity-contract
else
  emit FAIL CONTRACT_INVALID "$CONTRACT" "Parity contract model is malformed or incomplete" "$contract_output" "Restore the contract and canonical hook registration from the reviewed release" contract-invalid
  if finish_doctor; then status=0; else status=$?; fi
  exit "$status"
fi

if render_output=$("$RENDERER" --check 2>&1); then
  emit PASS PROJECTIONS_CURRENT "$REPO_ROOT/codex" "Generated projections match canonical sources" "$render_output" "No action required" generated-projections
else
  emit FAIL STALE_PROJECTION "$REPO_ROOT/codex" "Generated projection is stale or invalid" "$render_output" "Run ./setup.sh --parity-only" generated-projections
fi

discover_homes
check_runtime_compatibility
check_orca_compatibility
PROJECT_AGENTS=$(parity_managed_path "$CONTRACT" project_agents "$REPO_ROOT")
DEFAULT_AGENTS=$(parity_managed_path "$CONTRACT" default_agents "$REPO_ROOT")
DEFAULT_HOOKS=$(parity_managed_path "$CONTRACT" default_hooks "$REPO_ROOT")
DEFAULT_HOOK_REGISTRATION=$(parity_managed_path "$CONTRACT" default_hook_registration "$REPO_ROOT")
check_link PROJECT_AGENTS_LINK "$PROJECT_AGENTS" "$REPO_ROOT/codex/AGENTS.project.md"

while IFS=$'\t' read -r home kind; do
  [ -n "$home" ] || continue
  check_link GLOBAL_AGENTS_LINK "$home/AGENTS.md" "$REPO_ROOT/codex/AGENTS.global.md"
done < "$HOMES_FILE"

check_link DEFAULT_HOOKS_LINK "$DEFAULT_HOOKS" "$REPO_ROOT/hooks"
check_link DEFAULT_HOOK_REGISTRATION_LINK "$DEFAULT_HOOK_REGISTRATION" "$REPO_ROOT/codex/hooks.json"
check_skills
check_hook_sources
check_registration "$DEFAULT_HOOK_REGISTRATION" default

while IFS=$'\t' read -r home kind; do
  [ "$kind" = default ] && continue
  check_registration "$home/hooks.json" "$kind"
done < "$HOMES_FILE"

PROBE_HOME=${CODEX_HOME:-$HOME/.codex}
if [ -z "${CODEX_HOME:-}" ] && [ "$(wc -l < "$EXPLICIT_HOMES_FILE" | tr -d ' ')" -eq 1 ]; then
  PROBE_HOME=$(sed -n '1p' "$EXPLICIT_HOMES_FILE")
fi
case "$PROFILE" in
  core)
    if [ "$VERBOSE" = 1 ]; then
      for conditional_profile in material-ui browser figma; do
        probe_profile "$PROBE_HOME" "$conditional_profile" 0
      done
    else
      emit WARN CONDITIONAL_PROFILES_NOT_PROBED "material-ui,browser,figma" "Conditional capabilities were not probed" "Core mode intentionally avoids slow plugin and MCP inventories" "Run doctor --require PROFILE immediately before that workflow" conditional-profiles
    fi
    ;;
  material-ui|browser|figma) probe_profile "$PROBE_HOME" "$PROFILE" 1 ;;
esac

finish_doctor
