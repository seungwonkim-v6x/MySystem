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

## Prerequisites

- **git** (required)
- **bun** (required by gstack's `browse` skill — headless browser)
  ```bash
  curl -fsSL https://bun.sh/install | bash
  ```

## What's inside

| Path | Purpose |
|------|---------|
| `CLAUDE.md`, `RTK.md` | Global rules auto-loaded every session |
| `settings.json` | Claude Code harness config (permissions, hooks, plugins, model) |
| `skills/` | Mix of user-owned skills (tracked) + external skills (ignored, restored by `setup.sh`) |
| `agents/`, `hooks/` | Tracked |
| `setup.sh` | Declares + fetches external skills; idempotent |
| `install.sh` | `curl | bash` entry point for fresh machines |
| `VERSION`, `CHANGELOG.md` | Semver + history |

## External dependencies

MySystem uses exactly one external skill repo:

| Name | URL | Role |
|------|-----|------|
| gstack | https://github.com/garrytan/gstack.git | Workflow skills (autoplan, ship, review, office-hours, …) |

It is **cloned, not pinned** — `setup.sh` always pulls the latest `main`.
The list of skills gstack installs changes over time; `setup.sh` detects the
current list at runtime and writes it to `.git/info/exclude` (a git-local,
untracked ignore file) so the tracked `.gitignore` never needs to be edited
when gstack evolves.

### Adding another external skill repo

1. Append a new line to `EXTERNAL_REPOS` inside [`setup.sh`](./setup.sh):
   ```
   "name|https://github.com/org/repo.git|main"
   ```
2. Add a row to the table above.
3. If that repo installs its own sub-skills (like gstack does), they will
   be detected automatically by `setup.sh`'s `.git/info/exclude` logic as
   long as they end up as symlinks under `skills/<name>/SKILL.md`.
   Otherwise, add an explicit ignore entry in `.gitignore`.
4. Never use git submodules — MySystem moved away from them in v0.27.0.

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

## Uninstall

```bash
rm -rf ~/.claude
# Optional: restore the backup
# mv ~/.claude.backup.<timestamp> ~/.claude
```
