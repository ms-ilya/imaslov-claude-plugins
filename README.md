# imaslov-claude-plugins

A collection of Claude Code plugins by Ilya Maslau.

## Plugins

### [pr-review](./plugins/pr-review)

Multi-agent PR review for Swift codebases. Runs a 4-stage pipeline with 6 specialized agents that analyze code in parallel.

**What it does:**
- Per-file analysis: unused code, force unwraps, memory leaks, threading issues, naming violations
- Cross-file analysis: duplicate implementations (DRY), breaking API changes, SOLID violations
- Resumable: interrupted reviews continue from where they stopped

**Stages:**

| Stage | Command | What happens |
|-------|---------|--------------|
| Extract | `Extract context for PR 170` | Parses diff, extracts symbols and signature changes |
| Analyze | `Analyse PR 170 files` | Spawns parallel agents for per-file review (batches of 5) |
| Cross-check | `Check cross-file issues for PR 170` | Runs DRY, breaking change, and SOLID analyzers in parallel |
| Report | `Create review report for PR 170` | Aggregates all findings into a severity-sorted markdown report |

Also supports branch-to-branch review without a PR: `Extract context for branch feature/x where base branch main`

**Requirements:** `gh` CLI (PR mode), `git` (branch mode), `jq`

Full documentation: [plugins/pr-review/README.md](./plugins/pr-review/README.md)

---

*More plugins coming soon.*

## Installation

Add this marketplace to Claude Code plugins.

## License

[MIT](./LICENSE)
