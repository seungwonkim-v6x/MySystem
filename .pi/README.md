# Project-local Pi resources

This directory is the active Pi surface for MySystem.

- `APPEND_SYSTEM.md` — short operating rules
- `settings.json` — project defaults
- `mcp.json` — explicit MCP servers; currently PostHog, Notion, Exa, Scrapling, Firecrawl, Slack, Mobbin, Apify, XcodeBuildMCP, Supabase Personal, project Supabase, and Aside u0/u1/u2
- `references/aside-profiles.md` — on-demand routing notes for the three isolated browser identities
- `extensions/pi-safety.ts` — small safety boundary
- `prompts/` — optional, explicitly invoked prompt templates

Keep this directory small. Prefer Pi's native features and progressive disclosure over permanent workflow prose or automatic networked setup. Add MCP servers one at a time; use lazy proxy mode and approval gates rather than importing every host configuration.
