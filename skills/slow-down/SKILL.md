---
name: slow-down
description: "Enforce a concretization step before any code work. Clarify requirements, define scope, run a pre-mortem, and align on approach before implementation begins. Auto-triggers when the user requests coding work."
---

# Slow Down — Concretize First, Code Later

> "AI didn't make the slow phases less important — it made them more important."
> — The Engineering Manager
>
> "Anything that defines the gestalt of your system — architecture, API — write it by hand."
> — Mario Zechner

This skill enforces a mandatory concretization process before writing any code.
It runs automatically when the user requests implementation/coding work.

## When to Trigger

Run this process **before writing code** in these situations:
- User requests a feature implementation, bug fix, or refactoring
- User says "build", "implement", "fix", "create", "refactor", etc.
- Starting implementation work on a Jira ticket or task

## Exceptions (Skip When)

Skip this process when:
- User explicitly says "just do it", "skip slow-down", "skip concretization"
- The change is trivially obvious (typo fix, one-liner, simple rename)
- A detailed design already exists in the ticket (e.g., after `/plan-ticket`)
- The request is a question, explanation, or research task

## Concretization Process (5 Steps)

### Step 1: Problem Definition — "What and Why?"

Summarize the user's request in this format and **get user confirmation**:

```
## Problem Definition
- **Problem**: [What problem are we solving?]
- **Why now**: [Why does this need to be done now?]
- **Who/When**: [Who experiences this problem, in what context?]
```

If information is insufficient, **ask — don't assume**.

### Step 2: Done Criteria — "What does done look like?"

Define the concrete end state of a successful implementation:

```
## Done Criteria
- [ ] [Specific behavior/outcome 1]
- [ ] [Specific behavior/outcome 2]
- [ ] [How to verify/test]
```

**Key question**: "How can we verify the result of this work?"

### Step 3: Scope — "What are we NOT doing?"

Define the boundary clearly. Defining what's **excluded** is more important than what's included:

```
## Scope
- **In scope**: [What we're doing this time]
- **Out of scope**: [What we're NOT doing — future work]
- **Blast radius**: [Files/modules affected by the change]
```

### Step 4: Pre-Mortem — "What could go wrong?"

Run a pre-mortem. Check for:

```
## Pre-Mortem
- **Edge cases**: [Empty values, null, boundary conditions]
- **Side effects**: [Impact on other features]
- **Reversibility**: [Can we roll back if something goes wrong?]
```

Additionally, **invert the problem**: "What would make this project fail?"

### Step 5: Approach Alignment

Present the implementation direction concisely and get user approval:

```
## Approach
- **Method**: [How to implement — 1-3 sentences]
- **Alternatives**: [Approaches considered but not chosen, and why]
- **AI scope**: [What AI handles vs what requires user judgment]
```

## Output Format

Present all 5 steps as a single structured block. Proceed to implementation only after **user approval**.

```markdown
---
# Slow Down — Concretization

## 1. Problem Definition
...

## 2. Done Criteria
...

## 3. Scope
...

## 4. Pre-Mortem
...

## 5. Approach
...

---
If this looks correct, I'll start implementation. Let me know if anything needs adjustment.
```

## Principles

1. **Ask, don't assume** — Never fill gaps in requirements with guesses
2. **Simplest approach first** — Complex solutions only when simple ones won't work
3. **Keep scope narrow** — Break work into chunks that fit within AI review capacity
4. **Architecture decisions together** — AI doesn't make big design calls alone
5. **No code without approval** — Implementation starts only after user confirms the plan
