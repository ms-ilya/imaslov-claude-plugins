---
name: pr-review-extract
description: Extract PR or branch context. Triggers on "Extract context for PR <number>" or "Extract context for branch <name> where base branch <name>".
tools: Bash
---

## EXECUTION

1. **Detect mode:** Determine if input contains a PR number or branch names.

   - **PR mode:** Input matches `PR <number>` → extract `PR_NUMBER`.
   - **Branch mode:** Input matches `branch <head> where base branch <base>` → extract `HEAD_BRANCH` and `BASE_BRANCH`.
     - If head branch is omitted (e.g., "Extract context where base branch main"), use current branch.

2. **Clear and Extract:**

   **PR mode:**
   ```bash
   rm -rf .pr-review-temp && ./scripts/extract-pr-context.sh [PR_NUMBER]
   ```

   **Branch mode (with head branch):**
   ```bash
   rm -rf .pr-review-temp && ./scripts/extract-pr-context.sh --base [BASE_BRANCH] --branch [HEAD_BRANCH]
   ```

   **Branch mode (current branch as head):**
   ```bash
   rm -rf .pr-review-temp && ./scripts/extract-pr-context.sh --base [BASE_BRANCH]
   ```

3. **Verify:** Check file exists:
   ```bash
   test -f .pr-review-temp/pr-context.json && echo "OK" || echo "FAILED"
   ```

4. **Report:** Script outputs `Files: X | Symbols: Y | Signatures: Z`

**Next step:** To analyze the files, run: `Analyse PR [N] files` or `Analyse branch files`
