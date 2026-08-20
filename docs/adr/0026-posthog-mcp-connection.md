# ADR-0026: Add MCP servers to Pi one at a time

Date: 2026-08-21
Status: Accepted
Amends: ADR-0025
Tags: pi, mcp, posthog, oauth, least-privilege

## Context

Claude Code had a global MCP registry containing several servers, including
PostHog. Pi does not inherit Claude's MCP clients or credentials, and Pi's core
intentionally has no built-in MCP surface. Importing the entire Claude registry
would recreate the broad tool and authorization surface that the Pi migration
removed.

The first requested integration is PostHog. Its remote endpoint advertises OAuth
and exposes a large tool catalog, including both read and write capabilities.

## Decision

- Install the reviewed, pinned `pi-mcp-adapter@2.26.1` package locally.
- Configure only `posthog` in `.pi/mcp.json`; do not use the Claude host import.
- Use OAuth through the adapter's secure credential flow. Do not copy Claude
  tokens or inspect credential files.
- Keep the server lazy, proxy-only, output-guarded, and approval-gated for every
  MCP call. Do not register 197 individual tool schemas in the initial prompt.
- Connect and validate one server before considering another. The next MCP is a
  separate user decision and change.

## Verification

- OAuth completed successfully.
- A Pi one-shot connection using `mcp({ connect: "posthog" })` succeeded.
- Read-only metadata listing reported `posthog (197 tools)`.
- No PostHog data query or mutation was issued during validation.

## Consequences

- PostHog is available through Pi's `mcp` proxy after `/reload` or a new session.
- Every tool call presents an approval decision, including read operations.
- Tool descriptions remain out of the startup prompt until searched/used.
- The adapter adds a reviewed third-party extension with full local process
  permissions; its version is pinned and its source was inspected before install.
- Other Claude MCP servers remain disconnected until separately reviewed and
  explicitly approved.

## Rollback

Remove the `posthog` entry from `.pi/mcp.json`, remove the pinned package entry
from `.pi/settings.json`, and run `/reload`. Use `/mcp logout posthog` if the
stored OAuth credential should also be revoked from Pi's credential store.
