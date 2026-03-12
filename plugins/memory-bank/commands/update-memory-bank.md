---
description: Update or create Memory Bank documentation for a feature. Performs deep code analysis, generates/updates documentation, and runs mandatory verification.
---

# Update Memory Bank

You are updating the project's Memory Bank — a living documentation system that captures the current state of the codebase, organized by feature.

## Read the skill first

Before doing anything, read the Memory Bank skill documentation:

1. Read `SKILL.md` from the memory-bank skill directory
2. Read `references/templates.md` for exact file formats
3. Read `references/verification.md` for the mandatory verification procedure

## Determine the action

**If arguments are provided:**
The user wants to update/create documentation for a specific feature: `$ARGUMENTS`

→ Run **Workflow 1: Feature Update** from SKILL.md for the feature "$ARGUMENTS"

**If no arguments are provided:**
Ask the user which feature they want to document. Show a list of existing documented features (if `memory-bank/` exists) and offer to document a new one.

## Key reminders

- If `memory-bank/` doesn't exist yet, run **Workflow 2: Initialize** first
- Always show the discovered file list and wait for user confirmation before deep analysis
- Always run the **mandatory verification pass** before committing any docs
- DECISIONS.md is user-curated only — never auto-populate it
- Every file path and type name in docs must be verified against actual source code
- This is about **current state**, not history. Never write changelogs.
