---
name: documentation-lookup
description: Use up-to-date library and framework docs via Context7 MCP instead of training data. Activates for setup questions, API references, code examples, or when the user names a framework.
origin: ECC (affaan-m/everything-claude-code)
---

# Documentation Lookup (Context7)

When the user asks about libraries, frameworks, or APIs, fetch current documentation via the Context7 MCP (tools `resolve-library-id` and `query-docs`) instead of relying on training data.

## When to use

Activate when the user:

- Asks setup or configuration questions (e.g. "How do I configure Next.js middleware?")
- Requests code that depends on a library ("Write a Prisma query for...")
- Needs API or reference information ("What are the Supabase auth methods?")
- Mentions specific frameworks or libraries (React, Vue, Svelte, Express, Tailwind, Prisma, Supabase, etc.)

## How it works

### Step 1: Resolve the Library ID

Call the **resolve-library-id** MCP tool with:
- **libraryName**: The library or product name from the user's question
- **query**: The user's full question (improves relevance ranking)

### Step 2: Select the Best Match

From results, choose using:
- **Name match**: Prefer exact or closest match
- **Benchmark score**: Higher = better documentation quality (100 is highest)
- **Source reputation**: Prefer High or Medium reputation
- **Version**: If user specified a version, prefer version-specific library ID

### Step 3: Fetch the Documentation

Call the **query-docs** MCP tool with:
- **libraryId**: The selected Context7 library ID from Step 2
- **query**: The user's specific question or task

Limit: do not call query-docs (or resolve-library-id) more than 3 times per question.

### Step 4: Use the Documentation

- Answer using the fetched, current information
- Include relevant code examples from the docs
- Cite the library or version when it matters

## Best Practices

- **Be specific**: Use the user's full question as the query
- **Version awareness**: Use version-specific library IDs when available
- **Prefer official sources**: Prefer official packages over community forks
- **No sensitive data**: Redact API keys, passwords, tokens before passing to Context7
