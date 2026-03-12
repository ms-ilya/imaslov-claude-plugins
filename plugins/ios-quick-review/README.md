# iOS Quick Review Plugin

A step-by-step code review for iOS/Swift that adjusts its depth based on how big your changes are. Checks 8 areas: correctness, architecture, naming, dead code, performance, side effects, and AGENTS.md compliance.

**When to use this vs `ios-comprehensive-review`:** Use this plugin for smaller changes, uncommitted work, and when you want scope confirmation, performance checks, and compliance checks. Use `ios-comprehensive-review` for large PRs where you need parallel analysis, cross-file checks (duplicates/breaking changes/SOLID), and the ability to resume interrupted reviews.

## The Problem

Code reviews are inconsistent. Reviewers miss things because they don't check every area — thread safety, retain cycles, naming, dead code, performance, side effects. Reading through a diff once catches obvious problems but misses deeper issues that cause bugs in production.

AI-powered code reviews have an extra problem: made-up findings — fake line numbers, issues in code that was never actually read, references to checks that never happened. A review that invents problems is worse than no review at all.

## The Solution

An **8-phase code review** (Phase 0-7) that checks every changed file and traces where changed code is used across your project. Adapts to the size of your changes — small diffs get a quick single pass, large diffs are split across parallel agents. Reports every issue found — no artificial limits. If there are 47 issues, you see all 47.

**Core ideas:**
- **Multiple passes.** Each phase looks for a different type of problem — correctness, architecture, naming, performance, side effects — so nothing gets missed.
- **Verified findings only.** Every reported issue must reference code that was actually read. Code snippets are included as proof.
- **Adapts to diff size.** Small diffs (1-3 files) get a fast combined pass. Medium diffs run all phases one by one. Large diffs (15+ files) are split across parallel agents.

## What It Does

The review runs 8 sequential phases, each targeting a specific class of issue:

```
Phase 0: Acquire Changes    →  Get the diff via git commands (uncommitted, commit, or PR)
Phase 1: Scope Mapping      →  Map what's affected: changed files, changed symbols, all places they're used
Phase 2: Correctness        →  Logic errors, thread safety, retain cycles, optionals, error handling
Phase 3: Architecture       →  SRP, DRY, YAGNI, coupling, abstraction consistency
Phase 4: Naming             →  AGENTS.md compliance, no abbreviations or temporal names
Phase 5: Dead Code          →  Unused code, stale TODOs, missing ABOUTME comments
Phase 6: Performance        →  Hot path allocations, O(n²), missing lazy, caching
Phase 7: Side Effects       →  Hidden mutations, order-dependent operations, AGENTS.md compliance
```

### Key Features

- **No made-up findings** — must read the actual code before reporting, include real code snippets, re-check line numbers before writing each finding
- **Adapts to diff size** — small diffs run fast (~1 min); large diffs are split into batches across parallel agents
- **Phase 1 checkpoint** — shows you a summary of what will be reviewed and asks for confirmation before starting the deep analysis
- **Progress tracking** — creates a checklist of phases with live status updates
- **Traces where code is used** — every changed function/variable is searched across the entire project; files that weren't changed but might be affected are flagged

### How It Adapts to Diff Size

| Diff size | Strategy |
|-----------|----------|
| Small (1-3 files, <50 lines) | Phase 0, brief Phase 1, single combined pass for Phases 2-7 |
| Medium (3-15 files, 50-500 lines) | All phases sequentially |
| Large (15+ files, 500+ lines) | Phase 1 scope map, then Agent subagents per batch of 5-8 files |

### Output

Findings use severity-appropriate formatting:

| Severity | Meaning | Format | Action |
|----------|---------|--------|--------|
| CRITICAL | Crash, data loss, security vulnerability | Full (code + fix) | Must fix before merge |
| MAJOR | Incorrect behavior, memory leak, race condition | Full (code + fix) | Should fix before merge |
| MINOR | Code smell, DRY violation, naming issue | Compact (one-line) | Fix when convenient |
| NIT | Style, formatting, trivial improvement | Compact (one-line) | Fix if touching the file anyway |

Final report includes: summary table, risk assessment (top 3 riskiest findings), top 5 actions ordered by risk x effort, and missed call sites.

For reviews with 20+ findings, the full report is also written to a `code-review-YYYY-MM-DD.md` file.

## Commands & Skills

This plugin provides a single skill with a slash command:

| Command | Trigger | What it does |
|---------|---------|--------------|
| `/ios-quick-review` | "review my code", "review this commit", "check my changes", "look at my diff", "find bugs", "code review", "PR review", "what do you think about this code" | Full multi-pass code review |

You can also pass arguments: `/ios-quick-review <commit SHA or PR number>`

**Auto-trigger condition:** Only activates for Swift/iOS codebases (must contain `.swift` files, `.xcodeproj`, `.xcworkspace`, or `Package.swift`). Does NOT trigger for non-Swift projects.

## Claude Code Tools Used

| Tool | Purpose |
|------|---------|
| **Read** | Read source files to verify findings; re-read before writing each finding |
| **Grep** | Find symbol usages, call sites, protocol conformances across the project |
| **Glob** | Discover project structure, find files by pattern (`*.swift`, `*Tests.swift`) |
| **Bash** | Git commands only — `git diff`, `git log`, `git show`, `git status`, `gh pr diff` |
| **Agent** | Parallelize call-site tracing (10+ symbols) and large-diff reviews (15+ files) |
| **Write** | Save full review report to file for reviews with 20+ findings |
| **TodoWrite** | Track review progress across phases with real-time status updates |
| **AskUserQuestion** | Phase 1 checkpoint — confirm scope before deep analysis |

## Git State & Prerequisites

This plugin reviews **uncommitted changes** by default, making it the right choice for work-in-progress code. It also supports reviewing specific commits and PRs.

### Default (no arguments): Uncommitted Changes

Runs `git diff HEAD` to capture all staged and unstaged changes against the current HEAD.

| Scenario | What happens |
|----------|-------------|
| Uncommitted/staged changes exist | Reviews them — this is the default workflow |
| Clean working tree, no arguments | Asks what you'd like to review (graceful, no error) |
| On any branch (main, feature, etc.) | Works — compares working tree to HEAD |

### With Arguments

| Argument | Git command | What it reviews |
|----------|------------|-----------------|
| `<commit SHA>` | `git diff <sha>~1 <sha>` | Changes introduced by that specific commit |
| `<PR number>` | `gh pr diff <number>` | Full PR diff from GitHub |

### When to Use Which Plugin

| Your situation | Use |
|----------------|-----|
| Uncommitted/staged changes you want reviewed | `ios-quick-review` (reviews working tree by default) |
| Specific commit to review | `ios-quick-review <commit SHA>` |
| Feature branch with commits ready for PR | `ios-comprehensive-review --base main` |
| Open PR on GitHub | `ios-comprehensive-review <PR number>` |

### Requirements

- **Swift/iOS codebase** (required)
- **`gh` CLI authenticated** (PR mode only)
- **AGENTS.md in project root** (optional — enables naming convention enforcement and compliance checks in Phases 4 and 7; the skill gracefully degrades without it)

## Design

- **8 phases (0-7)** — structured steps from getting the diff to checking compliance
- **Verified findings only** — every issue is backed by code that was actually read, with snippets
- **Traces usage** — every changed symbol is searched across the entire project
- **No limits on findings** — reports everything found, not just the top 10
- **Adapts to diff size** — small changes reviewed quickly, large changes split across parallel agents
- **AGENTS.md integration** — naming rules and code standards enforced when available
- **Compact output** — full format for critical issues, one-liners for minor ones
