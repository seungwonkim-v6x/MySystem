# ADR-0029: Add Scrapling as the fourth Pi MCP

Date: 2026-08-21
Status: Accepted
Amends: ADR-0026
Tags: pi, mcp, scrapling, local-tools, least-privilege

## Context

Scrapling is a local MCP server already configured for Claude. It provides
fetch-oriented capabilities without an OAuth account or a metered provider
credential. It is a lower-risk next step than browser automation, Slack, or
Supabase, but its tools still execute with the local user's permissions and can
access network content.

## Decision

- Add only the local Scrapling command to `.pi/mcp.json`:
  `/Users/seungwonkim/.local/bin/scrapling mcp`.
- Keep it lazy, proxy-only, output-guarded, and approval-gated.
- Do not expose its tools individually in the initial prompt.
- Do not import any other Claude MCP in this change.

## Verification

- Pi connected Scrapling successfully.
- Metadata listing reported `scrapling (10 tools)`.
- No URL fetch or external page access was performed.

## Rollback

Remove the `scrapling` entry from `.pi/mcp.json` and run `/reload`.
