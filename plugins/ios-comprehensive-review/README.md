# iOS comprehensive review plugin

Multi-agent code review for iOS/Swift projects. Five parallel agents run a 4-stage pipeline (resumable if interrupted) to check code quality, find duplicate code, detect breaking API changes, and flag design issues.

What it checks:
- Per-file: force unwraps, memory leaks, threading, Swift Concurrency (`@Sendable`, actor isolation, continuations), unused code, naming
- Cross-file: duplicate code, breaking API changes (including deleted functions), design violations, over-engineering
- Test-aware: fewer warnings for test files (force unwraps, naming)
- Resumable: picks up where it left off if interrupted

**When to use this vs `ios-quick-review`:** This plugin targets large PRs and branch reviews requiring parallel analysis, cross-file checks (duplicates, breaking changes, design issues), and resumability. `ios-quick-review` fits smaller changes where detailed per-file checks (performance, side effects, compliance) and scope confirmation matter more.

## Installation

Add to Claude Code plugins.

## Commands and skills

### Full review (recommended; single command)

```
/review-all <PR number>
/review-all --base main
/review-all --base main --branch feature
```

Runs all 4 stages automatically: extract, analyze, cross-check, report.

| Command | What it does |
|---------|--------------|
| `/review-all <PR number>` | Review a specific PR |
| `/review-all --base <branch>` | Review current branch against base |
| `/review-all --base <branch> --branch <branch>` | Review a specific branch against base |

### Stage-by-stage commands (for debugging, partial re-runs, or splitting across sessions)

Run individual stages to split work across sessions or re-run one stage:

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

Stages 2-4 depend on stage 1 (they read from `.ios-review-temp/pr-context.json`). Re-running a stage skips work already done. Run `/review-cleanup` after the report to remove temporary JSON files.

## Architecture

Five agents, parallelized within each stage:

| Agent | Focus | Model |
|-------|-------|-------|
| `file-analyzer` | Per-file: style, unused code, safety, threading, Swift Concurrency | Sonnet |
| `dry-analyzer` | Cross-file: duplicate function detection | Sonnet |
| `breaking-analyzer` | Cross-file: breaking API changes + deleted functions + affected callers | Sonnet |
| `solid-analyzer` | Cross-file: design principle violations, over-engineering | Sonnet |
| `report-aggregator` | Combine all findings into a markdown report | Haiku |

## Output

- Final report: `.ios-review-temp/ios-review-report.md`
- Temporary JSON files are removed automatically by `/review-all`, or manually via `/review-cleanup`

## Resumption

If interrupted, re-run the same command to continue. The analyze stage skips files already processed, cross-check skips if outputs exist, and report can be re-run safely.

## Git state and prerequisites

This plugin only reviews **committed** changes. Each mode interacts with git state differently.

### PR mode (`/review-all <PR number>`)

Fetches the diff from GitHub via `gh pr diff`. Works from **any** local branch; local git state does not matter.

**Requires:** `gh` CLI authenticated and the PR must exist in the current repo's remote.

### Branch mode (`/review-all --base <branch>`)

Uses `git diff <base>...<head>` (three-dot diff) to compare commits between two branches.

| Scenario | What happens |
|----------|-------------|
| Feature branch with commits ahead of `--base` | Works - reviews all committed changes |
| `--base main --branch feature` from any branch | Works - explicitly targets the right branches |
| On `main`, run `--base main` | **Empty diff** - comparing main to itself, 0 findings |
| Feature branch with only uncommitted/staged changes | **Empty diff** - uncommitted changes are not included |
| `--base` branch doesn't exist locally | **git error** - the base branch must be reachable |

Branch mode compares **committed code only**, not unsaved changes. To review uncommitted work, commit first or use `ios-quick-review` instead.

### When to use which plugin

| Your situation | Use |
|----------------|-----|
| Uncommitted/staged changes you want reviewed | `ios-quick-review` (reviews working tree by default) |
| Feature branch with commits ready for PR | `ios-comprehensive-review --base main` |
| Open PR on GitHub | `ios-comprehensive-review <PR number>` |
| Specific commit to review | `ios-quick-review <commit SHA>` |

### Requirements

- `jq` for JSON processing (`brew install jq`)
- GitHub CLI (`gh`) authenticated - PR mode only
- `git` - branch mode only
- Swift files in diff
