---
description: "Analyze changed iOS/Swift files for code quality using parallel agents (stage 2 of 4)."
---

# Review Analyze — Stage 2/4

Analyze changed iOS/Swift PR files for code quality using parallel file-analyzer agents. Checks unused code, style violations, threading, memory, and safety issues.

## Read the skill first

Read `SKILL.md` from the `review-analyze` skill in the ios-comprehensive-review plugin.

## Action

Run the review-analyze workflow from SKILL.md.

**Prerequisite:** Run `/review-extract` first to create `.ios-review-temp/pr-context.json`.

Supports resume — re-running skips already-analyzed files.

**Next step:** `/review-cross-check`
