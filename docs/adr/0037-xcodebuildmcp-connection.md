# ADR-0037: Add XcodeBuildMCP as the ninth active Pi MCP

Date: 2026-08-21
Status: Accepted
Amends: ADR-0026
Tags: pi, mcp, xcode, local-tools, approval-gate

## Context

XcodeBuildMCP provides local Xcode build, test, simulator, and project tools.
It is useful only for iOS/macOS work and can cause substantial local side
effects, so it must remain lazy and approval-gated.

## Decision

- Add pinned `xcodebuildmcp@2.3.2` as a stdio MCP.
- Set `XCODEBUILDMCP_SENTRY_DISABLED=1`.
- Keep it proxy-only, output-guarded, and approval-gated.
- Do not execute build, test, install, simulator, or project mutation tools
  during connection validation.

## Verification

- Pi connected XcodeBuildMCP successfully.
- Metadata listing reported 32 tools.
- No Xcode operation was executed.

## Rollback

Remove the `xcodebuild` entry from `.pi/mcp.json` and run `/reload`.
