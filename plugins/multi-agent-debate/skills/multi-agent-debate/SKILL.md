---
name: multi-agent-debate
description: >-
  Run a structured multi-agent debate that spawns parallel LLM agents to argue
  from genuinely different perspectives, then applies an impartial Judge to
  synthesize a verdict. Use this skill whenever the user wants to analyze
  something from multiple perspectives, requests a "debate", "multi-agent
  analysis", "devil's advocate", "red team", "steelman", "pros and cons deep
  dive", "360-degree analysis", or says things like "argue both sides", "what
  would different experts say", "let's stress-test this idea", "analyze this
  from all angles", "give me competing viewpoints", or "I need a rigorous take
  on this". Also trigger when the user provides a decision, strategy, or
  proposal and wants it pressure-tested with adversarial collaboration. This
  skill uses the Anthropic API to spawn real parallel agents — each with its own
  system prompt, persona, and blind spots — producing a debate that is
  qualitatively better than a single model reasoning through perspectives
  sequentially.
tools: Read, Bash, Agent
---

# Multi-Agent Debate & Analysis Framework

## Why Parallel Agents Matter

A single model reasoning through "perspectives" tends to produce polite, convergent viewpoints that echo each other. This skill spawns **independent parallel API calls** — each agent gets its own system prompt, its own framing of the problem, and its own biases. They never see each other's system prompts. The result is genuine disagreement, not theater.

The architecture: Claude orchestrates by building agent personas, dispatching them in parallel via the Anthropic API, collecting their outputs, feeding those outputs as context into cross-examination rounds, and finally stepping into an impartial Judge role to synthesize the strongest reasoning.

---

## Step 0 — Parse & Frame the Issue

Before anything, identify the issue to debate. Sources in priority order:

1. **Explicit statement** — The user states it directly.
2. **Conversation context** — The user references something discussed earlier ("debate this", "stress-test that idea"). Scan history, extract the core question.
3. **Attached file** — The user provides a document. Summarize the core decision or question it contains.
4. **No clear issue** — Ask: *"What specific issue or decision should the panel debate?"* Don't guess.

Once identified, restate it as a single clear sentence:

> **Issue on the table:** [One-sentence framing]

### Narrowing & Validation

Before proceeding, sanity-check the issue:

- **Too broad** (e.g., "Is AI good or bad?") → Narrow it. Propose a specific framing and confirm: *"This is very broad. I'd suggest: [specific question]. Want to adjust?"*
- **Settled fact** (e.g., "Is the earth round?") → Don't debate established science. Offer to help with a related genuine question instead.
- **Deeply personal** (e.g., "Should I leave my job?") → Adapt to advisory mode. Agents become advisory perspectives (pragmatist, risk analyst, etc.). The Judge softens its verdict into a recommendation, not a ruling. Remind the user that personal decisions are ultimately theirs.
- **Binary framing** — Always use at least 3 agents. The third challenges the binary itself or introduces a dimension neither side considers.

If the user has been clear and unambiguous, proceed directly into Phase 1 without waiting for confirmation.

---

## Step 1 — Agent Assembly

Select **3–5 agents** (honor user requests for specific counts, but never fewer than 2 or more than 6). Each agent must be **tailored to this specific issue** — no generic "Optimist/Pessimist" panels.

### Selection Principles

- Agents must **genuinely disagree**, not just emphasize different aspects of the same conclusion.
- Include at least one agent who **challenges the premise** or conventional wisdom.
- No straw-men — every agent must be set up to make a strong case.
- Technical issues need at least one non-technical lens (user impact, ethics, business reality).
- Philosophical/political issues need at least one empirically grounded agent.
- Consider adding a "wildcard" agent whose perspective the user wouldn't expect.

### Agent Profile Schema

For each agent, define these fields (used as the foundation for their system prompt):

| Field | Purpose |
|---|---|
| **Name & Role** | Short label + domain (e.g., "The Pragmatist — Senior Engineering Lead") |
| **Emoji** | Unique color circle for visual tracking: 🔵🔴🟢🟡🟣 |
| **Lens** | What they optimize for (e.g., "delivery speed, team morale, debt reduction") |
| **Core assumption** | The foundational belief driving their position |
| **Blind spot** | What they undervalue or ignore — stated honestly, this sets up better cross-examination |

Present the assembled panel to the user before launching the debate rounds. This gives them a chance to swap an agent or adjust.

---

## Step 2 — Build & Dispatch: The Parallel Agent Engine

This is the technical core. Read `references/agent-engine.md` for the complete implementation guide with code templates.

### High-Level Architecture

```
┌─────────────────────────────────────────────┐
│              ORCHESTRATOR (Claude)           │
│                                             │
│  1. Build system prompts per agent          │
│  2. Dispatch parallel API calls             │
│  3. Collect & route responses               │
│  4. Feed cross-agent context for rebuttals  │
│  5. Step into Judge role for final verdict  │
└──────────┬──────────┬──────────┬────────────┘
           │          │          │
     ┌─────▼──┐ ┌─────▼──┐ ┌────▼───┐
     │Agent 🔵│ │Agent 🔴│ │Agent 🟢│  ... (parallel)
     │ Own     │ │ Own     │ │ Own     │
     │ system  │ │ system  │ │ system  │
     │ prompt  │ │ prompt  │ │ prompt  │
     └────────┘ └────────┘ └────────┘
```

### Implementation Approach: React Artifact with Anthropic API

Build a **React artifact** that:

1. Renders the debate as a live, interactive panel
2. Makes parallel `fetch()` calls to `https://api.anthropic.com/v1/messages`
3. Streams or displays each agent's response as it arrives
4. Manages round progression (Opening → Cross-Exam → Rebuttal → Judgment)
5. Allows the user to intervene (add a question, request another round, challenge an agent)

**Each agent gets its own API call** with a unique system prompt. They are truly independent — they don't share context until the orchestrator feeds them other agents' outputs in subsequent rounds.

### System Prompt Template (per agent)

Each agent's system prompt encodes their persona, constraints, and the debate rules. The template structure:

```
You are [Agent Name], [Role Description].

WHAT YOU OPTIMIZE FOR: [Lens]
YOUR CORE BELIEF: [Core assumption]
YOUR KNOWN BLIND SPOT (be aware of this): [Blind spot]

DEBATE RULES:
- Argue your position with conviction. You are not trying to be balanced.
- Use concrete evidence, real-world examples, data, and logical arguments.
- "Many experts agree" is not an argument. Be specific.
- Do not use empty diplomacy. No "great point" or "I appreciate the perspective."
- Keep your response focused: 150-250 words maximum.
- When critiquing others, quote their specific claims. No straw-manning.
- When conceding, be honest about what changed. When defending, bring NEW reasoning.
```

### Round-by-Round Dispatch

| Round | What agents receive | What they produce |
|---|---|---|
| **Round 1: Opening** | Just the issue + their system prompt | Problem framing, thesis, strongest argument |
| **Round 2: Cross-Exam** | All other agents' Round 1 outputs | Direct critiques: weakest link, edge cases, hidden costs for each opponent |
| **Round 3: Rebuttal** | Critiques directed at them from Round 2 | Concessions, new defenses, updated thesis |
| **Judgment** | All rounds from all agents | Orchestrator (Claude) does this directly — not an API call |

---

## Step 3 — Round Execution

### Round 1: Opening Positions

Dispatch all agents in parallel. Each agent independently produces:

1. **Problem framing** — How they define the core problem (agents should frame it differently — this is where real disagreement starts)
2. **Thesis** — A clear, falsifiable claim
3. **Strongest argument** — Single most compelling evidence or reasoning. Quality over quantity.

### Round 2: Cross-Examination

This is the most critical phase. Feed each agent the full text of every other agent's Round 1 output.

Each agent must, for every opponent:
1. **Identify the weakest link** — Most vulnerable claim or assumption
2. **Stress-test with edge cases** — Under what realistic conditions does the recommendation fail?
3. **Name the hidden cost** — What second-order effect is the opponent ignoring?

Enforcement rules (encode these in the round-specific user message):
- Must quote or reference specific claims — no vague disagreement
- "I generally agree but..." is banned — find real disagreement
- Each critique must be actionable: force a concession or new defense

### Round 3: Rebuttals & Updated Positions

Feed each agent only the critiques directed at them. Each must:

1. **Concede** at least one valid point — explain what it changes
2. **Defend** remaining positions with *new* reasoning not used in Round 1
3. **Restate thesis** — refined, narrowed, or unchanged (with justification)

Agents who concede nothing are suspicious. Agents who concede everything are useless.

---

## Step 4 — Final Judgment

Drop all agent roles. Claude becomes an impartial **Judge** whose only loyalty is to the strongest reasoning. Do NOT use an API call for this — the Judge benefits from having orchestrated the entire debate.

Produce three sections:

### ⚖️ Synthesis
- **Points of convergence** — Where agents agreed, even from different reasoning. These are high-confidence conclusions.
- **Genuine tensions** — Unresolved disagreements that reflect real tradeoffs, not just different priors. Name each tradeoff explicitly (e.g., "Speed vs. safety — optimizing for one degrades the other").

### ⚖️ Verdict
- **Recommendation** — Clear, actionable. Not "it depends." Commit to a position while acknowledging conditions.
- **Confidence level** — High / Moderate / Low, with one-sentence justification.
- **Key conditions** — What must be true for this verdict to hold? If these conditions change, the verdict may flip.

### ⚖️ Dissent Log
- **Minority positions worth preserving** — Which losing arguments contained insights the majority missed?
- **Flip conditions** — Under what specific, realistic scenarios would the verdict reverse? Be concrete.
- **Open questions** — What couldn't be settled and would need external data or experimentation to resolve?

---

## Step 5 — Post-Debate Options

After delivering the verdict, offer the user:

1. **"Go deeper"** — Run an additional cross-examination round focused on unresolved tensions from the Dissent Log
2. **"Challenge the verdict"** — User introduces a new constraint or objection; agents respond
3. **"Add an agent"** — Introduce a new perspective that was missing
4. **"Export"** — Generate a clean document (markdown or docx) summarizing the full debate and verdict

---

## Formatting & Tone

- **Voice differentiation:** Each agent should speak distinctly. An economist uses different language than an ethicist. A startup founder sounds different from a policy wonk. The Judge is measured, precise, and authoritative.
- **Length discipline:** Each agent's contribution per round: 150–250 words. The Judge's synthesis can be longer (300–500 words).
- **No premature consensus:** If all agents converge too early, the Judge must call this out and name what's being suppressed.
- **No empty diplomacy:** "That's a great point" and "I appreciate the perspective" are banned. Substance only.
- **Evidence standard:** Concrete reasoning, real-world examples, data, or logical arguments. "Many experts agree" is not an argument.
- **Visual tracking:** Use consistent emoji markers (🔵🔴🟢🟡🟣) so agents are identifiable at a glance across all rounds.

---

## Fallback: Non-Artifact Mode

If for any reason the React artifact approach fails (API errors, environment constraints), fall back to **inline simulation mode**:

- Claude plays all roles sequentially in a single response
- Still maintain distinct voices, the cross-examination structure, and the Judge verdict
- Label each section clearly with agent emojis
- This is less rigorous (agents share context implicitly) but still valuable

The key difference: in fallback mode, explicitly note to the user that this is a simulated debate rather than truly independent agents, and offer to retry the artifact approach if they'd like.

---

## Reference Files

- `references/agent-engine.md` — Complete implementation guide: React artifact code templates, API call patterns, system prompt construction, error handling, streaming, and the full round-management state machine. **Read this before building the artifact.**
