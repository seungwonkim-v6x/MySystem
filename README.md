# MySystem — Pi-first

This directory is a small, Pi-native personal coding environment. The former Claude Code/Codex workflow is preserved in Git history, not in the active checkout.

## Start Pi

```bash
cd ~/MySystem
pi --approve
```

On the first run, trust the project when Pi asks. Then use `/reload` after changing `.pi/` resources.

Pi-specific resources:

```text
AGENTS.override.md       short project agreement loaded by Pi
.pi/APPEND_SYSTEM.md    concise Pi operating rules
.pi/settings.json        project model/compaction defaults
.pi/extensions/          small Pi-native safety extension
.pi/mcp.json             one-at-a-time MCP configuration; PostHog + Notion + Exa + Scrapling + Firecrawl + Slack + Mobbin + Apify + XcodeBuildMCP + Supabase Personal + project Supabase + Aside u0/u1/u2
.pi/prompts/             optional review/verify/research commands
```

Global Pi defaults live at `~/.pi/agent/settings.json`. Credentials remain in Pi's own auth store and are never tracked here.

## Design goals

- No mandatory workflow, phase state machine, or approval ceremony.
- No networked SessionStart updater.
- No full gstack checkout in the active Pi prompt path.
- MCP servers are added one at a time, lazy, proxy-only, and approval-gated.
- Current MCPs: PostHog, Notion, Exa, Scrapling, Firecrawl, Slack, Mobbin, Apify, XcodeBuildMCP, Supabase Personal, project Supabase, and Aside u0/u1/u2. Other Claude MCP registrations remain disconnected.
- Skills and prompts are optional and progressively disclosed.
- Safety is limited to protected paths, catastrophic commands, and confirmations for high-impact actions.
- Pi's native compaction stays enabled; default reasoning is `high`, not `max`.

## Legacy surface

The active checkout intentionally contains no Claude Code/Codex hooks, parity tree, gstack checkout, or legacy skills. Those files remain recoverable from Git history. The old `~/.claude` directory is retained separately as a local archive until its runtime data is reviewed.

`setup.sh` and `install.sh` perform only local Pi health/bootstrap work and never update external repositories.

## Verification

```bash
node --experimental-strip-types --check .pi/extensions/pi-safety.ts
node --experimental-strip-types tests/pi-environment.mjs
pi --no-session --approve -p 'Reply only: ready'
```

Use `!!command` inside Pi when you need to run a command without adding its output to model context. Use `/compact` manually when a task changes direction; automatic compaction is enabled as a safety net.
