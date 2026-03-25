# Root cause analysis plugin

## The problem

When things break, the natural reaction is to fix what you see. A service crashes; restart it. A query is slow; add a cache. The same problems recur because nobody traced the real cause.

## What this does

An investigation tool that uses Claude Code to trace from symptom to root cause. It reads code, searches for patterns, checks git history, runs parallel investigations, and builds a chain of evidence using the 5 Whys technique.

Claude follows dependency chains and determines what went wrong. The output is a verified report with confidence ratings and fixes at three levels: immediate, short-term, and long-term.

## How it works

Claude runs a 4-phase investigation. You get a checkpoint between each phase.

```
Phase 0: Understand the Symptom  →  Clarify with user, determine scope → ✓ Scope checkpoint
Phase 1: Gather Evidence          →  Grep, Read, git history, parallel agents (Full) → ✓ Evidence checkpoint
Phase 2: 5 Whys Analysis          →  Build evidence-backed causal chain, confidence rating → ✓ Root cause checkpoint
Phase 3: Report & Solutions        →  Write RCA report, propose systemic fixes
```

### Scales to the problem

| Scope | When | Agent delegation | Output |
|-------|------|-----------------|--------|
| Quick | Single file, obvious bug | None | Inline summary in conversation |
| Standard | Multi-file regression, unclear cause | Optional Explore agent | RCA report written to `rca-reports/` |
| Full | Production incident, complex failure | 2 parallel investigation agents | Report with fishbone analysis |

### Techniques

**5 Whys** - Each "why" is backed by evidence from the investigation. The chain continues until it reaches a system-level cause.

**Fishbone diagram** - Groups contributing factors into categories: Code, Data, Infrastructure, and Process. Full investigations get the complete version; standard ones get a checklist.

**Confidence rating** - Every finding gets a High/Medium/Low rating based on evidence strength.

**Evidence log** - Organized record of all findings with source code references, used throughout the analysis.

Solutions target the system, not the person. "Add CI performance tests" over "train one developer."

### Verification

Every finding is checked against the actual codebase:
- File paths checked with Glob before inclusion
- Code behavior confirmed via Read (never inferred from names)
- Git history cited from actual `git log`/`git blame` output
- Git SHAs verified with `git show --stat` before citing
- Code re-read before including in final report
- Unverified claims marked as hypothesis

## Usage

| Skill | Trigger | What it does |
|-------|---------|--------------|
| `/root-cause-analysis` | "investigate this bug", "root cause", "why does this keep happening", "what caused this regression", "postmortem", "flaky test", "why does CI fail", "trace this error" | Evidence-backed root cause investigation |

You can pass arguments too: `/root-cause-analysis <description of the symptom>`

### Examples

| You say... | What happens |
|-----------|--------------|
| "Why does this test keep failing?" | Quick scope - traces the failure, finds root cause inline |
| "Investigate this crash" | Standard scope - full investigation, writes RCA report |
| "Do an RCA on last week's outage" | Full scope - parallel agents, fishbone analysis, detailed report |
| "What caused this regression?" | Standard scope - git history analysis, dependency tracing |
| "This test is flaky, figure out why" | Standard scope - race condition analysis, environment check |
| "Why does this work locally but fail in CI?" | Standard scope - environment-dependent investigation |

## Claude Code tools used

| Tool | Purpose |
|------|---------|
| Grep | Search for error messages, function names, patterns across the codebase |
| Glob | Find relevant files (tests, configs, migrations) and verify file paths exist |
| Read | Examine source code, read reference templates |
| Bash | Git operations: `git log`, `git blame`, `git diff`, `git show`, `git bisect` |
| Agent | Full scope: 2 parallel investigation agents (Code+Data, Infrastructure+Process). Standard: optional Explore agent |
| Write | Create RCA report file (Standard/Full scope) |
| AskUserQuestion | Scope confirmation, evidence checkpoint, validate root cause hypothesis |
| TodoWrite | Track investigation progress |

## Design principles

1. Symptom is not root cause - always dig deeper than the first "why"
2. Evidence over guessing - every claim backed by actual findings
3. Fix the system, not the person - improve processes, do not blame people
4. Simple bugs get simple treatment
5. User stays in control - checkpoints at scope, evidence, and root cause
6. Every finding carries a confidence level
7. Keeps AI context usage low with limits, summaries, and parallel agents
8. Blameless - focus on what happened and why, not who did it
