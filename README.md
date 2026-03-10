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

### [scratchpad](./plugins/scratchpad)

Context-preserving debugging journal that persists investigation state across sessions.

**What it does:**
- Creates `.scratchpads/` directory with per-issue markdown files
- Tracks failed approaches, edge cases, related files, and architectural decisions
- Transforms into clean knowledge artifacts on resolution

**Commands:**

| Command | What happens |
|---------|--------------|
| `/scratchpad` | Create new or update existing scratchpad |
| `/scratchpad resolve` | Transform and archive to resolved/ |
| `/scratchpad abandon` | Mark as dead end, keep as warning |
| `/scratchpad switch` | Switch active scratchpad |

**Requirements:** None (works in any project)

Full documentation: [plugins/scratchpad/README.md](./plugins/scratchpad/README.md)

### [memory-bank](./plugins/memory-bank)

Living documentation system that captures current project state, organized by feature. Every claim is verified against actual source code.

**What it does:**
- Creates a structured `memory-bank/` folder with per-feature documentation
- Deep code analysis: architecture, data flow, key types, dependencies, tests
- Anti-hallucination verification: every file path, type name, and behavioral claim is checked against real code
- Root-level docs: WIKI index, system patterns, tech context, troubleshooting

**Commands:**

| Command | What happens |
|---------|--------------|
| `/init-memory-bank` | Scan project and create `memory-bank/` with root-level docs |
| `/update-memory-bank <feature>` | Document or update a specific feature (primary workflow) |
| `/update-memory-bank-system` | Refresh root-level docs (architecture, deps, WIKI index) |
| `/add-decision <feature>: <description>` | Record a technical decision (ADR-style) |

**Requirements:** None (works in any project, optimized for Swift/iOS)

Full documentation: [plugins/memory-bank/README.md](./plugins/memory-bank/README.md)

### [multi-agent-debate](./plugins/multi-agent-debate)

Structured multi-agent debate that spawns parallel LLM agents for adversarial analysis and synthesis.

**What it does:**
- Spawns 3–5 independent agents with unique system prompts, each arguing from a genuinely different perspective
- 3-round structured debate: Opening Positions → Cross-Examination → Rebuttals
- Impartial Judge synthesizes a verdict with confidence level, dissent log, and flip conditions
- Fallback to inline simulation if API calls fail

**Usage:**

| Trigger | What happens |
|---------|--------------|
| "Debate whether we should use microservices" | Full 3-round debate with tailored agents |
| "Red team this proposal" | Adversarial analysis with pressure-testing |
| "Analyze this from all angles" | Multi-perspective analysis with synthesis |
| "Devil's advocate on our auth strategy" | Structured challenge with cross-examination |

Post-debate: "Go deeper", "Challenge the verdict", "Add an agent", or "Export"

**Requirements:** Anthropic API key

Full documentation: [plugins/multi-agent-debate/README.md](./plugins/multi-agent-debate/README.md)

### [ios-quick-review](./plugins/ios-quick-review)

Exhaustive multi-pass iOS/Swift code review for commits or uncommitted changes.

**What it does:**
- 8-phase sequential audit: scope mapping, correctness, architecture, naming, dead code, performance, side effects, AGENTS.md compliance
- Traces call sites across the entire codebase for every changed symbol
- No finding caps — reports everything found with severity, location, and fix suggestions
- Structured output with summary table, risk assessment, and top actions

**Usage:**

| Trigger | What happens |
|---------|--------------|
| "Review my code" | Full 8-phase review of uncommitted changes |
| "Review this commit" | Review a specific commit's changes |
| "Check my changes" | Review staged/unstaged changes |
| "Find bugs in this" | Targeted correctness and safety analysis |

**Requirements:** Swift/iOS codebase, AGENTS.md in project root

Full documentation: [plugins/ios-quick-review/README.md](./plugins/ios-quick-review/README.md)

---

## Installation

Add this marketplace to Claude Code plugins.

## License

[MIT](./LICENSE)
