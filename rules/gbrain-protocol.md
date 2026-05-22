# Persistent Memory Protocol (gbrain)

gbrain MCP is registered per ADR-0008 (experimental retrieval sidecar). This rule loads in every session (no `paths:` frontmatter) because gbrain triggers can occur in any conversation. Auto-capture pipeline runs hourly via launchd; this file covers in-session usage only.

## Retrieve — call BEFORE generating

- **User references a prior session** ("어제 그거", "remember when", "예전에", "지난번"):
  `mcp__gbrain__search` on keywords → `mcp__gbrain__get_page` on top hit
- **`/office-hours` Phase 1 or `/investigate` Phase 1**:
  `mcp__gbrain__search` on problem keywords before generating premises or hypotheses (falls under skill preamble's prior-learnings discovery)
- **Cross-repo question** (working on vProp, user mentions a MySystem decision, or vice versa):
  `mcp__gbrain__list_pages` with tag filter `cc-transcript`, scan for repo name
- **User about to commit to a decision**:
  `mcp__gbrain__recall` with grep filter to surface prior facts on the entity

## Write — call AFTER decision moments

- **Non-obvious choice** (architecture, scope cut, tool selection, ADR-worthy):
  `mcp__gbrain__put_page` with slug `decision-<topic>-<YYYY-MM-DD>`, body containing context / decision / why / alternatives-considered
- **New ADR landed**:
  `mcp__gbrain__add_link` from the decision page to the ADR file path
- **Session lands a concrete next-step commitment** ("I'll do X next week", "next session start with Y"):
  `mcp__gbrain__add_timeline_entry` on the relevant page

## Skip writes for

Routine grep/read, trivial yes/no, single-line tweaks, ephemeral chitchat. If `git log` or `grep` would surface it later, don't double-store.

## Infrastructure (machine-local, not Claude's responsibility to maintain)

Auto-capture: `~/Library/LaunchAgents/com.user.gbrain-session-capture.plist` runs `~/.claude/scripts/gbrain-ingest-sessions.sh` hourly. Writes one `cc-session-<repo>-<uuid>` page per session, idempotent via marker files in `~/.gbrain/ingested/`.

All writes local (PGLite at `~/.gbrain/brain.pglite/`). `artifacts_sync_mode=off`. Per ADR-0008, nothing leaves the machine. Rollback: `~/.claude/scripts/rollback-gbrain.sh` plus `launchctl unload ~/Library/LaunchAgents/com.user.gbrain-session-capture.plist`.
