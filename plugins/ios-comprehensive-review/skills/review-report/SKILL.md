---
name: review-report
description: >-
  Generate final iOS/Swift review report aggregating all findings by severity
  with statistics. ONLY for iOS/Swift projects. Use when asked to "create
  review report", "generate report", "compile findings", or "write review
  summary". This is stage 4 of 4 in the iOS comprehensive review pipeline.
  For a single-command full review, use review-all instead.
disable-model-invocation: true
allowed-tools: Agent, Bash
---

## Pre-loaded Context

Metadata: !`jq -r '"\(.pr_number)|\(.title)|\(.author)|\(.head_branch)|\(.base_branch)|\(.changed_files | length)"' .ios-review-temp/pr-context.json 2>/dev/null || echo "NO_CONTEXT"`

## EXECUTION

1. **Parse metadata:** Extract PR_NUMBER, TITLE, AUTHOR, HEAD_BRANCH, BASE_BRANCH, FILE_COUNT from pre-loaded context (pipe-delimited).

   If metadata shows `NO_CONTEXT`: report "Run `/ios-comprehensive-review:review-extract <PR>` first" → exit.

2. **Spawn aggregator:**
   ```
   Agent(subagent_type: "ios-comprehensive-review:report-aggregator",
        prompt: "PR_NUMBER: [N]\nTITLE: [T]\nAUTHOR: [A]\nBRANCH: [HEAD] → [BASE]\nFILES: [COUNT]")
   ```

3. **Verify:**
   ```bash
   test -f .ios-review-temp/ios-review-report.md && echo "OK" || echo "FAILED"
   ```

4. **Count:**
   ```bash
   jq -r '.findings[] | .severity' .ios-review-temp/*.json 2>/dev/null | sort | uniq -c
   ```

5. **Report:** `Complete. Report: .ios-review-temp/ios-review-report.md | Critical: X | Warning: Y | Suggestion: Z`
