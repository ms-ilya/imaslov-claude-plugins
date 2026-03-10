# Agent Engine — Implementation Reference

This file contains the complete implementation guide for building the multi-agent debate as a React artifact with parallel Anthropic API calls. Read this before writing any code.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [State Machine](#state-machine)
3. [System Prompt Construction](#system-prompt-construction)
4. [API Call Patterns](#api-call-patterns)
5. [Round Management](#round-management)
6. [React Artifact Structure](#react-artifact-structure)
7. [Error Handling & Resilience](#error-handling--resilience)
8. [Edge Cases](#edge-cases)

---

## Architecture Overview

The debate runs as a React artifact that manages a state machine of debate rounds. Each round dispatches parallel API calls — one per agent — and collects responses before advancing.

```
User provides issue
        │
        ▼
┌─────────────────┐
│  AGENT ASSEMBLY  │ ← Claude (orchestrator) defines agents
└────────┬────────┘
         ▼
┌─────────────────┐     ┌──────────┐
│  ROUND 1:       │────▶│ Agent 🔵 │──┐
│  OPENING        │────▶│ Agent 🔴 │──┤ parallel API calls
│  POSITIONS      │────▶│ Agent 🟢 │──┤
└────────┬────────┘     └──────────┘  │
         ▼                            │
   Collect all ◀──────────────────────┘
         │
         ▼
┌─────────────────┐     ┌──────────┐
│  ROUND 2:       │────▶│ Agent 🔵 │──┐ each receives all
│  CROSS-EXAM     │────▶│ Agent 🔴 │──┤ OTHER agents' R1
│                 │────▶│ Agent 🟢 │──┤
└────────┬────────┘     └──────────┘  │
         ▼                            │
   Collect all ◀──────────────────────┘
         │
         ▼
┌─────────────────┐     ┌──────────┐
│  ROUND 3:       │────▶│ Agent 🔵 │──┐ each receives only
│  REBUTTALS      │────▶│ Agent 🔴 │──┤ critiques AIMED
│                 │────▶│ Agent 🟢 │──┤ AT THEM
└────────┬────────┘     └──────────┘  │
         ▼                            │
   Collect all ◀──────────────────────┘
         │
         ▼
┌─────────────────┐
│  JUDGMENT        │ ← Single API call or inline
│  (Judge role)    │
└─────────────────┘
```

---

## State Machine

The debate artifact manages these states:

```javascript
const STATES = {
  SETUP: 'setup',           // User confirms issue + agents
  ROUND1_RUNNING: 'r1_run', // Opening positions in flight
  ROUND1_DONE: 'r1_done',   // All openings collected
  ROUND2_RUNNING: 'r2_run', // Cross-examination in flight
  ROUND2_DONE: 'r2_done',   // All cross-exams collected
  ROUND3_RUNNING: 'r3_run', // Rebuttals in flight
  ROUND3_DONE: 'r3_done',   // All rebuttals collected
  JUDGING: 'judging',       // Judge synthesis in flight
  COMPLETE: 'complete',     // Verdict delivered
  ERROR: 'error'            // Something failed
};
```

---

## System Prompt Construction

Each agent gets a system prompt that encodes their persona. Build these dynamically from the agent profiles.

```javascript
function buildAgentSystemPrompt(agent, roundType, issue) {
  const base = `You are ${agent.name}, ${agent.role}.

WHAT YOU OPTIMIZE FOR: ${agent.lens}
YOUR CORE BELIEF: ${agent.coreAssumption}
YOUR KNOWN BLIND SPOT (be aware of this, but don't let it paralyze you): ${agent.blindSpot}

THE ISSUE BEING DEBATED: ${issue}

DEBATE RULES:
- Argue your position with conviction. You are NOT trying to be balanced — that's the Judge's job.
- Use concrete evidence, real-world examples, data, and logical arguments.
- "Many experts agree" is not an argument. Be specific or don't cite it.
- No empty diplomacy. Never say "great point" or "I appreciate the perspective." Engage with substance.
- Keep your response focused: 150-250 words maximum. Density over volume.`;

  const roundInstructions = {
    opening: `
ROUND 1 — OPENING POSITION
Produce exactly three sections:
1. **Problem as I see it:** Frame the core problem from YOUR perspective. Other agents will frame it differently — that's the point.
2. **My thesis:** State your position as a clear, falsifiable claim.
3. **Strongest argument:** Your single most compelling piece of evidence or reasoning. One powerful argument beats three weak ones.`,

    crossExam: `
ROUND 2 — CROSS-EXAMINATION
You will receive the opening positions of all other agents. For EACH other agent:
1. **Weakest link:** Identify the most vulnerable claim or assumption in their argument.
2. **Edge case:** Under what realistic conditions does their recommendation fail?
3. **Hidden cost:** What second-order effect are they ignoring?

RULES:
- Quote or reference their specific claims. No straw-manning.
- "I generally agree but..." is BANNED. Find real disagreement or sharpen existing disagreement.
- Each critique must be actionable: force them to concede or defend with new reasoning.`,

    rebuttal: `
ROUND 3 — REBUTTAL
You will receive the critiques other agents directed at you. You must:
1. **Concede:** Name at least one point that was valid. Explain what it changes in your thinking.
2. **Defend:** For points you still hold, provide NEW reasoning or evidence not used in Round 1.
3. **Updated thesis:** Restate your position. It may have shifted, narrowed, or been refined. If unchanged, explain specifically why the critiques didn't land.

Intellectual honesty is paramount. Conceding nothing is suspicious. Conceding everything is useless.`
  };

  return base + roundInstructions[roundType];
}
```

---

## API Call Patterns

### Parallel Dispatch

Use `Promise.allSettled` (not `Promise.all`) so one agent's failure doesn't kill the entire round.

```javascript
async function dispatchRound(agents, roundType, issue, previousRounds) {
  const promises = agents.map(agent => {
    const systemPrompt = buildAgentSystemPrompt(agent, roundType, issue);
    const userMessage = buildUserMessage(agent, roundType, previousRounds);

    return callAgent(agent.id, systemPrompt, userMessage);
  });

  const results = await Promise.allSettled(promises);

  return results.map((result, i) => ({
    agentId: agents[i].id,
    agentName: agents[i].name,
    agentEmoji: agents[i].emoji,
    status: result.status,
    content: result.status === 'fulfilled'
      ? result.value
      : `[Agent failed: ${result.reason?.message || 'Unknown error'}]`,
  }));
}
```

### Single Agent API Call

```javascript
async function callAgent(agentId, systemPrompt, userMessage) {
  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      model: 'claude-sonnet-4-6',
      max_tokens: 1000,
      system: systemPrompt,
      messages: [{ role: 'user', content: userMessage }],
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`API error ${response.status}: ${err}`);
  }

  const data = await response.json();
  return data.content
    .filter(block => block.type === 'text')
    .map(block => block.text)
    .join('\n');
}
```

### Building User Messages Per Round

The user message changes per round to provide the right context:

```javascript
function buildUserMessage(agent, roundType, previousRounds) {
  switch (roundType) {
    case 'opening':
      return 'Present your opening position on this issue.';

    case 'crossExam': {
      const otherOpenings = previousRounds.round1
        .filter(r => r.agentId !== agent.id)
        .map(r => `${r.agentEmoji} ${r.agentName}:\n${r.content}`)
        .join('\n\n---\n\n');
      return `Here are the opening positions from the other agents. Cross-examine each one.\n\n${otherOpenings}`;
    }

    case 'rebuttal': {
      // Gather only critiques directed at THIS agent
      const critiquesAtMe = previousRounds.round2
        .filter(r => r.agentId !== agent.id)
        .map(r => {
          // The cross-exam content contains critiques of all agents;
          // ideally parse by section, but full context works too
          return `${r.agentEmoji} ${r.agentName}'s critique:\n${r.content}`;
        })
        .join('\n\n---\n\n');
      return `Here are the critiques from the cross-examination round. Respond to the points directed at you.\n\n${critiquesAtMe}`;
    }

    default:
      return 'Present your analysis.';
  }
}
```

---

## React Artifact Structure

Build the artifact as a single `.jsx` file. Key components:

```
<DebateApp>
  ├── <DebateHeader>        — Issue statement, status badge
  ├── <AgentPanel>          — Shows assembled agents with profiles
  ├── <RoundDisplay>        — Renders each round's outputs
  │   ├── <AgentResponse>   — Individual agent's contribution (collapsible)
  │   └── <RoundProgress>   — Loading indicators per agent
  ├── <JudgmentPanel>       — Synthesis, Verdict, Dissent Log
  ├── <ControlBar>          — "Next Round", "Go Deeper", "Add Agent", "Export"
  └── <ErrorBoundary>       — Graceful failure handling
```

### Key UI Patterns

**Progressive reveal:** Show each agent's response as it arrives (not all-at-once after the slowest finishes). Use individual loading states per agent.

**Visual differentiation:** Each agent gets their emoji + a subtle color accent. Use the emoji as a consistent identifier across all rounds.

**Collapsible rounds:** As the debate progresses, earlier rounds should be collapsible so the user isn't overwhelmed. Default: latest round expanded, previous rounds collapsed with a summary line.

**Live status indicators:**
- ⏳ Thinking... (API call in flight)
- ✅ Complete (response received)
- ❌ Failed (with retry button)
- ⚖️ Judging... (final synthesis in progress)

### Core State Shape

```javascript
const initialState = {
  phase: 'setup',
  issue: '',
  agents: [],           // Array of agent profiles
  rounds: {
    round1: [],         // Array of { agentId, agentName, agentEmoji, content, status }
    round2: [],
    round3: [],
  },
  judgment: null,        // { synthesis, verdict, dissent }
  error: null,
  isLoading: false,
  activeAgentCalls: {},  // { [agentId]: 'loading' | 'done' | 'error' }
};
```

---

## Error Handling & Resilience

### Agent Failure

If one agent fails, the debate continues without them. Show a clear indicator:

```javascript
// In the round display
{response.status === 'rejected' && (
  <div className="agent-error">
    {response.agentEmoji} {response.agentName} — Failed to respond.
    <button onClick={() => retryAgent(response.agentId, currentRound)}>
      Retry
    </button>
  </div>
)}
```

### Rate Limiting

If the API returns 429, implement exponential backoff:

```javascript
async function callWithRetry(fn, maxRetries = 3) {
  for (let i = 0; i < maxRetries; i++) {
    try {
      return await fn();
    } catch (err) {
      if (err.message.includes('429') && i < maxRetries - 1) {
        await new Promise(r => setTimeout(r, 1000 * Math.pow(2, i)));
        continue;
      }
      throw err;
    }
  }
}
```

### Timeout Protection

Set a 60-second timeout per agent call. If exceeded, mark as failed and continue:

```javascript
function withTimeout(promise, ms = 60000) {
  return Promise.race([
    promise,
    new Promise((_, reject) =>
      setTimeout(() => reject(new Error('Agent timed out')), ms)
    ),
  ]);
}
```

### Graceful Degradation

If ALL agents in a round fail, switch to fallback mode: Claude generates the round inline without API calls, noting the degradation to the user.

---

## Edge Cases

### User Requests Additional Rounds
The framework is extensible. After Round 3, offer additional cross-examination focused on unresolved tensions from the Dissent Log. Maintain the same dispatch pattern — just add a `round4`, `round5`, etc. to the state.

### User Wants to Inject a Question Mid-Debate
Allow a "Challenge" action that sends the user's question to all agents as an additional prompt. Treat it as a mini-round: dispatch in parallel, collect responses, display inline.

### Issue Changes Mid-Debate
If the user reframes the issue after agents are assembled, re-run from Step 1. Don't try to patch — agent personas may no longer be appropriate.

### Very Long Agent Responses
The system prompt instructs 150-250 words. If an agent exceeds 400 words, truncate with a note: "[Truncated — agent exceeded word limit]". This keeps the debate scannable.

### Sensitive or Political Issues
The skill is designed for productive analysis, not propaganda. For politically charged topics:
- Ensure agents represent genuinely held positions across the real spectrum of views
- The Judge must be scrupulously evenhanded
- Avoid strawmanning any political position
- Note in the verdict when the question involves value judgments where reasonable people disagree

### Personal Decisions
For "should I..." questions about personal life choices, adapt the framing:
- Agents become advisory perspectives (e.g., "The Risk-Aware Friend", "The Growth-Oriented Mentor")
- The Judge delivers a recommendation, not a ruling
- End with: "This is ultimately your call. The debate surfaces tradeoffs — it doesn't make the choice for you."

### Only Two Viable Sides
Use 3 agents minimum. The third agent challenges the binary framing or introduces an orthogonal dimension. Example: in a "build vs. buy" debate, the third agent might argue "neither — partner" or challenge whether the underlying need is real.

### User Requests Specific Agents or Perspectives
Honor the request. If they say "include a labor union perspective", build an agent for it. If they name a specific number of agents, use that number (within 2-6 range).

### Empty or Trivial Issues
If the issue is trivially answerable ("What's 2+2?") or empty, don't run a debate. Respond directly and offer to help with a substantive question instead.

---

## Performance Notes

- **Model choice:** Use `claude-sonnet-4-6` for agents (good balance of quality and speed). The Judge synthesis is done by the orchestrating Claude instance directly.
- **Parallel calls:** 3 agents = 3 simultaneous API calls per round. Total for a full debate: ~9 calls (3 rounds × 3 agents) + 0 for judgment. Stay well within rate limits.
- **Latency:** Each round takes ~5-15 seconds depending on agent response times. Full debate: ~30-60 seconds. The progressive reveal pattern keeps the user engaged during waits.
- **Token budget:** With 150-250 word responses, each agent call uses ~300-500 tokens output. Total debate: ~3000-5000 output tokens across all calls. Very manageable.
