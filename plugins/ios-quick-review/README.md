# iOS Quick Review Plugin

## The Problem

Code reviews are inconsistent. Reviewers miss issues because they don't systematically check every dimension — thread safety, retain cycles, naming conventions, dead code, performance, side effects. A single pass through a diff catches surface-level problems but misses the structural ones that cause production incidents.

## The Solution

An **exhaustive 8-phase code review** that systematically audits every changed file and traces call sites across the entire codebase. No shortcuts, no arbitrary caps on findings. If there are 47 issues, it reports 47 issues.

**Core idea: multi-pass coverage.** Each phase targets a different class of defect — correctness, architecture, naming, performance, side effects — so nothing falls through the cracks.

## How It Works

The review runs 8 sequential phases, each targeting a specific class of issue:

```
Phase 1: Scope Mapping       →  Map blast radius: changed files, symbols, call sites
Phase 2: Correctness & Safety →  Logic errors, thread safety, retain cycles, optionals
Phase 3: Architecture & Design →  SRP, DRY, YAGNI, coupling, abstraction consistency
Phase 4: Naming               →  AGENTS.md compliance, no abbreviations or temporal names
Phase 5: Dead Code & Hygiene  →  Unused code, stale TODOs, missing ABOUTME comments
Phase 6: Performance          →  Hot path allocations, O(n²), missing lazy, caching
Phase 7: Side Effects Audit   →  Hidden mutations, impure computed properties
Phase 8: AGENTS.md Compliance →  Smallest changes, style matching, root cause fixes
```

### Output

Every finding follows a structured format with severity, file location, phase, description, and concrete fix suggestion.

| Severity | Meaning |
|----------|---------|
| CRITICAL | Will crash, corrupt data, or cause security issues |
| MAJOR | Incorrect behavior, memory leak, race condition |
| MINOR | Code smell, DRY violation, naming issue |
| NIT | Style, formatting, trivial improvement |

Final report includes: summary table, risk assessment (top 3 riskiest findings), top 5 actions ordered by risk x effort, and missed call sites.

## Installation

Add to Claude Code plugins.

## Usage

Trigger naturally in the context of Swift/iOS code:

| You say... | What happens |
|-----------|--------------|
| "Review my code" | Full 8-phase review of uncommitted changes |
| "Review this commit" | Review a specific commit's changes |
| "Check my changes" | Review staged/unstaged changes |
| "Code review" | Full multi-pass audit |
| "Find bugs in this" | Targeted correctness and safety analysis |

## Requirements

- Swift/iOS codebase
- AGENTS.md in project root (for naming and compliance checks)

## Design

- **8 mandatory phases** — no skipping, no merging, no abbreviating
- **Call site tracing** — every changed symbol is traced across the entire project
- **No finding caps** — reports everything found, not an arbitrary top-10
- **AGENTS.md integration** — naming rules and code standards enforced automatically
- **Structured output** — every finding has severity, location, phase, and fix suggestion
