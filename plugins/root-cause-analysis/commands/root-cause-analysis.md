---
description: Systematic root cause analysis that investigates codebases to find why bugs, crashes, and failures happen.
---

# Root Cause Analysis

Investigate the codebase to find the underlying reason for a failure. Produce evidence-backed findings, not speculation.

## Read the skill first

Before doing anything, read the Root Cause Analysis skill documentation:

1. Read `SKILL.md` from the root-cause-analysis skill directory
2. Read `references/techniques.md` for investigation techniques (only for Full scope)
3. Read `references/templates.md` for the RCA report template (only for Standard/Full scope)

## Action

Run the Root Cause Analysis workflow from SKILL.md.

**If arguments are provided:**
The user wants to investigate: `$ARGUMENTS`

**If no arguments are provided:**
Ask the user to describe the symptom — what is the observable problem?

## Key reminders

- Every claim must come from a tool result — never from memory or assumption
- Verify file paths with Glob before citing
- Only describe behavior of code you've Read — never infer from names alone
- Mark unverified claims as HYPOTHESIS
- The root cause must explain ALL observed symptoms
- Simple bugs get simple treatment — not every issue needs a full postmortem
