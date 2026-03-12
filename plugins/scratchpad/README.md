# Scratchpad Plugin

## The Problem

AI agents make mistakes during debugging — they try approaches that fail, go in circles, and lose context between sessions. Without a record of what was tried and why it failed, every new session starts from zero. The same dead ends get explored again and again.

## The Solution

A `.md` file per bug/issue that works as a **debugging notebook** while you investigate and becomes a **clean summary of the solution** when you're done. One command — `/scratchpad` — handles everything automatically.

**Core idea: "Keep the wrong stuff in."** Failed attempts stay visible like a map of dead ends, so the AI doesn't repeat the same mistakes. When the issue is resolved, the noise is removed and only the solution remains.

## What It Does

The scratchpad is a **guide for what to do next** — not a history log. It answers two questions:
1. **Where NOT to go** — failed approaches with reasons
2. **Where to go next** — evolved understanding, edge cases, plan to fix

Every `/scratchpad` call runs a single automatic flow:

```
LOCATE → find or create the right scratchpad (Glob scan of .scratchpads/)
READ   → re-read from disk (never trust in-memory — another session may have changed it)
DIFF   → extract new findings from conversation (dedup against existing content via Grep)
WRITE  → append to appropriate sections (Edit for updates, Write for new files)
CONFIRM → brief summary of what changed
```

### What Gets Tracked

- **Failed approaches** — what was tried, what happened, why it's wrong, actual insight (2-4 lines each)
- **Edge cases** — living checklist that grows into the definition of "done"
- **Related files** — investigated, changed, root cause
- **Architectural decisions** — short decision records, expanded into full format when resolved
- **Error messages / symptoms** — key observations, not full stack traces
- **Evolved understanding** — new insights discovered during investigation

### Lifecycle

```
investigating → attempted → resolved
                    ↓            ↓
                abandoned    regressed
```

- **investigating** — gathering info, no fix tried yet
- **attempted** — fix tried, failed approaches documented
- **resolved** — cleaned up into a solution summary, moved to `resolved/`
- **abandoned** — dead end, kept in `.scratchpads/` as a warning (can be reopened)
- **regressed** — was resolved, broke again (auto-transitions to attempted on first update)

## Commands & Skills

This plugin provides a single skill with a slash command:

| Command | What it does |
|---------|--------------|
| `/scratchpad` | Create, update, resolve, abandon, or switch scratchpads |

Intent is detected from natural language — no sub-commands to remember:

| You say... | What happens |
|-----------|--------------|
| `/scratchpad` | Create new or update existing scratchpad from conversation context |
| `/scratchpad resolve` | Confirm with user, then transform into knowledge artifact and move to `resolved/` |
| `/scratchpad abandon` | Confirm with user, mark as dead end, keep as warning |
| `/scratchpad switch` | List active scratchpads, let user pick a different one |

### Resolve transformation

When you resolve a scratchpad, it gets cleaned up completely:
- All failed approaches are removed (useful insights are saved first)
- Issue description is rewritten as a clean 3-8 sentence summary
- Solution section is populated from the successful fix
- File is moved to `.scratchpads/resolved/`

### Anti-hallucination rules

- Only records findings explicitly stated or demonstrated in the conversation
- Discussed-but-untested hypotheses are NOT failed approaches
- Files mentioned but not opened are NOT "investigated"
- Plan to Fix is user-written only — Claude never auto-populates it
- Root Cause is only populated when conclusively demonstrated

## Claude Code Tools Used

| Tool | Purpose |
|------|---------|
| **Glob** | Scan `.scratchpads/SP-*.md` for discovery |
| **Read** | Fetch scratchpad content from disk, read templates |
| **Edit** | Append findings to existing scratchpads (preferred for updates) |
| **Write** | Create new scratchpads, full resolve transformations |
| **Grep** | Check if a finding is already recorded (dedup) |
| **Bash** | `git rev-parse --show-toplevel` (project root), `mv` (resolve/regress), `wc -l` (size check) |

## Output

```
<project-root>/
└── .scratchpads/
    ├── SP-auth-token-refresh-loop.md
    ├── SP-race-condition-ws-handler.md
    └── resolved/
        └── SP-null-ref-user-service.md
```

File naming: `SP-<kebab-case-issue-name>.md` — Claude proposes the name, you confirm.

## Design Principles

1. **One command** — `/scratchpad` does everything; understands what you want from plain language
2. **Points forward, not backward** — "don't go there" + "try this instead"
3. **Failed approaches are protected** — never changed during active debugging, only removed on resolve
4. **Clean resolve** — becomes a 3-8 sentence solution summary
5. **Stays small** — every word takes up AI context; auto-shrinks at 150+ lines
6. **Always re-reads from disk** — never trusts what's in memory; safe when multiple sessions run at once

## Inspiration

- [obra/superpowers](https://github.com/obra/superpowers) — systematic-debugging: 4-phase root cause investigation
- [compound-engineering (EveryInc)](https://every.to/chain-of-thought/the-case-for-compound-engineering) — each unit of work makes future work easier
- [nikiforovall structured-note-taking](https://github.com/nikiforovall/structured-note-taking) — CURRENT_SESSION.md, DECISIONS.md, ADR patterns
- Anthropic context engineering — scratchpad files as persistent memory across sessions
