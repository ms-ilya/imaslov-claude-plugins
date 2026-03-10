---
name: scratchpad
description: >-
  Context-preserving bug-fixing scratchpad that persists investigation state,
  failed approaches, architectural decisions, and knowledge across sessions via
  .md files. Use this skill whenever the user explicitly invokes /scratchpad or
  writes something like "use scratchpad skill", "scratchpad this", or
  "scratchpad resolve/abandon/switch". This skill NEVER activates on its own —
  only when the user calls it. Covers creating, updating, resolving, abandoning,
  and managing .scratchpads/ files for any debugging or investigation workflow.
tools: Read, Write, Edit, Glob, Bash
---

# Scratchpad Skill

A single, evolving `.md` file per issue that serves as a **living investigation journal** during debugging and transforms into a **clean knowledge artifact** on resolution.

**Philosophy: "Keep the wrong stuff in."** Agents make mistakes — erasing failure removes evidence. Without evidence, the model can't adapt. Failed approaches stay visible until the issue is resolved.

The scratchpad is a **directional document** — a map that leads away from known dead ends and toward working solutions. It is NOT a changelog or diff history.

**Platform-agnostic** — works in both Claude.ai and Claude Code with no adaptation needed.

---

## Trigger

**Explicit invocation only.** The user says `/scratchpad`, "use scratchpad skill", "scratchpad this", etc. Never activate on your own — no background monitoring, no proactive suggestions.

---

## The Single Flow

Every `/scratchpad` call runs one automatic flow. No sub-commands. The user's message provides context — you figure out the rest.

### Step 1: LOCATE — Find or create the right scratchpad

- **First call in conversation?** Scan `.scratchpads/` directory at the project root.
  - No folder or no `.md` files → Create new (propose a name, ask user to confirm).
  - One active scratchpad → Auto-select it, confirm to user.
  - Multiple active scratchpads → List them with status, ask user to pick (or create new).
- **Already selected this conversation?** Use the same one (session memory). No re-scanning.
- User says **"switch"** or names a different scratchpad → Re-run selection, clear session memory.

### Step 2: READ — Re-read from disk

Always re-read the scratchpad file from disk before doing anything. Never trust in-memory content — another session may have modified it. If content changed since your last read, note: *"Scratchpad updated externally. Incorporating."*

### Step 3: DIFF — Compare conversation against scratchpad

Scan messages since the last `/scratchpad` call in this conversation (or from the start if this is the first call). Identify what's new across these categories:

- Failed approaches (with why-it's-wrong)
- Edge cases / test scenarios
- Related files (investigated / changed / root cause)
- Architectural decisions
- Evolved understanding of the issue
- Error messages / symptoms

### Step 4: WRITE — Apply changes

- **New scratchpad?** Create it with populated sections from context. Read `references/template-active.md` for the structure.
- **Existing + new findings?** Append new content. **Never modify existing failed approaches** — they are sacred during active debugging.
- **Existing + nothing new?** Tell user: *"Scratchpad is up to date."* Show a one-line status summary.
- Update status if appropriate (`investigating` → `attempted` once a fix has been tried).

### Step 5: CONFIRM — Brief summary

Tell the user what was added or changed. Keep it short.

---

## Intent Detection

The user controls special flows by stating intent in their message alongside `/scratchpad`. These are natural language — not sub-commands.

| User says something like... | Action |
|---|---|
| "resolve", "mark as resolved" | Run the **Resolve Flow** |
| "abandon", "give up on this" | Run the **Abandon Flow** |
| "switch", "different one" | Re-run selection, clear session memory |
| *(nothing special)* | Default flow: locate → read → diff → write → confirm |

---

## Resolve Flow

Triggered when user indicates resolution (e.g., `/scratchpad resolve`).

1. If edge cases are unchecked → warn the user, proceed only if they confirm.
2. **Transform** the scratchpad — read `references/template-resolved.md` for the target structure:
   - Delete all "Failed Approaches"
   - Rewrite description as a clean 3–8 sentence past-tense knowledge artifact
   - Promote ADRs to full format (Status, Context, Decision, Consequences, Alternatives)
   - Mark edge cases as confirmed/checked
3. Move the file to `.scratchpads/resolved/` (create directory if needed).

## Abandon Flow

Triggered when user indicates abandonment (e.g., `/scratchpad abandon`).

1. Optionally ask for a reason.
2. Set status to `abandoned`.
3. Keep the file in `.scratchpads/` — it's still valuable as a "don't go here" warning.

---

## Status Workflow

```
investigating → attempted → resolved
                    ↓            ↓
                abandoned    regressed
                              (→ back to attempted)
```

- **investigating**: Gathering information. No fix attempts yet.
- **attempted**: At least one fix tried. Failed approaches being documented.
- **resolved**: Fix confirmed. Transformed into memory bank, moved to `resolved/`.
- **abandoned**: Dead end. Stays in `.scratchpads/` as a warning.
- **regressed**: Was resolved, broke again. See "Targeting a resolved scratchpad" below.

---

## File Structure

### Location
```
<project-root>/
└── .scratchpads/
    ├── SP-auth-token-refresh-loop.md
    ├── SP-race-condition-ws-handler.md
    └── resolved/
        └── SP-null-ref-user-service.md
```

### Naming
- Format: `SP-<kebab-case-issue-name>.md`
- No date prefix.
- Propose the name; user confirms or overrides.
- On creation, check for name collisions with existing scratchpads — flag similarity if found.

### Git
Team decision. The skill takes no opinion on whether `.scratchpads/` is gitignored or committed.

---

## Token Efficiency Rules

Every word costs tokens every time the scratchpad is loaded in future sessions.

1. **Be concise.** Failed approaches: 2–4 lines each. Issue descriptions: 1–3 sentences. ADRs: 1–2 sentences. The scratchpad is a map, not a novel.
2. **Omit empty sections.** Do NOT include section headers with no content. Add sections when they first have content.
3. **Condense on growth.** If a scratchpad exceeds ~150 lines, condense older failed approaches to one-liners (keep approach name + what was tried + why it's wrong). Never delete — condense.
4. **Scope the scan.** Analyze only messages since the last `/scratchpad` call. If first call, analyze from conversation start.
5. **Re-read before writing.** Always re-read from disk. Another conversation may have modified it.

---

## Templates

The full templates live in the `references/` directory. Read them when you need to create or transform a scratchpad:

- **`references/template-active.md`** — Structure for active (investigating/attempted) scratchpads. Only include sections that have content.
- **`references/template-resolved.md`** — Structure for resolved scratchpads after transformation.

### Failed Approach Format

**Default (compact)** — use this unless the failure is too complex for one-liners:
```markdown
### Approach: [Short name]
- **What was tried**: [1 sentence]
- **What happened**: [1 sentence]
- **Why it's wrong**: [1 sentence]
- **Actual insight**: [1 sentence]
```

**Expanded** — only when compact would be misleading:
```markdown
### Approach: [Short name]
- **What was tried**: [longer description]
- **What happened**: [observed result]
- **Why it's wrong**: [root explanation]
- **Wrong hypothesis**: [what we incorrectly believed]
- **Actual insight**: [what we learned]
```

---

## Edge Cases

### First call, no `.scratchpads/` folder
Create the folder. Propose a new scratchpad from conversation context. If no clear issue in conversation, ask the user to describe it.

### First call, multiple issues in conversation
List the distinct issues found. Ask which one this scratchpad is for. Never pick silently.

### Nothing new to capture
Tell the user: *"Scratchpad is up to date."* Show a one-line status summary.

### Targeting a resolved scratchpad
Change status to `regressed`. Move back from `resolved/` to `.scratchpads/`. Preserve the resolved description under a new `## Previous Resolution` section. Re-add empty "Failed Approaches" and "Plan to Fix" sections. Proceed with update.

### Abandoned scratchpad revival
Change status to `investigating`. Proceed normally. All existing content preserved.

### Name collision on creation
If a similarly named scratchpad exists, flag the similarity and ask: related or distinct?

---

## Key Design Principles

1. **One command.** `/scratchpad` triggers everything. The rest is automatic.
2. **Directional, not historical.** "Don't go there" + "try this direction."
3. **No timestamps.** What matters is what was tried and why it failed.
4. **No code storage.** Descriptions and reasoning only. No snippets, diffs, or patches.
5. **Sacred failed approaches.** Never removed or modified during active debugging. Only deleted on resolve.
6. **Clean resolve.** Transforms into a 3–8 sentence knowledge artifact. All noise stripped.
7. **Plan to Fix is NEVER auto-filled.** Only the user populates it.
8. **Edge cases grow.** Living checklist. Definition of "done."
9. **Token-conscious.** Every word costs tokens on every future read. Be brief.
10. **Omit, don't pad.** No empty section headers. Add sections when they earn content.

---

## Inspiration & References

- **obra/superpowers → systematic-debugging**: 4-phase root cause investigation
- **compound-engineering (EveryInc)**: Each unit of work makes future work easier
- **nikiforovall structured-note-taking**: CURRENT_SESSION.md, DECISIONS.md, ADRs patterns
- **Anthropic context engineering**: Scratchpad files as persistent memory across sessions

This skill combines all of these into a single, issue-scoped, transformation-capable debugging document.
