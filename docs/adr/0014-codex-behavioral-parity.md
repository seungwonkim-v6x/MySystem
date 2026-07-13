# ADR-0014: Codex behavioral parity from one canonical workflow

Date: 2026-07-10
Status: Accepted

## Context

MySystem's current Claude workflow had evolved beyond the manually maintained
Codex files. The Codex project `AGENTS.md` still described eight steps while
the canonical workflow had nine, lacked the material-UI discipline, and depended
on a natural-language instruction to read `CLAUDE.md`. Required portable skills
were missing from `~/.agents/skills`, and default Codex hooks were independent
copies.

The product requirement is behavioral equivalence: Codex must show the same
workflow routing, approval stops, skill/tool attempts, and forbidden actions as
current Claude Code. Byte-for-byte runtime equality is neither necessary nor
safe. Auth, history, session state, configuration, databases, plugin state, MCP
credentials, and host metadata must remain provider-owned.

Research against Codex CLI 0.144.1 and Orca 1.4.128 established:

- `$CODEX_HOME/AGENTS.md` is a global instruction source and follows symlinks.
- Global instructions load separately from project discovery's
  `project_doc_max_bytes` budget.
- Codex's user skill location is `~/.agents/skills`; symlinked complete skill
  directories are supported.
- Orca refreshes its merged hooks before a new Codex launch and owns that file.
- Plugin/MCP JSON inventories prove structure, not authentication or live use.

## Decision

Keep `~/.claude` as the only versioned source of truth and generate two
Codex-native projections:

1. `codex/AGENTS.global.md` contains a small Codex terminology adapter plus
   marked canonical sections from `CLAUDE.md`, `operating-principles.md`, and
   `trust-boundaries.md`.
2. `codex/AGENTS.project.md` contains the marked MySystem-only
   `repo-self-management.md` section.

`codex/parity-contract.json` is the narrow machine-readable contract for source
order, output budgets, typed skill ownership, closed capability profiles, hook
requiredness and exact registration, managed paths, compatibility evidence,
approved legacy migrations, and recovery identities. It contains no workflow
prose.

Humans edit canonical prose and the narrow contract. The renderer copies marked
sections verbatim, strips only marker comments, records normalized source hashes,
forbids timestamps, enforces LF/final newlines, cross-checks skill declarations,
and atomically writes byte-stable output. Generated files are never hand-edited.

## Runtime placement

```text
codex/AGENTS.global.md
  -> ~/.codex/AGENTS.md
  -> current/explicit/Orca CODEX_HOME/AGENTS.md

codex/AGENTS.project.md
  -> ~/.claude/AGENTS.md

hooks/ -> ~/.codex/hooks
codex/hooks.json -> ~/.codex/hooks.json
portable skills -> ~/.agents/skills/<name>
```

Only `AGENTS.md` is managed inside alternate homes. Alternate config, hooks,
auth, sessions, databases, plugin state, and MCP state remain read-only. Orca's
merged hooks must contain every required safety semantic tuple but may contain
additional host tuples.

## Skill ownership

- `gstack-generated`: retain gstack's Codex-native generated directory.
- `portable-local`: link a tracked, provider-adapted complete skill directory.
- `portable-sparse`: link the installed sparse complete directory.
- `plugin-profile`: do not link; verify through a named runtime profile.

The core profile is closed and always required. `material-ui`, `browser`, and
`figma` add only their declared plugin/MCP requirements. On supported Orca,
`browser` may use the contract-declared Aside CLI fallback because Orca rebuilds
its host-owned MCP inventory at launch. Structural registration
does not claim authentication; the coordinator performs a non-mutating live
check immediately before use.

## Installation and recovery

The isolated parity installer preflights the complete write set. It installs
absent/correctable links, removes only empty placeholders, and migrates only
files or trees whose exact committed digest is approved. Unknown real content
is preserved and blocks all link mutation. Approved migrations use a durable
transaction and unique adjacent backup. State and lock leaves are opened without
following symlinks. `--recover` restores only when the destination still targets
the recorded MySystem source and the backup matches its recorded content
identity; crash finalization also requires the restored destination identity.

This is recoverable per managed path, not release-atomic. Direct links are
preferred over a copied immutable release store because the reviewed Git
checkout is already MySystem's live canonical state.

## Budgets

The global projection has a MySystem compatibility ceiling of 32,768 bytes with
at least 4,096 bytes total headroom. The project supplement is checked
independently against 32,768 bytes. Behavioral coverage wins over further prompt
reduction; silent truncation and lossy workflow summaries are forbidden.

## Verification

Deterministic CI covers rendering, source closure, marker/declaration errors,
budgets, installer states, unknown preservation, backup/recovery, links, typed
skills, exact hook-contract closure, state-leaf attacks, identity-bound recovery,
doctor profiles, JSON diagnostics, and Linux/macOS portability.

A bounded live suite is a mandatory release gate for ordinary and Orca Codex.
It asserts observable workflow state and harmless hook dispatch, not exact model
wording. It never runs from setup, CI, or SessionStart.

## Consequences

Positive:

- Claude and Codex consume one workflow prose contract.
- Codex instructions are native and survive provider/tool naming differences.
- Safety hooks and portable skills no longer drift as independent copies.
- Setup failures are actionable and unknown user content is not overwritten.

Costs and residual risks:

- Marker and manifest changes must ship together.
- Global prompt weight remains material and is guarded, not eliminated.
- New Codex/Orca versions can change discovery or JSON schemas; the doctor must
  report unsupported/unverifiable states rather than guess.
- Live auth and actual model adherence still require bounded release evidence.

## Alternatives rejected

- Natural-language bridge that asks Codex to read `CLAUDE.md`: weaker than
  native discovery and already drifted.
- Independent hand-maintained Codex workflow: creates a second source of truth.
- Copying Claude runtime state into Codex: unsafe ownership violation.
- General dotfile manager or instruction compiler: disproportionate scope.
- Immutable copied release bundle: stronger release switching but introduces a
  second artifact lifecycle for a personal live-checkout system.

## Supersedes

This ADR supersedes only the Codex-specific loading, budget, and AGENTS deferral
assumptions in ADR-0009. ADR-0009's Claude-native rules decision remains active.
