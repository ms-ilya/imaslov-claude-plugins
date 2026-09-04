# ABOUTME: The exact layout of an audit report — verdict first, then findings, then the checklist.

Loaded in Phase 4 when the section layout is needed. The ordering is the
substance here, not decoration.

## Why the verdict comes first

A developer decides whether to keep reading before they decide whether to read
at all. A report that opens with its first finding makes them scan for a
conclusion that is never stated, and the conclusion is the thing they came for:
can I submit this.

## Skeleton

```markdown
# App Store audit — <app name>

**NOT READY — 3 critical finding(s)** · citations unverified this run

<one line: N targets scanned, M findings, K checklist items, run date>

## Findings

### <target name> (<kind>)

#### [critical · PROVEN] <rule title>
Guideline 5.1.1 · rule `privacy-manifest-absent`

<what is wrong, one or two sentences>

**Evidence** — `CleanWidget/Info.plist`
> no PrivacyInfo.xcprivacy in the CleanWidget target

**Resolve by** — either:
- Add a PrivacyInfo.xcprivacy to the CleanWidget target
- Declare an empty NSPrivacyAccessedAPITypes array if it reaches no required-reason API

**Applies to** — Brazil storefront, from June 2026 · verified against the policy source

#### [warning · PROBABLE] <rule title>
...
**Not confirmed** — could not confirm whether the Stripe charge is for a
digital or a physical good.

## App Store Connect checklist

Items no code scan can decide. Each says why.

- [ ] **Confirm the privacy policy URL resolves** — the URL lives in App Store
      Connect and its reachability depends on a live server.
      *Shown because* the scan found account creation in `AccountView.swift`.

## Rules withheld

Omit this section when empty.

- `current-sdk-rule` — cites guideline 2.5.10, which Apple's retrieved text
  marks intentionally omitted.
- `usage-description-missing` — needs CleanWidget's Info.plist, which was not
  read (`info_plist_source: unresolved`). Absence could not be established.
```

## Rules for the body

**Verdict line.** `READY` with no critical and no warning findings.
`LIKELY READY — N warning(s) to review` with warnings but no critical.
`NOT READY — N critical finding(s)` with any critical. Append
`· citations unverified this run` when any source went unverified, and
`· degraded scan` when anything the collector needed could not be read. Both
suffixes exist so the verdict cannot read stronger than the run that produced it.

**A withheld rule is not a passed rule.** Where rules were withheld, the verdict
also carries `· N rule(s) withheld`, because `READY` with four rules withheld is
a different statement from `READY` with none, and the difference is exactly the
one a developer needs before they stop looking.

**Grouping.** Target first, then severity within it. A developer fixes one
target at a time, and a widget's problems are not the app's.

**Both grades, always, in the heading.** Severity says how bad it is if true.
Verifiability says how firmly the code supports saying it is true. Printing only
one collapses the distinction the whole catalogue is built on.

**Evidence is quoted, never paraphrased.** If it cannot be quoted, the finding
is not PROVEN.

**Every resolution, not the first one.** Where a finding admits two fixes, print
both under "either". Choosing for the developer means choosing with less
information than they have.

**PROBABLE findings print what was not confirmed.** That sentence is what lets
a reader decide whether the finding is worth their time, and it is the only
thing separating a graded uncertainty from a guess.

**Checklist items say why they are there.** An item shown because the scan found
something names what it found. An item that always applies says nothing extra.
A checklist that lists everything unconditionally is one people learn to skip.

## What not to do

- Do not print a count you did not compute. The verdict's number is the length
  of the critical findings list, not an impression of it.
- Do not merge the checklist into the findings. They have different bars: a
  finding says the code is wrong, a checklist item says the code cannot tell.
- Do not soften a `NOT READY` verdict with encouragement. The count is the
  message.
