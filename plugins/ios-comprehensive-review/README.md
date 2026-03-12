# iOS Comprehensive Review Plugin

Multi-agent code review for iOS/Swift projects. Uses 5 specialized parallel agents across a 4-stage pipeline (can resume if interrupted) to check code quality, find duplicate code, detect breaking API changes, and flag design issues.

**Key capabilities:**
- Per-file: force unwraps, memory leaks, threading, Swift Concurrency (`@Sendable`, actor isolation, continuations), unused code, naming
- Cross-file: finds duplicate code, breaking API changes (including deleted functions), design violations, over-engineering
- Test-aware: reports fewer warnings for test files (force unwraps, naming)
- Resumable: if interrupted, picks up where it left off

**When to use this vs `ios-quick-review`:** Use this plugin for large PRs and branch reviews where you need parallel analysis, cross-file checks (duplicates/breaking changes/design issues), and the ability to resume. Use `ios-quick-review` for smaller changes where detailed checks (performance, side effects, compliance) and scope confirmation matter more.

## Installation

Add to Claude Code plugins.

## Commands & Skills

### Full Review (recommended — single command)

```
/review-all <PR number>
/review-all --base main
/review-all --base main --branch feature
```

This runs all 4 stages automatically: extract → analyze → cross-check → report.

| Command | What it does |
|---------|--------------|
| `/review-all <PR number>` | Review a specific PR |
| `/review-all --base <branch>` | Review current branch against base |
| `/review-all --base <branch> --branch <branch>` | Review a specific branch against base |

### Stage-by-Stage Commands (for debugging, partial re-runs, or splitting across sessions)

Run individual stages when you want to split work across separate sessions or re-run a specific stage:

```
/review-extract <PR number>       # Stage 1: fetch diff and metadata
/review-analyze                   # Stage 2: per-file analysis (parallel agents)
/review-cross-check               # Stage 3: DRY, breaking changes, SOLID
/review-report                    # Stage 4: generate final report
/review-cleanup                   # Remove intermediate files, keep only report
```

| Command | Stage | Description |
|---------|-------|-------------|
| `/review-extract <PR number>` | 1. Extract | Fetch diff, parse changed files, symbols, signature changes |
| `/review-extract --base <branch>` | 1. Extract | Same, but from branch diff instead of PR |
| `/review-analyze` | 2. Analyze | Per-file review: style, unused code, threading, memory, safety |
| `/review-cross-check` | 3. Cross-check | Cross-file: DRY violations, breaking API changes, SOLID issues |
| `/review-report` | 4. Report | Aggregate findings into final markdown report |
| `/review-cleanup` | Cleanup | Remove intermediate files, keep only the final report |

Stages 2-4 need stage 1 to run first (they read from `.ios-review-temp/pr-context.json`). Each stage can resume — re-running it skips work that's already done. Run `/review-cleanup` after the report to remove temporary JSON files.

## Architecture

5 specialized agents (parallelized within each stage):

| Agent | Focus | Model |
|-------|-------|-------|
| `file-analyzer` | Per-file: style, unused code, safety, threading, Swift Concurrency | Sonnet |
| `dry-analyzer` | Cross-file: duplicate function detection | Sonnet |
| `breaking-analyzer` | Cross-file: breaking API changes + deleted functions + affected callers | Sonnet |
| `solid-analyzer` | Cross-file: design principle violations, over-engineering check | Sonnet |
| `report-aggregator` | Combine all findings into a markdown report | Haiku |

## Output

- Final report: `.ios-review-temp/ios-review-report.md`
- Temporary JSON files are removed automatically by `/review-all`, or manually via `/review-cleanup`

## Resumption

If interrupted, re-run the same command to continue:
- Analyze skips already-processed files
- Cross-check skips if outputs exist
- Report can be re-run safely

## Git State & Prerequisites

This plugin reviews **committed** changes only. Understanding how each mode interacts with your git state avoids confusion:

### PR Mode (`/review-all <PR number>`)

Fetches the diff from GitHub via `gh pr diff`. Works from **any** local branch — your local git state doesn't matter.

**Requires:** `gh` CLI authenticated and the PR must exist in the current repo's remote.

### Branch Mode (`/review-all --base <branch>`)

Uses `git diff <base>...<head>` (three-dot diff) to compare the commits between two branches.

| Scenario | What happens |
|----------|-------------|
| Feature branch with commits ahead of `--base` | Works — reviews all committed changes |
| `--base main --branch feature` from any branch | Works — explicitly targets the right branches |
| On `main`, run `--base main` | **Empty diff** — comparing main to itself, 0 findings |
| Feature branch with only uncommitted/staged changes | **Empty diff** — uncommitted changes are not included |
| `--base` branch doesn't exist locally | **git error** — the base branch must be reachable |

**Key point:** Branch mode compares **committed code only**, not your current unsaved changes. If you want to review uncommitted work, either commit it first or use `ios-quick-review` instead.

### When to Use Which Plugin

| Your situation | Use |
|----------------|-----|
| Uncommitted/staged changes you want reviewed | `ios-quick-review` (reviews working tree by default) |
| Feature branch with commits ready for PR | `ios-comprehensive-review --base main` |
| Open PR on GitHub | `ios-comprehensive-review <PR number>` |
| Specific commit to review | `ios-quick-review <commit SHA>` |

### Requirements

- `jq` — JSON processing (`brew install jq`)
- GitHub CLI (`gh`) authenticated — PR mode only
- `git` — branch mode only
- Swift files in diff
