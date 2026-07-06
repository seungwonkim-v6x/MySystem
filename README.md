# MySystem

Personal Claude Code setup — skills, agents, hooks, global rules — synced
across all my machines as `~/.claude/`.

## Setup on a new machine

**With Claude Code (recommended):**

Start `claude`, then paste:

> Read https://github.com/seungwonkim-v6x/MySystem/blob/main/SETUP.md and execute it.

**One-liner:**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/seungwonkim-v6x/MySystem/main/install.sh)
```

**Step-by-step / troubleshooting:** see [SETUP.md](./SETUP.md).

## Update an existing machine

```bash
cd ~/.claude && git pull && ./setup.sh
```

## External dependencies

### Skills (workflow)

| Type | Source | Skills adopted |
|------|--------|----------------|
| Full repo | [gstack](https://github.com/garrytan/gstack) | workflow skills (autoplan, ship, review, office-hours, investigate, retro, …) |
| Sparse cherry-pick | [obra/superpowers](https://github.com/obra/superpowers) | `requesting-code-review` (Step 7), `verification-before-completion` (Step 5 augment, SHA-pinned), `test-driven-development` (user-invoked) |
| Sparse cherry-pick | [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) | `deep-research` (Step 2, needs firecrawl MCP key) |
| Sparse cherry-pick | [mattpocock/skills](https://github.com/mattpocock/skills) | `diagnose` (debug alternate, SHA-pinned), `grill-with-docs` (pre-Step-3, SHA-pinned), `handoff` (cross-agent, SHA-pinned), `prototype`, `triage`, `zoom-out` (user-invoked) |

**SHA pinning**: autonomous (workflow-whitelisted) sparse skills are pinned to specific commit SHAs in [`setup.sh`](setup.sh) per [ADR-0007](docs/adr/0007-skill-cherry-pick-batch-v0.37.md). User-invoked skills remain unpinned.

### Claude Code plugins (auto-fetched)

Registered in `settings.json` via `extraKnownMarketplaces` + `enabledPlugins`.
Claude Code fetches them on the next session start — no extra setup script,
no API keys.

| Marketplace | Plugins | Role |
|---|---|---|
| [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) | `frontend-design`, `context7`, `code-review`, `figma` | Official starter plugins |

All external repos are always pulled at latest default branch; never pinned.
Managed via [`setup.sh`](./setup.sh) (no git submodules, no YAML manifest).
The MySystem philosophy: **harness existing skills, don't build new ones.**
New workflow needs → hunt for a public skill first, only add a user-owned
skill when no public alternative exists.

## Layout

- `CLAUDE.md` — global rules loaded every session (re-injected by Claude Code natively after `/compact`)
- `rules/*.md` — detailed rules loaded by Anthropic's native `.claude/rules/` mechanism. Two are always-loaded (`operating-principles.md`, `trust-boundaries.md`). `repo-self-management.md` is path-scoped via absolute `~/.claude/` paths so it triggers only when editing MySystem itself, not when working in vProp/cc-guard/etc. See ADR-0009. (`gbrain-protocol.md` was removed 2026-06-11 with the gbrain excision — see ADR-0008 SUPERSEDED.)
- `CONTEXT.md` — project glossary (who, why, vocabulary, install mechanisms)
- `docs/adr/` — Architecture Decision Records for MySystem itself
- `.out-of-scope/` — explicit "considered, chose no" rationales
- `settings.json` — harness config (permissions, hooks, plugins)
- `scripts/` — ops helpers; `claude-md-budget.sh` itemizes the always-loaded chain and Codex CLI cap compliance
- `skills/` — user-owned (tracked: `verify-test/`, `deep-research/`, `aside-qa/`, `ai-review-loop/`) + external (symlinked by `setup.sh`)
- `external-skills/` — cache for sparse cherry-picked repos (git-ignored)
- `hooks/` — tracked (includes a Stop hook that renders substantive assistant turns as kami-parchment HTML in your browser at `~/.claude/previews/latest.html`)
- `setup.sh` — declares + fetches external skills; idempotent
- `install.sh` — `curl | bash` bootstrap for fresh machines

## Versioning

Semver. `VERSION` + [`CHANGELOG.md`](./CHANGELOG.md) + `git tag v<X.Y.Z>` per
release. Workflow-level changes bump minor; breaking changes bump major.

## Trust

`install.sh` and everything under `setup.sh` runs on your machine with your
shell privileges. Read them before executing on an unfamiliar host.
