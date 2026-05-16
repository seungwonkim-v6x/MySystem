# References — Treasure Trove

Curated read-only knowledge bases. Cloned by `setup.sh` into `references/<name>/`
and kept current via `git pull`. **Not** skills — these don't run, the agent
just reads them when relevant.

When in doubt during a task, **grep across `references/` first**, then fall back
to web search. Local knowledge is faster, version-pinned to whatever pulled
last, and doesn't burn fresh context on rediscovery.

## Engineering Wisdom

| Topic | Local path | Use when |
|-------|------------|----------|
| **Large-scale system design** | `references/system-design-primer/` | Designing any service that needs to scale; prep for system design discussions; quick lookup on caching/sharding/CAP trade-offs |
| **Scalability patterns** | `references/awesome-scalability/` | Need real-world post-mortems and architectures from named companies (Netflix, Discord, LinkedIn, etc.) |
| **CS classics** | `references/papers-we-love/` | "Why does this work this way?" — Dynamo, MapReduce, Raft, Bigtable, etc. The original papers, not blog summaries |
| **Falsehoods programmers believe** | `references/awesome-falsehood/` | Designing schemas / validators for names, addresses, time zones, phone numbers, gender, IPs. Read this **before** writing the regex |
| **Design patterns** | `references/awesome-design-patterns/` | Architecture decision (cloud, distributed, microservice, DDD); refactoring large codebases |
| **Engineering blogs** | `references/engineering-blogs/` | "How did [company] solve X?" — direct index into named companies' eng blogs |

## AI / LLM

| Topic | Local path | Use when |
|-------|------------|----------|
| **LLM literature** | `references/awesome-llm/` | Papers, models, courses, fine-tuning, eval methodologies |
| **AI agents** | `references/awesome-ai-agents/` | Researching agent architectures, autonomous systems, comparing to Claude Code patterns |

## Design / Frontend

| Topic | Local path | Use when |
|-------|------------|----------|
| **DESIGN.md drop-ins** | `references/awesome-design-md/` | Generating UI in a specific brand's aesthetic (Linear, Stripe, Apple, …) — copy a `DESIGN.md` into the project, let the agent match |
| **Design system index** | `references/awesome-design-systems/` | Need a real, complete design system (Material, Atlassian, Polaris, …); studying patterns from production systems |
| **Tailwind ecosystem** | `references/awesome-tailwindcss/` | Hunting a Tailwind plugin, template, component lib, or learning resource |
| **React components** | `references/awesome-react-components/` | "Is there a battle-tested React component for X?" — table, form, calendar, etc. |

## How to use

```bash
# Grep across all references
grep -r "consistent hashing" ~/.claude/references/

# Or specific repo
grep -r "Raft" ~/.claude/references/papers-we-love/

# Open a README directly
$EDITOR ~/.claude/references/system-design-primer/README.md
```

## How to add a new reference repo

1. Append to `REFERENCE_REPOS` in [`../setup.sh`](../setup.sh):
   ```
   "local-name|https://github.com/org/repo.git|branch"
   ```
2. Add a row to this `INDEX.md` under the right category, with a one-line
   "Use when" hook so the agent knows when to consult it.
3. Run `./setup.sh` to clone.

## How to remove one

1. Delete its line from `REFERENCE_REPOS` and `INDEX.md`.
2. `rm -rf references/<local-name>/` (already git-ignored).
3. Run `./setup.sh` to refresh `.git/info/exclude`.
