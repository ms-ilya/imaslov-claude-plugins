---
name: appstore-audit
description: >-
  Audits a native iOS Xcode project for App Store rejection risks against a
  checked rule catalogue, grading every finding by severity and by how firmly
  code evidence supports it, and emits an App Store Connect metadata checklist
  for what no code scan can decide. Use when the user is preparing an iOS app
  for submission or TestFlight and asks to check for rejection risks, review
  App Store readiness, audit guideline compliance, check privacy manifests or
  usage descriptions, or asks why Apple rejected a build and cites a guideline
  number. Do NOT use for general Swift code review — the ios-quick-review and
  ios-comprehensive-review plugins own that — nor for Google Play policy, nor
  for Flutter, React Native, Expo, Capacitor, Unity or other cross-platform
  projects, which this auditor reports as out of scope rather than auditing.
argument-hint: "[path to the Xcode project] [--out <report path>]"
compatibility: >-
  Reaches the network at run time. Each audit resolves Apple's current App
  Review Guidelines and policy-update pages by web search and fetches them, so
  citations reflect Apple's published text on the day of the run rather than a
  vendored snapshot. The audit still completes without network access; findings
  then record their citations as unverified for that run. Writes exactly one
  file into the audited project — its report — and modifies nothing else.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Write
  - Agent
  - TodoWrite
  - WebSearch
  - WebFetch
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/collect-context.sh *)
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-catalogue.sh *)
  - Bash(bash ${CLAUDE_PLUGIN_ROOT}/scripts/validate-findings.sh *)
---

# ABOUTME: Orchestrates a read-only App Store guideline audit — collect once, fan out per rule category, aggregate, verdict.

You audit a native iOS project for App Store rejection risks. You report; you
never fix. The catalogue decides what the rules are, you decide what this
project does, and the two grades on every finding keep those separate.

## The contract you must not break

| # | Rule |
|---|---|
| **R1** | **NEVER** modify a file that already existed in the audited project. You create exactly one path there: the report. |
| **R2** | **NEVER** emit a finding for a rule that is not in the catalogue. An uncatalogued rule has not passed the entry gate. |
| **R3** | **NEVER** state a guideline number a rule does not carry, or invent one for a rule whose `guideline` is `null`. |
| **R4** | **NEVER** drop a candidate risk for being uncertain. Grade it PROBABLE, or route it to the checklist as MANUAL. |
| **R5** | **NEVER** report a citation as verified on a run where its source was not retrieved. |
| **R6** | **NEVER** audit a cross-platform project. Report it as out of scope and stop. |
| **R7** | **NEVER** treat a substrate the collector could not read as a substrate that is empty. `null` is not `[]`, and only `[]` supports a finding of absence. |

## Phase 0 — Scope

Resolve the project path from `$ARGUMENTS`, defaulting to the working directory.

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/collect-context.sh <project-path>
```

It prints the scratch directory it wrote to, **outside** the project. Read
`context.json` from there.

If `in_scope` is false, **stop**. Emit no findings and write no report — and
never let that read as a clean bill of health. `out_of_scope_reason` says which
of four it is, and they need different words:

| Reason | What to say |
|---|---|
| `cross-platform-framework` | Name the framework and the marker that gave it away. This auditor covers native iOS; running it anyway produces findings from a scan that could not see where that framework keeps its configuration. |
| `no-xcode-project` | No `.xcodeproj` was found under this path. Ask for the project directory rather than guessing. |
| `unreadable-project` | An Xcode project exists but **no target could be read from it**. Say plainly that this is a failure to read, not a finding of zero problems, and name the `pbxproj` path. |
| `no-shipping-targets` | Targets exist but none of them ships — only tests, frameworks or libraries. List the skipped ones so the reader can see what was found. |
| `unrecognised-product-types` | Targets exist and at least one carries a product type this collector does not know. Name the type. Do **not** say the targets do not ship — you do not know that, and the reason this branch exists is that saying it was how a sticker-pack app got told there was nothing App Review would see. |

The last three matter most. An empty report is the one output a developer will
happily accept, so a run that audited nothing must never be phrased as a run
that found nothing.

If `parse_degraded` is true, print every entry of `parse_degraded_reasons` in
the report. Each names a target and what could not be read about it. A degraded
flag with no reasons tells a developer their report is worth less without
telling them what to fix.

**Substrates, and why `null` matters.** Each shipping target reports
`info_plist_keys` and `info_plist_source`. `info_plist_keys: null` means the
collector did not read the plist — not that the plist is empty. The two used to
be the same value, and a project whose Info.plist simply was not found produced
a page of confident critical findings about keys that were there all along.
Sources: `file`, `build-settings` (Xcode synthesises the plist from
`INFOPLIST_KEY_*` settings — a complete substrate), `file+build-settings`,
`unresolved`, `unreadable`, `undeclared`. The last three carry `null` keys.
`entitlements_source` works the same way. Where a rule's clause needed a
substrate that was not read, list the rule under **Rules withheld** with the
reason — see R7 and Phase 4.

## Phase 1 — Resolve Apple's current text

Search first, then fetch what the search resolves to. A pinned URL list cannot
reach a policy item published after this plugin shipped, and the regional and
dated layer is exactly the layer that grows: the guidelines page itself mentions
Brazil, CADE, Korea, GRAC, Core Technology and Time Allowances **zero** times.
Those live in `developer.apple.com/news/` items, announced as they happen.

1. `WebSearch` for Apple's current App Review Guidelines page —
   `developer.apple.com/app-store/review/guidelines/`.
2. `WebSearch` for Apple's recent developer policy announcements, using terms
   rather than ids so an item published after this file was written is still
   reached:
   - `site:developer.apple.com/news App Store age rating requirements`
   - `site:developer.apple.com/news alternative payment storefront terms`
   - `site:developer.apple.com/news App Store changes European Union`
   - `site:developer.apple.com App Review Guidelines updated`
3. `WebFetch` the guidelines page and each policy page the search resolved.

Five policy items were present when this catalogue was derived. They are a
**floor**, not the definition — returning more is the mechanism working;
returning fewer means the search failed, not that Apple withdrew them.

| Item | What it carries |
|---|---|
| `news/?id=a233fmpw` | The June 8 2026 guidelines update |
| `news/?id=tlur8uvi` | Age-rating questionnaire: social media questions, mandatory from September 2026 |
| `news/?id=oj3r9pvw` | Age rating updates for the Republic of Korea |
| `news/?id=gmws0jgp` | Changes for apps in the European Union |
| `news/?id=dhwadr2x` | Changes to iOS in Brazil |

Two further news ids are **not** part of this layer — do not add them:
`12m75xbj` is an account-deletion explainer superseded by the guideline itself,
and `d75yllv4` is the guidelines page's own changelog rather than a policy delta.

A rule carrying an `applies_to` block — a storefront, a date, or both — is
verified against the **policy** sources, never against the guidelines page. A
regional requirement reported on the guidelines page's authority is reported on
the authority of a page that does not mention it.

Record a `CITATION_STATE` — one entry per source, `verified` or `unverified`:

```json
[{"source": "guidelines", "state": "verified"},
 {"source": "policy", "state": "unverified", "detail": "no policy page was retrieved on this run"}]
```

**The state is per source, not per run.** A run that reached the guidelines but
not the policy pages is a real and common state, and collapsing it to one flag
is what makes a regional finding read as verified when it is not.

### Turning the fetch into a file the checker can read

`WebFetch` returns a small model's **answer about** the page, not the page. Ask
it for a summary and you get prose with no clause numbers in it, and the checker
then fails with "no guideline numbers could be parsed". That failure is loud,
which is right — but the whole citation layer depends on asking correctly, so
the prompt is written down here rather than improvised per run.

Fetch the guidelines page with **this** prompt:

> Reproduce every numbered guideline clause on this page verbatim, in order, as
> a markdown list. One list item per clause, in exactly this form:
> `- **<number> <title>**` followed by the clause's own body text on the
> following lines. Include sub-clauses that carry a parenthetical letter, such
> as 3.1.1(a) and 5.1.1(i), as their own items. Include clauses whose body is
> "Intentionally omitted" — reproduce that text. Do not summarise, do not
> paraphrase, do not skip a clause because it seems minor, and do not add
> commentary of your own.

Then `Write` the result to `<scratch>/guidelines.md` and point the checker at
it. Two things make this format load-bearing: the checker anchors on `- **`
and reads the number off the front, and it keeps the **longest** body per
number — so a clause reproduced only as a cross-reference elsewhere must not be
the only copy.

Sanity-check before trusting the result: the checker prints how many numbers it
parsed. A page of Apple's guidelines yields on the order of 200. A number in
the single or low double digits means the fetch came back as prose, and the run
should treat citations as `unverified` rather than as checked.

```bash
APPSTORE_GUIDELINE_TEXT=<scratch>/guidelines.md bash ${CLAUDE_PLUGIN_ROOT}/scripts/check-catalogue.sh
```

A rule whose number no longer resolves, or now resolves to different content,
is **withheld from this run's findings** and listed in the report under
"Rules withheld", with what the check said. Apple renumbers: 2.5.10 was retired
and Push Notifications moved from 4.5.5 to 4.5.4. A citation that has drifted is
worse than a missing rule, because the developer checks it and finds you wrong.

If nothing was retrieved, continue with every citation `unverified`. The audit
still runs — a transient network failure must not make a read-only advisory tool
unavailable — and the verdict line says the run was degraded.

## Phase 2 — Fan out, one subagent per rule category

Five categories: `safety`, `performance`, `business`, `design`, `legal`.

Dispatch all five **in one message**, `run_in_background: true`:

```
Agent(run_in_background: true,
      subagent_type: "appstore-guideline-auditor:rule-category-auditor",
      prompt: "CATEGORY: legal
RULES_FILE: ${CLAUDE_PLUGIN_ROOT}/rules/legal.json
GUIDANCE_FILE: ${CLAUDE_PLUGIN_ROOT}/skills/appstore-audit/references/detection-legal.md
CONTEXT_FILES: <scratch>/target-*.json
OUTPUT_FILE: <scratch>/findings-legal.json
CITATION_STATE: <the JSON array from Phase 1>")
```

Then wait for their completion notifications, which arrive on their own. Do not
read the agents' output files — those are full transcripts and reading one
overflows this context.

Aggregate **only after all five have finished.** A partial merge silently
under-reports, and under-reporting is the failure a developer discovers from
App Review rather than from you. If an agent fails or never reports, that
category is a failure, not an absence of findings: name it under **Rules
withheld** and say the category did not run.

## Phase 3 — Validate before merging

```bash
bash ${CLAUDE_PLUGIN_ROOT}/scripts/validate-findings.sh <scratch>/findings-*.json
```

Two gates run, and they ask different questions. The schema asks whether the
document has the right shape; it is closed, so a field it does not define is a
failure rather than an extra. The catalogue check asks whether the findings are
about rules that exist, at the guideline numbers and severities those rules
actually carry — which is R2 and R3 made mechanical rather than requested.

An output that fails either is **not merged** — report the category as failed,
name what the validator said, and carry on with the rest. A malformed result is
not a result; merging it anyway is how a fabricated line number reaches a report.

Then merge, and de-duplicate: the same rule matching the same file and line in
the same target is one finding, not two.

## Phase 4 — Verdict, findings, checklist

The report opens with the verdict. A developer decides whether to keep reading
before they decide whether to read at all.

| Counts | Verdict line |
|---|---|
| 0 critical, 0 warning | `READY — no blocking findings` |
| 0 critical, ≥1 warning | `LIKELY READY — N warning(s) to review` |
| ≥1 critical | `NOT READY — N critical finding(s)` |

Append `· citations unverified this run` when any source is unverified,
`· degraded scan` when `parse_degraded` was true, and `· N rule(s) withheld`
when anything reached the withheld section. A verdict that hides how the run
went is a verdict that gets trusted more than it earned, and `READY` with four
rules withheld is a different claim from `READY` with none.

Then three sections, in this order:

**Findings** — grouped by target, then severity. Each one names the rule, the
guideline number (or states the rule carries no Apple anchor), the severity and
verifiability, the file, the line where there is one, the quoted evidence, and
**every** resolution. Where a finding admits two fixes, give both: an unused push
entitlement is resolved by removing the entitlement *or* by registering for
notifications, and only the developer knows which they meant. For a PROBABLE
finding, print what was not confirmed on its own line — that sentence is what
lets the reader decide whether to spend time on it. For a regional or dated
requirement, print the storefront or date it applies to and the source it was
verified against.

**App Store Connect checklist** — every MANUAL item, distinct from the findings.
These are the risks no code scan can decide: a live URL, a deployed backend,
values that exist only in App Store Connect. Show an item **only where its
applicability condition was met**, and where the item applied because of
something the scan found, say what that was. A checklist that lists everything
is one people skip.

**Rules withheld** — three things go here, and they are all cases where the
audit could not decide rather than decided there was nothing:

- a rule Phase 1 withheld because its guideline number drifted;
- a category that failed validation or whose agent never reported;
- a rule whose detection needed a substrate the collector did not read — name
  the target, the substrate and the `*_source` value that says why.

Empty is normal; omit the section when empty. This section is what keeps R7
honest: a withheld rule is visible, and a rule silently graded against an empty
substrate is not.

## Phase 5 — Write the report

Write the report to `.appstore-audit/report.md` inside the audited project, or
to the path given after `--out`. Print the path you wrote.

That file is the **only** path you create in the project. Findings files, target
context and fetched text all stay in the scratch directory. Before finishing,
confirm you have created nothing else there.

## References

Load on demand, not up front.

| File | When |
|---|---|
| `references/detection-<category>.md` | passed to that category's subagent; you do not read it |
| `references/report-format.md` | Phase 4, if you need the exact section layout |
