# MySystem Setup Guide

Personal Claude Code configuration — skills, agents, hooks, global rules —
maintained at [seungwonkim-v6x/MySystem](https://github.com/seungwonkim-v6x/MySystem).

This file is the single source of truth for setup. Claude Code can read it
and execute every step; a human can read it and run the same commands.

## Setup on a new machine

### Option A — Ask Claude (recommended)

Start `claude`, then paste:

> Read https://github.com/seungwonkim-v6x/MySystem/blob/main/SETUP.md and execute it on this machine.

Claude will:

1. Check that `git` is available.
2. If `~/.claude` already exists, move it to `~/.claude.backup.<timestamp>`.
3. `git clone https://github.com/seungwonkim-v6x/MySystem.git ~/.claude`
4. `cd ~/.claude && ./setup.sh`
5. Remind you to install `bun` if missing (gstack's `browse` skill needs it).

### Option B — One-liner (curl | bash)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/seungwonkim-v6x/MySystem/main/install.sh)
```

This runs [`install.sh`](./install.sh), which does exactly what Option A does.

### Option C — Manual step-by-step

```bash
# 1. Back up any existing ~/.claude
[ -e ~/.claude ] && mv ~/.claude ~/.claude.backup.$(date +%Y%m%d-%H%M%S)

# 2. Clone
git clone https://github.com/seungwonkim-v6x/MySystem.git ~/.claude

# 3. Bootstrap external skills + gstack setup
cd ~/.claude && ./setup.sh
```

## Updating an existing machine

```bash
cd ~/.claude
git pull
./setup.sh    # re-pulls gstack and re-registers installed skill dirs
```

`setup.sh` is idempotent — running it twice is safe.

### Persistent memory on a fresh machine

No setup step needed. gbrain was removed 2026-06-11 (PGLite WASM dead on
macOS 26 — see [ADR-0008](./docs/adr/0008-gbrain-as-memory-layer.md) SUPERSEDED).
Persistent recall is now two plain-file layers that need no activation:
file-based memory at `~/.claude/projects/<proj>/memory/` (loaded every
session) and the seungwon-wiki Obsidian vault. No MCP, no daemon, no SHA pin.

## Prerequisites

- **git** (required)
- **bun** (required by gstack's `browse` skill — headless browser)
  ```bash
  curl -fsSL https://bun.sh/install | bash
  ```

## What's inside

| Path | Purpose |
|------|---------|
| `CLAUDE.md`, `RTK.md` | Global rules auto-loaded every session (CLAUDE.md re-injected after `/compact`) |
| `rules/*.md` | Native `.claude/rules/`: 2 always-loaded (operating-principles, trust-boundaries) + 1 path-scoped to `~/.claude/**` (repo-self-management). See ADR-0009. |
| `scripts/` | Ops helpers — `claude-md-budget.sh` (always-loaded chain + Codex CLI cap check) |
| `CONTEXT.md` | Project glossary — who, why, vocabulary, install mechanisms |
| `docs/adr/` | Architecture Decision Records for MySystem itself |
| `.out-of-scope/` | "Considered, chose no" decision records |
| `settings.json` | Claude Code harness config (permissions, hooks, plugins, model) |
| `skills/` | User-owned (tracked: `verify-test/`, `deep-research/`, `aside-qa/`, `ai-review-loop/`) + external skills (symlinked, ignored) |
| `external-skills/` | Cache for sparse cherry-picked repos; ignored |
| `hooks/` | Tracked |
| `setup.sh` | Declares + fetches external skills; idempotent |
| `install.sh` | `curl | bash` entry point for fresh machines |
| `VERSION`, `CHANGELOG.md` | Semver + history |

## External dependencies

MySystem uses two install mechanisms in `setup.sh`:

### Full-repo install (`EXTERNAL_REPOS`)

The external repo's own setup script installs 20+ skills.

| Name | URL | Role |
|------|-----|------|
| gstack | https://github.com/garrytan/gstack.git | Workflow skills (autoplan, ship, review, office-hours, investigate, retro, …) |

### Sparse cherry-pick (`SPARSE_SKILLS`)

Clone repo, symlink **one subpath** as a single skill. Use when you want a
specific skill from a larger collection without inheriting siblings.

Format: `"skill-name|url|branch|subpath[|optional-commit-SHA]"`. Optional 5th
field pins to a specific commit (autonomous skills only — see ADR-0007).

| Skill | URL | Subpath | Pin? | Notes |
|-------|-----|---------|------|-------|
| requesting-code-review | https://github.com/obra/superpowers.git | `skills/requesting-code-review` | unpinned | Adversarial 2nd-pass review (Step 7) |
| deep-research | https://github.com/affaan-m/everything-claude-code.git | `.agents/skills/deep-research` | unpinned | Step 2. Requires firecrawl MCP. |
| **verification-before-completion** | https://github.com/obra/superpowers.git | `skills/verification-before-completion` | pinned `f2cbfbefebbf` | Step 5 augment (Iron Law: no completion claims without evidence) |
| **test-driven-development** | https://github.com/obra/superpowers.git | `skills/test-driven-development` | unpinned | User-invoked Step 4 modifier (Iron Law: no prod code without failing test) |
| **diagnose** | https://github.com/mattpocock/skills.git | `skills/engineering/diagnose` | pinned `e74f0061bb67` | Debug Step 1 alternate (feedback-loop-first) |
| **grill-with-docs** | https://github.com/mattpocock/skills.git | `skills/engineering/grill-with-docs` | pinned `e74f0061bb67` | Pre-Step-3 (interview vs CONTEXT.md/ADRs) |
| **prototype** | https://github.com/mattpocock/skills.git | `skills/engineering/prototype` | unpinned | User-invoked throwaway runnable code |
| **triage** | https://github.com/mattpocock/skills.git | `skills/engineering/triage` | unpinned | User-invoked (collaborative-repo issues) |
| **zoom-out** | https://github.com/mattpocock/skills.git | `skills/engineering/zoom-out` | unpinned | User-invoked navigation aid |
| **handoff** | https://github.com/mattpocock/skills.git | `skills/productivity/handoff` | pinned `e74f0061bb67` | Cross-agent continuation doc (distinct from `/context-save`) |

### Reference repos (`REFERENCE_REPOS`)

Plain `git clone` into `references/<name>/`. **No symlinks, no skill behaviour** —
these are read-only knowledge bases for human + agent lookup. Curated entry
point: [`references/INDEX.md`](./references/INDEX.md). Twelve seed repos cover
system design, distributed systems papers, CS hazards (falsehoods), design
patterns, engineering blogs, LLM / AI agents, design systems + Tailwind +
React components.

All sources are **cloned, not pinned** — `setup.sh` always pulls each repo's
default branch.

### Claude Code plugins

`settings.json` registers two marketplaces in `extraKnownMarketplaces` and
enables six plugins in `enabledPlugins`:

| Marketplace | Plugins |
|---|---|
| `claude-plugins-official` (Anthropic) | `frontend-design`, `context7`, `code-review` |
| `learning-opportunities` (DrCatHicks) | `learning-opportunities`, `learning-opportunities-auto`, `orient` |

Claude Code clones each marketplace on first session start after `git pull`,
then fetches and activates the enabled plugins. **No `setup.sh` re-run is
required, and no API keys are needed.** To confirm activation in a fresh
session, run `/plugin list` — the three `learning-opportunities` entries
should appear as enabled alongside the official ones.

To disable any one plugin, flip its `enabledPlugins` entry to `false` in
`settings.json` and commit. The change propagates on the next `git pull` on
every machine.

**Marketplace URLs are unpinned** (track upstream `main`). DrCatHicks is a
single-maintainer repo; review its diff before pulling MySystem updates if
the plugin's behavior matters to you. Anthropic's official marketplace is
the same shape but a much smaller trust delta.

`learning-opportunities` plugins are CC-BY-4.0; see CHANGELOG v0.33.0
Attribution for the full notice.

### MCP keys

The `deep-research` skill needs a firecrawl API key. Stored as plain text in
`~/.claude.json` under `mcpServers.firecrawl.env.FIRECRAWL_API_KEY` — that
file is outside the tracked repo and never committed. On a new machine, you
must add your own key after running `setup.sh`.

### Adding another external skill repo

1. Pick a mechanism: full-repo (sibling skills come along) or sparse cherry-pick
   (single skill only).
2. Append to the right list in [`setup.sh`](./setup.sh):
   - Full repo: `EXTERNAL_REPOS+=( "name|url|main" )`
   - Sparse: `SPARSE_SKILLS+=( "skill-name|url|main|subpath" )` (unpinned) OR `SPARSE_SKILLS+=( "skill-name|url|main|subpath|commit-SHA" )` (pinned per ADR-0007 — required for autonomous skills)
3. Add a row to the table above.
4. Never use git submodules — MySystem moved away from them in v0.27.0.

### Adding another reference repo

1. Append to `REFERENCE_REPOS` in `setup.sh`:
   ```
   "local-name|https://github.com/org/repo.git|branch"
   ```
2. Add a row to `references/INDEX.md` under the right category with a
   one-line "Use when" hook.
3. Run `./setup.sh` — clones into `references/<local-name>/`.

## Troubleshooting

- **`skills/gstack` has uncommitted local changes → pull fails**
  ```bash
  cd ~/.claude/skills/gstack
  git stash              # or: git reset --hard origin/main
  cd ~/.claude && ./setup.sh
  ```

- **`bun: command not found`** — install bun (see Prerequisites).

- **SessionStart hook complains about submodules** — the old submodule
  config was removed in v0.27.0. Restart Claude Code (the error comes
  from a cached process); if it persists, verify `.gitmodules` is gone.

- **A gstack skill disappeared after `./setup.sh`** — gstack dropped it
  upstream. Check gstack's CHANGELOG at https://github.com/garrytan/gstack.

- **`git status` shows all 20+ gstack skills as untracked** — `.git/info/exclude`
  hasn't been written yet. Run `./setup.sh` once; they'll stop showing.

- **`/deep-research` fails: "firecrawl tool not found"** — firecrawl MCP isn't
  configured. Add an entry to `~/.claude.json`:
  ```json
  "firecrawl": { "command": "npx", "args": ["-y", "firecrawl-mcp"],
                 "env": { "FIRECRAWL_API_KEY": "fc-..." }, "type": "stdio" }
  ```
  Restart Claude Code. Get a key at https://firecrawl.dev.

## Uninstall

```bash
rm -rf ~/.claude
# Optional: restore the backup
# mv ~/.claude.backup.<timestamp> ~/.claude
```
