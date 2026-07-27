#!/usr/bin/env bash
# Shared test helper: remove Orca's injected hooks from a copied codex/hooks.json.
#
# Why this exists. Orca (a third-party agent orchestrator) continuously reinjects
# its telemetry hooks into the live `codex/hooks.json` and drops a `.bak` beside
# it. Tests that copy the working-tree `codex/` directory dragged that pollution
# into their fixtures, the renderer failed CONTRACT_HOOK_REGISTRATION_INVALID, and
# 22 parity tests went red for reasons unrelated to the code under test.
#
# Only Orca's entries are removed, identified by the `.orca/agent-hooks` path in
# their command. Every other working-tree edit is preserved on purpose, so a real
# change to the hook registration still fails the contract tests as it should.

# strip_orca_hooks <hooks.json path>
# No-op when the file is absent or carries no Orca entries. Fails loudly when the
# file IS polluted but jq is unavailable, rather than silently testing the wrong
# bytes.
strip_orca_hooks() {
  local hooks="$1"
  [ -f "$hooks" ] || return 0
  grep -q '\.orca/agent-hooks' "$hooks" 2>/dev/null || return 0
  if ! command -v jq >/dev/null 2>&1; then
    echo "strip_orca_hooks: jq required to sanitize $hooks" >&2
    return 1
  fi
  jq '.hooks |= (
        with_entries(.value |= (
          map(.hooks |= map(select((.command // "") | test("\\.orca/agent-hooks") | not)))
          | map(select((.hooks | length) > 0))
        ))
        | with_entries(select((.value | length) > 0))
      )' "$hooks" > "$hooks.sanitized" && mv "$hooks.sanitized" "$hooks"
}

# sanitize_codex_copy <dir containing a copied codex/>
# Convenience wrapper: drops Orca's .bak leftovers and strips the hook entries.
sanitize_codex_copy() {
  rm -f "$1"/codex/*.bak
  strip_orca_hooks "$1/codex/hooks.json"
}
