#!/usr/bin/env bash
# rollback-gbrain.sh — Undo v0.38.0 gbrain activation in one command.
#
# Removes:
#   - mcpServers.gbrain entry from ~/.claude.json (backs up first)
#   - gbrain CLI from Bun global install
#   - ~/.gbrain/ directory (PGLite corpus, config.json) — only if backup tarball
#     was created successfully
#
# Does NOT:
#   - Revert ADR-0008 / CHANGELOG / VERSION / .out-of-scope/ (those stay in git
#     history; if you're rolling back v0.38.0 entirely, also `git revert <v0.38.0-commit>`)
#   - Touch the 5 PreToolUse hooks (gbrain never installed any; nothing to undo)
#   - Restore ~/.claude.json from any pre-existing backup — it creates a new
#     rollback-side backup before mutating, but does not consult prior backups
#
# Usage:
#   ./rollback-gbrain.sh         # interactive (requires tty for confirmation)
#   ./rollback-gbrain.sh --yes   # non-interactive (CI / scripted)
#
# Per ADR-0008 K1-K4 triggers. Per ADR-0006 / ADR-0007 supply-chain discipline.

set -euo pipefail

# Resolve the script's location once so error messages can point at it.
SCRIPT="${0##*/}"

echo "[$SCRIPT] Rolling back v0.38.0 gbrain activation..."
echo ""

# --- 1. Confirm intent (this is destructive) -----------------------------------
# Support --yes flag for non-interactive contexts (CI, automation).
# Without it, require an interactive tty so `read` doesn't silently no-op or
# accept piped input.
if [ "${1:-}" = "--yes" ]; then
  echo "[$SCRIPT] --yes flag given; proceeding without prompt."
elif [ ! -t 0 ]; then
  echo "[$SCRIPT] No tty for confirmation prompt. Re-run with --yes for non-interactive mode."
  exit 1
else
  read -r -p "[$SCRIPT] Delete ~/.gbrain/ corpus + remove MCP entry + uninstall gbrain CLI? Type 'yes' to confirm: " CONFIRM
  if [ "$CONFIRM" != "yes" ]; then
    echo "[$SCRIPT] Aborted. Nothing changed."
    exit 1
  fi
fi
echo ""

# --- 2. Remove mcpServers.gbrain from ~/.claude.json --------------------------
if [ -f "$HOME/.claude.json" ] && command -v jq >/dev/null 2>&1; then
  # Validate JSON before mutating — malformed JSON should fail loudly, not get
  # treated as "no entry" by jq -e (which returns non-zero on parse error AND
  # on missing key, indistinguishably).
  if ! jq empty "$HOME/.claude.json" 2>/dev/null; then
    echo "[$SCRIPT] WARN: ~/.claude.json is malformed JSON. Skipping MCP removal."
    echo "[$SCRIPT]       Fix the file manually and re-run if you want MCP entry cleanup."
  elif jq -e '.mcpServers.gbrain' "$HOME/.claude.json" >/dev/null 2>&1; then
    BACKUP="$HOME/.claude.json.rollback-bak-$(date +%s)"
    cp "$HOME/.claude.json" "$BACKUP"
    jq 'del(.mcpServers.gbrain)' "$HOME/.claude.json" > "$HOME/.claude.json.tmp"
    mv "$HOME/.claude.json.tmp" "$HOME/.claude.json"
    chmod 600 "$HOME/.claude.json"
    echo "[$SCRIPT] Removed mcpServers.gbrain (backup: $BACKUP)"
  else
    echo "[$SCRIPT] No mcpServers.gbrain entry to remove."
  fi
else
  echo "[$SCRIPT] WARN: ~/.claude.json or jq missing — skipping MCP removal."
fi

# --- 3. Uninstall gbrain CLI globally -----------------------------------------
# bun's top-level `remove -g` is the correct uninstall command. `bun pm rm`
# is not a valid Bun subcommand (verified vs Bun 1.3.x help).
if command -v bun >/dev/null 2>&1; then
  # Anchor the match so packages with "gbrain" in their name (e.g., "gbrain-foo")
  # don't false-positive into the "Uninstalled gbrain" log line.
  if bun pm ls -g 2>/dev/null | grep -qE '(^| )gbrain[@ ]'; then
    bun remove -g gbrain 2>&1 | tail -5 || true
    echo "[$SCRIPT] Uninstalled gbrain via bun remove -g"
  else
    echo "[$SCRIPT] gbrain not in bun global install — skipping."
  fi
else
  echo "[$SCRIPT] WARN: bun missing — cannot uninstall gbrain CLI."
fi

# --- 4. Delete ~/.gbrain/ (corpus + config) -----------------------------------
# Gate the delete on a successful backup tarball. If tar fails, leave the corpus
# in place — the "in case rollback was a mistake" promise must hold.
if [ -d "$HOME/.gbrain" ]; then
  CORPUS_BACKUP="$HOME/.gbrain-rollback-bak-$(date +%s).tar.gz"
  echo "[$SCRIPT] Tarring ~/.gbrain/ to $CORPUS_BACKUP (in case rollback was a mistake)..."
  if tar czf "$CORPUS_BACKUP" -C "$HOME" .gbrain && [ -s "$CORPUS_BACKUP" ]; then
    rm -rf "$HOME/.gbrain"
    echo "[$SCRIPT] Deleted ~/.gbrain/ (backup tarball: $CORPUS_BACKUP)"
  else
    echo "[$SCRIPT] WARN: tar backup failed or empty ($CORPUS_BACKUP). Leaving ~/.gbrain/ in place."
    echo "[$SCRIPT]       Investigate disk space / permissions, then re-run."
    rm -f "$CORPUS_BACKUP" 2>/dev/null || true
  fi
else
  echo "[$SCRIPT] ~/.gbrain/ already absent — nothing to delete."
fi

# --- 5. Reset gstack-config keys that we set during activation ----------------
if [ -x "$HOME/.claude/skills/gstack/bin/gstack-config" ]; then
  "$HOME/.claude/skills/gstack/bin/gstack-config" set artifacts_sync_mode off 2>/dev/null || true
  "$HOME/.claude/skills/gstack/bin/gstack-config" set transcript_ingest_mode off 2>/dev/null || true
  "$HOME/.claude/skills/gstack/bin/gstack-config" set artifacts_sync_mode_prompted false 2>/dev/null || true
  echo "[$SCRIPT] Reset gstack-config keys (artifacts_sync_mode, transcript_ingest_mode)"
fi

# --- 6. Verify rollback -------------------------------------------------------
echo ""
echo "[$SCRIPT] Post-rollback state:"
[ -f "$HOME/.gbrain/config.json" ] && echo "  ~/.gbrain/config.json: STILL PRESENT (manual cleanup needed)" \
                                   || echo "  ~/.gbrain/config.json: removed ✓"
command -v gbrain >/dev/null 2>&1 && echo "  gbrain CLI: STILL ON PATH (manual cleanup needed)" \
                                  || echo "  gbrain CLI: removed ✓"
if command -v jq >/dev/null 2>&1 && [ -f "$HOME/.claude.json" ]; then
  jq -e '.mcpServers.gbrain' "$HOME/.claude.json" >/dev/null 2>&1 \
    && echo "  mcpServers.gbrain: STILL PRESENT (manual cleanup needed)" \
    || echo "  mcpServers.gbrain: removed ✓"
fi

echo ""
echo "[$SCRIPT] Rollback complete."
echo ""
echo "Next steps:"
echo "  1. Restart any open Claude Code sessions (MCP changes are loaded at session start)."
echo "  2. If rolling back v0.38.0 entirely (not just disabling): "
echo "     git revert <v0.38.0-commit>  # reverts VERSION + CHANGELOG + ADR-0008 + .out-of-scope"
echo "  3. Corpus backup at the tarball above can be restored via: "
echo "     mkdir -p ~/.gbrain && tar xzf <backup>.tar.gz -C \$HOME"
echo ""
