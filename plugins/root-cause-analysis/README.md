# Root Cause Analysis Plugin

## The Problem

When things break, the natural reaction is to fix what you see and move on. A service crashes — restart it. A query is slow — add a cache. But the same problems keep coming back because the real cause was never found. Without a clear method, debugging becomes guesswork and the same issues repeat.

## The Solution

An investigation tool that uses Claude Code to trace from what you see (the symptom) to what actually caused it (the root cause) — by reading your code, searching for patterns, checking git history, running parallel investigations, and building a chain of evidence using the **5 Whys** technique.

**Core idea: fix the system, not the symptom.** Claude investigates your code, follows the chain of dependencies, identifies what went wrong and why, then writes a verified report with confidence ratings and solutions at three levels (immediate, short-term, long-term).

## What It Does

Claude runs a 4-phase investigation with user checkpoints at each transition:

```
Phase 0: Understand the Symptom  →  Clarify with user, determine scope → ✓ Scope checkpoint
Phase 1: Gather Evidence          →  Grep, Read, git history, parallel agents (Full) → ✓ Evidence checkpoint
Phase 2: 5 Whys Analysis          →  Build evidence-backed causal chain, confidence rating → ✓ Root cause checkpoint
Phase 3: Report & Solutions        →  Write RCA report, propose systemic fixes
```

### Adapts to Problem Size

| Scope | When | Agent Delegation | Output |
|-------|------|-----------------|--------|
| **Quick** | Single file, obvious bug | None | Inline summary in conversation |
| **Standard** | Multi-file regression, unclear cause | Optional Explore agent | RCA report written to `rca-reports/` |
| **Full** | Production incident, complex failure | 2 parallel investigation agents | Comprehensive report with fishbone analysis |

### Techniques

- **5 Whys** — Each "why" is backed by evidence found during the investigation. Keeps going until it reaches the real, system-level cause.
- **Fishbone Diagram** — Groups contributing factors into categories: Code, Data, Infrastructure, Process, and People. Full version for big investigations, simple checklist for standard ones.
- **Confidence Rating** — Every finding is rated High/Medium/Low based on how strong the evidence is.
- **Evidence Log** — Organized record of all findings with references to source code, used throughout the analysis.
- **Fix the system, not the person** — Always prefers system-level solutions ("add CI performance tests") over individual fixes ("train one developer").

### Verification

Every finding is verified against the actual codebase:
- File paths checked with Glob before inclusion
- Code behavior confirmed via Read (never inferred from names)
- Git history cited from actual `git log`/`git blame` output
- Git SHAs verified with `git show --stat` before citing
- Code re-read before including in final report
- Unverified claims marked `⚠️ HYPOTHESIS`

## Commands & Skills

This plugin provides a single skill with a slash command:

| Command | Trigger | What it does |
|---------|---------|--------------|
| `/root-cause-analysis` | "investigate this bug", "root cause", "why does this keep happening", "what caused this regression", "postmortem", "flaky test", "why does CI fail", "trace this error" | Full evidence-backed root cause investigation |

You can also pass arguments: `/root-cause-analysis <description of the symptom>`

### Examples

| You say... | What happens |
|-----------|--------------|
| "Why does this test keep failing?" | Quick scope — traces the failure, finds root cause inline |
| "Investigate this crash" | Standard scope — full investigation, writes RCA report |
| "Do an RCA on last week's outage" | Full scope — parallel agents, fishbone analysis, detailed report |
| "What caused this regression?" | Standard scope — git history analysis, dependency tracing |
| "This test is flaky, figure out why" | Standard scope — race condition analysis, environment check |
| "Why does this work locally but fail in CI?" | Standard scope — environment-dependent investigation |

## Claude Code Tools Used

| Tool | Purpose |
|------|---------|
| **Grep** | Search for error messages, function names, patterns across codebase |
| **Glob** | Find relevant files (tests, configs, migrations). Verify file paths exist |
| **Read** | Examine source code, read reference templates |
| **Bash** | Git operations: `git log`, `git blame`, `git diff`, `git show`, `git bisect` |
| **Agent** | Full scope: 2 parallel investigation agents (Code+Data, Infrastructure+Process). Standard: optional Explore agent |
| **Write** | Create RCA report file (Standard/Full scope) |
| **AskUserQuestion** | Scope confirmation, evidence checkpoint, validate root cause hypothesis |
| **TodoWrite** | Track investigation progress |

## Design Principles

1. **Symptom ≠ Root Cause** — Always dig deeper than the first "why"
2. **Evidence over guessing** — Every claim backed by actual findings
3. **Fix the system, not the person** — Improve processes, not blame people
4. **Adapts to the problem** — Simple bugs get simple treatment
5. **User stays in control** — Three checkpoints: scope, evidence, root cause
6. **Confidence-rated** — Every finding carries a confidence level
7. **Efficient** — Keeps AI context usage low with limits, summaries, and parallel agents
8. **Blameless** — Focus on what happened and why, not who did it
