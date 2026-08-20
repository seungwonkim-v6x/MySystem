# ADR-0031: Remove Pencil from all MCP configuration surfaces

Date: 2026-08-21
Status: Accepted
Amends: ADR-0026 through ADR-0030
Tags: mcp, pencil, cleanup, least-privilege

## Context

Pencil was present in multiple host configurations: Claude global and project
MCP files, Codex configuration, Gemini settings, and Claude permission entries.
The user does not need Pencil in the Pi environment, and leaving it in shared
or imported files would allow a future host-config discovery step to reintroduce
it.

## Decision

Remove the Pencil server and permission entry from every discovered config:

- `~/.claude.json`
- `~/.claude/.mcp.json`
- `~/.claude/.codex/config.toml`
- `~/.gemini/settings.json`
- `~/.claude/settings.json`
- `~/.claude/.claude/settings.local.json`
- `.pi/mcp.json`

Do not kill existing Pencil processes forcibly; they are owned by already-running
host sessions. New sessions must not discover or connect to Pencil.

## Verification

A fresh Pi resource/config load must list only the explicitly retained MCPs and
must not list Pencil. JSON/TOML parsing and Pi MCP metadata checks must pass.

## Rollback

Restore the individual host configuration entries from version control or the
host's own backup if Pencil is explicitly needed again. Re-adding it to Pi is a
separate user decision.
