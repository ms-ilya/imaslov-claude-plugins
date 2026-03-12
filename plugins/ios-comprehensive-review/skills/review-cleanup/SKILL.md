---
name: review-cleanup
description: >-
  Clean up intermediate files from .ios-review-temp/ after iOS/Swift code review,
  keeping only the final report. Use when asked to "clean up review", "remove temp
  files", "clean review files", or "cleanup after review". Run this after
  review-report (stage 4) to remove intermediate JSON files no longer needed.
  For a single-command full review with automatic cleanup, use review-all instead.
disable-model-invocation: true
allowed-tools: Bash
---

## EXECUTION

1. **Verify report exists:**
   ```bash
   test -f .ios-review-temp/ios-review-report.md && echo "OK" || echo "NO_REPORT"
   ```

   If `NO_REPORT`: report "No report found. Run `/ios-comprehensive-review:review-report` first." → exit.

2. **Remove intermediate files:**
   ```bash
   find .ios-review-temp -type f ! -name 'ios-review-report.md' -delete 2>/dev/null && echo "OK" || echo "FAILED"
   ```

3. **Report:** `Cleanup complete. Kept: .ios-review-temp/ios-review-report.md`
