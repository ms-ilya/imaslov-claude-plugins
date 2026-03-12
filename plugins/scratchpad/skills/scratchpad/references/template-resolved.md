# Resolved Scratchpad Template

When a scratchpad is resolved, it **transforms** from an investigation journal into a clean knowledge artifact. This is the target structure.

## Transformation Rules

1. All "Failed Approaches" → **deleted entirely**
2. Issue Description → **rewritten** as a clean 3–8 sentence past-tense narrative. Readable months later without debugging context.
3. All ADRs → **promoted** to full format (Status, Context, Decision, Consequences, Alternatives)
4. Edge cases → **confirmed and checked** (all boxes ticked)
5. File → **moved** to `.scratchpads/resolved/`

## Template

```markdown
# SP: [Issue Name]

## Status
resolved

## Description
[3-8 sentences. Past tense. What the issue was and how it was resolved.
Readable months later without debugging context.]

## Solution
[What was done to fix it. Direct, no false starts.]

## Edge Cases / Test Scenarios
- [x] [Scenario 1: confirmed working]
- [x] [Scenario 2: confirmed working]

## Related Files

### Changed
- `path/to/file.ts` — what was modified

### Root Cause
- `path/to/file.ts` — `functionName()` — root cause explanation

## Architectural Decisions (ADRs)

### ADR: [Title]
**Status**: Accepted
**Context**: [Why this decision was needed]
**Decision**: [What was decided]
**Consequences**:
- Positive: [...]
- Negative: [...]
**Alternatives Considered**: [What was rejected and why]

## Related Scratchpads
- `SP-other-issue.md` — connection
```

