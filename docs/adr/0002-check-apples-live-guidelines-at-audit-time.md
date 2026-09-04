# ADR-0002 — Check Apple's live guidelines at audit time

Status: Accepted
Date: 2026-09-03
Implemented by: `plugins/appstore-guideline-auditor/`

## Context

The auditor merges four upstream sources that disagree with each other about what
Apple's guidelines say. Three disagreements are verified: two sources state
Guideline 4.8 as "any third-party login requires Sign in with Apple" when Apple's
text requires a login meeting three criteria; one source cites `2.5.10` for
"Current SDK" when Apple marks `2.5.10` intentionally omitted; and two sources map
privacy reason code `3EC4.1` to incompatible use cases, neither verified.

Underneath those disagreements is a staleness problem that ranking the sources
does not solve. The vendored verbatim Apple text is dated February 6, 2026. The
source carrying current policy — EU alternative payments, Brazil's CADE agreement,
Korean age ratings, the September 2026 social-media questionnaire — is dated June
8, 2026, verified August 29, 2026. Both age. A tiebreak rule between four
snapshots produces an auditor that is confidently wrong on a schedule.

## Decision

The authority for what a guideline says is **Apple's live published guidelines,
fetched when the audit runs** — not adjudication between the vendored snapshots.

In the user's words: *"With all plugin usage we should check the most recent
source from the apple links."*

The vendored corpus remains in the repository as the derivation record for the
rule catalogue — where each rule came from, which source proposed it, what
rejection cases motivated it. It stops being the authority on current rule text.

## Consequences

The staleness problem is removed at its root. A guideline number that Apple has
since retired, a rule Apple has since softened, and a policy that changed after
the corpus was vendored are all caught at audit time rather than shipped as a
confident citation.

The costs are real and were not present in any alternative considered:

- **The auditor becomes network-dependent.** A static code-scanning tool that
  reaches the network on every run is a different tool, with a different trust
  model, than one that does not.
- **Runs stop being deterministic.** Two audits of the same unchanged project can
  now differ, because Apple changed something in between. That is the point, but
  it means a finding is only reproducible together with the date it was made.
- **A new failure path exists.** What the auditor does when the fetch fails — refuse
  to run, fall back to the vendored snapshot with findings downgraded, or run and
  mark citations unverified — is **not decided**. It is recorded as open question
  Q15 in the design record, and it is the highest-impact gap this decision creates.
- **Which Apple URLs are canonical is not decided** either, recorded as Q14.

## Alternatives considered

**Verbatim vendored text as authority, with a currency layer overriding it for
post-February-2026 policy.** This was the orchestrator's recommendation. It keeps
the auditor offline, deterministic and reproducible, and it resolves 4.8 correctly
today. Rejected because it is correct only until Apple next changes something, and
nothing in the design would notice when that happened.

**Most recent vendored source wins.** Simple to apply, but has no verbatim Apple
text behind it, so citation drift becomes uncheckable — which is the specific
failure the catalogue's guideline-number check exists to prevent.

**Strictest source wins.** Rejected: this is the direct cause of the overstated
4.8 rule that flags compliant apps.

**Record every variant, assert none.** Maximally honest, but pushes adjudication
onto the reader on every finding.

## Open

Q14 (canonical Apple URLs, and whether the vendored text is retained as cache or
fallback) and Q15 (offline and fetch-failure behaviour) are both unanswered and
both High impact. This ADR fixes the authority; it does not fix what happens when
the authority is unreachable.

### Resolved during implementation

**Q14 — the vendored text is retained as neither.** No snapshot of Apple's text
ships inside the plugin. `check-catalogue.sh` verifies citations only against a
copy supplied through `APPSTORE_GUIDELINE_TEXT`, which the audit fills from what
it fetched in Phase 1; with nothing supplied it reports citation resolution as
*skipped* rather than falling back. A pinned copy cannot reach a clause
renumbered after release, and a stale anchor is worse than an absent one because
it makes a drifted citation look verified. The `.research/` corpus remains in the
repository as the derivation record only, and no shipped script reads it.

**Q15 — a fetch failure degrades the run, it does not fail it.** The audit
completes with every citation recorded `unverified` **per source**, and the
verdict line says the run was degraded. A run that reached the guidelines but not
the policy pages is a real and common state; collapsing it to one flag is what
makes a regional finding read as verified when it is not.
