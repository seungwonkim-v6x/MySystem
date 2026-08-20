# ADR-0038: Add Supabase Personal as the tenth active Pi MCP

Date: 2026-08-21
Status: Accepted
Amends: ADR-0026
Tags: pi, mcp, supabase, oauth, database, approval-gate

## Context

Supabase Personal is a database MCP and therefore has a substantially higher
blast radius than the research and design integrations. The first OAuth flow
was cancelled at the user's request so the personal workspace could be
requested again; the second flow was explicitly approved.

## Decision

- Add only the personal Supabase remote MCP to `.pi/mcp.json`.
- Authenticate with Pi OAuth after explicit user approval.
- Keep it lazy, proxy-only, output-guarded, and approval-gated for every call.
- Do not run SQL, inspect tables, read data, write data, migrate, or mutate
  anything during connection validation.

## Verification

- The second OAuth request completed successfully.
- Pi connected Supabase Personal successfully.
- Metadata listing reported 29 tools.
- No database operation was executed.

## Rollback

Remove the `supabase-personal` entry from `.pi/mcp.json`, run `/reload`, and
use `/mcp logout supabase-personal` if the stored OAuth credential should be
revoked.
