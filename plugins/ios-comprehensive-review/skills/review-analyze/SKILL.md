---
name: review-analyze
description: Stage 2 of 4 — per-file iOS/Swift analysis of the extracted diff with parallel file-analyzer agents. Run review-extract first; review-all runs every stage.
disable-model-invocation: true
allowed-tools:
  - Agent
  - Bash(jq *)
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

SafePath: replace `/` with `--`, spaces with `__`, dots with `_DOT_`, remove `.swift` extension only.

`ls .ios-review-temp/` → a file is done when its `review-[SAFEPATH].json` exists. Keep only the files without one.

If all files processed: report "All files already processed" → exit.

### 3. Process Files

Group remaining files into batches of 10. Claude Code caps concurrent subagents at 20, and a batch at the cap fails to spawn whenever anything else is running.

For each batch:

**3a. Spawn ALL files in batch in ONE message:**

```
Agent(subagent_type: "ios-comprehensive-review:file-analyzer",
     prompt: "FILE_PATH: [path]
ADDED_LINES: [\"42-50\", \"88\"]
NEW_SYMBOLS: [JSON array]
OUTPUT_FILE: .ios-review-temp/review-[SAFEPATH].json")
```

Report: `Spawned batch X/Y (N files)`

**3b. Wait for the batch.** Subagents run in the background and each one reports back on its own when it finishes. Wait until every agent in the batch has reported; do not poll, sleep, or read their transcripts. Their findings are in the output files, not in the reports.

**3c. Handle failures:** After the batch has reported, `ls .ios-review-temp/` and re-spawn, once, in the next batch every file whose `review-[SAFEPATH].json` is missing. A file still missing after its second attempt is a failure: record it for the final report and continue.

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
