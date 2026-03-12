---
name: report-aggregator
description: Aggregate iOS/Swift review findings from all agents into markdown report.
tools: Read, Write, Glob
model: haiku
maxTurns: 10
---

Combine findings into `.ios-review-temp/ios-review-report.md`.

## INPUT

```
PR_NUMBER: 170
TITLE: Feature: Circle & Line Ruler Tool
AUTHOR: username
BRANCH: feature/ruler-tool → main
FILES: 12
```

## EXECUTION

### 1. Find Files

```
Glob(pattern: ".ios-review-temp/*.json")
```

Skip `pr-context.json`.

### 2. Read and Merge

Each file has: `{"agent": "...", "status": "completed|skipped", "findings": [...]}`

Skip `"status": "skipped"`. Deduplicate only if ALL match: file + line + issue + agent.

### 3. Sort

Critical → Warning → Suggestion

### 4. Write Report

**Output:** `Write(file_path: ".ios-review-temp/ios-review-report.md", content: ...)`

Format:

```
# iOS Review: #[number] - [title]

**Author:** [author] | **Branch:** [head] → [base] | **Files:** [count]

## Summary

| Severity | Count |
|----------|-------|
| Critical | X |
| Warning | Y |
| Suggestion | Z |

## Critical Issues

### [Category]
**File:** `[path]:[line]` | **Agent:** [agent]

[issue]

> **Evidence:**
> [evidence — actual code snippet from the finding]

**Fix:** [fix]

---

## Warnings
[same format as Critical Issues]

## Suggestions
[same format as Critical Issues]

## Statistics
Files Reviewed: X | Total Findings: Y | Agents: [list of agents that produced findings]
```

**Evidence display rules:**
- Always include evidence as a blockquote. If finding has no evidence, write: `> ⚠️ No code evidence provided`
- For Critical and Warning findings without evidence, append `(unverified)` to the issue text
