# ADR-0032: Add Slack as the sixth Pi MCP

Date: 2026-08-21
Status: Accepted
Amends: ADR-0026
Tags: pi, mcp, slack, oauth, approval-gate

## Context

Slack is a useful communication and search integration, but its MCP surface can
include both read and write operations. A workspace connection must therefore
be explicit and each call must remain user-approved.

## Decision

- Add only the Slack remote MCP to `.pi/mcp.json`.
- Use the pre-registered OAuth client and localhost callback from the existing
  Claude configuration, without copying OAuth tokens.
- Keep Slack lazy, proxy-only, output-guarded, and approval-gated for every
  call.
- Do not read or send Slack messages during connection validation.

## Verification

- Slack OAuth completed after explicit workspace approval.
- Pi connected Slack successfully.
- Metadata listing reported `slack (20 tools)`.
- No message, channel, search, send, or mutation operation was executed.

## Rollback

Remove the `slack` entry from `.pi/mcp.json`, run `/reload`, and use
`/mcp logout slack` if the stored OAuth credential should also be revoked.
