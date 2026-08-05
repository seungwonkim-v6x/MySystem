# ADR-0020: Restore the step scaffolding to the Claude Code surface, without the approval gates

Date: 2026-08-05
Status: Accepted
Amends: ADR-0019 (split the Claude Code and Codex surfaces). The surface split stands; what
ADR-0019 removed from `CLAUDE.md` is partly restored. Does not touch ADR-0017 (Step 6/7
merge), ADR-0018 (no Step 9), or ADR-0006 (hooks).

## Context

ADR-0019 moved the gated workflow contract off `CLAUDE.md` and into
`codex/workflow-contract.md`, leaving the Claude Code surface with Request Lock, the
self-scored-loop ban, and one abstract line of ordering:

```
scope → research → design → implement → test → review → PR
```

That line names *phases*. It does not name which skill owns a phase, it does not carry
the Step 5 verification menu, and it does not carry the Step 6 two-pass review. The owner
reported the consequence directly: the per-step work that used to be visible on the Claude
Code surface is gone, and it needs to come back.

ADR-0019's own measurement is what constrains the shape of the restore. It found that
**71% of course-corrections arrived after code was written**, so the six sequential
approval waits were not catching direction errors, and only **31% of sessions reached
`/ship`**. The gates were the part that measured badly. The step→skill mapping and the
verification/review content were never implicated by that measurement — they were removed
because they lived in the same file, not because they failed.

## Decision

Restore four things to `CLAUDE.md`, and only these four:

1. **Step → Skill Mapping (canonical)** — the table, unchanged in content.
2. **Complete Workflow** — steps 1–8 for the feature branch and the debug branch.
3. **Step 5: Verification — Ask User** — the A–F menu, the automatic
   `/verification-before-completion` augment, the `/aside-qa` browser layer, and the Quick
   Visual Check.
4. **Step 6: Concurrent Two-Pass Review** — `/review` plus `/requesting-code-review`,
   merged into one gate.

Explicitly **not** restored: the `↓ (wait for user approval)` arrows between steps. *Short
Loop*'s rule survives intact — stop and wait only for **PR** and irreversible actions.
This is the whole point of the ADR: the scaffolding is what was missing; the gates are what
ADR-0019 measured and rejected.

Two deviations from a verbatim restore, both recorded because a verbatim copy would have
contradicted text ADR-0019 added and the owner did not ask to remove:

- The mapping's absolutist sentence ("The agent **must** call exactly these skills for
  exactly these steps") is replaced by a scoped one: the table says *which* skill owns a
  step, and *Default Order* still decides whether a step runs. Kept verbatim, it would
  cancel *Default Order*'s "Skip steps to match the weight of the task" and restore the
  gated contract through the back door.
- Step numbering keeps its gaps (no 7, no 9) so that "Step 6" keeps resolving to one
  thing across `CLAUDE.md`, `codex/workflow-contract.md`, ADR-0017, and ADR-0018.

The Codex surface is untouched. `codex/workflow-contract.md` remains the
`AGENTS.global.md` projection source with its gates intact, per ADR-0016's measurement
that Codex — not Claude Code — regressed without them. The two surfaces now overlap on the
step content and differ on the gates, which is the divergence ADR-0019 built the split to
allow.

## Consequences

- `CLAUDE.md` grows from 6,037 B to roughly 12 KB. The always-loaded chain moves from
  ~17.9 KB to ~24 KB. There is no hard budget on this surface — the 32,768 B compatibility
  limit applies to the Codex projection, and `CLAUDE.md` stopped being a projection source
  in ADR-0019, so the growth costs context but breaks nothing.
- Step content is now duplicated across the two surfaces. That is the accepted cost of the
  split; the alternative (re-merging the surfaces) would drag the Codex gates back onto the
  Claude Code surface, which is what ADR-0019 spent a measurement to separate.
- ADR-0019's kill criterion — re-run `scratchpad/drift.py` against the 79%-scope and
  71%-after-code baselines — still applies, and now measures a different configuration:
  scaffolding present, gates absent. If REDIRECT corrections climb back toward 47%, the
  scaffolding is not what was holding scope, and this ADR is the thing to reverse.
- Versioning: `rules/repo-self-management.md` step 7 calls a change to the canonical
  mapping in `CLAUDE.md` a major bump, which would be 1.0.0. Taken as a minor, on the same
  reasoning ADR-0019 used: the mapping's *content* is unchanged — it is being re-added to a
  second surface — and 1.0.0 would assert a stability promise this repo moved into `0.x`
  specifically to avoid.

## Rollback

Delete the four restored sections from `CLAUDE.md`. They remain intact in
`codex/workflow-contract.md`, and `git show ecee83e^:CLAUDE.md` holds the pre-ADR-0019
original including the approval-wait arrows.
