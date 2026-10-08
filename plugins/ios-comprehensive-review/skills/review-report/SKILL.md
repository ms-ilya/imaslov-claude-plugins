---
name: review-report
description: Stage 4 of 4 — verify the critical and warning findings in .ios-review-temp/ against the code, then build the final iOS/Swift review report. review-all runs every stage.
disable-model-invocation: true
allowed-tools:
  - Agent
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/findings-worklist.sh *)
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/build-report.sh *)
---

## Pre-loaded Context

Context: !`ls .ios-review-temp/pr-context.json 2>/dev/null || echo "NO_CONTEXT"`

## EXECUTION

If the context shows `NO_CONTEXT`: report "Run `/ios-comprehensive-review:review-extract <PR>` first" → exit.

### 1. Verify Findings

The analyzers each saw a narrow slice of the code, so their critical and warning findings are re-checked by an agent that did not write them before anything reaches the report.

List the findings that still need a verdict:

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/findings-worklist.sh
```

Each output line is one finding as a JSON object. No output: nothing to verify → go to step 2.

Split the lines into batches of at most 15, keeping the findings of one `file` in the same batch so that a verifier reads each file once. `ls .ios-review-temp/` and number the batches after the highest existing `verdicts-N.json`. Spawn ALL batches in ONE message:

```
Agent(subagent_type: "ios-comprehensive-review:finding-verifier",
     prompt: "WORKLIST:
[the batch's lines, copied exactly]
OUTPUT_FILE: .ios-review-temp/verdicts-[N].json")
```

Subagents run in the background and each one reports back on its own when it finishes. Wait until every verifier has reported; do not poll, sleep, or read their transcripts.

Run the worklist script again. Findings it still lists got no verdict: spawn one more round for them. Whatever is still listed after that round stays in the report, marked unverified.

### 2. Build the Report

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/build-report.sh
```

The script writes `.ios-review-temp/ios-review-report.md` and prints the counts. If it exits non-zero: report its error and stop.

### 3. Report

`Complete. Report: .ios-review-temp/ios-review-report.md | ` followed by the script's count line.

**Next step:** Run `/ios-comprehensive-review:review-cleanup` to remove the intermediate files.
