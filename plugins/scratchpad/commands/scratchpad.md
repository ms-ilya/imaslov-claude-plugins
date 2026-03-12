---
description: Context-preserving bug-fixing scratchpad that persists investigation state across sessions.
---

# Scratchpad

A living investigation journal that persists debugging state, failed approaches, architectural decisions, and knowledge across sessions via `.scratchpads/` files.

## Read the skill first

Before doing anything, read the Scratchpad skill documentation:

1. Read `SKILL.md` from the scratchpad skill directory

## Action

Run the Scratchpad workflow from SKILL.md.

**If arguments are provided:**
Context or intent: `$ARGUMENTS` (e.g., "resolve", "abandon", "switch", or a bug description)

**If no arguments are provided:**
Run the default flow — locate or create a scratchpad from conversation context.

## Key reminders

- Always re-read the scratchpad file from disk before doing anything
- Only record findings explicitly stated in the conversation — no speculation
- Failed approaches are sacred during active debugging — never delete them
- Keep entries concise: 2-4 lines per failed approach, 1-3 sentences for descriptions
- Omit empty sections — add section headers only when they have content
