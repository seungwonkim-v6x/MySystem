# MySystem — Working Agreement

## Request Lock (the load-bearing rule in this file)

**The user's request sentence is the scope.** Research may discover anything; the
request does not change because of it.

- Additional items you find are **not built**. List them at the end as one line
  each under "Not done".
- No refactoring, redesign, routing changes, file moves, or added features that
  were not requested.
- If the scope genuinely needs to widen, **ask before widening**. Never widen and
  then report it.
- When feedback arrives, apply **that feedback only**. Do not fix adjacent things
  in the same pass.

### No self-scored improvement loops

A loop that scores its own output and then works to raise the score has no stopping
point at "what was asked" — the metric only rewards more. Measured: unguided
self-refinement gains ≤1.8pp over five iterations and often degrades output, while
externally-guided feedback gains up to 80% (arXiv 2310.01798, 2508.12903).

- `plan-design-review`'s `## The 0-10 Rating Method` ("if it's not a 10 … do the
  work to get it there", "repeat until 10") and the same pattern in
  `plan-devex-review` / `ios-design-review` are **off** unless the user asks for
  that skill by name. `/autoplan`'s "all 7 dimensions, full depth" does not run by
  default.
- Where a skill prints `Completeness: X/10` on choices, the score rates coverage
  **inside** the locked scope. A bigger scope is not a higher score, and the
  requested scope is never labeled a "shortcut".
- **Every loop needs an exit that is not "the user interrupts."** State the exit
  before starting one, and stop there. Not-a-10 is a valid, finished result. For an
  unattended loop, put the exit in code — a `/goal` condition or a Stop hook, both
  of which stop on an external check rather than on a self-assessment.

**Named override — gstack skills argue against Request Lock.** Every gstack skill
injects `## Completeness Principle — Boil the Ocean`, whose claim is that
"the only thing out of scope is genuinely unrelated work".
Request Lock supersedes it: work that is *related* but not *requested* is out of scope. Their `Confusion Protocol` (stop and
ask on high-stakes ambiguity) is kept and encouraged.

## Critical Workflow Rules

The agent has ZERO discretion to skip or reorder workflow steps. Every step is MANDATORY and runs in order. NEVER skip, reorder, or suggest skipping. NEVER write code before `/autoplan` is done — not even one line. NEVER ask the user "should we skip?" or "do you want to run the full workflow?" — just run the next step. If the user wants to skip, THEY interrupt; that is their job, not yours.

**Skill whitelist.** The agent may autonomously invoke only skills mapped to workflow steps below. Any other installed skill (`/design-shotgun`, `/scrape`, `/codex`, `/humanizer`, `/qa`, etc.) runs **only when the user types its name**. Do not proactively suggest off-workflow skills. IF A WHITELISTED SKILL APPLIES TO THE CURRENT REQUEST AT THE FEATURE / BUG FIX / REFACTOR LEVEL, YOU MUST INVOKE IT BEFORE RESPONDING. Even minimal probability requires invocation.

**Triviality carve-out (conservative).** Direct-to-implementation is permitted ONLY for: typo fixes, single-character edits, comment-only changes, single-symbol renames via Edit, or work the user explicitly framed as "trivial". Anything touching behavior or adding a file → invoke the step.

**Autonomous (in whitelist).** `/verification-before-completion` (Step 5 augment; applies
even on F/Skip), `/aside-qa` (browser layer for Step 5 / Quick Visual Check),
`/frontend-design` (Step 4 design discipline — **materiality-gated**: fires only on a *new
UI or reshaping of existing UI*, NOT on any UI file touched or a one-line CSS tweak).

**The harness enforces this, not your judgment (ADR-0024).** A `PreToolUse` gate
(`hooks/gate.py`) enforces exactly three things, and they are the three that survived
three rounds of adversarial review untouched:

1. **Step order** — a step may only advance the phase it is next for.
2. **The turn boundary** — a second step in the same turn is denied, so you present
   results, end the turn, and the owner's reply lets the next step run.
3. **`Write`/`Edit`/`MultiEdit`/`NotebookEdit` are denied before phase 3** (after
   `/autoplan`). The repo's own `docs/` tree and `CHANGELOG.md`/`VERSION`/`TODOS.md`/
   `CONTEXT.md`/`.gitignore` stay writable, resolved through symlinks and confined to
   the invoking repo.

**Everything else is a rule you follow, not one the harness enforces.** `Bash` is
ungated, so writing code or publishing through it evades the gate — do not. Three review
rounds each broke a predicate added around the core (a read-only `Bash` allowlist, then a
publishing allowlist, then an "is this edit trivial" test), so those predicates are gone
rather than sharpened a fourth time.

Run `~/.claude/scripts/mysystem-steps status` for the phase and `… explain` for the last
denial (not on `PATH` — use the full path). Only the owner may type `gate: off` (that one
request) or `gate: reset`, as plain text — a leading `/` is resolved as a CLI command and
rejected before the harness sees it.

Request Lock still binds inside every step. A mandatory step is a mandatory *step*, not a
license to widen what that step is about.

## Default Order

```
scope → research → design → implement → test → review → PR
```

Research is not the thing to cut. Only stop research from widening the scope.

For a genuinely large feature, `/autoplan` is not enough on its own: also interview the
user with `AskUserQuestion`, write a self-contained spec that names the files involved,
**states what is out of scope**, and ends with an end-to-end verification step — then
implement it in a fresh session.

## Step → Skill Mapping (canonical)

| Step | Skill (slash command) | Source |
|------|------------------------|--------|
| 1. Frame the request | `/scope-check` — the default. A change to code that already exists | user-owned (ADR-0023) |
|    (new idea) | `/office-hours` — only when the thing does not exist yet, or "is this worth building" | gstack |
|    (debug branch) | `/investigate` — a defect whose cause is unknown | gstack |
| 2. Research | `/deep-research` | vendored, provider-pluggable (ADR-0011) |
| 3. Plan + multi-review | `/autoplan` | gstack |
| 4. Implementation | direct (coordinator writes code); on a **material UI change** also load `/frontend-design` + the project `DESIGN.md` rider | Anthropic plugin (frontend-design) + user rider |
| 5. Verification | `/verify-test` and/or `/qa-only` and/or `/design-review` | user-owned (verify-test) + gstack |
|    (Step 5 augment) | `/verification-before-completion` | sparse cherry-pick obra/superpowers — Iron Law: no completion claims without evidence |
| 6. Concurrent two-pass review (one gate) | `/review` (in-session, context-rich structural) **+** `/requesting-code-review` (parallel fresh-context subagent) — run concurrently, findings merged into a single approval gate | gstack + sparse cherry-pick obra/superpowers |
| 8. Ship | `/ship` | gstack |

The agent **must** call exactly these skills for exactly these steps. Substituting "a
similar gstack skill" or "a quick manual pass" is forbidden.

**Step 1 is exactly one of `/scope-check` (default — existing codebase, including a new file in it), `/office-hours` (a new product, not a new file), `/investigate` (unknown cause). None of them is a skipped step.**

## Complete Workflow

### Feature / Bug Fix / Refactoring

```
1. /scope-check        frame the request (/office-hours if the thing is new)
2. /deep-research      docs, codebase, web, existing solutions
3. /autoplan           plan + CEO/Design/Eng review
4. Implementation      coordinator writes the code
5. Verification        ask the user which check to run (see below)
6. Concurrent review   /review + /requesting-code-review, findings merged into ONE gate
8. /ship               commit, push, create PR (terminal step)
```

**Each step transition ends the turn.** Present the step's results and stop; the owner's
next message is what lets the following step run. This is not advice — `hooks/gate.py`
denies a second step invoked inside the same turn (ADR-0024). Step 7 is folded into Step 6
(ADR-0017); there is no Step 9 (ADR-0018). The numbering is kept so that references to
"Step 6" keep meaning one thing.

### Debugging

```
1. /investigate  →  2. /deep-research  →  3. /autoplan  →  4. Implementation
                 →  5. Verification    →  6. Concurrent review  →  8. /ship
```

Step 1 follows the ranked-falsifiable-hypotheses rule in *Short Loop* → **Debugging**.

## Step 5: Verification — Ask User

**This menu picks the step's content, not whether it runs.** The Verification step always
runs; the menu is a within-step choice. `F` does not skip Step 5 — it runs it with no
functional check, and `/verification-before-completion` still fires. So *Critical Workflow
Rules*' "NEVER suggest skipping" (which governs whole steps) is not in tension with asking
here. The gate agrees: Step-5 skills unlock only at phase 4, once a write has actually
happened, because verifying an implementation that does not exist yet is not verification.

After implementation, present these options:

> Which verification should we run?
>
> **A) All** — `/verify-test` + `/qa-only` + `/design-review` (when UI changed)
> **B) `/verify-test` only** — throwaway code test
> **C) `/qa-only` only** — browser-driven flow check
> **D) `/design-review` only** — designer's-eye visual QA
> **E) Both functional** — `/verify-test` + `/qa-only`
> **F) Skip** — proceed directly to Step 6 (concurrent review)

Drop `/design-review` from A and D automatically when the change has no UI surface (pure
backend, refactor, infra). Wait for the user's choice, then execute.

**Automatic Step-5 augment.** Whichever option the user picks (A/B/C/D/E), also invoke
`/verification-before-completion` (Iron Law: no completion claims without fresh
verification evidence). It runs orthogonally — it cross-checks any "I tested it" / "this
works" claim from Step 4. Invoke it on F (Skip) too. Autonomous — do not ask whether to
run it.

**Browser layer.** All browser-driven verification (`/qa-only`, `/design-review` browser
actions, Quick Visual Check) drives the browser via `/aside-qa` (real logged-in session,
full Playwright API). gstack `/browse` is the fallback for public unauthenticated pages
or when aside is unavailable — announce the fallback, never switch silently.

**Quick Visual Check (pre-Step-5, when UI changed).** Before presenting the menu:
(1) `git diff --name-only` filtered to UI files, (2) navigate to affected pages via
`/aside-qa` (attach to an open tab first; `openTab` only when none matches), (3) verify
project design constraints (`DESIGN.md`), (4) full-page screenshot at 1440px desktop,
(5) capture console messages. Screenshot + console become inputs for the user's choice.
Skip entirely on pure backend/docs/config changes.

## Step 6: Concurrent Two-Pass Review (one gate)

Both passes run concurrently and present **one** approval gate (ADR-0017). They catch
different bug classes and both MUST run:

- **`/review` (gstack)** — runs **in-session** (context-rich): knows the plan and repo
  invariants. Targeted structural analysis: SQL safety, LLM trust boundaries,
  conditional side effects. Catches "violates a known invariant / unsafe against our
  schema / diverges from the plan."
- **`/requesting-code-review` (superpowers)** — dispatched as a **parallel fresh-context
  subagent** on `BASE_SHA..HEAD_SHA` (never the session history). Open adversarial
  re-read: Critical / Important / Minor. Catches what the author — and a context-sharing
  reviewer — is blind to.

**Execution:** launch both concurrently, then **merge and dedupe findings into one table
and present ONE approval gate.** A clean `/review` does not excuse skipping the fresh
pass; both must complete before the gate.

Step 6 reviews the **pre-merge diff**, and it is the only review gate. There is no
post-PR review step (ADR-0018 removed it): if a PR-attached bot reviewer posts findings
worth acting on, read them and decide by hand.

## Short Loop

- Before building, restate your understanding in three lines. If any part is
  ambiguous, ask it as a multiple-choice question. Spend the question budget on
  verifying the spec before building, not on taste after.
- Make the first result as small as possible, as fast as possible, and show it.
  The user's reaction is the next input.
- **Give yourself a check that returns pass or fail** — a test, a build, a
  screenshot to compare. Without one, the user is the verification loop and every
  mistake waits for them to notice it. Show the evidence, don't assert success.
- After two failed corrections on the same issue, stop correcting. `/clear` and
  restart with a prompt that incorporates what was learned.
- Stop at **each step transition**, at **PR**, and before **irreversible actions**. The
  first of those is enforced by `hooks/gate.py`, not left to you (ADR-0024).

## Safety (enforced in code)

- Never weaken a hook, `settings.json` matcher, or safety rule to get unblocked —
  fix what it reports. Bypass is human-only.
- **Never install PostToolUse hooks that mutate git state** (`git add/commit/push`,
  `gh pr create`, any write to `.git/`). Git mutations happen via `/ship` or an
  explicit user request only.
- Commits are scoped to a single logical change, not a single file. Bundle related
  edits into one commit.

## Skills

Workflow skills — the autonomous-invocation whitelist (see *Critical Workflow Rules*):
`/scope-check`, `/office-hours`, `/investigate`,
`/deep-research`, `/autoplan`, `/verify-test`, `/qa-only`, `/design-review`,
`/review`, `/requesting-code-review`, `/verification-before-completion`, `/ship`.

Any other installed skill runs only when the user types its name.

Browser work goes through `/aside-qa` (real logged-in session); gstack `/browse`
is the fallback for public pages — say so when you switch.

On a **new UI or a reshaping of existing UI**, load `/frontend-design` and the
project `DESIGN.md` together. The rider's bans always apply; `/frontend-design`
wins on taste.

Do not claim work is complete without fresh verification output.

**Debugging.** Before instrumenting anything, generate 3-5 ranked, **falsifiable**
hypotheses and show the ranked list: each one disprovable by a concrete
observation, ordered by prior probability rather than ease of testing, and distinct
in root cause. After three failed fix attempts, question the architecture rather
than the current attempt.

## Project Knowledge

- `<repo>/CONTEXT.md` (living glossary) and `<repo>/docs/adr/NNNN-<slug>.md` (one
  ADR per non-trivial decision). Templates in `~/.claude/templates/`.
- Memory: `~/.claude/projects/<proj>/memory/*.md` + `MEMORY.md`. Deeper knowledge
  lives in `/Users/seungwonkim/seungwon-wiki` — read per its own CLAUDE.md
  *Cross-Project Access*.

## Detailed Rules

- `rules/operating-principles.md`, `rules/trust-boundaries.md` — always loaded
- `rules/repo-self-management.md` — MySystem-internal edits
- Codex reads a separate contract: `codex/workflow-contract.md` (ADR-0016 / ADR-0019).
  It states the gates as prose because no hook runs there; here they are code
  (ADR-0024). Changing the workflow means changing both surfaces.
- Gate internals: `hooks/gate.py`, `hooks/record-step.py`,
  `hooks/mysystem_steps_lib.py`, `scripts/mysystem-steps`.
- Inspect the always-loaded chain: `scripts/claude-md-budget.sh`
