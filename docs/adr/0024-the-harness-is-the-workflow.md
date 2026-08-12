# ADR-0024: The harness is the workflow — default-deny phase gate in hooks

- **Status**: Accepted
- **Date**: 2026-08-11
- **Author**: seungwon-v6x
- **Tags**: workflow, harness, hooks, enforcement, measurement

<!-- mysystem:managed-start (intentionally empty — reserved for future tooling) -->
<!-- mysystem:managed-end -->

## Context

The owner reported that steps keep being skipped and code gets written directly.
Investigation this session found the report correct and the cause structural: every
previous attempt to fix it was **prose**.

| Config window | Step 1 ran before the first edit |
|---|---|
| pre-ADR-0015 (rule present) | 46% |
| ADR-0015, rule deleted | 8% |
| ADR-0016, rule restored | 62% |
| ADR-0019, rule deleted again | 0% |
| ADR-0020, restored as description only | 0% |
| ADR-0021, rule restored | 31% → **57%** |

```
corpus  2026-08-06T20:03 .. 2026-08-11T11:28   21 counted of 275 seen
        excluding: claude-501, scratchpad   generated 2026-08-11T11:38
```

Quote that corpus line with any number above or the number means nothing; the
transcripts are retention-pruned and `scripts/measure-step1.py` undercounts a
typed skill, so every figure is a floor.

The direction is consistent across three removals and three restorations: prose
present 46-62%, prose absent 0-8%. Prose reaches roughly half and stops. A sixth
prose attempt was drafted this session (restoring the 2026-05 approval waits to
`CLAUDE.md`) and abandoned in favour of this one, because it would have been the
fifth reversal of the same decision using the same lever.

Meanwhile `rules/operating-principles.md` → *Harness, Not Model* has said since
v0.35.0 that prompt-only rules rot under context pressure and that every CRITICAL
RULE should aspire to a paired harness enforcement. `hooks/` contained **zero**
workflow enforcement: four safety hooks (all dry-run) and four utilities. The
principle and the implementation disagreed for nine months.

**Prior art was searched before building.** No widely-used workflow repo enforces
step order in code. BMAD-METHOD encodes order in `step-XX-*.md` shards, GitHub
Spec Kit gates four phases at the prompt level, Agent OS and OpenSpec chain
markdown artifacts, and obra/superpowers injects a prompt from a `SessionStart`
hook — all prose. `tdd-guard` does use a `PreToolUse` hook, but its validator
invokes a separate Claude session to judge TDD adherence, which relocates
discretion rather than removing it (ADR-0023 rejected it for the same reason).
Most pointedly, obra/superpowers issue #384 proposed almost exactly this design —
*"Add a hook that fires before `Edit` or `Write` tools on non-test files"*,
checking whether the skill ran first, *"requires session state tracking"* — and is
**closed as not planned**, with no recorded reason. Read charitably, this design is
not novel out of ignorance. Read uncharitably, there is no prior implementation to
copy and no one else's bug reports to learn from. Both are true.

**The design inversion.** ADR-0023 declared `Bash` write-detection unsolvable and
was right about *blocklists*: `prettier --write`, `make`, `git apply`, `patch`,
`perl -pi`, `> "$f"` defeat any pattern list. gstack's own `/careful` hook is the
field evidence — its comments record patching for BSD capital `-R` and then for
command substitution ending in an allowlisted suffix
(`rm -rf $(./wipe-all)/node_modules`). So this gate asks the opposite question:
**what is allowed right now?** A phase determines an allowlist and everything else
is denied. That inverts the failure direction — a wrong allowlist blocks
legitimate work, which is visible and recoverable in one keystroke, instead of
silently permitting a skipped step, which is the failure being fixed. It is also
what removes model discretion: there is nothing left to interpret.

**Measured on CLI 2.1.227, 2026-08-11**, with probe hooks in two isolated
projects, all runs under `--dangerously-skip-permissions`:

| Question | Result |
|---|---|
| Does a `deny` from one `PreToolUse` hook win over another's `allow`? | **Yes.** Both fired in the same second (parallel confirmed); the write did not happen |
| Does deny hold under `bypassPermissions`? | **Yes** |
| Does `Skill` fire `PreToolUse`? | **Yes** — `code.claude.com/docs/en/hooks` says "Skill tool matchable: No" and is still wrong |
| Is `prompt_id` on the payload? | **Yes**, with `session_id`, `permission_mode`, `effort`, `cwd`, `transcript_path`, `tool_use_id` |
| Does a **user-typed** `/skill` fire `Skill` hooks? | **No.** The skill ran while Pre/PostToolUse counts stayed 1 → 1 |
| Does `UserPromptSubmit` see the typed command? | **Yes** — `prompt: "/probeskill"` plus `prompt_id` |

The docs also state *"All matching hooks run in parallel"* with no ordering
guarantee, so no hook may assume it runs after another. Re-run the probes if the
CLI minor version moves past 2.1.227; the whole design rests on them.

## Decision

Enforce the workflow in code: one state file, one recorder, one gate, one CLI.

**State.** `~/.local/state/mysystem/steps/<session_id>.json` holds `phase`,
`phase_prompt_id`, `current_prompt_id`, the recorded steps, and `bypass_prompt_id`.
Written atomically (temp + `os.replace`, so a reader never sees a torn file) with
O(1) reads and no transcript parsing. Writes are serialised by an atomic-`mkdir`
lock: an earlier draft assumed one writer per session and review disproved it —
the model emits parallel tool calls, so the two Step-6 review passes raced and
dropped one entry, pinning the phase at 5 so `/ship` never unlocked.
ADR-0023 named this `(session_id, prompt_id)` marker as the viable mechanism; this
is it.

**`hooks/record-step.py`** — `PostToolUse` on `Skill` and on the write tools, plus
`UserPromptSubmit`. Records only; never denies. All three registrations are
required: a typed `/scope-check` fires no `Skill` hook, so a recorder watching only
`Skill` would leave the gate denying an owner who complied.

**`hooks/gate.py`** — `PreToolUse` matcher `*`. Computes the phase's allowlist and
denies the rest, via JSON `permissionDecision: "deny"` (the form measured to hold
under `bypassPermissions` and to win over another hook's allow).

| Phase | Reached by | Adds |
|---|---|---|
| 0 | session start | the three Step-1 skills |
| 1 | a Step-1 skill | `/deep-research` |
| 2 | `/deep-research` | `/autoplan` |
| 3 | `/autoplan` | the write tools, `/frontend-design` |
| 4 | the first write | the Step-5 skills and augments |
| 5 | a Step-5 check | `/review`, `/requesting-code-review` |
| 6 | **both** review passes | `/ship`, `git commit`/`push`, `gh pr create` |
| 7 | `/ship` | terminal; the next request resets to 0 |

Read-only tools are never gated, so investigation before Step 1 stays free — which
is what makes Step 1 answerable instead of blind.

**Amendment, same day, after the Step-6 review: `Bash` is not gated at all.** The
first version default-denied it before phase 3 behind a read-only allowlist.
Adversarial review walked through that allowlist five independent ways — `sort -o`,
`uniq in out`, `tree -o`, `git diff --output=`, `git config` (including
`--global`, and `core.hooksPath`, which redirects every future git hook), and
`bats`, which is arbitrary shell with the `*.md` carve-out supplying the script —
and `os.path.basename(argv[0])` accepted a file merely NAMED like an admitted
binary. The allowlist's own comment asserted "nothing enters unless it cannot write
with ANY argument" and was false in the commit that wrote it.

The lesson is about the design, not the entries. Default-deny inverts the
*default*, but an allowlist still has to know every write path of every admitted
command — the same losing game ADR-0023 named, only smaller. So the allowlist is
deleted rather than patched, and the consequence is recorded rather than hidden:
**the write gate is enforcing for `Write`/`Edit`/`MultiEdit`/`NotebookEdit` and
advisory against `Bash`.** A model that wants to write before phase 3 can
`cat > file`. ADR-0023 had already concluded Bash write-detection is unsolvable;
this applies that conclusion instead of working around it.

What `Bash` is still gated on is **publishing** — `git commit|push|tag|am|apply|
rebase|merge|reset`, `gh pr create|merge|…`, `gh release …`, and `gh api` with a
mutating method. That is a small closed set rather than an open-ended "can this
write" question. The check scans past global options, because review showed
`git -C . commit`, `git -c user.name=x commit`, `git --no-pager push` and
`gh api -X POST …/pulls` all sailing through a version that read `tokens[1]` only.

**Transitions end the turn.** Advancing requires
`phase_prompt_id != current_prompt_id`. This is fb35992's "After presenting
results, STOP and wait" as a comparison rather than a sentence, and it restores the
`## Workflow Successor Map` state machine that ADR-0019 dropped. Entering phase 4
by writing deliberately does **not** stamp `phase_prompt_id`, so writing code and
verifying it in one turn stays possible.

**Step 2 is gated like the rest, which settles a conflict prose could not.** The
CLI injects "Do not use workflows or deep-research unless the user requested it" as
an Opus-5 prompt-bundle default (binary fallback behind internal gate
`tengu_heron_brook`; absent when the model is not in `opus_5_prompt_bundle`).
ADR-0021:41-45 concluded that repo prose cannot outrank a provider default. A
denial does not need to: the model attempts `/autoplan`, the gate refuses and names
`/deep-research`, and the conflict resolves the same way every time, at the point
of decision. This ADR therefore does **not** add a line claiming the vendor default
is void — that claim was drafted this session and dropped as unfounded.

**Carve-outs, computed and never judged.** Docs paths (`docs/**`, `*.md`,
`CHANGELOG.md`, `VERSION`, `.gitignore`, `tests/fixtures/**`) are writable in any
phase. An `Edit` differing by ≤ 1 line and ≤ 40 characters passes in any phase —
`CLAUDE.md`'s existing triviality carve-out as arithmetic. Asking the model whether
something is trivial would hand back the discretion this ADR removes. ADR-0023
named the absence of these as a decisive objection to the previous attempt.

**Escape hatch.** The owner types `gate: off`, keyed to that `prompt_id`, so it
expires with their next message; `gate: reset` starts a new cycle. The form matters:
end-to-end testing found that a leading `/` is resolved by the CLI as a command and
an unknown one is rejected with "Unknown command" before the prompt is submitted, so
`/gate-off` never reaches the hook. The unit tests missed this because they feed the
hook directly and skip the CLI's command parsing — the argument for keeping an
end-to-end tier rather than trusting green units. Never an env
var: ADR-0023's objection was that an env var is how a guard gets switched off
permanently. Only `UserPromptSubmit` can arm it, so text the model emits cannot.

**Enforcing by default**, unlike the safety hooks, because the owner asked for it
to bind. `MYSYSTEM_GATE_DRYRUN=1` logs without enforcing. Every decision, allow or
deny, lands in `~/.local/state/mysystem/gate-log.jsonl`, and
`scripts/mysystem-steps status|explain|reset|sessions` makes a false deny
explainable — without it the only recourse is disabling the guard, the failure
ADR-0023 predicted.

**Crash-open, decision-closed.** A crash in the gate fails open so a bug cannot
brick a session. A deliberate refusal (wrong phase, unparseable command) is a
decision and is returned. An unparseable `Bash` command is denied, not allowed;
failing closed there is the point of the allowlist.

Supersedes the no-gate portions of ADR-0019, ADR-0020 and ADR-0021, and supersedes
ADR-0023's decision to hold the enforcement hook. ADR-0023's Step-1 rewiring and
its measured findings stand.

## Alternatives considered

- **A sixth prose patch** (restore the 2026-05 approval waits to `CLAUDE.md`) —
  drafted in full this session, reviewed, and dropped. It would have been the fifth
  reversal using the lever that measured 46-62% and stopped. The review also found
  it contradicted itself in seven places and required rewording a line byte-locked
  to the Codex contract, which would have revived the 95-byte projection limit.
- **A hard rollback to the 2026-05 `CLAUDE.md`** — rejected. That file predates
  Request Lock, and ADR-0021 already judged the trade: 79% of logged corrections
  were scope, so deleting Request Lock to recover step compliance swaps a bigger
  measured problem for a smaller one. It also doubles always-loaded context.
- **Per-request context re-injection** (ADR-0023's designated first resort) —
  viable and cheaper, not chosen: it answers decay without removing discretion, and
  the owner asked for enforcement rather than reminding.
- **Blocklist-style `Bash` detection** — rejected, see the inversion above.
- **`tdd-guard`** — rejected; an LLM judge inside the hook.
- **BMAD-style step sharding** (withhold the next step's instructions rather than
  deny tools) — a genuinely different lever, orthogonal to this one, deferred. It
  reduces discretion without a false-positive surface and is the natural next
  iteration if this gate proves noisy.

## Amendment 2 — stripped to the core that survived review

Three review rounds, each finding Criticals in the code written to fix the previous
round's Criticals. Every break had the same shape: **a predicate over an open-ended
space, written by the author, believed complete.**

| Round | What broke |
|---|---|
| 1 (in-session) | lost update on the marker — no lock |
| 1 (fresh context) | read-only `Bash` allowlist (5 write paths), `docs/..` traversal, a test helper reading a stale log line |
| 2 (fresh context) | publishing allowlist (6 bypasses incl. `sh -c`), `is_trivial_edit` (0.6 ratio admits any logic flip), Step-6 conjunction poisoning, symlink laundering, concurrent stale-lock reclaim |

The single most damning finding: `PUBLISH_UNLOCK_PHASE = 6` → `= 0` was permitted at
phase 0 through the trivial-edit carve-out, because carve-outs were evaluated **before**
the phase check. The gate could switch off its own threshold before Step 1 ran.

So the predicates are deleted, not sharpened:

- **Publishing gating: gone.** `sh -c 'git commit'` alone defeats any such predicate, and
  a command prefix, subshell, alias, `git revert`, or `gh api -f` (implicit POST) defeat
  the rest. `Bash` is now ungated entirely.
- **The trivial-edit carve-out: gone.** `gate: off` covers a real typo without a
  predicate to beat.
- **The docs carve-out: narrowed** to named files plus the repo's own `docs/`, resolved
  with `realpath` and confined to the invoking repo. The blanket `*.md` had made
  `~/.claude/skills/**/SKILL.md` writable, and those are instructions this agent executes.
- **`steps` is appended only after the ordering check passes**, so a rejected out-of-order
  skill cannot satisfy a later conjunction.
- **Payload fields are coerced before use.** `session_id` and `tool_name` came from the
  payload and were used before any coercion; `tool_name in WRITE_TOOLS` on a list raised
  `TypeError` while building the log entry, *after* the deny was computed, and the
  crash-open handler emitted an allow. That is the third appearance of one shape: a
  correct deny lost to an exception on its way to the log.
- **The stale-lock reclaim is serialised** with an `O_EXCL` marker. The staleness check
  and the removal were not atomic, so several contenders each removed whatever sat at the
  path — including a peer's brand-new live lock. Measured 120 mutual-exclusion violations
  in 400 trials with 4 contenders; the normal non-stale path measured 0/400 throughout.
  Both paths now measure 0/400.

**What the gate claims after this amendment** is only step order, the turn boundary, and
write-tool denial before phase 3 — the three no reviewer broke. It is a smaller claim than
this ADR originally made, and it is the honest one.

## Consequences

- ✓ The workflow's sequence is now a check that returns pass/fail. 59 new tests
  across `tests/gate-phases.bats`, `gate-bash-allowlist.bats`,
  `gate-transition.bats`, `gate-carveouts.bats`, `record-step.bats`; the full suite
  is 199 green.
- ✓ Tests assert the gate's `rule` name from the log, not the deny prose, so
  wording stays free to improve while policy does not drift.
- ✓ The command shape that escaped gstack `/careful`'s whitelist
  (`rm -rf $(./wipe-all)/node_modules`) is refused here, because unparseable input
  fails closed.
- ✓ **Throwaway verification found six openings that the contract tests could
  not.** Two classes, both fixed before shipping and pinned by
  `tests/gate-robustness.bats`. First, malformed input read as permission: because
  the gate fails open on a crash, a `TypeError` from a bad marker (`[1,2,3]`, a
  `phase` of `"3"`, a numeric `file_path`) silently disabled enforcement — so
  `load()` now sanitises every field and `as_text()` coerces tool inputs. Second,
  three entries in the read-only allowlist could write with no redirection to
  notice: `sed -i`, `awk '{print > "f"}'`, and `env make`; they are removed,
  `find` is action-checked, and `python3` is narrowed to repo script paths. The
  lesson is recorded in the set's comment as an admission rule — nothing enters
  `READONLY_BASH` unless it cannot write with any argument. A default-deny design
  moves the entire risk into the allowlist, so the allowlist is the thing to
  attack, and unit tests that feed the hook directly will not do it.
- ✓ The Codex projection is unchanged at 32673 bytes: only a stripped HTML comment
  changed on that surface.
- ✓ **The Step-6 review found eight Critical defects that three earlier tiers
  missed, and one of them explains the other seven.** `tests/helpers/gate.bash`
  read the LAST line of `gate-log.jsonl`; a crashing gate writes no line, so the
  helper reported the PREVIOUS call's verdict and the test passed. Every
  multi-assertion loop in the suite shared it, and it was masking a Critical
  fail-open where a non-dict `tool_input` crashed `log_decision` after the deny
  was computed, so the crash handler turned the deny into an allow. The suite was
  green for the wrong reason, which is why the allowlist holes felt covered.
  Stdout is now the source of truth and a missing log line is a failure.
  Also closed: `docs/../hooks/gate.py` passing as a docs write (path normalisation
  now applied, `tests/fixtures/` dropped from the carve-out since it can hold
  code); a typed `/autoplan` jumping to phase 3 with steps 1-2 never run (the
  ordering predicate is applied in `record_skill` too, because a typed skill never
  passes `PreToolUse`); a `Skill` payload with no `prompt_id` opening the turn
  boundary; `is_trivial_edit` accepting two lines and bounding only the NET length
  change, so `if not user.is_admin: raise` → `if True: pass` counted as a typo.
- ✓ **Live nested sessions were the only tier that found the usability defects.**
  Three false positives surfaced only by letting a real model type real commands:
  test runners denied at phase 0 (which pushed the model to request `gate: off`
  for something routine — the bypass-habit route ADR-0023 warned about), `2>&1`
  shredded by splitting on every `&`, and `2>/dev/null` counted as a file write.
  All three are fixed and pinned. The tier ordering that worked was contract tests
  → throwaway edge cases → live sessions, and each tier found a class the previous
  one structurally could not: synthetic payloads never contain what a model
  actually writes.
- ✓ Observed model behaviour under a deny is what the design wants: it states the
  phase, names the skill that advances it, declines to bypass on its own, and hands
  the choice to the owner. A docs edit and a one-character typo fix both completed
  in a single turn with no gate friction, so the carve-outs work in the wild.
- ✗ **`Bash` is an open door for writes before phase 3, by decision.** Stated in
  `CLAUDE.md` as a rule the agent follows rather than one the harness enforces.
  Anyone who wants it closed has to solve what ADR-0023 called unsolvable first.
- ✗ **The old Bash gating would have produced false positives too.** Build
  and test commands are blocked until `/autoplan` completes. `BASH_UNLOCK_PHASE` is
  a single named constant so the fix is one value, not a redesign.
- ✗ **The harm metric is still missing.** Success here is measured by invocation
  rate, which has no harm term — ADR-0023's objection, unsolved.
  `scratchpad/drift.py` is gone from disk. Reconstructing it remains the more
  valuable measurement and is not done.
- ✗ **Only sequence and presence are enforced, never quality.** A hook fires on
  calls the model already made, so it cannot cause an invocation. Which Step-1
  skill fits, whether `/deep-research` actually researched, and writes made by a
  subprocess a phase-3 session spawns are all outside it. Claiming "no model
  discretion" beyond that would be false.
- ✗ A follow-up request mid-workflow inherits the unlocked phase; only `/ship` or
  `/gate-reset` starts a new cycle. Resetting on every prompt would demand
  re-running Step 1 for every follow-up message. Tested and documented as a limit
  rather than hidden.
- ? Whether the gate survives contact with real sessions, or gets `/gate-off`-ed
  daily. The log answers this on 2026-08-18.

**Review on 2026-08-18.** Read `gate-log.jsonl` and classify every deny as a
genuine skip or a false positive. Above ~1 false positive per 20 sessions means an
allowlist is wrong — widen `READONLY_BASH` or move `BASH_UNLOCK_PHASE`. Do not
disable a gate to fix a false positive.

**Kill condition, pre-registered for 2026-09-11.** Re-run
`scripts/measure-step1.py` over sessions since this shipped and read the log.
Revert the gates if either the Step-1 rate is not above the 57% floor, or the owner
reports them as friction. Quote the corpus line with any number.

## References

- Related ADR: ADR-0015 (built and deleted `tier-guard`), ADR-0016, ADR-0019
  (split the surfaces), ADR-0020, ADR-0021 (mandatory invocation; recorded the
  vendor-default conflict as unsettled), ADR-0023 (rewired Step 1, held this hook,
  measured `Skill` matchability)
- Code: `hooks/gate.py`, `hooks/record-step.py`, `hooks/mysystem_steps_lib.py`,
  `scripts/mysystem-steps`, `settings.json`, `CLAUDE.md`,
  `codex/workflow-contract.md`
- Tests: `tests/gate-phases.bats`, `tests/gate-bash-allowlist.bats`,
  `tests/gate-transition.bats`, `tests/gate-carveouts.bats`,
  `tests/record-step.bats`, `tests/mandatory-invocation.bats`
- Prior art: obra/superpowers issue #384 (closed as not planned), `nizos/tdd-guard`,
  BMAD-METHOD workflow map, GitHub Spec Kit, gstack `freeze/bin/check-freeze.sh`
  and `careful/bin/check-careful.sh`
- Vendor docs contradicted by measurement: `code.claude.com/docs/en/hooks`
  ("Skill tool matchable: No")

## How this file is maintained

- ADR numbering is monotonic per project. Don't reuse numbers; mark superseded instead.
- Rewrite history only by adding a new ADR that supersedes the old one.
- An ADR is deliberate. Don't auto-generate from PR descriptions.
