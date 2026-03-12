---
name: review-extract
description: >-
  Extract PR or branch diff context for iOS/Swift code review. Parses changed
  files, new symbols, and signature changes into structured JSON.
  Use when asked to "extract context", "get PR diff", "parse PR changes",
  "prepare review data", or "extract PR N". This is stage 1 of 4 in the
  comprehensive review pipeline. For a single-command full review, use
  review-all instead.
argument-hint: <PR number> or --base <branch> [--branch <branch>]
disable-model-invocation: true
allowed-tools: Bash
---

## EXECUTION

1. **Check dependencies:**
   ```bash
   command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not installed (brew install jq)"; exit 1; }
   ```

2. **Clear and extract:**
   ```bash
   rm -rf .ios-review-temp && ${CLAUDE_SKILL_DIR}/../../scripts/extract-pr-context.sh $ARGUMENTS
   ```

   If no arguments provided, show usage:
   ```
   Usage: /ios-comprehensive-review:review-extract <PR number>
          /ios-comprehensive-review:review-extract --base <branch> [--branch <branch>]
   ```

3. **Verify:**
   ```bash
   test -f .ios-review-temp/pr-context.json && echo "OK" || echo "FAILED: Context file not created"
   ```

4. **Report:** Script outputs `Files: X | Symbols: Y | Signatures: Z`

**Next step:** Run `/ios-comprehensive-review:review-analyze`
