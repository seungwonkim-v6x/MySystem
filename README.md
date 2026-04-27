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

- [gstack](https://github.com/garrytan/gstack) — workflow skills
  (autoplan, ship, review, office-hours, …)

Always pulled at latest `main`; never pinned. Managed via
[`setup.sh`](./setup.sh) (no git submodules, no YAML manifest).

## Layout

- `CLAUDE.md`, `RTK.md` — global rules loaded every session
- `settings.json` — harness config (permissions, hooks, plugins)
- `skills/` — user-owned (tracked) + external (restored by `setup.sh`)
- `agents/`, `hooks/` — tracked
- `setup.sh` — declares + fetches external skills; idempotent
- `install.sh` — `curl | bash` bootstrap for fresh machines

## Versioning

Semver. `VERSION` + [`CHANGELOG.md`](./CHANGELOG.md) + `git tag v<X.Y.Z>` per
release. Workflow-level changes bump minor; breaking changes bump major.

## Trust

`install.sh` and everything under `setup.sh` runs on your machine with your
shell privileges. Read them before executing on an unfamiliar host.
