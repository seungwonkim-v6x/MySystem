# ADR-0034: Remove the unidentified Corpus MCP

Date: 2026-08-21
Status: Accepted
Amends: ADR-0026
Tags: pi, mcp, corpus, cleanup, least-privilege

## Context

A local `corpus` MCP was present in Claude's global registry and was connected
before its purpose and data scope were understood. The user requested its
removal rather than accepting an unknown local data surface.

## Decision

Remove `corpus` from Claude's global MCP registry and Pi's `.pi/mcp.json`.
Do not query or write corpus data, and do not forcibly kill already-running
processes owned by another host session.

## Verification

No configured file under the reviewed Claude/Pi MCP surfaces contains the
Corpus server after the change. A new Pi status load must not list `corpus`.

## Rollback

Re-add the server only after its source, data scope, and permissions are
reviewed and explicitly approved.
