---
description: "Extract PR or branch diff context for iOS/Swift code review (stage 1 of 4)."
---

# Review Extract — Stage 1/4

Extract PR or branch diff context, parsing changed files, new symbols, and signature changes into structured JSON.

## Read the skill first

Read `SKILL.md` from the `review-extract` skill in the ios-comprehensive-review plugin.

## Action

Run the review-extract workflow from SKILL.md.

**Arguments:** `$ARGUMENTS`

Usage:
- `/review-extract <PR number>` — extract context from a PR
- `/review-extract --base <branch>` — extract from current branch vs base
- `/review-extract --base <branch> --branch <branch>` — extract from specific branch vs base

**If no arguments are provided:**
Show usage instructions and ask the user for a PR number or branch.

**Next step:** `/review-analyze`
