# Multi-Agent Debate Plugin

## The Problem

A single model reasoning through "perspectives" produces polite, convergent viewpoints that echo each other. Asking one LLM to "consider both sides" is theater — it shares context across all perspectives, so genuine disagreement is structurally impossible.

## The Solution

Spawn **independent parallel API calls** — each agent gets its own system prompt, its own framing, and its own biases. They never see each other's system prompts. The result is genuine disagreement, not theater.

**Core idea: adversarial collaboration.** Agents are set up to genuinely disagree, cross-examine each other's weakest points, and make honest concessions. An impartial Judge synthesizes the strongest reasoning into a verdict.

## How It Works

The debate runs through structured rounds, each dispatched as parallel API calls:

```
Round 1: Opening Positions  →  Each agent frames the problem and states their thesis
Round 2: Cross-Examination  →  Each agent attacks every other agent's weakest claims
Round 3: Rebuttals           →  Each agent concedes valid points and defends with new reasoning
Judgment                     →  Claude synthesizes a verdict with confidence level and dissent log
```

### Agent Design

Each debate gets **3–5 custom agents** tailored to the specific issue — no generic "Optimist/Pessimist" panels. Every agent has:

- **Name & Role** — Domain-specific identity
- **Lens** — What they optimize for
- **Core assumption** — The belief driving their position
- **Blind spot** — What they undervalue (stated honestly for better cross-examination)

### Judge Output

The final verdict includes:

- **Synthesis** — Points of convergence and genuine unresolved tensions
- **Verdict** — Clear recommendation with confidence level and key conditions
- **Dissent Log** — Minority positions worth preserving, flip conditions, open questions

## Installation

Add to Claude Code plugins.

## Usage

Trigger naturally — no slash command needed:

| You say... | What happens |
|-----------|--------------|
| "Debate whether we should use microservices" | Full 3-round debate with tailored agents |
| "Red team this proposal" | Adversarial analysis with pressure-testing |
| "Analyze this from all angles" | Multi-perspective analysis with synthesis |
| "Devil's advocate on our auth strategy" | Structured challenge with cross-examination |
| "Stress-test this idea" | Edge cases and hidden costs surfaced |

### Post-Debate Options

After the verdict, you can:

1. **"Go deeper"** — Additional round on unresolved tensions
2. **"Challenge the verdict"** — Introduce a new constraint; agents respond
3. **"Add an agent"** — Bring in a missing perspective
4. **"Export"** — Generate a clean summary document

## Architecture

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
     │Agent   │ │Agent   │ │Agent   │  ... (parallel)
     │  Own   │ │  Own   │ │  Own   │
     │ system │ │ system │ │ system │
     │ prompt │ │ prompt │ │ prompt │
     └────────┘ └────────┘ └────────┘
```

## Requirements

- Anthropic API key (for spawning parallel agent calls)

## Design

- Agents are truly independent — separate API calls, no shared context until cross-examination
- Minimum 3 agents per debate to prevent binary framing
- Fallback to inline simulation if API calls fail
- Token-conscious: 150–250 words per agent per round
