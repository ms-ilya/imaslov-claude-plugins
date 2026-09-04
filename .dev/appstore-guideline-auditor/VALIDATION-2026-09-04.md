# ABOUTME: Validation run of appstore-guideline-auditor v1.0.0 — what held, what broke, and what to change.

**Date:** 4 September 2026
**Plugin:** `appstore-guideline-auditor` 1.0.0 (cache copy byte-identical to this repo)
**Subject project:** `iBraid` — native SwiftUI/ARKit app, 56 Swift files, 1 shipping target, WebRTC + socket.io
**Method:** deterministic layers tested directly against purpose-built fixtures; then one full live audit end to end, with an independently gathered ground truth to score its findings against.

Verdict up front: **the design holds and the live run was accurate — 4 findings, all true positives, zero false positives.** The defects below are in the collector and the validator, not in the grading model. Three of them are silent: they make the tool under-report without saying it did, which is the one failure mode this plugin's own SKILL.md singles out as unacceptable.

---

## 1. What was verified to work

| # | Property | How it was tested | Result |
|---|---|---|---|
| V1 | Catalogue integrity | `check-catalogue.sh`, offline | 68 rules, ids unique, 68/68 guidance slugs resolve, 0 problems |
| V2 | Citation accuracy | `APPSTORE_GUIDELINE_TEXT` = text fetched from Apple today | **66/66 citations resolve, zero drift** |
| V3 | Cross-platform rejection | Flutter (`pubspec.yaml`), React Native (`package.json` dep) fixtures | Correct, framework and marker both named |
| V4 | Out-of-scope branches | `no-xcode-project`, `unreadable-project`, `no-shipping-targets` fixtures | All three distinct, correctly worded, never phrased as a clean bill of health |
| V5 | R1 read-only | 146-file `stat` snapshot before/after the live run | **1 path added (`.appstore-audit/report.md`), 0 modified, 0 removed** |
| V6 | Scratch containment | `collect-context.sh <proj> <proj>/.appstore-audit` | Refused, exit 2, with the reason |
| V7 | Schema gate | 29 hand-built adversarial documents | 28 correct; the 1 disagreement was a bug in my fixture, not the validator |
| V8 | Degraded parse | pbxproj that `plutil` rejects but the regex path can read | Target recovered, `parse_degraded: true` set and printed |
| V9 | Drift detection | guideline number deleted / text garbage / file missing | All three caught and named |
| V10 | Live audit quality | 5 subagents, scored against independent ground truth | 4 findings, **4 true positives, 0 false positives** |

**V7 detail.** Every anti-hallucination invariant the schema claims to enforce by construction actually does: `PROVEN` + `absence:false` without a `line` is rejected; `PROBABLE` without `unconfirmed` is rejected; `verifiability: MANUAL` cannot appear on a finding at all; the closed schema rejects extra fields; `line: 0`, `line: true` and `line: "42"` are all rejected. That layer is genuinely load-bearing.

**V10 detail — the false-positive carve-outs held under real pressure.** The subject app calls `ARFaceTrackingConfiguration` (`FaceDetectionView.swift:17,48`), and rule `facial-recognition-wrong-framework` (2.5.13) keys on exactly that. It correctly did **not** fire, because 2.5.13 is about facial recognition *for account authentication* and the app has no login. A naive scanner fires here. Also correctly resisted: Swift's `$0` read as a currency literal, "design tokens" read as monetization, a `// diagnostics` comment read as a medical claim, WebRTC `message`/`followDistance` read as social features, and `INFOPLIST_KEY_UILaunchScreen_Generation` understood as launch-screen synthesis rather than absence.

---

## 2. Findings

### F1 — Guideline sub-clause parser silently defeats retirement detection · **High** · proven, fix validated

`CLAUSE_LINE` in `scripts/lib/check_catalogue.py:214` ends with `\b`:

```python
CLAUSE_LINE = re.compile(r'^\s*[-*]\s+\*\*((?:[1-5])(?:\.[0-9]+)*(?:\([a-z]+\))?)\b')
```

`\b` cannot match between `)` and a space, so the regex always backtracks and discards the `(\([a-z]+\))?` group. The group is unreachable. Measured against Apple's current text: **0 of 118 indexed numbers carry a parenthetical.** `5.1.1(i)` indexes as `5.1.1`, `3.1.1(a)` as `3.1.1`, `2.1(a)` as `2.1`.

That alone would be cosmetic. It is not, because `build_index` keeps the *longest* body per key. When Apple retires a clause that has parenthetical siblings, a longer sibling overwrites the retired entry and the `omitted` flag is lost:

```
Retire 5.1.1 as "Intentionally omitted", keep 5.1.1(i)..(x):
  baseline  -> CATALOGUE OK              (11 rules keep citing a retired clause)
  patched   -> 11 PROBLEM(S)             (all 11 correctly withheld)
```

This is precisely the drift the check exists to catch — the file's own header cites the 2.5.10 and 4.5.5 renumbers as the motivating cases. 2.5.10 happens to be caught only because it has no parenthetical siblings.

**Fix (validated):** replace the trailing `\b` with a lookahead that lets the parenthetical survive.

```python
CLAUSE_LINE = re.compile(r'^\s*[-*]\s+\*\*((?:[1-5])(?:\.[0-9]+)*(?:\([a-z]+\))?)(?=[\s*]|$)')
```

Regression-tested on a full plugin copy against the same Apple text: identical output on the real catalogue (66 citations checked, `CATALOGUE OK`), index grows 118 → 210 numbers with 92 parentheticals now addressable, and the retirement scenario above is caught. No catalogue rule currently cites a parenthetical, so nothing existing changes behaviour.

### F2 — Three shipping product types are silently dropped · **High** · proven

`SHIPPING_PRODUCT_TYPES` in `scripts/lib/collect_context.py:24` omits products that App Review absolutely sees:

- `com.apple.product-type.application.on-demand-install-capable` (App Clip)
- `com.apple.product-type.app-extension.messages` (Messages extension)
- `com.apple.product-type.app-extension.messages-sticker-pack` (Sticker pack)

They fall through to `skipped_targets` with `kind: "unknown"`. Two consequences, the second serious:

1. In a mixed project they are skipped without being audited — every privacy-manifest rule (the ITMS-91053 class the collector's own header says motivated per-target enumeration) never runs against them.
2. In a project where such a target is the *only* one — a sticker-pack app, which is a real and common App Store product — the run reports:

```
OUT OF SCOPE: no-shipping-targets
  1 target(s) found, none of them shipping — only tests, frameworks or libraries.
  There is nothing App Review would see.
  skipped (unknown): MyStickerApp
```

Every clause of that is false. SKILL.md Phase 0 says "a run that audited nothing must never be phrased as a run that found nothing" — this is that failure, reached through the product-type table rather than the wording.

**Fix:** add the three types to `SHIPPING_PRODUCT_TYPES` (App Clip as its own kind, the two Messages types as `app-extension`). Separately, make the `no-shipping-targets` message conditional: when any skipped target is `unknown`, say the product type was not recognised and name it, rather than asserting "only tests, frameworks or libraries".

### F3 — R2 and R3 are enforced by instruction only, never by construction · **High** · proven

`validate-findings.sh` checks shape but never checks the finding against the catalogue it claims to come from. Both of these pass validation cleanly:

```
ok  R2R3-fabricated.json:      1 finding(s), 0 checklist item(s)
    rule "totally-invented-rule-id", guideline "7.9.9(z)"   <- neither exists; Apple has no section 7
ok  R3-drifted-severity.json:  1 finding(s), 0 checklist item(s)
    rule "privacy-manifest-absent" cited as guideline "1.2.3", severity "suggestion"
    catalogue says:                              guideline "5.1.1", severity "critical"
```

The contract's two rules specifically about invention — R2 "never emit a finding for a rule not in the catalogue", R3 "never state a guideline number a rule does not carry" — have no mechanical backstop. This sits oddly beside the schema's own boast that MANUAL-routing is "enforced by construction instead of by instruction", and beside the agent card's "Severity comes from the rule and you do not change it."

Note the guideline pattern `^[1-5](\.[0-9]+)*(\([a-z]+\))?$` is already written and enforced on the catalogue side in `check_catalogue.py`; the finding schema simply doesn't apply it.

**Fix:** have `validate-findings.sh` load `rules/*.json` and, per finding and checklist item, assert `rule` exists and that `guideline` and `severity` equal the catalogue record's. Failure should be the same non-merge outcome as a shape failure. This is roughly 15 lines and closes the whole class.

### F4 — Nested `.xcodeproj` resolves Info.plist against the wrong root, and does not flag it · **Medium** · proven

`resolve()` (`collect_context.py:168`) joins `INFOPLIST_FILE` onto the **scan root**, but `INFOPLIST_FILE` is relative to `SRCROOT` — the `.xcodeproj`'s parent. `find_pbxproj` walks the tree, so the two differ whenever the project is not at the top level (`Nested/`, `ios/`, `App/`, a monorepo package).

Fixture with the project one level down:

```
IN SCOPE: 1 shipping target(s)
  app  Nested  plist=-   manifest=MISSING   entitlements=-
context.json:  info_plist: null     info_plist_keys: []     parse_degraded: false
build_settings: {"INFOPLIST_FILE": "Nested/Info.plist", ...}   <- the file exists on disk
```

The plist is present and readable; the collector just looked in the wrong place. Because `info_plist_keys` is then `[]`, every rule reading a plist key sees definitive absence — `usage-description-missing`, `app-transport-security-disabled`, `export-compliance-undeclared`, `launch-screen-absent`. Those are `absence: true` findings, which the schema grades **PROVEN with no line required**. So a nested project yields a page of confident, critical, fabricated findings, and `parse_degraded` stays `false`, so nothing in the report warns the reader.

This is the highest-consequence defect in the set: F1 and F2 make the tool miss things, F4 makes it assert things that are not true, at the grade the reader trusts most.

**Fix:** resolve build-setting paths against `os.path.dirname(os.path.dirname(pbxproj))`, not `root`. Also treat "`INFOPLIST_FILE` is set but did not resolve" as a degraded condition rather than as absence — the two are different and only one is a finding.

### F5 — `all_entitlements` drops everything under an ancestor named `build`, `Pods`, … · **Medium** · proven

The entitlements walk (`collect_context.py:222`) filters with `set(dp.split(os.sep)) & SKIP_DIRS` against the **absolute** path, so any ancestor directory anywhere above the project matching `SKIP_DIRS` zeroes the list. Sources and privacy manifests use `dirnames[:]` pruning instead, which only prunes below the root — so the same script treats the three inconsistently.

Clean A/B on identical trees:

```
under .../fixtures/build/MyApp   all_entitlements: []                      <- silently empty
under .../fixtures/normal/MyApp  all_entitlements: ['Ref/Ref.entitlements']
                                 (all_privacy_manifests identical in both)
```

Any entitlement-keyed rule — `push-entitlement-unused`, `app-group-identifier-mismatch` — silently cannot fire. **Fix:** use the same `dirnames[:]` pruning as the other two walks.

### F6 — `age-rating-social-descriptor` pattern is too loose, and the subagent had to overrule the catalogue · **Medium** · observed live

The rule matches `(?i)(chat|message|directMessage|follow(ers|ing)|userProfile|feed|comment)` across Swift sources, with no `note` carve-out. In the live run it hit 16 files — all incidental: `errorMessage`, `statusMessage`, WebRTC signalling payloads, `followDistance`, "grid follows head inertia". The design subagent suppressed it on judgment.

The suppression was correct, and I would not want the item on the checklist here. But the mechanism is wrong: the catalogue matched and an LLM silently overrode it. That is the non-determinism the catalogue exists to remove, and it cuts the other way too — a different run may well emit it. The agent card's "Never suppress a candidate because you are unsure" and "A carve-out beats a match" point in opposite directions when no carve-out is written.

**Fix:** tighten to social-surface symbols rather than substrings (`sendMessage`, `messageThread`, `followUser`, `userProfile`, `commentOn`, `postComment`), and add a `note` recording the WebRTC-signalling and `errorMessage` false positives explicitly. Then the suppression is the catalogue's decision and is reproducible.

**Separate question worth a decision:** the rule's `applies_to.effective` is `2026-09-01`, which has now passed, and Apple's announcement (`news/?id=tlur8uvi`, fetched and verified this run) says responses are required for **all** new apps and updates from September 2026, not only social ones. As written the item only appears for apps with social vocabulary. If the intent is "every submission from now on needs this answered", the detection should be `kind: always`.

### F7 — Phase 1 has no supported way to produce `APPSTORE_GUIDELINE_TEXT` · **Medium** · observed live

SKILL.md Phase 1 says to run `APPSTORE_GUIDELINE_TEXT=<fetched text file> check-catalogue.sh`, but the tool that does the fetching, `WebFetch`, returns a small model's *answer about* the page, not the page. Nothing in the skill says how the answer becomes a file with Apple's numbered clauses intact, and `build_index` needs the exact `- **<number> <title>**` bullet form.

In this run I had to prompt WebFetch explicitly to reproduce every clause verbatim in that bullet format, then `Write` it. It worked — 210 clauses, 66/66 citations verified. A run that asks WebFetch for a summary instead gets prose, and then:

```
FAIL [outdated] guideline anchor: no guideline numbers could be parsed out of <file>
```

The failure is at least loud rather than silent, which is the right default. But the whole citation-verification layer — arguably the plugin's headline feature — currently depends on prompt wording that the skill does not specify.

**Fix:** put the exact extraction prompt in SKILL.md Phase 1, along with the target format and the instruction to `Write` it to the scratch directory before invoking the checker.

### F8 — SKILL.md prescribes a deprecated collection mechanism · **Low** · observed live

Phase 2 says to collect with `TaskOutput(task_id, block: true, timeout: 600000)` and "do not poll with `block: false`". In this harness `TaskOutput` is deprecated; background agents deliver results via task notification automatically, and its own description warns that reading a `local_agent` output file will overflow the caller's context. Following Phase 2 literally is at best redundant and at worst harmful.

**Fix:** restate Phase 2 as "dispatch all five in one message and wait for their completion notifications; do not read the agents' output files", keeping the load-bearing instruction, which is *aggregate only after all five have finished*.

### F9 — Smaller items

| Item | Where | Note |
|---|---|---|
| `rm -rf "$SCRATCH"` on an unvalidated `$2` | `collect-context.sh` | `collect-context.sh <proj> ~/Documents` deletes `~/Documents`. The skill never passes `$2`, so this is a manual-use footgun only — but it should refuse a target that is non-empty and does not look like its own scratch dir. |
| Comment/code drift | `collect_context.py:154-157` | The comment says the regex path collects build settings "that appear anywhere so rules can still see them". It does not; it returns empty `buildSettings`. Delete the claim or implement it. |
| Unused parameter | `collect_context.py:197` | `build(root, outdir)` never uses `outdir`. |
| Double slash in scratch path | `collect-context.sh` | `${TMPDIR}` already ends in `/`, so paths render as `…/T//appstore-audit/…`. Cosmetic. |
| `_resolve` raises `KeyError` | `schema_check.py:47` | A bad `$ref` gives a raw traceback rather than a `SchemaError`. Only reachable by editing the schema. |

---

## 3. Catalogue coverage

Measured against Apple's live text: the catalogue cites **31 of 112** non-omitted numbered clauses (28%).

Most of the gap is legitimate — 1.1.x objectionable content and 5.3 gambling are judgment calls no static scan should attempt. But some uncovered clauses are both code- or metadata-detectable and high frequency:

| Clause | Why it belongs | Detectable from |
|---|---|---|
| **1.5 Developer Information** | A support URL with current contact info is required for **every** app. A universal MANUAL checklist item, cheap to add, and currently absent. | App Store Connect — checklist |
| **2.5.14 Recording and logging** | Explicit consent plus a visible or audible indicator when recording user activity. **Would have produced a finding on the subject app**, which streams the live camera feed to a browser over WebRTC. | `RPScreenRecorder`, `AVAssetWriter`, `AVCaptureMovieFileOutput`, WebRTC video tracks |
| **4.2.1 ARKit experiences** | "Merely dropping a model into an AR view is not enough." Directly aimed at ARKit apps; the catalogue has no ARKit-quality rule at all. | ARKit imports vs. scene complexity — PROBABLE at best |
| **5.1.5 Location Services** | Location must be relevant to the app's features. | `CLLocationManager` + usage-description strings |
| **2.3.9 / 2.3.8 metadata rights and age-appropriateness** | Same class as the four metadata checklist items already present. | App Store Connect — checklist |

The 2.5.14 gap is worth acting on first: it is the one clause where this validation run's subject app has a plausible real exposure that the audit could not report.

---

## 4. Proposals, in priority order

1. **F4 — fix `SRCROOT` resolution.** Silent fabrication of PROVEN critical findings on any non-top-level project. Highest consequence.
2. **F3 — cross-check findings against the catalogue in `validate-findings.sh`.** Makes R2 and R3 mechanical instead of aspirational; ~15 lines; closes an entire class.
3. **F2 — add the three missing shipping product types**, and stop asserting "only tests, frameworks or libraries" when a skipped target was merely unrecognised.
4. **F1 — apply the validated `CLAUSE_LINE` patch.** One-line change, regression-tested, restores retirement detection.
5. **F5 — make the entitlements walk prune like the other two.**
6. **F7 — specify the guideline-text extraction prompt in SKILL.md.** The citation layer currently rests on unwritten prompt wording.
7. **F6 — tighten the social-descriptor pattern and add its carve-out note;** separately decide whether the item is now unconditional.
8. **F8 — drop the `TaskOutput` prescription** from Phase 2.
9. **Coverage — add 1.5 and 2.5.14 first**, then consider 4.2.1 and 5.1.5.
10. **F9 — the small items**, notably guarding `rm -rf "$SCRATCH"`.

None of these change the architecture. The two-axis grading, the closed schema, the collect-once/fan-out shape and the scratch-outside-the-project rule all did their jobs; the defects are in three specific functions and one missing validator pass.

---

## 5. Live run — reproduction record

```
Project      : /Users/user/Dev/iBraid/mobile-application-main
Scope        : IN SCOPE — 1 shipping target (iBraid, app), 0 skipped, 56 sources
               privacy manifest MISSING, no entitlements, parse_mode plutil, not degraded
Citations    : guidelines verified · policy verified (5 policy pages fetched)
               66/66 catalogue citations resolved against Apple's text of 2026-09-04
Subagents    : 5 dispatched in one message, all completed, all schema-valid
               safety skipped · business 0+2 · design 0+1 · legal 2+2 · performance 2+4
Aggregate    : 4 findings (1 critical, 2 warning, 1 suggestion), 9 checklist items
Verdict      : NOT READY — 1 critical finding
Report       : .appstore-audit/report.md
R1           : 146 -> 147 files; 1 added, 0 modified, 0 removed
Wall clock   : ~6 min for the fan-out (slowest agent 360 s), ~2 min for phases 0-1
Token cost   : 5 subagents, 201,713 subagent tokens total, 89 tool calls
```

Findings, each independently confirmed against the source before being accepted:

| Rule | Grade | Confirmed by |
|---|---|---|
| `privacy-manifest-absent` | critical · PROVEN | `find . -name PrivacyInfo.xcprivacy` → nothing |
| `export-compliance-undeclared` | warning · PROVEN | `plutil -p iBraid/Info.plist` → 4 keys, no `ITSAppUsesNonExemptEncryption` |
| `placeholder-content-shipping` | warning · PROBABLE | `VRTrainingView.swift:72` → `Text("COMING SOON")`; navigation traced, unreachable — recorded as `unconfirmed`, not suppressed |
| `ipad-support-disabled` | suggestion · PROVEN | `TARGETED_DEVICE_FAMILY = 1;` in both configurations |

The `placeholder-content-shipping` entry is the best single illustration of the design working: the pattern matched, the agent traced navigation and found no call site outside `#Preview`, and rather than dropping the finding or overstating it, it graded PROBABLE and wrote three sentences saying exactly what it could not confirm. That is the behaviour the two-axis model exists to produce.
