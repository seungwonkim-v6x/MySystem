---
name: search-first
description: Research-before-coding workflow. Search for existing tools, libraries, and patterns before writing custom code. Invokes the researcher agent.
origin: ECC (affaan-m/everything-claude-code)
---

# /search-first — Research Before You Code

Systematizes the "search for existing solutions before implementing" workflow.

## Trigger

Use this skill when:
- Starting a new feature that likely has existing solutions
- Adding a dependency or integration
- The user asks "add X functionality" and you're about to write code
- Before creating a new utility, helper, or abstraction

## Workflow

```
1. NEED ANALYSIS
   Define what functionality is needed
   Identify language/framework constraints

2. PARALLEL SEARCH (researcher agent)
   - npm / PyPI
   - MCP / Skills
   - GitHub / Web

3. EVALUATE
   Score candidates (functionality, maintenance,
   community, docs, license, deps)

4. DECIDE
   - Adopt as-is
   - Extend / Wrap
   - Build Custom

5. IMPLEMENT
   Install package / Configure MCP /
   Write minimal custom code
```

## Decision Matrix

| Signal | Action |
|--------|--------|
| Exact match, well-maintained, MIT/Apache | **Adopt** -- install and use directly |
| Partial match, good foundation | **Extend** -- install + write thin wrapper |
| Multiple weak matches | **Compose** -- combine 2-3 small packages |
| Nothing suitable found | **Build** -- write custom, but informed by research |

## How to Use

### Quick Mode (inline)

Before writing a utility or adding functionality, mentally run through:

0. Does this already exist in the repo? -- `rg` through relevant modules/tests first
1. Is this a common problem? -- Search npm/PyPI
2. Is there an MCP for this? -- Check `~/.claude/settings.json` and search
3. Is there a skill for this? -- Check `~/.claude/skills/`
4. Is there a GitHub implementation/template? -- Run GitHub code search

### Full Mode (agent)

For non-trivial functionality, launch the researcher agent:

```
Task(subagent_type="general-purpose", prompt="
  Research existing tools for: [DESCRIPTION]
  Language/framework: [LANG]
  Constraints: [ANY]

  Search: npm/PyPI, MCP servers, Claude Code skills, GitHub
  Return: Structured comparison with recommendation
")
```

## Anti-Patterns

- **Jumping to code**: Writing a utility without checking if one exists
- **Ignoring MCP**: Not checking if an MCP server already provides the capability
- **Over-customizing**: Wrapping a library so heavily it loses its benefits
- **Dependency bloat**: Installing a massive package for one small feature
