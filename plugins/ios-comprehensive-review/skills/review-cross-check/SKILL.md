---
name: review-cross-check
description: >-
  Cross-file iOS/Swift analysis for DRY violations, breaking API changes, and
  SOLID issues using parallel background agents. ONLY for iOS/Swift projects.
  Use when asked to "check cross-file issues", "find duplicates", "check
  breaking changes", "run cross-check", or "check SOLID violations".
  This is stage 3 of 4 in the iOS comprehensive review pipeline.
  For a single-command full review, use review-all instead.
disable-model-invocation: true
allowed-tools: Agent, Bash, Glob, TaskOutput
---

## Pre-loaded Context

Functions: !`jq '[.changed_files[] | .new_symbols[] | select(.type == "function")] | length' .ios-review-temp/pr-context.json 2>/dev/null || echo "0"`
Types: !`jq '[.changed_files[] | .new_symbols[] | select(.type != "function" and .type != "property")] | length' .ios-review-temp/pr-context.json 2>/dev/null || echo "0"`
Signatures: !`jq '.signature_changes | length' .ios-review-temp/pr-context.json 2>/dev/null || echo "0"`

## EXECUTION

### 1. Load Context

If ALL pre-loaded counts are 0: report "No cross-file analysis needed (no new functions, types, or signature changes)" → exit.

Extract detailed data as needed:

```bash
# Functions (name|file:line)
jq -r '.changed_files[] | .path as $p | .new_symbols[] | select(.type == "function") | "\(.name)|\($p):\(.line)"' .ios-review-temp/pr-context.json

# Types (name|file:line)
jq -r '.changed_files[] | .path as $p | .new_symbols[] | select(.type != "function" and .type != "property") | "\(.name)|\($p):\(.line)"' .ios-review-temp/pr-context.json

# Signature changes (method|old_sig|new_sig|file:line|change_type)
jq -r '.signature_changes[] | "\(.method)|\(.old_signature)|\(.new_signature // "")|\(.file):\(.line)|\(.change_type)"' .ios-review-temp/pr-context.json
```

### 2. Resume

`Glob(".ios-review-temp/*-analysis.json")` → check existing outputs.

Skip agent if file exists: `dry-analysis.json` → dry-analyzer, `breaking-analysis.json` → breaking-analyzer, `solid-analysis.json` → solid-analyzer.

If all exist: report "All cross-checks already complete" → exit.

### 3. Spawn Agents

Spawn ALL applicable agents (not already complete) in ONE message with `run_in_background: true`:

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

Spawn conditions:
- New functions exist → dry-analyzer
- Signature changes exist → breaking-analyzer
- New types OR new functions exist → solid-analyzer

Collect returned `task_id` for each spawned agent.

Report: `Spawned N cross-check agents`

### 4. Collect Results

For each spawned agent:

```
TaskOutput(task_id: [id], block: true, timeout: 600000)
```

Do NOT poll with `block: false`. Use `block: true` which waits for completion automatically.

**Timeout retry:** If `TaskOutput` returns a timeout (retrieval_status: timeout, or no meaningful result), the agent is still running. Call `TaskOutput` again with the SAME `task_id` and `block: true, timeout: 600000`. Repeat until the agent completes or fails. There is no limit on retries — agents must be given as much time as they need.

### 5. Final Report

```
DRY: done/skipped/failed | Breaking: done/skipped/failed | SOLID: done/skipped/failed
```

**Next step:** Run `/ios-comprehensive-review:review-report`
