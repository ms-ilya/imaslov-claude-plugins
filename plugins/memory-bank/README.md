# Memory Bank Plugin

## The Problem

AI agents and new developers waste time figuring out how features work from scratch. Wikis go stale. READMEs get outdated. Knowledge is scattered across git history, code comments, and people's heads. Every new session starts from zero.

## The Solution

An always-up-to-date documentation system that records **what is true right now** about your project, organized by feature. One command documents a feature — deep code analysis, structured output, and mandatory checks against actual source code.

**Core idea: no made-up information.** Every file path, type name, and description of behavior is checked against the real codebase using Claude Code's built-in tools (Glob, Grep, Read) before being written to docs.

## What It Does

The Memory Bank creates a structured `memory-bank/` folder at your project root with two layers:

**Root-level documentation** (project-wide):
- **WIKI.md** — navigation hub and feature index (read this first)
- **systemPatterns.md** — architecture, design patterns, conventions
- **techContext.md** — tech stack, dependencies, build setup
- **TROUBLESHOOTING.md** — project-wide known issues

**Per-feature documentation** (one folder per feature):
- **IMPLEMENTATION.md** — how the feature works, key files, data flow, dependencies
- **ACTIVE_CONTEXT.md** — current state, in-progress work, known TODOs
- **TROUBLESHOOTING.md** — feature-specific gotchas and known issues
- **DECISIONS.md** — key technical decisions (ADR-style, manually curated via `/add-decision`)

## Commands & Skills

This plugin provides 5 commands:

| Command | Trigger | What it does |
|---------|---------|--------------|
| `/init-memory-bank` | "create memory-bank", "initialize memory-bank" | Scans your project, detects language/framework, creates `memory-bank/` with root-level docs |
| `/update-memory-bank <feature>` | "document feature X", "update memory-bank for X" | Discovers related files via Grep/Glob, performs deep analysis, generates 3 feature docs (IMPLEMENTATION, ACTIVE_CONTEXT, TROUBLESHOOTING), runs verification, updates root WIKI |
| `/update-memory-bank-system` | "refresh system docs", "rebuild wiki index" | Re-scans architecture and dependencies, rebuilds the WIKI index and root-level files |
| `/add-decision <feature>: <desc>` | "add decision for X: ..." | Records a technical decision (ADR-style) in the feature's DECISIONS.md |
| `/memory-bank` | "how does the memory bank work" | Shows Memory Bank structure, routes to the right sub-skill |

### Workflow

```
/init-memory-bank                                     (one-time setup)
  ↓
/update-memory-bank authentication                    (document each feature)
/update-memory-bank push-notifications
  ↓
/update-memory-bank-system                            (refresh root docs periodically)
  ↓
/add-decision authentication: Use Keychain for tokens (record decisions as they happen)
```

### What happens when you document a feature

1. Claude searches the codebase for all files related to the feature (multiple naming conventions: camelCase, PascalCase, snake_case, kebab-case)
2. Shows discovered files and **asks for confirmation** before proceeding
3. Reads files using a tiered strategy — full read for core files, targeted read for secondary files
4. Generates (or updates) the 3 feature documentation files
5. Runs a **mandatory verification pass** — every file path checked via Glob, every type name checked via Grep, behavioral claims traced via Read
6. Flags unverifiable content with `⚠️ INFERRED` or removes it
7. Updates the root WIKI.md and other root files

## Accuracy Verification

Every Memory Bank update includes a mandatory check to make sure nothing is made up:

- **File paths** — every path in the docs is checked to actually exist on disk
- **Type names** — every class/struct/protocol/enum is searched for in the source files
- **Behavior descriptions** — descriptions are traced back to actual code to confirm they're correct
- **Unverifiable content** — flagged with `⚠️ INFERRED` (with notes on what WAS verified) or removed entirely
- **Verification summary** — shown after each file with pass/fail counts; must have ≤30% INFERRED rate

## Claude Code Tools Used

| Tool | Purpose |
|------|---------|
| **Glob** | Find project files, verify file paths exist |
| **Grep** | Discover feature-related files, verify type names |
| **Read** | Read source code for analysis, read templates, verify behavioral claims |
| **Write** | Create new documentation files |
| **Edit** | Update existing documentation files |

No Bash commands needed — all operations use Claude Code's built-in tools.

## When to Use This Plugin

The Memory Bank is designed for projects where:
- AI agents need fast, accurate information about features
- New developers need to get up to speed quickly
- You want documentation that stays up to date
- You're tired of outdated wikis and stale READMEs

**It's NOT:**
- A changelog (use git)
- A task tracker (use your issue tracker)
- Auto-generated API docs (use DocC/Jazzy/TypeDoc for that)

## Output Structure

```
your-project/
├── memory-bank/
│   ├── WIKI.md
│   ├── systemPatterns.md
│   ├── techContext.md
│   ├── TROUBLESHOOTING.md
│   ├── authentication/
│   │   ├── IMPLEMENTATION.md
│   │   ├── ACTIVE_CONTEXT.md
│   │   ├── DECISIONS.md          (created via /add-decision)
│   │   └── TROUBLESHOOTING.md
│   └── push-notifications/
│       └── ...
```

## Tips

- **Run `/update-memory-bank <feature>` after significant changes** to keep docs current
- **Run `/update-memory-bank-system` periodically** to keep root-level docs fresh
- **Commit the `memory-bank/` folder** to your repo — it's meant to be shared
- **DECISIONS.md is manually curated** — Claude won't auto-populate it; use `/add-decision` to record decisions explicitly
- **The verification step takes extra time but prevents made-up information** — it's worth it

## Design

- Works with any language — detects project type and adapts (Swift, TypeScript, Python, Rust, Go, Kotlin, Java)
- Optimized for Swift/iOS/macOS projects with a dedicated reference file
- Organized by feature for quick access
- Current state only — no changelogs, no date-stamped entries
