# Active Scratchpad Template

Only include sections that have content. A brand-new scratchpad might only have Status, Issue Description, and one or two others. Add sections as they earn content — never pad with empty headers.

```markdown
# SP: [Issue Name]

## Status
investigating

## Issue Description
[1-3 sentences. What is broken and under what conditions.]

## Error / Symptom
[Optional. Key error message or observable symptom. 1-2 lines, not full stack trace.]

## Edge Cases / Test Scenarios
- [ ] [Scenario 1]
- [ ] [Scenario 2]

## Related Files

### Investigated
- `path/to/file.ts` — `functionName()` — what it does

### Changed
- `path/to/file.ts` — what was modified

### Root Cause
- `path/to/file.ts` — `functionName()` — why it breaks

## Failed Approaches — DO NOT RETRY

### Approach: [Short name]
- **What was tried**: [1 sentence]
- **What happened**: [1 sentence]
- **Why it's wrong**: [1 sentence]
- **Actual insight**: [1 sentence]

## Plan to Fix

## Architectural Decisions (ADRs)

### Decision: [Short title]
Decided [X] over [Y] because [Z].

## Related Scratchpads
- `SP-other-issue.md` — how it relates
```
