# PR Review Plugin

Multi-agent PR review for Swift codebases.

## Installation

Add to Claude Code plugins.

## Usage

### Review a GitHub PR

```
Extract context for PR 170
Analyse PR 170 files
Check cross-file issues for PR 170
Create review report for PR 170
```

### Self-review before opening a PR

Compare your branch against the base branch (where you'll open the PR):

```
Extract context for branch feature/ruler-tool where base branch main
Analyse branch files
Check cross-file issues for branch
Create review report for branch
```

If you're already on the branch, omit the branch name:

```
Extract context where base branch main
```

## Commands

| Stage | PR trigger | Branch trigger | Description |
|-------|-----------|---------------|-------------|
| 1. Extract | "Extract context for PR 170" | "Extract context for branch X where base branch Y" | Fetch diff and metadata |
| 2. Analyze | "Analyse PR 170 files" | "Analyse branch files" | Per-file review (style, quality, unused code) |
| 3. Cross-check | "Check cross-file issues for PR 170" | "Check cross-file issues for branch" | DRY violations, breaking API changes, SOLID issues |
| 4. Report | "Create review report for PR 170" | "Create review report for branch" | Final markdown report |

## Output

- Temp files: `.pr-review-temp/`
- Final report: `pr-review-temp.md`

## Resumption

If interrupted, re-run the same command to continue:
- Analyze skips already-processed files
- Cross-check skips if outputs exist
- Report can be re-run safely

## Requirements

- GitHub CLI (`gh`) authenticated — PR mode only
- `git` — branch mode only
- Swift files in diff
