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
| Sparse cherry-pick | [obra/superpowers](https://github.com/obra/superpowers) | `requesting-code-review` (adversarial 2nd-pass review) |
| Sparse cherry-pick | [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) | `deep-research` (needs firecrawl MCP key) |

### References (treasure trove — read-only knowledge bases)

12 curated repos cloned into `references/<name>/`. Not skills; the agent
greps them when a task touches the matching domain. Full catalog with
"use when" hooks: [`references/INDEX.md`](./references/INDEX.md).

Covers: system design (system-design-primer, awesome-scalability),
CS classics (papers-we-love), schema-design hazards (awesome-falsehood),
design patterns, engineering blogs by company, LLM/AI agents,
design systems (awesome-design-md, awesome-design-systems),
Tailwind, React components.

All external repos are always pulled at latest default branch; never pinned.
Managed via [`setup.sh`](./setup.sh) (no git submodules, no YAML manifest).
The MySystem philosophy: **harness existing skills, don't build new ones.**
New workflow needs → hunt for a public skill first, only add a user-owned
skill when no public alternative exists.

## Layout

- `CLAUDE.md`, `RTK.md` — global rules loaded every session
- `settings.json` — harness config (permissions, hooks, plugins)
- `skills/` — user-owned (tracked, currently just `verify-test/`) + external (symlinked by `setup.sh`)
- `external-skills/` — cache for sparse cherry-picked repos (git-ignored)
- `references/` — `INDEX.md` (tracked) + cloned read-only knowledge repos (git-ignored)
- `hooks/` — tracked (includes a Stop hook that renders substantive assistant turns as kami-parchment HTML in your browser at `~/.claude/previews/latest.html`)
- `setup.sh` — declares + fetches external skills; idempotent
- `install.sh` — `curl | bash` bootstrap for fresh machines

## Versioning

Semver. `VERSION` + [`CHANGELOG.md`](./CHANGELOG.md) + `git tag v<X.Y.Z>` per
release. Workflow-level changes bump minor; breaking changes bump major.

## Trust

`install.sh` and everything under `setup.sh` runs on your machine with your
shell privileges. Read them before executing on an unfamiliar host.
