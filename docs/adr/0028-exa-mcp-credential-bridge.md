# ADR-0028: Connect Exa with a dynamic credential bridge

Date: 2026-08-21
Status: Accepted
Amends: ADR-0026
Tags: pi, mcp, exa, credentials, least-privilege

## Context

Exa is the next useful MCP for Pi because it provides search and fetch without
browser or workspace mutation. The existing Claude MCP definition uses a
pinned `exa-mcp-server@3.2.1` and stores an API key in Claude-owned config.

Copying that literal key into `.pi/mcp.json`, the shell history, or a chat
message would create a second credential copy and violate the Pi migration's
runtime ownership boundary.

## Decision

- Add Exa as a lazy, proxy-only Pi MCP with the existing pinned server version.
- Set its `EXA_API_KEY` environment value to a Pi MCP adapter command reference:
  `jq` reads the existing Claude config only when the stdio server connects.
- Pass the value to the child process only; never persist or print the key.
- Keep the global MCP approval policy in force and do not issue search/fetch
  calls during connection validation.

## Verification

- A non-secret presence check confirmed the Claude Exa credential exists.
- Pi connected Exa successfully using the dynamic bridge.
- Metadata listing reported `exa (3 tools)`.
- No Exa search or fetch was issued during validation.

## Consequences

- Exa is available to Pi without duplicating its API key.
- Exa's billing/quota policy still applies; use it deliberately and inspect
  provider usage before broad research.
- The bridge depends on the existing Claude config shape and `jq` being present.
- If the Claude config is removed or its Exa entry changes, Pi fails closed at
  connection time rather than using a stale credential.

## Rollback

Remove the `exa` entry from `.pi/mcp.json`, run `/reload`, and delete the
connection-time bridge only. Do not rotate or delete the original Claude
credential as part of this rollback.
