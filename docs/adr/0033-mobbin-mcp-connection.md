# ADR-0033: Add Mobbin as the seventh Pi MCP

Date: 2026-08-21
Status: Accepted
Amends: ADR-0026
Tags: pi, mcp, mobbin, oauth, design-research

## Context

Mobbin provides design-reference screens and flows. It is a read-oriented
research integration and is lower risk than live browser control or database
MCPs, but its results are still external content and must be treated as data.

## Decision

- Add only Mobbin's remote MCP to `.pi/mcp.json`.
- Authenticate through Pi OAuth without copying Claude credentials.
- Keep Mobbin lazy, proxy-only, output-guarded, and approval-gated.
- Do not call design search or screen tools during connection validation.

## Verification

- Mobbin OAuth completed successfully.
- Pi connected Mobbin successfully.
- Metadata listing reported `mobbin (6 tools)`.
- No Mobbin search, screen, flow, section, or account data was accessed.

## Rollback

Remove the `mobbin` entry from `.pi/mcp.json`, run `/reload`, and use
`/mcp logout mobbin` if the stored OAuth credential should also be revoked.
