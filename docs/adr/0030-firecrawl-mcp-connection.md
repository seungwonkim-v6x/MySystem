# ADR-0030: Add Firecrawl as the fifth Pi MCP

Date: 2026-08-21
Status: Accepted
Amends: ADR-0026
Tags: pi, mcp, firecrawl, credentials, least-privilege

## Context

Firecrawl complements Exa and Scrapling for JavaScript-rendered and structured
web extraction. The existing Claude configuration uses a pinned stdio server
and an API key stored in Claude-owned configuration.

## Decision

- Add only the pinned `firecrawl-mcp@3.17.0` server to `.pi/mcp.json`.
- Read its API key at connection time with the Pi MCP adapter's `jq` command
  reference; never copy the literal key into Pi files or chat.
- Keep Firecrawl lazy, proxy-only, output-guarded, and approval-gated.
- Do not issue a search, scrape, fetch, or mutation during connection testing.

## Verification

- A non-secret presence check confirmed the Claude Firecrawl credential exists.
- Pi connected Firecrawl successfully.
- Metadata listing reported `firecrawl (24 tools)`.
- No external page was searched, scraped, or fetched.

## Rollback

Remove the `firecrawl` entry from `.pi/mcp.json` and run `/reload`. Do not
rotate or delete the original Claude credential as part of this rollback.
