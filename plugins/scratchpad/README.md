# Scratchpad Plugin

## The Problem

AI agents make mistakes during debugging — they try approaches that fail, go in circles, and lose context between sessions. Without a record of what was tried and why it failed, every new session starts from zero. The same dead ends get explored again and again.

## The Solution

A per-issue `.md` file that acts as a **living investigation journal** during debugging and transforms into a **clean knowledge artifact** on resolution. One command — `/scratchpad` — handles everything automatically.

**Core idea: "Keep the wrong stuff in."** Failed approaches stay visible as a minefield map, steering the agent away from known dead ends. On resolution, the noise is stripped and only the solution remains.

## How It Works

The scratchpad is a **directional document** — not a changelog. It answers two questions:
1. **Where NOT to go** — failed approaches with reasons
2. **Where to go next** — evolved understanding, edge cases, plan to fix

Every `/scratchpad` call runs a single automatic flow: find the right scratchpad → re-read from disk → diff against conversation → append new findings → confirm.

### Lifecycle

```
investigating → attempted → resolved
                    ↓            ↓
                abandoned    regressed
```

- **investigating** — gathering info, no fix tried yet
- **attempted** — fix tried, failed approaches documented
- **resolved** — transformed into knowledge artifact, archived
- **abandoned** — dead end, kept as warning
- **regressed** — was resolved, broke again, reopened

## Installation

Add to Claude Code plugins.

## Usage

```
/scratchpad
```

Intent is detected from natural language — no sub-commands to remember:

| You say... | What happens |
|-----------|--------------|
| `/scratchpad` | Create new or update existing scratchpad from conversation |
| `/scratchpad resolve` | Transform into knowledge artifact, move to `resolved/` |
| `/scratchpad abandon` | Mark as dead end, keep as warning |
| `/scratchpad switch` | Switch to a different scratchpad |

## What Gets Tracked

- **Failed approaches** — what was tried, what happened, why it's wrong, actual insight (2–4 lines each)
- **Edge cases** — living checklist that grows into the definition of "done"
- **Related files** — investigated, changed, root cause
- **Architectural decisions** — compact ADRs, promoted to full format on resolve
- **Error messages / symptoms** — key observations, not full stack traces

## Output

```
<project-root>/
└── .scratchpads/
    ├── SP-auth-token-refresh-loop.md
    ├── SP-race-condition-ws-handler.md
    └── resolved/
        └── SP-null-ref-user-service.md
```

## Design Principles

1. **One command** — `/scratchpad` triggers everything
2. **Directional, not historical** — "don't go there" + "try this direction"
3. **Sacred failed approaches** — never modified during active debugging, deleted only on resolve
4. **Clean resolve** — transforms into a 3–8 sentence knowledge artifact
5. **Token-conscious** — every word costs tokens on every future read
6. **Platform-agnostic** — works in Claude.ai and Claude Code with no adaptation

## Inspiration

- [obra/superpowers → systematic-debugging](https://github.com/obra/superpowers) — 4-phase root cause investigation
- [compound-engineering (EveryInc)](https://every.to/chain-of-thought/the-case-for-compound-engineering) — each unit of work makes future work easier
- [nikiforovall structured-note-taking](https://github.com/nikiforovall/structured-note-taking) — CURRENT_SESSION.md, DECISIONS.md, ADR patterns
- Anthropic context engineering — scratchpad files as persistent memory across sessions
