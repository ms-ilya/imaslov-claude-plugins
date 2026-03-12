---
description: Run a complete iOS/Swift comprehensive code review with 5 specialized parallel agents.
---

# iOS Comprehensive Review

Run a complete iOS/Swift comprehensive code review using 5 specialized parallel agents across 4 stages: extraction, per-file analysis, cross-file checks (DRY/breaking/SOLID), and report generation.

## Read the skill first

Before doing anything, read the iOS Comprehensive Review skill documentation:

1. Read `SKILL.md` from the `review-all` skill in the ios-comprehensive-review plugin

## Action

Run the review-all workflow from SKILL.md.

**Arguments:** `$ARGUMENTS`

Usage:
- `/review-all <PR number>` — review a specific PR
- `/review-all --base <branch>` — review current branch against base
- `/review-all --base <branch> --branch <branch>` — review branch against base

**If no arguments are provided:**
Show usage instructions and ask the user for a PR number or branch.

## Key reminders

- Requires `jq` to be installed
- Creates `.ios-review-temp/` directory for intermediate results
- Supports resume — re-running skips already-completed analysis files
- Final report written to `.ios-review-temp/ios-review-report.md`
