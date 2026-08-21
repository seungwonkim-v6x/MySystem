# ADR-0036: Add Apify as the eighth active Pi MCP

Date: 2026-08-21
Status: Accepted
Amends: ADR-0026
Tags: pi, mcp, apify, credentials, cost-control

## Context

Apify is a managed search/scraping MCP and can incur usage charges. The
existing Claude configuration launches a pinned stdio server through `/bin/sh`
and sources a user-owned mode-600 secret file.

## Decision

- Add the same pinned Apify launch command to `.pi/mcp.json`.
- Keep the secret file outside Git and source it only inside the child process.
- Keep Apify lazy, proxy-only, output-guarded, and approval-gated.
- Do not run an Actor, search, scrape, fetch, or mutation during validation.

## Verification

- The existing Apify secret file was confirmed present with mode 600 without
  reading its contents.
- Pi connected Apify successfully.
- Metadata listing reported `apify (11 tools)`.
- No billable data operation was executed.

## Rollback

Remove the `apify` entry from `.pi/mcp.json` and run `/reload`. Do not remove
the original secret file as part of this rollback.
