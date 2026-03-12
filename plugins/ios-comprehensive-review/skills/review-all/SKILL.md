---
name: review-all
description: >-
  Run a complete iOS/Swift comprehensive code review in one command.
  Uses 5 specialized parallel agents across 4 stages: extraction, per-file
  analysis, cross-file checks (DRY/breaking/SOLID), and report generation.
  Use when the project is iOS/Swift and the user asks for "full review",
  "comprehensive review", "deep review", "review PR N", "review everything",
  "complete code review", "multi-agent review", "analyze PR", "review branch",
  "full iOS review", "run comprehensive review", or "check PR N".
  Do NOT use for quick single-file reviews — use ios-quick-review instead.
argument-hint: <PR number> or --base <branch> [--branch <branch>]
allowed-tools: Bash, Glob, Agent, TaskOutput, TodoWrite
---

## EXECUTION

### 1. Setup Progress

```
TodoWrite([
  {content: "Extract PR/branch context", status: "in_progress", activeForm: "Extracting PR/branch context"},
  {content: "Analyze changed files", status: "pending", activeForm: "Analyzing changed files"},
  {content: "Run cross-file checks", status: "pending", activeForm: "Running cross-file checks"},
  {content: "Generate review report", status: "pending", activeForm: "Generating review report"},
  {content: "Clean up temp files", status: "pending", activeForm: "Cleaning up temp files"}
])
```

### 2. Extract Context

```bash
command -v jq >/dev/null 2>&1 || { echo "ERROR: jq not installed (brew install jq)"; exit 1; }
```

```bash
rm -rf .ios-review-temp && ${CLAUDE_SKILL_DIR}/../../scripts/extract-pr-context.sh $ARGUMENTS
```

If no arguments provided, show usage and stop:
```
Usage: Review PR <number>
       Review branch developer against main
       /ios-comprehensive-review:review-all <PR number>
       /ios-comprehensive-review:review-all --base <branch> [--branch <branch>]
```

Verify:
```bash
test -f .ios-review-temp/pr-context.json && echo "OK" || echo "FAILED"
```

If FAILED: report error and stop.

Mark extract completed, analyze in_progress.

### 3. Analyze Files

Load file list:

```bash
jq -r '.changed_files[] | select(.change_type != "deleted") | "\(.path)|\(.added_lines | @json)|\(.new_symbols | @json)"' .ios-review-temp/pr-context.json
```

If no files: report "No analyzable files" → skip to step 4.

**Resume check:** `Glob(".ios-review-temp/review-*.json")` → build set of completed SafePaths.

SafePath: replace `/` with `--`, spaces with `__`, dots with `_DOT_`, remove `.swift` extension only.

Filter to only files WITHOUT existing `review-[SAFEPATH].json`.

If all files processed: report "All files already analyzed" → skip to step 4.

**Process files in batches of 20:**

For each batch, spawn ALL files in ONE message with `run_in_background: true`:

```
Agent(run_in_background: true,
     subagent_type: "ios-comprehensive-review:file-analyzer",
     prompt: "FILE_PATH: [path]
ADDED_LINES: [\"42-50\", \"88\"]
NEW_SYMBOLS: [JSON array]
OUTPUT_FILE: .ios-review-temp/review-[SAFEPATH].json")
```

Collect returned `task_id` for each spawned agent.

Report: `Spawned batch X/Y (N files)`

Collect results for each `task_id`:

```
TaskOutput(task_id: [id], block: true, timeout: 600000)
```

Do NOT poll with `block: false`. Use `block: true` which waits automatically.

**Timeout retry:** If `TaskOutput` returns a timeout (retrieval_status: timeout, or no meaningful result), the agent is still running. Call `TaskOutput` again with the SAME `task_id` and `block: true, timeout: 600000`. Repeat until the agent completes or fails. There is no limit on retries — agents must be given as much time as they need.

Failed files retry once in the next batch. After second failure: record, continue.

Mark analyze completed, cross-check in_progress.

### 4. Cross-File Checks

Load counts:

```bash
echo "FUNCTIONS:$(jq '[.changed_files[] | .new_symbols[] | select(.type == "function")] | length' .ios-review-temp/pr-context.json)"
echo "TYPES:$(jq '[.changed_files[] | .new_symbols[] | select(.type != "function" and .type != "property")] | length' .ios-review-temp/pr-context.json)"
echo "SIGNATURES:$(jq '.signature_changes | length' .ios-review-temp/pr-context.json)"
```

If ALL counts are 0: report "No cross-file analysis needed" → skip to step 5.

**Resume check:** `Glob(".ios-review-temp/*-analysis.json")` → skip agents with existing outputs.

Extract detailed data:

```bash
# Functions (name|file:line)
jq -r '.changed_files[] | .path as $p | .new_symbols[] | select(.type == "function") | "\(.name)|\($p):\(.line)"' .ios-review-temp/pr-context.json

# Types (name|file:line)
jq -r '.changed_files[] | .path as $p | .new_symbols[] | select(.type != "function" and .type != "property") | "\(.name)|\($p):\(.line)"' .ios-review-temp/pr-context.json

# Signature changes (method|old_sig|new_sig|file:line|change_type)
jq -r '.signature_changes[] | "\(.method)|\(.old_signature)|\(.new_signature // "")|\(.file):\(.line)|\(.change_type)"' .ios-review-temp/pr-context.json
```

Spawn ALL applicable agents (not already complete) in ONE message with `run_in_background: true`:

- New functions exist AND no `dry-analysis.json` → spawn dry-analyzer
- Signature changes exist AND no `breaking-analysis.json` → spawn breaking-analyzer
- (New types OR new functions) AND no `solid-analysis.json` → spawn solid-analyzer

```
Agent(run_in_background: true,
     subagent_type: "ios-comprehensive-review:dry-analyzer",
     prompt: "NEW_FUNCTIONS:\n[list]\nOUTPUT_FILE: .ios-review-temp/dry-analysis.json")

Agent(run_in_background: true,
     subagent_type: "ios-comprehensive-review:breaking-analyzer",
     prompt: "SIGNATURE_CHANGES:\n[list]\nOUTPUT_FILE: .ios-review-temp/breaking-analysis.json")

Agent(run_in_background: true,
     subagent_type: "ios-comprehensive-review:solid-analyzer",
     prompt: "NEW_TYPES:\n[list]\nNEW_FUNCTIONS:\n[list]\nOUTPUT_FILE: .ios-review-temp/solid-analysis.json")
```

Collect results with `TaskOutput(task_id: [id], block: true, timeout: 600000)`.

**Timeout retry:** If `TaskOutput` returns a timeout (retrieval_status: timeout, or no meaningful result), the agent is still running. Call `TaskOutput` again with the SAME `task_id` and `block: true, timeout: 600000`. Repeat until the agent completes or fails. There is no limit on retries — agents must be given as much time as they need.

Mark cross-check completed, report in_progress.

### 5. Generate Report

Extract metadata:

```bash
jq -r '"\(.pr_number)|\(.title)|\(.author)|\(.head_branch)|\(.base_branch)|\(.changed_files | length)"' .ios-review-temp/pr-context.json
```

Parse PR_NUMBER, TITLE, AUTHOR, HEAD_BRANCH, BASE_BRANCH, FILE_COUNT (pipe-delimited).

Spawn report aggregator:

```
Agent(subagent_type: "ios-comprehensive-review:report-aggregator",
     prompt: "PR_NUMBER: [N]\nTITLE: [T]\nAUTHOR: [A]\nBRANCH: [HEAD] → [BASE]\nFILES: [COUNT]")
```

Verify:
```bash
test -f .ios-review-temp/ios-review-report.md && echo "OK" || echo "FAILED"
```

Count findings:
```bash
jq -r '.findings[] | .severity' .ios-review-temp/*.json 2>/dev/null | sort | uniq -c
```

Mark report completed, cleanup in_progress.

### 6. Clean Up Temp Files

Remove all intermediate files from `.ios-review-temp/`, keeping only the final report:

```bash
find .ios-review-temp -type f ! -name 'ios-review-report.md' -delete 2>/dev/null && echo "OK" || echo "FAILED"
```

Mark cleanup completed.

### 7. Final Summary

```
Complete. Report: .ios-review-temp/ios-review-report.md | Critical: X | Warning: Y | Suggestion: Z
```
