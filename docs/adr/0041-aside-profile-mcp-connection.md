# ADR-0041: Connect the three Aside browser profiles explicitly

Date: 2026-08-21
Status: Accepted
Amends: ADR-0026
Tags: pi, mcp, aside, browser, identity, high-risk

## Context

Aside exposes three isolated browser identities. A generic server name would
make account selection ambiguous and could silently operate on the wrong
workspace. The servers are high risk because they carry live login sessions and
cookies.

## Decision

- Add three separate lazy, proxy-only, approval-gated MCP servers:
  - `aside` → account `u0` personal/main
  - `aside-u1` → account `u1` BounceBallSim
  - `aside-u2` → account `u2` FlagCup
- Keep browser actions behind the MCP approval gate.
- Store profile-routing notes in `.pi/references/aside-profiles.md`, loaded on
  demand rather than permanently injected into the prompt.
- Default browser verification to read-only tab attachment. No cross-profile
  cookie or DOM transfer.

## Verification

- Metadata-only connection succeeded for all three profiles.
- Each profile exposed one MCP tool.
- Direct read-only `listBrowserTabs()` calls returned profile-specific tabs.
- No navigation, click, typing, form submission, cookie access, or external
  mutation was performed.

## Rollback

Remove the three Aside entries from `.pi/mcp.json` and run `/reload`. Delete or
retain the on-demand profile reference independently.
