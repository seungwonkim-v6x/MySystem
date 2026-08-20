# ADR-0027: Add Notion as the second Pi MCP

Date: 2026-08-21
Status: Accepted
Amends: ADR-0026
Tags: pi, mcp, notion, oauth, least-privilege

## Context

PostHog was the first MCP connected to Pi under the one-at-a-time policy. The
remaining Claude registry contains several higher-risk or higher-cost servers.
Notion is useful for personal knowledge retrieval, but its MCP also exposes
write operations, so it must not be imported wholesale or silently trusted.

## Decision

- Add only `notion` to `.pi/mcp.json`.
- Authenticate through Pi's OAuth flow; do not copy Claude credentials.
- Keep Notion lazy, proxy-only, output-guarded, and approval-gated for every
  tool call.
- Do not import any other Claude MCP server in this change.

## Verification

- Notion OAuth completed successfully.
- A Pi one-shot connection using `mcp({ connect: "notion" })` succeeded.
- Read-only metadata listing reported `notion (31 tools)`.
- No Notion page was read, created, edited, or deleted during validation.

## Rollback

Remove the `notion` entry from `.pi/mcp.json`, run `/reload`, and use
`/mcp logout notion` if the stored OAuth credential should also be revoked.
