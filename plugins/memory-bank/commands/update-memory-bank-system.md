---
description: Refresh Memory Bank root-level documentation (systemPatterns, techContext, WIKI index, troubleshooting). Does not touch individual feature docs.
---

# Update Memory Bank System Docs

You are refreshing the project-wide Memory Bank documentation — the root-level files that describe architecture, tech stack, and the feature index.

## Read the skill first

Before doing anything, read the Memory Bank skill documentation:

1. Read `SKILL.md` from the memory-bank skill directory
2. Read `references/templates.md` for exact file formats
3. Read `references/verification.md` for the mandatory verification procedure

## Action

Run **Workflow 3: System Update** from SKILL.md.

This will:
1. Re-analyze project-wide: architecture, dependencies, patterns, build setup
2. Update `systemPatterns.md` and `techContext.md`
3. Re-scan all feature folders and rebuild the `WIKI.md` feature index
4. Update root `TROUBLESHOOTING.md` with refreshed links and cross-cutting issues
5. Run the verification pass

## Key reminders

- If `memory-bank/` doesn't exist, run Initialize first
- This does NOT update individual feature documentation — use `/update-memory-bank <feature>` for that
- Every file path and type name must be verified against actual source code
