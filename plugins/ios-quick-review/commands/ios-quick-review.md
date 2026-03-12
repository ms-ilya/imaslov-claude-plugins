---
description: Efficient multi-pass iOS/Swift code review for commits or uncommitted changes.
---

# iOS Quick Review

Perform an efficient, focused multi-pass iOS/Swift code review. Every finding references exact symbols, files, and lines — verified by reading actual code.

## Read the skill first

Before doing anything, read the iOS Quick Review skill documentation:

1. Read `SKILL.md` from the ios-quick-review skill directory

## Action

Run the iOS Quick Review workflow from SKILL.md.

**If arguments are provided:**
Review target: `$ARGUMENTS` (commit SHA, PR number, or file path)

**If no arguments are provided:**
Review uncommitted changes (`git diff HEAD`). If clean, ask the user what to review.

## Key reminders

- Only report findings for code you have READ — never infer from memory
- Before writing each finding, re-read the specific lines being cited
- Include actual code snippets as proof in each finding
- Use scope-proportional strategy: small diffs get combined passes, large diffs get batched
- Read AGENTS.md from the project root for project-specific rules
