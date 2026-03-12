# RCA Templates

Read this file once at the start of Phase 3 (Report & Solutions) for Standard/Full scope. Do not read for Quick scope.

## RCA Report Template

Use this for Standard and Full scope RCA reports written to file.

```markdown
# RCA: [Issue Title]

## Summary
> 1-3 sentence description of the incident and root cause.

## Severity
<!-- P1 Critical: Data loss, security breach, complete outage, or widespread user impact -->
<!-- P2 Major: Significant functionality broken, affects many users, no workaround -->
<!-- P3 Minor: Edge case, minor degradation, cosmetic issue, or easy workaround available -->
[P1 Critical / P2 Major / P3 Minor]

## Impact
- **Duration:** [How long the issue persisted]
- **Scope:** [What was affected — users, features, services]

## Symptom
[What was observed — error messages, behavior, metrics]

## Timeline
| Time/Commit | Event |
|-------------|-------|
| [timestamp or SHA] | [What happened] |

## Evidence Ledger
[Paste the evidence ledger maintained during investigation]

## 5 Whys Analysis
[Filled from the 5 Whys analysis in Phase 2]

## Root Cause
[The underlying systemic issue. Must explain ALL observed symptoms.]

**Confidence:** [High / Medium / Low]
**Evidence strength:** [N] independent sources support this finding

## Assumptions & Limitations
- [What was assumed but not verified]
- [What couldn't be investigated and why (e.g., no access to production logs)]
- [Hypotheses that need further validation — reference ⚠️ HYPOTHESIS items from evidence ledger]

## Contributing Factors
| Factor | Category | Evidence |
|--------|----------|----------|
| [factor] | Code / Data / Infrastructure / Process | [evidence ID or file path] |

## Solutions

### Immediate (done or in progress)
- [ ] [Fix the symptom]

### Short-term (prevent recurrence)
- [ ] [Add test, alert, validation]

### Long-term (systemic fix)
- [ ] [Process change, architecture improvement, monitoring]

## Prevention Checklist
- [ ] Root cause fix verified
- [ ] Regression test added
- [ ] Monitoring/alerting covers this failure mode
- [ ] Related code reviewed for similar patterns
- [ ] Team informed
```

---

## Follow-Up Checklist

Use this at the end of any Standard/Full RCA report to verify completeness.

```
[ ] Incident details documented
[ ] Timeline established
[ ] Evidence ledger complete (all findings have source)
[ ] Git history analyzed (git log/blame)
[ ] Root cause identified with confidence rating
[ ] Contributing factors listed with evidence
[ ] Hypotheses explicitly marked (⚠️ HYPOTHESIS)
[ ] Assumptions and limitations documented
[ ] Immediate fix applied or described
[ ] Short-term prevention planned
[ ] Long-term systemic fix identified
[ ] Solutions prioritized by impact/effort
[ ] RCA report written to rca-reports/
```
