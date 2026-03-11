---
name: bugbot
description: Fresh-eye bug review of branch changes. Auto-runs before commit/push, or invoke manually with "/bugbot" or "bugbot run".
---

# Bugbot — Fresh-Eye Bug Review

Review current branch changes with **completely fresh eyes** to catch runtime bugs, logic errors, and edge cases.

## When to Run

1. **Manual**: User invokes `/bugbot` or says "bugbot run"
2. **Automatic**: When user requests a commit or push, run this review BEFORE committing

## Workflow

### Step 1: Collect Changes

Gather the diff between the base branch (usually `develop`) and the current branch.

```bash
# Full diff against base branch
git diff develop..HEAD

# Uncommitted changes (staged + unstaged)
git diff HEAD

# Changed files summary
git diff develop..HEAD --stat
```

Include uncommitted changes in the review if they exist.

### Step 2: Launch Fresh-Eye Review Agent

**MUST use a separate Agent (subagent)** — isolation from current context is the whole point.

Use this prompt for the Agent:

```
You are a bug reviewer with completely fresh eyes. You have NO prior context about why these changes were made. Your job is to find real bugs only.

Review the code changes on this branch and find:

1. **Runtime Bugs**: Logic errors, null/undefined issues, type mismatches, off-by-one errors
2. **Double-wrapping / Duplication**: Values being wrapped or prefixed multiple times as they propagate through layers
3. **Error Handling Gaps**: Uncaught errors, swallowed exceptions, incorrect error propagation
4. **Race Conditions**: Async issues, missing awaits, parallel execution problems
5. **Edge Cases**: Empty arrays, null inputs, boundary conditions not handled
6. **Breaking Changes**: API contract violations, removed exports that may be used elsewhere

Steps:
1. Run `git diff develop..HEAD --stat` to see changed files
2. Run `git diff develop..HEAD` to see the full diff
3. Run `git diff HEAD` to see uncommitted changes (if any)
4. For each changed file, READ the full file (not just the diff) to understand surrounding context
5. Report findings

For each bug found, specify:
- **Severity**: Critical / Medium / Low
- **Location**: file:line
- **Description**: What's wrong and why
- **Fix suggestion**: How to fix it

IMPORTANT RULES:
- Do NOT invent false positives. Only report bugs you are confident about.
- Do NOT report code style issues, missing comments, or improvement suggestions.
- Do NOT report issues in unchanged code — only review the diff.
- DO read the full files to understand the context around changes.
```

### Step 3: Report Results

Present the review to the user:

```markdown
## Bugbot Review Results

### [Critical/Medium/Low] Bug Title
- **Location**: file:line
- **Description**: ...
- **Fix suggestion**: ...

---
Review complete — [N] issues found / No issues found
```

### Step 4: Confirm Fixes

- **Critical bugs**: Ask the user "Want me to fix this?" before proceeding
- **Medium/Low**: Report only, let the user decide
- If the user wants fixes, apply them and then continue with the commit

## Rules

- **No false positives** — only report bugs you're confident about
- **No style nits** — bugs only, not improvements or suggestions
- **Diff scope only** — don't report issues in unchanged code
- **Agent must read full files** — not just the diff, to understand context
- **Clean review = proceed** — if no bugs found, continue with commit/push immediately
