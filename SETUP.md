# Pi Setup

MySystem is Pi-first as of v2.0.0. No Claude Code/Codex parity installation is required.

## Prerequisites

- Pi 0.84.2 or newer
- Node.js 22.19.0 or newer
- A Pi-supported provider login (`/login`) or API key

## Start

```bash
cd ~/MySystem
pi --approve
```

Approve this project once with `/trust` if you want Pi to load its `.pi/` resources automatically. Restart Pi or run `/reload` after editing them.

## Active configuration

| Path | Purpose |
|---|---|
| `AGENTS.override.md` | Pi project agreement; overrides the legacy `AGENTS.md` symlink |
| `.pi/APPEND_SYSTEM.md` | concise system-level behavior rules |
| `.pi/settings.json` | project model, compaction, retry, telemetry, and Pi package defaults |
| `.pi/mcp.json` | explicit MCP servers; currently PostHog, Notion, Exa, Scrapling, Firecrawl, Slack, Mobbin, Apify, XcodeBuildMCP, Supabase Personal, project Supabase, and Aside u0/u1/u2 |
| `.pi/extensions/pi-safety.ts` | protected paths and high-impact command confirmations |
| `.pi/prompts/` | optional `/review`, `/verify`, and `/research` prompt templates |
| `~/.pi/agent/settings.json` | global Pi defaults |
| `~/.pi/agent/auth.json` | provider credentials; never commit or inspect casually |

## Runtime policy

Pi is intentionally direct. There is no required scope → research → plan → review pipeline. Load a prompt template or skill only when it helps the current request.

`setup.sh` is now a local Pi health check and performs no network or legacy-runtime update. `install.sh` is a safe fresh-checkout bootstrap. Do not run the old gstack updater or Codex parity installer; those historical scripts are no longer active.

## Network and packages

Pi does not install packages or update external resources at session start. Install a Pi package explicitly with a pinned npm version or Git ref only after reviewing its source. Third-party Pi extensions execute with full user permissions.

The active MCPs are PostHog, Notion, Exa, Scrapling, Firecrawl, Slack, Mobbin, Apify, XcodeBuildMCP, Supabase Personal, project Supabase, and Aside u0/u1/u2. PostHog, Notion, Slack, Mobbin, Supabase Personal, and project Supabase use OAuth; Exa and Firecrawl use pinned stdio servers with connection-time `jq` credential bridges; Scrapling uses a local stdio command; Apify uses the existing mode-600 secret file only inside its child process; XcodeBuildMCP uses a pinned local stdio package with telemetry disabled; Aside uses three explicit local browser identities. All connect lazily, expose a single proxy tool surface, and require approval for every MCP call. Use `/mcp` or `/mcp-auth <server>` in Pi; do not import the full Claude MCP configuration. Add each next server only after reviewing and validating the previous one.

## Recovery

The legacy Claude/Codex files remain in this checkout and can be recovered from Git history. Runtime credentials, Pi sessions, browser state, and other provider-owned data are outside this repository and are not removed by the Pi migration.
