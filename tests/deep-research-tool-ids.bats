#!/usr/bin/env bats
#
# Watchdog for /deep-research's MCP tool identifiers.
#
# Claude Code defers MCP tools: none is in the active tool list until ToolSearch
# loads it, and `select:` matches EXACT names. A bare server-side name like
# `web_search_exa` is therefore not callable — `select:web_search_exa` returns
# "No matching deferred tools found" — and neither is a well-formed WRONG id like
# `mcp__exa__web_search` or `mcp__eza__web_search_exa`. All three fail the same
# silent way: the provider is simply never reached, and nothing errors.
#
# Measured before the fix: across 45 real /deep-research invocations in 30 days,
# ToolSearch loaded WebSearch/WebFetch 27 times, exa once, firecrawl once. The one
# provider that was reached at any rate, context7, was the one whose identifiers
# the file spelled out. (Mobbin was also used without its ids being written down;
# its OAuth flow surfaces them out of band, so it is not evidence either way.)
#
# WHAT THIS FILE GUARDS, and why it is a roster rather than a pattern:
#
# An earlier version of this test asserted identifier *shape* — "every provider
# tool name appears inside some `mcp__x__y`". An adversarial pass ran 42 mutations
# against it and 28 passed, including every realistic one: a renamed upstream tool,
# a typo'd server key, apify's double hyphen collapsed to one, and — worst — the
# whole context7 row rewritten to `mcp__context7__…`, which is what you get by
# applying the derivation rule the document itself used to state. Shape was never
# the property that mattered. Identity is.
#
# So EXPECTED_IDS below is the roster: the exact set of MCP identifiers the skill
# file is allowed to name. Adding a provider turns this red, and the fix is to add
# one line naming the exact id — which is the discipline the skill is asking for.
#
# KNOWN LIMITS, stated rather than left to be discovered:
#
#  1. Liveness is not checked. Whether each id resolves against a running server
#     needs the MCP servers up; that is done by hand (spawn each stdio server,
#     `tools/list`, diff against this roster) rather than in CI, where it would be
#     a network-flaky test of someone else's uptime.
#  2. A tool name nobody listed is invisible. BARE_NAMES is a closed list, so a
#     brand-new provider written bare in prose (`tavily_search`) passes. The roster
#     test does catch a new provider added *correctly*, because any unlisted
#     `mcp__x__y` is drift — so the hole is narrower than it looks, but it is real.
#     Adding a provider means adding it to both lists here.
#
# Assertions are chained with `|| return 1`. bats 1.13.0 does not fail a test on a
# bare non-final `[[ ]]`, so an unchained mid-test assertion silently asserts
# nothing (standing TODO in TODOS.md). This file uses `[ ]` and chains everything.

SOURCE_REPO="$BATS_TEST_DIRNAME/.."
SKILL="$SOURCE_REPO/skills/deep-research/SKILL.md"

# Every MCP identifier the skill file may name. Sorted, one per line.
# Two entries are deliberately non-resolving, and are listed so a future reader
# does not take them for live ids: `mcp__exa__crawling_exa`, which the file names
# only to say "do not call this", and `mcp__exa__web_search_advanced_exa`, which
# is a real tool that is off by default — the file names it so the "is it
# enabled?" check has something to pass to `select:`. Both were confirmed
# non-resolving in this environment.
EXPECTED_IDS='mcp__apify__apify--rag-web-browser
mcp__exa__crawling_exa
mcp__exa__web_fetch_exa
mcp__exa__web_search_advanced_exa
mcp__exa__web_search_exa
mcp__firecrawl__firecrawl_scrape
mcp__firecrawl__firecrawl_search
mcp__mobbin__search_flows
mcp__mobbin__search_screens
mcp__mobbin__search_sections
mcp__plugin_context7_context7__query-docs
mcp__plugin_context7_context7__resolve-library-id
mcp__scrapling__stealthy_fetch
mcp__stitch__create_design_system_from_design_md'

# Server-side tool names. Each may appear only inside a full identifier, or as one
# of the two exempt literals below.
BARE_NAMES='web_search_exa|web_fetch_exa|web_search_advanced_exa|crawling_exa|firecrawl_search|firecrawl_scrape|stealthy_fetch|apify--rag-web-browser|resolve-library-id|get-library-docs|query-docs|search_screens|search_flows|search_sections|create_design_system_from_design_md'

# THREE bare names are quoted on purpose, to teach how bare names behave. The
# exemption removes those exact TOKENS before scanning — not their lines. A
# line-level exemption was self-granting: appending `<!-- No matching deferred -->`
# to a table row exempted the whole row, an innocent paragraph rewrap turned the
# suite red with no regression behind it, and the filter silently dropped a third
# line the comment never mentioned. Tokens, enumerated here, and asserted present
# by a test below so the list cannot quietly outlive what it exempts:
#
#   1. select:web_search_exa       — the exact-match example that fails
#   2. ToolSearch("web_search_exa") — the keyword example that succeeds
#   3. `get-library-docs`          — context7's renamed, no-longer-resolving tool

@test "skill file exists" {
  [ -f "$SKILL" ]
}

@test "the file names exactly the expected set of MCP identifiers" {
  # The server segment allows hyphens: real server keys carry them (this machine
  # has `supabase-personal`, and the vendor doc's own example is `enterprise-tools`).
  # A class of [A-Za-z0-9_]+ silently skipped every such id.
  run bash -c "grep -oE 'mcp__[A-Za-z0-9_-]+__[A-Za-z0-9_.-]+' '$SKILL' | sort -u"
  [ "$status" -eq 0 ] || return 1
  if [ "$output" != "$EXPECTED_IDS" ]; then
    echo "Identifier roster drifted."
    echo "--- unexpected (in file, not in roster) ---"
    comm -13 <(printf '%s\n' "$EXPECTED_IDS") <(printf '%s\n' "$output")
    echo "--- missing (in roster, not in file) ---"
    comm -23 <(printf '%s\n' "$EXPECTED_IDS") <(printf '%s\n' "$output")
    echo "A wrong-but-well-formed id is as unreachable as a bare name. If this"
    echo "change is intentional, add or remove the exact id in EXPECTED_IDS."
    return 1
  fi
}

@test "prose never names a tool bare" {
  # Table rows are excluded and checked by the next test: their left-hand cells
  # carry the server-side name ON PURPOSE, because a runtime without tool search
  # (Codex) has no other name to call. Everywhere else — param notes, rails, the
  # Step 3 and Step 4 examples — a bare name is an instruction to call something
  # that is not callable, which is where the original defect lived.
  run bash -c "sed -e 's/select:web_search_exa//g' -e 's/ToolSearch(\"web_search_exa\")//g' -e 's/\`get-library-docs\`//g' '$SKILL' | grep -v '^| ' | grep -oE '(mcp__[A-Za-z0-9_]+__)?($BARE_NAMES)' | grep -vE '^mcp__'"
  # grep exits 1 when it finds nothing, which is the passing case here.
  [ "$status" -eq 1 ] || {
    echo "Bare provider tool name(s) in prose — not callable under tool search:"
    echo "$output"
    return 1
  }
}

@test "every provider-table tool CELL pairs both names" {
  # The cell form is `server-side-name` -> `mcp__server__tool`. Dropping either
  # half breaks one runtime silently: without the arrow-right id Claude Code has
  # nothing to load, without the left name Codex has nothing to call.
  #
  # Per CELL, not per row. A row-level check passes when one of its two tool
  # cells is intact, and every row this change exists to fix has two — so the
  # row-level version guarded builtin, apify and scrapling while missing exa,
  # firecrawl and context7. Reintroducing the original defect on exa's search
  # cell went green.
  run bash -c "awk -F'|' '/^\| /{for(i=2;i<=NF;i++) print NR\": \"\$i}' '$SKILL' | grep -E '($BARE_NAMES)' | grep -vE 'mcp__.*→|→.*mcp__'"
  # grep exits 1 when it finds nothing, which is the passing case here.
  [ "$status" -eq 1 ] || {
    echo "Table cell names a tool without pairing both forms (need 'bare → mcp__server__tool'):"
    echo "$output"
    return 1
  }
}

@test "every provider still has a row in the table" {
  # The roster test above reads identifiers from the whole file, so deleting a
  # provider's table row while its ids linger in the param notes leaves the roster
  # intact. The row is what the selection rules read; without it the provider is
  # gone from the table and the agent never considers it, which is the same
  # silent-unreachability outcome by a different route.
  for provider in builtin exa apify firecrawl scrapling context7; do
    grep -qE "^\| $provider \|" "$SKILL" || {
      echo "Provider table has no row for: $provider"
      return 1
    }
  done
}

@test "each exempt mention appears exactly once and is still explanatory" {
  # Two properties, and the count is the load-bearing one. The strip is global,
  # so a SECOND occurrence would be exempted too — someone could write "when in
  # doubt call `get-library-docs`" and the scan would never see it. Pinning the
  # count to 1 means the exemption covers the occurrence it was written for and
  # no other. If one vanishes entirely the exemption is dead weight and should be
  # removed with it.
  #
  # Test the explanation, not the bare name: an earlier version grepped for a
  # string that was a substring of the full id, so the assertion whose job was to
  # notice the exemption had died instead certified the exact bug's return.
  for token in 'select:web_search_exa' 'ToolSearch("web_search_exa")' '`get-library-docs`'; do
    n=$(grep -oF "$token" "$SKILL" | wc -l | tr -d ' ')
    [ "$n" -eq 1 ] || {
      echo "Exempt token appears $n times, expected exactly 1: $token"
      return 1
    }
  done
  grep -qF 'earlier plugin release' "$SKILL" || return 1
}

@test "the read-it-off-the-row rule is documented" {
  # The literals in EXPECTED_IDS rot if a server is renamed or a plugin moves.
  # What survives is the instruction not to derive the prefix: context7's is
  # mcp__plugin_context7_context7__, which no derivation from the `id` column
  # produces. Deriving it is how the whole context7 row goes dead silently.
  grep -qF 'Read the callable id off the row' "$SKILL" || return 1
  grep -qF 'ToolSearch' "$SKILL" || return 1
}
