---
description: Initialize a new Memory Bank for the current project. Scans the codebase and creates root-level documentation files.
---

# Initialize Memory Bank

You are creating a brand new Memory Bank for this project — a living documentation system that captures the current state of the codebase, organized by feature.

## Read the skill first

Before doing anything, read the Memory Bank skill documentation:

1. Read `SKILL.md` from the memory-bank skill directory
2. Read `references/templates.md` for exact file formats
3. Read `references/verification.md` for the mandatory verification procedure

## Action

Run **Workflow 2: Initialize** from SKILL.md.

This will:
1. Scan the full project for tech stack, architecture, dependencies
2. Create `memory-bank/` at the project root
3. Generate root-level files: `WIKI.md`, `systemPatterns.md`, `techContext.md`, `TROUBLESHOOTING.md`
4. Run the verification pass on all generated files

## After initialization

Let the user know the Memory Bank is ready and they can start documenting features with:
- `/update-memory-bank <feature-name>` to document individual features
- `/update-memory-bank-system` to refresh root-level docs later

## Key reminders

- If `memory-bank/` already exists, inform the user and ask if they want to reinitialize (which will overwrite root files) or just update with `/update-memory-bank-system`
- Every file path and type name must be verified against actual source code
- This is about **current state**, not history
