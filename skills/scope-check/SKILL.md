---
name: scope-check
description: Step 1 for an ordinary change. Restate the request in three lines, name what is out of scope, and ask only about a genuinely ambiguous reading. Use for a feature, bug fix, or refactor on code that already exists — /office-hours is for a new idea, /investigate is for a defect with an unknown cause.
---

# /scope-check — Step 1 for an ordinary change

The cheapest possible Step 1. It exists because `/office-hours` lists its
proactive triggers as "a **new product idea** … something that **doesn't exist
yet** … **before any code is written**", which is not what most requests are.
Nothing in that skill forbids other uses, but a mapping that sends every change
to a skill whose own triggers exclude it invites the model to route around Step 1
rather than through it.

To be accurate about the evidence: Step 1 still ran 52-62% of the time under that
mapping, and the collapse to 0% came from deleting the rule, not from the
mis-wire (ADR-0023). Fixing the wiring removes a standing invitation to skip; it
is not the whole cause.

This skill writes nothing to disk and invokes no other skill.

## When to run

Step 1 of the Feature / Bug Fix / Refactoring workflow, when the request is a change
to code that already exists and the cause is known.

Route elsewhere instead when:

| Request | Step 1 skill |
|---|---|
| A new idea, or "is this worth building" | `/office-hours` |
| Something is broken and the cause is unknown | `/investigate` |
| Anything else — a change to existing code | **`/scope-check`** |

Skip only under the `CLAUDE.md` *Triviality carve-out*: typo fixes, single-character
edits, comment-only changes, single-symbol renames, or work the user framed as trivial.

## What to do

### 1. Restate the request in three lines

Not a summary of the conversation. Your reading of what is being asked, in a form
the user can contradict in one word.

```
Reading:
1. <what changes>
2. <where — name the files or the surface>
3. <how you will know it worked>
```

Line 3 is the *Short Loop* check that returns pass or fail. If you cannot write it,
you do not yet know what was asked — that is the ambiguity to raise below.

### 2. Name what is out of scope

One line each, no elaboration. This is Request Lock made explicit before the work
rather than apologised for after it.

```
Out of scope: <adjacent thing you noticed and will not touch>
```

Anything you discover mid-task that is related but not requested belongs here, not
in the diff. If nothing is nearby, say "nothing adjacent".

### 3. Ask only if a reading is genuinely ambiguous

Ask only when two readings would lead to materially different work. Geometry,
motion, ordering, and state transitions are the usual offenders — a wrong reading
of those costs the whole build. One question is almost always enough here;
`rules/operating-principles.md` allows up to three per step if the spec genuinely
needs them.

Do not ask about taste, do not ask for permission to proceed, and do not ask which
files to touch when the request names them. If the request is clear, say so in one
line and continue to Step 2.

## What this is not

- Not a design doc. Nothing is written to `~/.gstack/` or the repo.
- Not an approval gate. State the reading and continue; the user interrupts if it is wrong.
- Not a place to widen scope. Discovering that a nearby structure is wrong does not
  license changing it — that is what step 2 above is for.
- Not a substitute for `/office-hours` on genuinely new work. If the request is
  "should we build X at all", stop and run that instead.

## Done when

You have printed the three-line reading and the out-of-scope line, and either asked
the one question or stated that the request is unambiguous. Then Step 2.
