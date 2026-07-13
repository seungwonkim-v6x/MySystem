# MySystem Setup Guide

This guide installs one versioned workflow for Claude Code and Codex. The Git
checkout at `~/.claude` is canonical; generated Codex instructions and links are
derived from it.

## Prerequisites

Required:

- `git`
- Bash 3.2 or newer
- `jq`
- `python3`

Optional but expected by specific workflows:

- `bun` for gstack browser tooling
- `bats` for the local contract suite
- Codex CLI for Codex sessions and conditional profile probes
- Claude Code for Claude sessions and Claude plugin activation

On macOS with Homebrew:

```bash
brew install git jq python bats-core bun
```

## Fresh install

One-liner:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/seungwonkim-v6x/MySystem/main/install.sh)
```

Manual:

```bash
[ -e ~/.claude ] && mv ~/.claude ~/.claude.backup.$(date +%Y%m%d-%H%M%S)
git clone https://github.com/seungwonkim-v6x/MySystem.git ~/.claude
cd ~/.claude
./setup.sh
```

Setup updates gstack and sparse sources, validates Claude skills, renders Codex
projections, safely migrates approved legacy Codex paths, installs links, then
runs the structural doctor. The final line should resemble:

```text
SUMMARY profile=core PASS=<count> WARN=1 FAIL=0 exit=0
```

The normal warning says conditional profiles were intentionally not probed.
Start a new Claude Code or Codex session after setup. For Orca, create a new
Codex session so the host refreshes its merged hooks.

## Update

```bash
cd ~/.claude
git pull
./setup.sh
```

Warm local parity updates avoid network work:

```bash
./setup.sh --parity-only
```

## Command reference

```text
./setup.sh
    Update external skills, render/install parity, and run core doctor.

./setup.sh --check
    Read-only projection, link, skill, and hook check. No network or repair.

./setup.sh --parity-only
    Render and install only parity-managed paths. No external repository update.

./setup.sh doctor [--require PROFILE] [--json] [--verbose]
    Read-only diagnostics. PROFILE is core, material-ui, browser, or figma.

./setup.sh --recover
    Restore the latest retained approved legacy backup if its destination still
    points to the expected MySystem target. Repeat to restore earlier migrations.

./setup.sh ... --codex-home PATH
    Add an existing user-owned Codex home. Repeatable; spaces are supported.
```

Invalid invocation exits `2`. Doctor exits `1` when any core check fails;
warnings exit `0`.

## Managed paths

| Destination | Target | Behavior |
|---|---|---|
| `~/.claude/AGENTS.md` | `codex/AGENTS.project.md` | MySystem-only supplement |
| `~/.codex/AGENTS.md` | `codex/AGENTS.global.md` | global Codex workflow |
| alternate `CODEX_HOME/AGENTS.md` | same global projection | instructions only |
| `~/.codex/hooks` | `~/.claude/hooks` | shared hook implementations |
| `~/.codex/hooks.json` | `~/.claude/codex/hooks.json` | default Codex registration |
| portable `~/.agents/skills/<name>` | canonical complete skill directory | required skills |

Alternate-home config, auth, history, sessions, databases, plugins, MCP state,
and host metadata are read-only. Orca's `hooks.json` is inspected as a semantic
superset and never rewritten by MySystem.

Destination classification is fail-closed:

- absent, correct/wrong/broken symlink, or empty placeholder: safe link install
- exact approved legacy file/tree: move to a named backup, then link
- unknown real file, non-empty directory, special file, unsafe parent: preserve
  it and fail before any managed link mutation

## Capability profiles

Run the matching preflight immediately before a conditional workflow:

```bash
./setup.sh doctor --require material-ui
./setup.sh doctor --require browser
./setup.sh doctor --require figma
```

`material-ui` requires the enabled `frontend-design` Codex plugin. `browser`
requires the local `aside-qa` skill and an enabled Aside MCP registration in
ordinary Codex. Supported Orca homes may report the declared `aside` CLI
fallback because Orca regenerates its host-owned MCP inventory on launch.
`figma` requires the enabled Figma plugin and MCP registration. Structural
success does not prove authentication or a live tool. The active coordinator
must perform one documented non-mutating tool call before relying on it.

On a machine where the `aside` CLI is already installed but Codex has no Aside
MCP entry, the explicit runtime-owned registration is:

```bash
codex mcp add aside -- "$(command -v aside)" mcp
```

Start a new Codex session afterward. MySystem diagnoses this state but does not
write runtime-owned MCP configuration automatically.

## Recovery and rollback

### Restore an approved legacy path

```bash
cd ~/.claude
./setup.sh --recover
```

Recovery stops if the managed destination or retained backup differs from its
recorded content identity. A missing backup is treated as a completed atomic
restore only when the destination matches that identity; otherwise the migration
record is retained as a conflict. Backups are named beside their former
destination as `*.mysystem-backup.<UTC>.<pid>.<counter>` and are retained with
user-only permissions until deliberately removed after release verification.

### Roll back generated parity

1. Check out the prior reviewed MySystem tag.
2. Run `./setup.sh --parity-only`.
3. Run `./setup.sh --check`.

This restores direct links to the selected checkout. The guarantee is
recoverability per managed path, not release-wide atomic rollback. Gstack and
unpinned sparse upstream contents are restored exactly only when their source
SHA is separately recorded and checked out.

### Interrupted migration

The installer writes a durable transaction before moving an approved legacy
path. On the next run it either restores the prior path or completes the exact
recorded link transition. Lock, transaction, and migration leaves are validated
without following symlinks. Backup type and mode-independent content identity
are recorded so concurrent replacement cannot be mistaken for completed
recovery. A conflict is preserved and reported.

## Host refresh

Orca owns its merged runtime `hooks.json`. After default hook registration
changes, start a new Codex session from Orca and rerun:

```bash
cd ~/.claude
./setup.sh --check
```

If `HOST_REFRESH_REQUIRED` remains, inspect the reported runtime path and Orca
hook UI. Do not replace the host file with `~/.codex/hooks.json`.

## External skills

`setup.sh` has two external source mechanisms:

| Mechanism | Current source | Ownership |
|---|---|---|
| `EXTERNAL_REPOS` | gstack | upstream setup generates Claude and Codex-native skills |
| `SPARSE_SKILLS` | obra/superpowers | one complete skill subdirectory; autonomous source pinned where required |

Tracked local skills are `verify-test`, `deep-research`, `aside-qa`, and
`ai-review-loop`. `deep-research` is vendored and provider-adapted; it is no
longer a sparse install. Seven unused sparse skills were removed in v0.44.0.

To add a workflow skill:

1. Follow the canonical workflow and update `CLAUDE.md` mapping/declarations.
2. Add exactly one typed source entry to `codex/parity-contract.json`.
3. Add an external source to `setup.sh` only when it is not tracked locally or
   generated by gstack.
4. Add installer/doctor fixture coverage and update this table.
5. Run the deterministic suite and the mandatory behavioral release scenarios.

Never use git submodules. Unexpected cache or skill paths are preserved rather
than deleted.

## Diagnostics

Every warning/failure includes `STATUS`, stable `CHECK_ID`, subject, Problem,
Cause, Fix, and one of the anchors below. `--json` emits the same fields plus a
summary.

### Parity contract

`CONTRACT_INVALID` means the tracked manifest is absent, malformed, incomplete,
or disagrees with the canonical hook registration. Budget types, digest lists,
the exact safety/convenience tuples, and hook command argv are validated before
contract-derived paths are read. Restore the contract and registration from the
reviewed release.

### Generated projections

`STALE_PROJECTION` or a render failure means canonical sources, markers, skill
declarations, source closure, or byte budgets no longer match generated files.
Run `./setup.sh --parity-only`; do not edit generated files.

### Codex home unsafe

Explicit homes must be existing absolute user-owned paths without control
characters, unsafe symlink components, world-writable ownership, or overlap
with protected paths.

### Default Codex home missing

Run `./setup.sh --parity-only` to initialize the default managed directory.

### Managed links

A required link is absent or resolves outside the canonical checkout. Run the
parity installer. Unknown real content must be inspected and moved manually.

### Hook registration

Default `hooks.json` is malformed or lacks a semantic event/matcher/script
tuple. Run the parity installer, then review/trust hooks in the Codex UI.

### Hook safety missing

A required safety tuple is missing from default Codex. Do not continue with
mutating tool use until `./setup.sh --parity-only` passes.

### Host hooks

The alternate host does not expose an inspectable hook registration. Confirm
its hook support manually; MySystem will not create host-owned state.

### Host refresh required

Start a new Orca Codex session, rerun doctor, and inspect the host integration
if the safety tuple remains absent.

### Host convenience degraded

Rendering, preview, or update convenience behavior is missing. Safety may still
be intact; refresh the host or continue without that convenience.

### Core skill missing

Run full `./setup.sh`. If the skill is gstack-generated, inspect gstack setup
output. If portable, inspect the canonical source directory.

### Portable skills

The complete directory must resolve to the typed source in the parity contract.
Independent copies are drift and are not accepted.

### Gstack skills

These are generated Codex-native directories. Refresh through full `./setup.sh`;
never replace them with Claude source links.

### Unsupported probe

The installed Codex CLI does not expose compatible plugin/MCP JSON. Upgrade it
or inspect `/plugins` and `/mcp` manually before the conditional workflow.

### Capability profiles

Install/enable the named plugin or MCP, start a new session, then rerun the
matching `--require` command.

### Live capability check

Configuration is present but auth/tool execution is unverified. Perform one
non-mutating operation in the current model session.

### Conditional profiles

Core mode intentionally skips slow inventories. This warning is expected; run
the named profile only when entering that workflow.

## Uninstall

First inspect and optionally restore retained backups with `./setup.sh --recover`.
Then remove only links that still resolve into the MySystem checkout. Runtime
auth/session/config state is outside MySystem and should not be deleted as part
of parity uninstall.
