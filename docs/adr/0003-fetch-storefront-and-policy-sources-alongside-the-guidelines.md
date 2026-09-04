# ADR-0003 — Fetch storefront and policy-update sources alongside the guidelines

Status: Accepted
Date: 2026-09-03
Implemented by: `plugins/appstore-guideline-auditor/`
Extends: ADR-0002

## Context

ADR-0002 made Apple's live published guidelines the authority for what a rule
requires, fetched when the audit runs. Its Context paragraph listed the policy
changes that motivated the decision by name: EU alternative payments, Brazil's
CADE agreement, Korean age ratings, the September 2026 social-media
questionnaire.

A coverage audit in round 3 established that **the fetch ADR-0002 specifies
cannot reach any of them.** Searching the vendored verbatim scrape of the App
Review Guidelines page returns zero occurrences of Brazil, CADE, Korea, GRAC,
"Core Technology", "alternative marketplace" and "Time Allowances". The upstream
source that carries them labels them "post-June policy announcements" and cites
`developer.apple.com/news/` item URLs, not the guidelines page.

So ADR-0002 named four motivating policy changes and then chose a mechanism that
retrieves none of them. The decision was right; its scope was too narrow. This is
recorded as grounding fact 30.

At least one of those changes is a live, dated rejection vector: the social-media
age-rating questions are mandatory for submissions from September 2026, and an
app that answers them wrongly is rejected regardless of what its code does.

## Decision

Named Apple **storefront and policy-update sources are fetched alongside the
guidelines, in the same run**, and are the authority for regional and dated
requirements.

The guidelines page stays authoritative for what a numbered guideline requires.
The policy sources are authoritative for requirements that apply to a storefront
or that commence on a date. A rule whose requirement is regional or dated names
which source it was verified against, so a reader can tell the two apart.

## Consequences

The gap between what ADR-0002 promised and what it could deliver is closed. The
September 2026 age-rating mandate, the Brazil and EU distribution terms and the
Korean rating changes become checkable rather than silently absent.

The costs compound ADR-0002's rather than sitting beside them:

- **Q15's failure path now has two ways to fail, and a third state neither ADR
  contemplated.** Guidelines reachable but policy pages not — a partial success —
  is not one of the three answers Q15 offers (refuse, fall back, mark unverified).
  Q15 was already the highest-impact open question in the spec; this decision
  makes it larger, and this ADR does not answer it.
- **The network surface widens.** More endpoints, each able to move, rename or
  rate-limit independently of the others.
- **Policy pages are less stable to parse than the guidelines page.** A numbered
  guidelines document has structure a check can anchor to. A news item is prose
  with a date, and nothing guarantees its shape from one announcement to the next.
- **Dated requirements need a notion of "now".** A rule that commences in
  September 2026 is not a finding in August, and the auditor has no clock in its
  design as it stands.

## Alternatives considered

**Route regional and dated risks to the MANUAL checklist instead.** No extra
fetch, no extra failure path, and honest about what static analysis can prove —
the checklist would say "confirm your Korea age rating before October 2026".
Rejected because it hides a specific, checkable, dated requirement behind a
checklist line that itself goes stale the moment the date passes, reproducing at
the checklist layer exactly the staleness ADR-0002 removed at the rule layer.

**Leave regional policy out of scope.** Simplest, and defensible for a tool whose
stated scope is a native iOS code audit. Rejected because the September 2026
mandate is a rejection vector that ships this month, and a plugin that merges
four sources while dropping the only one that tracks current policy is not an
improvement over that source.

**Vendor the policy pages as a fifth corpus.** Keeps the auditor offline for this
class of rule. Rejected for the reason ADR-0002 gives: a vendored policy snapshot
is confidently wrong on a schedule, and dated policy ages faster than guideline
text, not slower.

## Open

Q14 is narrowed but not closed: this decision settles the *classes* of canonical
source, and round 3 recovered concrete URLs from the corpus, but the literal list
ships as a plan assumption rather than a settled answer. Whether the vendored
text is retained as cache or fallback remains open and belongs to Q15.

Q15 is unanswered and this ADR widened it. It is the single highest-value
question remaining in the spec.
