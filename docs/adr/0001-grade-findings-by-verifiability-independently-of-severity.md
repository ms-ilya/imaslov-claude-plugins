# ADR-0001 — Grade findings by verifiability, independently of severity

Status: Accepted
Date: 2026-09-03
Implemented by: `plugins/appstore-guideline-auditor/`

## Context

The App Store guideline auditor is asked to do two things that pull against each
other: identify as many real rejection risks as possible, and do so with high
precision.

The four upstream sources being merged demonstrate why that tension is not
theoretical. Two of them state Guideline 4.8 as "any third-party login requires
Sign in with Apple", while Apple's own verbatim text — corroborated by a third
source — requires a login service meeting three criteria, of which Sign in with
Apple is only the simplest option. An auditor inheriting the strict reading flags
compliant apps. Meanwhile the largest single category of real rejections,
Guideline 2.1 App Completeness, turns on things no static scan can decide: whether
a URL resolves, whether a demo account works, whether a backend is live during
review.

So suppressing uncertain findings loses the risks that matter most, and emitting
them undifferentiated produces the failure one source names explicitly in its own
feedback taxonomy: "a flood of low-value findings drowned out the ones that
mattered."

## Decision

Every finding carries **two independent grades**:

- a **severity** — how bad it is if true;
- a **verifiability tier** — how firmly code supports it, drawn from a fixed set
  of three: `PROVEN` (code evidence at a named file and line), `PROBABLE`
  (pattern matched, surrounding context unconfirmed), `MANUAL` (undecidable from
  code, routed to a checklist rather than presented among code findings).

No candidate risk is withheld for being uncertain. Uncertainty is expressed as a
grade instead of as silence.

## Consequences

Recall stays maximal, because nothing is dropped. Precision comes from never
presenting a guess as a fact — the reader can tell at a glance which findings are
load-bearing and which need a human to confirm.

The cost is that every rule in the catalogue must carry a verifiability tier, and
the report grows a checklist section alongside its findings section. A rule whose
tier is wrong is now a specific, nameable defect rather than a vague complaint
about noise, which is what makes it fixable.

This generalises justinperea's external-verification checklist — the corpus's best
idea, and one no other source has — from a report appendix into a first-class
field on every finding.

## Alternatives considered

**Precision first, suppress low-certainty findings.** Rejected: it silently drops
the whole class of risks that need human judgement, which is where App
Completeness rejections actually live.

**Recall first, emit every candidate undifferentiated.** Rejected: the corpus
itself documents this failure mode as distinct and damaging.

## Open

The severity vocabulary is not settled. The four sources use four incompatible
scales with different bars — `BLOCKER` glossed as "will definitely be rejected"
is not the same claim as `CRITICAL` glossed as "reject almost certain". Which
vocabulary the auditor adopts is deferred as Q11 in the design record. This ADR
fixes the *verifiability* axis only.
