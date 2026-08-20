# ADR-0035: Remove Stitch from all MCP configurations

Date: 2026-08-21
Status: Accepted
Amends: ADR-0026
Tags: pi, mcp, stitch, cleanup, least-privilege

## Context

Stitch was considered as the next design MCP. Its existing Claude definition
used a Google API key header, and the remote OAuth server rejected dynamic client
registration. The user does not need Stitch, so retaining a credential bridge or
an incomplete OAuth configuration would create unnecessary surface area.

## Decision

Remove Stitch from Claude's global registry and Pi's `.pi/mcp.json`. Do not
copy or retain its API key bridge. No running Stitch process was found, so no
process termination was necessary.

## Verification

The reviewed Claude/Pi configuration files contain no Stitch entry, and the
Pi server list does not include it. No Stitch design data was accessed.

## Rollback

Re-add Stitch only after a separate explicit decision and a reviewed
authentication method.
