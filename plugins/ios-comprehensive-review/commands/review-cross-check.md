---
description: "Cross-file iOS/Swift analysis for DRY, breaking changes, and SOLID (stage 3 of 4)."
---

# Review Cross-Check — Stage 3/4

Cross-file analysis for DRY violations, breaking API changes, and SOLID issues using parallel background agents.

## Read the skill first

Read `SKILL.md` from the `review-cross-check` skill in the ios-comprehensive-review plugin.

## Action

Run the review-cross-check workflow from SKILL.md.

**Prerequisite:** Run `/review-extract` first to create `.ios-review-temp/pr-context.json`.

Supports resume — re-running skips already-completed checks.

**Next step:** `/review-report`
