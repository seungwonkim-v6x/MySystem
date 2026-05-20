# ADR-0008: Activate gbrain as experimental retrieval sidecar

**Status:** Accepted (2026-05-20)
**Context window:** v0.38.0 release
**Related:**
- ADR-0001 (gstack consolidation — gbrain is gstack's sibling tool, same maintainer)
- ADR-0005 (Plugin marketplace + supply-chain unpinned-by-design)
- ADR-0007 (SHA-pin amendment for autonomous SPARSE_SKILLS — pattern extended here to a Bun-installed CLI binary)
- ADR-0006 (Defense-in-depth via PreToolUse hooks — gbrain adds **zero** new hooks, verified at activation)

## Context

After v0.37.0, every gstack skill preamble runs a gbrain-detection branch
that takes the "not configured" path on this machine — silently, on every
skill invocation. The dormant branch is part of gstack's designed memory
architecture; activating it closes a designed-but-disabled gap.

User asked whether to adopt `rohitg00/agentmemory` instead. After
/office-hours + /deep-research + /autoplan with 4 reviewer voices, the
answer is no — gbrain is by the same maintainer as gstack (transitive
trust already extended), has higher retrieval benchmarks (R@5 97.9% vs
95.2%), installs zero new Claude Code hooks (vs agentmemory's 12), and
has no bidirectional CLAUDE.md sync. Full rejection rationale in
`.out-of-scope/agentmemory-2026-05.md`.

The autoplan dual voices (CEO subagent + Codex + Eng subagent + Codex)
unanimously challenged the original "canonical memory layer" framing.
User accepted the reframe to **experimental retrieval sidecar** but
rejected the originally-proposed 30-day search-count kill criteria as
the wrong KPI — gbrain's primary value is **capture itself**, not
retrieval frequency. The conversation/decision/reasoning layer has no
existing home in MySystem; gbrain fills that gap from day 1.

## Decision

### 1. Activate gbrain via PGLite-local path

- **CLI install:** `bun install -g git+https://github.com/garrytan/gbrain.git#bc9f7774bf85c14113d799af73bdb2234a203f3a` (SHA pin, same pattern as ADR-0007 SPARSE_SKILLS but adapted to Bun-installed CLI rather than sparse git clone).
- **Engine:** PGLite (in-process WASM Postgres, zero accounts, ~2s init). Stored at `~/.gbrain/brain.pglite/`.
- **Config:** `~/.gbrain/config.json` (mode 0600, written by `gbrain init --pglite`).
- **MCP registration:** stdio transport, user scope, absolute bin path. Manually written to `~/.claude.json` mcpServers.gbrain (no `claude` CLI present in this VSCode-native environment).
- **Per-remote policy:** `read-write` for github.com/seungwonkim-v6x/mysystem (the source repo for this agent's own config).
- **Permissions:** `chmod 700 ~/.gbrain && chmod 600 ~/.gbrain/config.json` (per Eng-8 finding — secret-bearing dir).
- **gstack-config:** `artifacts_sync_mode=off` (local-only, no cross-machine sync), `transcript_ingest_mode=incremental` (capture going forward, no historical bulk).

### 2. Frame as experimental retrieval sidecar — not "canonical memory layer"

Three layers in the workflow contract retain their authority:

- **CLAUDE.md / ADRs / CONTEXT.md** — hand-curated, never auto-mutated. Level 3b in instruction-precedence ladder (v0.36.0).
- **gstack project artifacts** — frozen per-session output (plans, designs, reviews).
- **auto-memory** — Anthropic's built-in (user/feedback/project/reference memories).

gbrain is **additive, not replacement**. It captures the conversation /
decision-flow / reasoning that no other layer holds. Retrieval
(via `gbrain search`, `gbrain code-def`, `gbrain code-refs`,
`gbrain code-callers`, `gbrain graph-query`) is a side-effect of the
capture, not the primary value.

The "canonical" framing is reserved for layers the workflow contract
**depends on**. gbrain is augment, not dependency — if gbrain disappeared
tomorrow, the 8-step workflow continues. That asymmetry is encoded in the
"sidecar" framing.

### 3. SHA-pin policy (extends ADR-0007 to Bun-installed CLI)

gbrain ships **2-4 minor/patch bumps per day**, with schema migrations
in nearly every minor release, and **no GitHub Releases tags** (versions
live in CHANGELOG + package.json). Tracking `master` is unsafe; pinning
to a specific commit SHA is required.

**Pin format:**
```
bun install -g git+https://github.com/garrytan/gbrain.git#<full-40-char-sha>
```

**Initial pin (this ADR):** `bc9f7774bf85c14113d799af73bdb2234a203f3a`
(captured 2026-05-20T01:12:01Z, gbrain v0.37.0.0, commit `feat(skillpack):
registry cathedral — third-party publish + install + 10/10 quality bar`).

**Refresh process** — adapted from ADR-0007 for Bun-CLI rather than
SPARSE_SKILLS git-clone. Mechanics differ:

1. **Trigger:** tied to `/retro` quarterly cadence (mod-3 month boundary)
   OR on any K-criteria trigger (see section 4) OR on-demand if user
   notices a specific upstream feature they want.
2. **Inspect upstream diff:** use `gh api repos/garrytan/gbrain/compare/<old-sha>..master` rather than local `git log`. Bun caches in `~/.bun/install/cache/` which is not a git worktree.
3. **Read CHANGELOG entries** between pinned and tip. Look for: `breaking`, `BREAKING`, `schema change`, `migration`, `remove`, `rename`, `deprecate`. Quote each verbatim with version + date in the refresh log.
4. **Snapshot baseline:** `jq -c '.hooks // {}' ~/.claude/settings.json > /tmp/v038-hooks-before-<new-sha>.json` before install. **This is the load-bearing K1 check** — gbrain installing a Claude Code lifecycle hook would have to mutate `~/.claude/settings.json hooks`, which this snapshot detects directly.
5. **Install pinned SHA:** `bun install -g git+https://github.com/garrytan/gbrain.git#<new-sha>` then `gbrain --version` to confirm.
6. **Re-snapshot hooks:** `jq -c '.hooks // {}' ~/.claude/settings.json | shasum -a 256` and compare to the baseline hash. Must match exactly. Mismatch ⇒ K1 fires; uninstall (`bun remove -g gbrain`) and rollback.
7. **Run `gbrain doctor`:** acceptable to see same "unhealthy" status as v0.38.0 initial install (resolver_health N/A); any new fail/warn beyond that requires investigation before declaring bump safe.
8. **Smoke test:** put-and-search round-trip. Must succeed.
9. **Record:** add row to "Refresh log" table at bottom of this ADR with old SHA, new SHA, date, upstream commit range, CHANGELOG highlights, hook-diff verdict.

**No auto-update.** Each pin bump is a deliberate decision.

### 4. Kill criteria (revised per Final Gate Option B + user feedback)

Original autoplan plan had a "<5 searches in 30 days → rollback" criterion.
User correctly rejected this as the wrong KPI — gbrain's value is capture
itself, not retrieval frequency. Replaced with safety-only kill criteria:

- **K1 — Hook installed.** Post-pin-bump (or any gbrain reinstall),
  `~/.claude/settings.json` `hooks` diff against baseline shows any
  PreToolUse / PostToolUse / SessionStart / SessionStop / Stop /
  UserPromptSubmit / PreCompact entry added or modified by gbrain.
  Breaks the config-only assumption.
- **K2 — Maintainer disappears.** gbrain upstream silent >90 days
  (no commits) OR Garry Tan visibly leaves gstack/gbrain maintenance.
  Bus-factor-1 risk materializes.
- **K3 — Native equivalent ships.** Anthropic ships native semantic
  memory with comparable conversation-capture surface that materially
  supersedes gbrain. Reassess via fresh /office-hours; rollback if
  reassessment confirms.
- **K4 — Workflow disruption.** Any attributable disruption — skill
  failure caused by MCP timeout, retrieval result acted on incorrectly
  by the agent, PGLite corruption. **One incident → investigate, two →
  rollback.**

**Rollback path:** `~/.claude/scripts/rollback-gbrain.sh` — one command
undoes the runtime state: removes `mcpServers.gbrain` from `~/.claude.json`
(with backup), uninstalls the CLI via `bun remove -g gbrain`, and tars +
deletes `~/.gbrain/` (the corpus delete is gated on a successful backup
tarball — if tar fails, the corpus stays). The script does NOT touch
`~/.claude/settings.json hooks` because gbrain never installs a hook to
begin with (the hook-snapshot baseline at refresh time is a verification
artifact, not a restoration target). After rollback, revert tracked-doc
changes separately: `git revert <v0.38.0-commit>` covers ADR-0008,
`.out-of-scope/agentmemory-2026-05.md`, VERSION, and the CHANGELOG entry.

### 5. Corpus retention policy

PGLite corpus at `~/.gbrain/brain.pglite/` accumulates over time. Without
policy, this is the "memory sprawl" pattern v0.36.0 warned about.

- **Default:** wipe on rollback (rollback script handles this).
- **Quarterly review:** at each /retro mod-3 trigger, before SHA-pin
  bump, also review corpus size (`du -sh ~/.gbrain/brain.pglite`).
  If >500MB and >70% of pages are session transcripts older than 6
  months, prune bulk. Mechanism varies: prefer a gstack-bundled prune
  helper if one exists at refresh time (check
  `~/.claude/skills/gstack/bin/gstack-transcript-prune` first), else
  fall back to per-slug `gbrain delete <page-slug>` for the worst
  offenders, or run `rollback-gbrain.sh` and re-init the corpus from
  scratch.
- **No auto-eviction** — gbrain has its own `consolidate` cycle for
  semantic upsert; that's enough at this scale.
- **Manual delete by slug:** `gbrain delete <page-slug>` for one-off
  removal (note: `gbrain rm` does not exist — confirmed during smoke
  test).

### 6. CLAUDE.md remains untouched

Per the v0.38.0 plan: no edits to `CLAUDE.md`, `setup.sh`, `hooks/`,
`.gitignore`, or `settings.json`. The activation is config-only outside
the tracked repo. All audit information lives in:

- This ADR (immutable record).
- `.out-of-scope/agentmemory-2026-05.md` (rejection rationale).
- `CHANGELOG.md` v0.38.0 entry.
- `~/.gbrain/config.json` (machine-local state).
- `~/.claude.json` mcpServers.gbrain (machine-local MCP registration).

The `/setup-gbrain` skill's Step 8 normally writes a `## GBrain
Configuration` block to CLAUDE.md. **We skipped that step** per the
plan. Future maintenance: re-running `/setup-gbrain` on this machine
would attempt to add the CLAUDE.md block again — manually skip Step 8
or accept a no-op patch.

### 7. Per-worktree `.gbrain-source` pin (deferred)

Skill preambles already check for `.gbrain-source` files at the git
toplevel (kubectl-style per-worktree pin). MySystem itself does NOT
have a `.gbrain-source` file because the corpus is empty initially —
nothing to scope to.

When corpus grows enough to benefit from worktree scoping (e.g.,
working on vProp + MySystem simultaneously and wanting search scoped
to one), run `/sync-gbrain --full` per-worktree to register the
source + create the `.gbrain-source` pin. Defer until that pain is
real.

## Consequences

### Positive

- The conversation / decision / reasoning layer that had no home in
  MySystem's 7 existing layers now has one. Capture-first, retrieval
  as side-effect.
- gstack skill preambles' "GBrain configured" branches now fire on
  every invocation, surfacing prior artifacts where relevant. The
  dormant code paths come to life.
- Supply-chain risk on gbrain is bounded by SHA pinning + the
  quarterly refresh process. Single-maintainer dependency made
  explicit, not hidden.
- agentmemory rejection is recorded with quantitative evidence
  (6-dimension gap analysis); future-Claude reading
  `.out-of-scope/agentmemory-2026-05.md` will see why in 30 seconds.
- No CLAUDE.md changes, no workflow contract mutation. Level-3b
  precedence intact.
- Zero new Claude Code lifecycle hooks. The 5 PreToolUse hooks
  (secret-scanner, dangerous-command-blocker, env-file-protection,
  block-dangerous-git, RTK) remain untouched. ADR-0006 invariants
  preserved.

### Negative

- Bun is now a hard runtime dependency for gbrain (was already a soft
  one for gstack). Bun version drift (we're on 1.3.5; gbrain prefers
  ≥1.3.10) is tolerated but not enforced — verified at activation.
- Machine-local config: ADR-0008 + CHANGELOG ship via git, but
  `~/.gbrain/config.json` + `~/.claude.json mcpServers.gbrain` do
  NOT. Fresh clone on a 2nd Mac will see the documentation but not
  the activation. `SETUP.md` notes the recommendation to run
  `/setup-gbrain` post-clone (per Eng-4 / M6).
- Quarterly SHA-pin review is on the user's manual cadence. Tied to
  `/retro` to make it less likely to be forgotten, but ultimately
  depends on user follow-through. K-criteria triggers cover the
  catastrophic case (hook installed, upstream dead) but routine
  staleness is unprotected.
- gbrain `doctor` reports "unhealthy" (health_score 55) on fresh
  PGLite install because of `resolver_health` checking for
  `skills/RESOLVER.md` (an OpenClaw pattern, N/A for MySystem). This
  is cosmetic — actual capability flags are OK. Documented here so
  future re-runs of `gbrain doctor` don't trigger a false-alarm
  rollback.

## Alternatives Considered

| Alternative | Reason rejected |
|---|---|
| Adopt `rohitg00/agentmemory` wholesale | Worse benchmarks (R@5 95.2% vs gbrain's 97.9%), new maintainer trust surface, 12 hooks added, bidirectional CLAUDE.md sync conflicts with v0.36.0. Full rejection in `.out-of-scope/agentmemory-2026-05.md`. |
| Borrow specific agentmemory patterns (4-tier consolidation, privacy filter) | 6-dimension gap analysis showed gbrain covers each with PARTIAL-but-better-shape or YES. No genuine gap; borrowing would be speculative. |
| Frame as "canonical memory layer" | Both CEO voices unanimously challenged this. Canonical status reserved for layers the workflow contract depends on (CLAUDE.md, ADRs, CONTEXT.md). gbrain is augment, not dependency. |
| 30-day kill criterion based on search count | User rejected. Search count is the wrong KPI — capture itself has value from day 1, retrieval is downstream. Replaced with safety-only K1-K4 triggers. |
| Layer overlap audit before activation | Considered (Challenge 2 in autoplan). User correctly noted the 7 layers don't overlap in retrieval shape (different keys, lifetimes, consumers) — premature optimization. Conversation-layer gap is the genuine unfilled space. |
| Supabase backend (cross-machine sync) | Out of scope for v0.38.0. Requires Personal Access Token with broad scope, project provisioning. Defer until 2nd machine becomes a real need. |
| Skip CLAUDE.md `## GBrain Configuration` block | Chosen. Plan said no CLAUDE.md edits; skill preamble detection works on `command -v gbrain` + `~/.gbrain/config.json` exists, doesn't need CLAUDE.md block. Documentation lives here in ADR-0008 instead. |
| Track gbrain `master` (unpinned) | Rejected. 2-4 bumps/day + schema migrations per minor + no Release tags = silent breakage risk. SHA pinning per ADR-0007 pattern. |
| Stash all gbrain config under tracked `setup.sh` | Rejected. gbrain config involves secrets (database URLs, embedding API keys when used). Machine-local state. Same reason `~/.claude.json` mcpServers isn't tracked. |

## Refresh log

When the SHA pin is bumped, append a row here:

| Date | Old SHA | New SHA | Commits | Hook-diff verdict | Notes |
|------|---------|---------|---------|-------------------|-------|
| 2026-05-20 | (initial) | bc9f7774bf85 | gbrain v0.37.0.0 | clean (hooks unchanged) | Initial activation. Health-score 55 due to N/A resolver_health. Smoke test put/search passed. |

## Implementation evidence

For future reviewers verifying this ADR matches reality:

- `~/.gbrain/config.json` exists, mode 0600
- `~/.gbrain/brain.pglite/` is a PGLite directory
- `~/.claude.json` mcpServers.gbrain = `{"type":"stdio","command":"/Users/seungwonkim/.bun/bin/gbrain","args":["serve"],"env":{}}`
- `~/.claude.json.bak-v038-1779245124` is the pre-activation backup
- `/tmp/v038-hooks-before.json` is the pre-activation hook snapshot (sha256: 4607c437c7b8fe126bd440157afddf473a1447cf4031e2e3f4107cf20cdaa90a)
- `bun pm ls -g | grep gbrain` returns `gbrain@github:garrytan/gbrain#bc9f777`
- Smoke page slug `setup-gbrain-smoke-1779245146` remains in corpus as first ingested entry (delete after corpus has organic content)
