---
name: review-analyze
description: >-
  Analyze changed iOS/Swift PR files for code quality using parallel file-analyzer
  agents. Checks unused code, style violations, threading, memory, and safety
  issues. ONLY for iOS/Swift projects. Use when asked to "analyze files",
  "check code quality", "run file analysis", or "analyze PR files".
  This is stage 2 of 4 in the iOS comprehensive review pipeline.
  For a single-command full review, use review-all instead.
disable-model-invocation: true
allowed-tools: Agent, Bash, Glob, TaskOutput
---

## Pre-loaded Context

File count: !`jq '.changed_files | map(select(.change_type != "deleted")) | length' .ios-review-temp/pr-context.json 2>/dev/null || echo "NO_CONTEXT"`

## EXECUTION

### 1. Load File List

If pre-loaded file count shows `NO_CONTEXT`: report "Run `/ios-comprehensive-review:review-extract <PR>` first" → exit.

If file count is 0: report "No analyzable files" → exit.

Load full file list:

```bash
jq -r '.changed_files[] | select(.change_type != "deleted") | "\(.path)|\(.added_lines | @json)|\(.new_symbols | @json)"' .ios-review-temp/pr-context.json
```

Output format per line: `path|["42-50","88"]|[symbols json]`

### 2. Resume

`Glob(".ios-review-temp/review-*.json")` → build set of completed SafePaths.

SafePath: replace `/` with `--`, spaces with `__`, dots with `_DOT_`, remove `.swift` extension only.

Filter to only files WITHOUT existing `review-[SAFEPATH].json`.

If all files processed: report "All files already processed" → exit.

### 3. Process Files

Group remaining files into batches of 20.

For each batch:

**3a. Spawn ALL files in batch in ONE message with `run_in_background: true`:**

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

**3b. Collect results for each `task_id`:**

```
TaskOutput(task_id: [id], block: true, timeout: 600000)
```

Do NOT poll with `block: false`. Do NOT implement polling loops or sleep.
Use `block: true` which waits for completion automatically.

**Timeout retry:** If `TaskOutput` returns a timeout (retrieval_status: timeout, or no meaningful result), the agent is still running. Call `TaskOutput` again with the SAME `task_id` and `block: true, timeout: 600000`. Repeat until the agent completes or fails. There is no limit on retries — agents must be given as much time as they need.

If task status is "failed", record file for retry.

Report as results arrive: `Batch X/Y: progress A/B`

**3c. Handle failures:** Failed files retry once in the next batch. After second failure: record in final report, continue.

### 4. Count Findings

After all batches complete:

```bash
jq -s '[.[].findings | length] | add // 0' .ios-review-temp/review-*.json
```

### 5. Final Report

```
Complete. Files: X/Y | Findings: Z | Failed: F
```

If failures exist:
```
Failed files:
- [path]: [error reason]
```

**Next step:** Run `/ios-comprehensive-review:review-cross-check`
