# MySystem

Personal Claude Code and Codex workflow configuration, versioned once at
`~/.claude/` and projected into each runtime's native discovery paths.

`CLAUDE.md` is the only human-authored workflow. Codex receives generated,
byte-stable `AGENTS.md` projections of the same marked canonical sections.
Authentication, history, sessions, model selection, plugins, MCP credentials,
and host metadata remain owned by each runtime.

## Quick start

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/seungwonkim-v6x/MySystem/main/install.sh)
```

Or install manually:

```bash
git clone https://github.com/seungwonkim-v6x/MySystem.git ~/.claude
cd ~/.claude
./setup.sh
```

The final summary should contain `FAIL=0`. Start a new Claude Code or Codex
session after setup. See [SETUP.md](./SETUP.md) for prerequisites, host refresh,
capability profiles, and recovery.

## Daily commands

```bash
./setup.sh                         # update skills + install Codex parity
./setup.sh --parity-only           # local parity install; no network updates
./setup.sh --check                 # read-only structural check
./setup.sh doctor --json           # machine-readable diagnostics
./setup.sh doctor --require browser
./setup.sh --recover               # restore the latest approved legacy backup
```

Additional Codex homes are explicit and repeatable:

```bash
./setup.sh --parity-only --codex-home "/absolute/path/with spaces"
```

## Ownership model

```text
CLAUDE.md + rules/*.md
          |
          v
codex/parity-contract.json + scripts/render-codex-agents.sh
          |
          +--> codex/AGENTS.global.md  --> ~/.codex/AGENTS.md
          |                              --> alternate CODEX_HOME/AGENTS.md
          |
          `--> codex/AGENTS.project.md --> ~/.claude/AGENTS.md

hooks/ -----------------------------> ~/.codex/hooks
codex/hooks.json -------------------> ~/.codex/hooks.json
portable workflow skills ----------> ~/.agents/skills/<name>
```

The MySystem project supplement is separate so repository release rules do not
leak into unrelated projects. Gstack skills keep their generated Codex-native
directories; portable local and sparse skills are linked as complete folders.

## Behavioral parity

Structural parity means the projections, links, required skills, and safety-hook
registrations are current. Behavioral parity additionally requires the bounded
manual release scenarios in [TESTING.md](./TESTING.md): feature/debug routing,
one-step approval advancement, Step 5 verification behavior, Step 9 chaining,
and project-rule isolation. Tests assert observable state transitions, not exact
model wording.

Conditional capabilities are closed profiles:

| Profile | Adds | Preflight |
|---|---|---|
| `core` | workflow skills and safety hooks | `./setup.sh --check` |
| `material-ui` | `frontend-design` plugin | `./setup.sh doctor --require material-ui` |
| `browser` | Aside skill plus MCP registration, or the declared Orca CLI fallback | `./setup.sh doctor --require browser` |
| `figma` | Figma plugin plus MCP registration | `./setup.sh doctor --require figma` |

A structural MCP result never claims that the current session is authenticated
or that a live tool call works. The coordinator performs a non-mutating live
check immediately before relying on that capability.

Parity state rejects linked or unsafe lock/transaction leaves. Approved legacy
backups retain a mode-independent content identity, so recovery finalizes a
crash window only when the restored destination still matches that identity.

## External dependencies

| Type | Source | Adopted behavior |
|---|---|---|
| Full repo | [gstack](https://github.com/garrytan/gstack) | Steps 1, 3, 5, 6, 8 and supporting workflows |
| Sparse | [obra/superpowers](https://github.com/obra/superpowers) | Step 6 fresh-context review pass plus the Step 5 completion gate |
| Vendored local | `skills/deep-research/` | Step 2 provider-pluggable research |
| User-owned local | `verify-test`, `aside-qa`, `ai-review-loop` | Steps 5 and 9 |
| Claude plugins | `settings.json` | Claude-native conditional capabilities |
| Codex plugins/MCP | Codex runtime state | Profile-probed, never copied from Claude state |

Autonomous sparse skills are SHA-pinned where declared in `setup.sh`.
`requesting-code-review` remains unpinned by the existing ADR policy. Gstack
owns its generated Codex outputs; MySystem does not replace them with Claude
source directories.

## Layout

- `CLAUDE.md` - canonical global workflow prose
- `rules/` - canonical detailed rules
- `codex/` - narrow contract, adapter header, generated projections, hook registration
- `scripts/render-codex-agents.sh` - deterministic projection generator/checker
- `scripts/install-codex-parity.sh` - isolated safe link installer and recovery boundary
- `scripts/codex-parity-doctor.sh` - read-only diagnostics and profile probes
- `skills/` - tracked user-owned skills plus setup-managed external sources
- `hooks/` - shared safety and convenience hook scripts
- `tests/` - hook, installer, projection, profile, and workflow-helper contracts
- `docs/adr/` - architecture decisions

## Trust

`install.sh`, `setup.sh`, external repository setup scripts, and hooks execute
with user privileges. The parity installer preflights every managed destination,
backs up only approved legacy states, and refuses unknown real content. It never
modifies alternate-home auth, config, session, database, plugin, or MCP state.
