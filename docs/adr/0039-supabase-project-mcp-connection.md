# ADR-0039: Add the project-scoped Supabase MCP

Date: 2026-08-21
Status: Accepted
Amends: ADR-0026
Tags: pi, mcp, supabase, oauth, database, project-scope

## Context

The Claude registry contains a Supabase MCP scoped to one explicit project
reference. It has a database-level blast radius and is separate from the
personal Supabase MCP, so it requires its own explicit approval and entry.

## Decision

- Add the project-scoped Supabase remote MCP to `.pi/mcp.json` with its explicit
  project reference.
- Authenticate with Pi OAuth after explicit user approval.
- Keep it lazy, proxy-only, output-guarded, and approval-gated.
- Do not run SQL, inspect tables, read/write data, migrate, or mutate during
  connection validation.

## Verification

- Project OAuth completed successfully.
- Pi connected the project Supabase MCP.
- Metadata listing reported 20 tools.
- No database operation was executed.

## Rollback

Remove `supabase-project` from `.pi/mcp.json`, run `/reload`, and use
`/mcp logout supabase-project` if the stored OAuth credential should be revoked.
