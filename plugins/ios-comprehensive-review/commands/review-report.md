---
description: "Generate final iOS/Swift review report aggregating all findings (stage 4 of 4)."
---

# Review Report — Stage 4/4

Generate final iOS/Swift review report aggregating all findings by severity with statistics.

## Read the skill first

Read `SKILL.md` from the `review-report` skill in the ios-comprehensive-review plugin.

## Action

Run the review-report workflow from SKILL.md.

**Prerequisite:** Run `/review-extract` (and optionally `/review-analyze` + `/review-cross-check`) first.

Output: `.ios-review-temp/ios-review-report.md`

**Next step:** `/review-cleanup` to remove intermediate files.
