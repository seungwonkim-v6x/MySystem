# RTK - Rust Token Killer

**Usage**: Token-optimized CLI proxy (60-90% savings on dev operations).

> Internal voyagerx tool. Wired into MySystem via `settings.json` PreToolUse Bash
> hook (`rtk hook claude`) — every Bash command gets transparently rewritten so the
> output Claude sees is compressed.

## Install (per machine)

```
binary path:    ~/.local/bin/rtk
current build:  v6x.260421.1   (verify with `rtk --version`)
not on:         brew, cargo, asdf
source:         voyagerx internal — see #ai-tools Slack
```

If `rtk` is missing on a fresh machine, ask in voyagerx Slack (`#ai-tools` or relevant channel) for the latest internal build. `setup.sh` warns on missing rtk but does not block — the hook gracefully no-ops.

History / context: Slack thread (voyagerx-internal) — refer to whoever introduced rtk to the team for upgrade cadence and breaking-change notes.

## Meta Commands (always use rtk directly)

```bash
rtk gain              # Show token savings analytics (cumulative)
rtk gain --history    # Recent commands with savings per call
rtk discover          # Analyze Claude Code history for missed opportunities
rtk proxy <cmd>       # Execute raw command without filtering (debugging)
```

## Verify after install

```bash
rtk --version         # Should show: rtk X.Y.Z-v6x.YYMMDD.N
which rtk             # /Users/<you>/.local/bin/rtk
rtk gain              # Should print analytics, not "command not found"
```

⚠️ **Name collision**: If `rtk gain` fails, you may have `reachingforthejack/rtk` (Rust Type Kit) shadowing voyagerx rtk on `PATH`.

## Hook-Based Usage

All Bash commands are rewritten transparently by the Claude Code PreToolUse hook
(`settings.json` → `hooks.PreToolUse[].matcher: "Bash"`). Example:
`git status` → `rtk git status` (transparent, 0 token overhead).

Subcommands rtk knows about (proxies it provides): ls, tree, read, smart, git, gh, aws, psql, pnpm, err, test, json, deps, env, find, diff, log, dotnet, docker, kubectl, summary, grep, init, wget, wc.

## Sanity check

Run `rtk gain` periodically. If `Total commands` is climbing and `Tokens saved` >
~1M, the hook is doing its job. If counts are 0, the hook isn't firing — check
`settings.json` and `which rtk`.
