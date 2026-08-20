# ADR-0040: Remove the unapproved Supermemory MCP

Date: 2026-08-21
Status: Accepted
Amends: ADR-0026
Tags: pi, mcp, supermemory, cleanup, least-privilege

## Context

Supermemory was present in Claude's global MCP registry, but its data scope and
purpose were not confirmed. Unlike the explicitly approved MCPs, it was not
connected or needed for the Pi environment.

## Decision

Remove Supermemory from Claude's global MCP configuration, including server and
disabled-server references. Do not add it to Pi and do not attempt OAuth.

## Verification

The reviewed Claude/Pi configuration surfaces contain no Supermemory entry.
No Supermemory server was connected, queried, or mutated.

## Rollback

Re-add it only after its data scope and permissions are reviewed and the user
explicitly approves the connection.
