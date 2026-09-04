# App Store Review Sources — Extraction

Raw corpus for the planned unified App Store guideline-violation plugin. All four upstream
repos are vendored verbatim under `appstore-sources/`, each pinned to the commit recorded in
`<name>.PROVENANCE.txt`. This file is the map: what each source actually contains, what is
unique to it, where they overlap, and where they contradict each other.

| Source | Repo | Upstream commit date | Size |
|---|---|---|---|
| `justinperea` | JustinPerea/app-store-review-skill | 2026-03-08 | ~2 100 lines |
| `cruisediary` | cruisediary/apple-app-review-skills | 2026-05-02 | ~5 000 lines |
| `devsemih` | devsemih/appstore-review-skill | 2026-07-13 | ~2 100 lines |
| `safaiyeh` | safaiyeh/app-store-review-skill | 2026-08-29 | ~3 800 lines |

**Pruned after the plugin shipped.** The full extraction was 20 132 lines across 117 files.
What remains is the 48 files the plugin's checks actually read, plus each source's `LICENSE`
and `PROVENANCE.txt`:

| Kept | Why |
|---|---|
| `devsemih/references/guidelines-summary.md` | The offline guideline anchor. `check-catalogue.sh` resolves every citation against it. |
| `justinperea/references/checks.md` | 53 numbered checks — a ledger input set. |
| `cruisediary/skills/**/SKILL.md` (31) | 31 micro-skills — a ledger input set, and the source of the ported rejection cases. |
| `devsemih/skills/appstore-review/SKILL.md` | The audit-step topics and the framework table — a ledger input set. |
| `safaiyeh/SKILL.md`, `safaiyeh/rules/*.md` | Rule topics, the regional policy layer and the feedback taxonomy — a ledger input set. |
| `LICENSE` × 4, `*.PROVENANCE.txt` × 4 | MIT attribution and the pinned upstream commit per source. |

The other 69 files were repo scaffolding, per-framework reference material, code examples and
agent definitions that no check reads. **Nothing is lost irrecoverably:** each
`PROVENANCE.txt` pins the exact upstream commit, so any pruned file can be fetched back from
its source repository at the revision this analysis was made against.

Sections below still describe the corpus as it was extracted. Where they name a file that is
no longer here, that file was pruned rather than retracted — the analysis of it stands.

---

## 1. What each source is, architecturally

The four are **not** four versions of the same thing. They occupy different layers, which is
why merging them is worth doing rather than picking a winner.

### justinperea — the *detection engine*
Single flat skill (`SKILL.md`, 189 lines) + four reference files. Its value is
`references/checks.md`: **53 numbered checks** (2.1–2.53). This is the most operational artifact
in the whole corpus — it tells you *how to find* a violation, not just that one exists.

*Corrected after verification.* This entry originally claimed each check carries "concrete search
patterns, regexes, and false-positive carve-outs". Measured: **53/53** carry `**Severity**`,
**29/53** carry `**How to check**`, the file contains **0** `grep`/`rg` invocations and 5
regex-looking lines in 1 091. Detection is stated as prose bullets naming API symbols
(`AVCaptureDevice` → `NSCameraUsageDescription`). Carve-outs are **not** a per-check field: they
live in a global "false positive prevention" block at `SKILL.md:149-184` plus a handful inline
(`checks.md:469, 756, 847`). **Consequence for the plan:** FR-008 requires machine-readable
detection patterns, and no source ships any — they must be authored, not derived.

- `references/checks.md` (1 091 lines) — the 53 checks
- `references/privacy-keys.md` (89) — complete API→`NS*UsageDescription` mapping (**34 keys**:
  33 `NS*` + 1 `NFC*`) plus the **privacy-manifest reason-code tables**
  (`CA92.1`, `DDA9.1`, `35F9.1`, `E174.1`, `3EC4.1`…)
- `references/recommendations.md` (311) — R1–R14 quality signals, incl. the **SDK → App Store
  Connect privacy-nutrition-label mapping table** and the **external-verification checklist**
  (things code review *cannot* prove: live URLs, deployed Firestore rules, APNs key validity,
  AASA file correctness, IAP product status)
- `references/approval-guide.md` (441) — ASO/metadata, review notes, appeal + escalation path,
  submission timing, top-5 rejection reasons with 2024 volume data (7.77M submissions,
  1.93M rejections, 2.1 App Completeness ≈40%)
- `evals/evals.json` + `evals/trigger-eval.json` — the only source shipping an **eval harness**

Distinctive checks found nowhere else: export compliance `ITSAppUsesNonExemptEncryption` (2.17),
GPL/LGPL dependency scan (2.36), Apple trademark in bundle ID (2.37), URL-scheme collision with
Apple reserved schemes + `prefs:root=` (2.30), App Group ID mismatch across targets (2.23),
Firebase security-rules scan (2.42), binary-size estimation (2.40), hardcoded prices vs
`displayPrice` (2.38), availability-check gaps vs deployment target (2.31).

### cruisediary — the *evidence base*
31 micro-skills across 7 categories + 5 agents, all on a rigid repeated template
(Purpose / Apple Guideline / **Real-World Rejection Cases** / Trigger / Inputs / Actions /
Output Format / Constraints / Quick Commands / Detection Steps).

Its unique asset: **88 documented real rejection cases**, each with a source URL and a
root-cause explanation. Examples:
- ITMS-91053 fired because *Firebase Performance* internally calls `mach_absolute_time` — the
  app must declare `NSPrivacyAccessedAPICategorySystemBootTime` even though app code never
  calls it
- "Deactivate Account" rejected as not-deletion
- Sign in with Apple deletion rejected for not calling Apple's **token revocation endpoint**
  (Apple TN3194)
- ATT dialog re-prompting on every launch after update, caused by prior binary's tracking
  metadata

Also unique: the **`shared_context` pattern** — the full-audit agent collects project files
*once* in Phase 1 and passes them to all 31 skills, which skip their own Phase 1. That is the
right answer to the context-cost problem of running many checks.

Also unique: **12 Swift `Bad*`/`Good*` pattern files** (`examples/swift/`) — compilable
anti-pattern/fix pairs per guideline. And genuine **layout/HIG coverage** (iPad size classes,
safe area / Dynamic Island, Dynamic Type, orientation) that no other source has.

Severity vocabulary: 🔴 CRITICAL / 🟠 HIGH / 🟡 MEDIUM / 🟢 LOW.

### devsemih — the *source of truth* + cross-platform reach
- `references/guidelines-summary.md` (753 lines) — a near-**verbatim scrape of Apple's official
  guidelines page**, sections 1–5, including the `![ASR & NR]` notarization markers. This is the
  citation substrate: the thing to quote when reporting a violation.
- `references/play-policy-summary.md` (465) — **Google Play Developer Program Policies**,
  8 sections. Nothing else in the corpus covers Android at all.
- `skills/appstore-review/SKILL.md` (466) — the widest **framework matrix**: native Swift/ObjC,
  Flutter, React Native, Expo, KMP, .NET MAUI, Cordova/Ionic, Capacitor, Unity — each with
  detection markers and per-framework config-file locations. Includes real Expo subtleties
  (managed workflow has no `ios/`; `expo.plugins` inject permissions at build time;
  `eas.json` production profile must not set `developmentClient`).
  *The table has 9 rows, but 9 is not the count of cross-platform frameworks: one row is
  **Native Swift/ObjC**, which is the in-scope case, and **Cordova/Ionic** is a single row.
  The table therefore names **8 cross-platform families**. Anything deriving an
  out-of-scope list from this table should count 8, not 9.*
- Only source that walks guidelines **exhaustively by number** (2.5.11 → 2.5.18, 4.7.1 → 4.7.5,
  5.1.2(i) → 5.1.2(vii)) rather than by curated check list.
- Only source declaring skill frontmatter with `context: fork` + `agent: general-purpose`.

Guidelines version: **February 6, 2026**.

### safaiyeh — the *current rulebook*
Five rule files mirroring guideline sections 1–5 (3 533 lines), each rule as a checkbox list
with paired Swift *and* React Native/Expo code samples.

Its unique asset: it is **the most current**, and the only source tracking post-June policy
change: guidelines current through **Apple's June 8, 2026 update**, verified 2026-08-29, plus:
- social-media age-rating questions **mandatory from September 2026** (Social Media descriptor +
  Time Allowances category)
- **Republic of Korea** GRAC RCN override; Oct 2026 descriptor reclassification to 12+
- **Brazil** CADE agreement (June 2026, iOS 26.5+) — external payments + alternative marketplaces
- **EU** terms effective Oct 1, 2026 — Core Technology Fee replaced by 5% Core Technology
  Commission
- current **App Review test devices: iPad Air 11-inch (M3) and iPhone 17 Pro Max** (Aug 2026)
- 4.3(b) category-saturation language and 1.2 developer-responsibility/remediation-plan language
- 4.8 restated correctly: the requirement is *a login meeting three criteria*, Sign in with Apple
  is merely the simplest option — not "Sign in with Apple is mandatory"

Also unique: a **structured skill-feedback protocol** at `SKILL.md:194-232` — **11 categories**
in 4 groups (*Accuracy:* false positive, false negative, wrong citation, outdated · *Usefulness:*
too noisy, not actionable, bad fix · *Coverage:* missing rule, contradiction · *Behavior:*
trigger/weight, unclear) with hard consent rules — never send user code, ask first, show the
draft, one offer per session. That taxonomy is directly reusable as our own finding-quality
vocabulary. *(Corrected: this entry previously said "9 categories" while listing 11.)*

---

## 2. Coverage matrix

`●` primary/deep · `○` present · `–` absent

| Area | justinperea | cruisediary | devsemih | safaiyeh |
|---|:--:|:--:|:--:|:--:|
| Verbatim Apple guideline text | – | – | ● | ○ |
| Numbered check definitions (prose, not regex) | ● | ○ | ○ | – |
| Real rejection cases w/ sources | ○ | ● (88) | – | – |
| Privacy manifest / reason codes | ● | ● | ○ | ○ |
| `NS*UsageDescription` full map | ● (34) | ○ | ○ (15) | ○ |
| Layout / HIG (iPad, Dynamic Type, safe area) | ○ | ● | ○ | ○ |
| Metadata / ASO / screenshots | ● | ● | ○ | ○ |
| Review notes + appeal process | ● | ○ | – | – |
| Cross-platform frameworks | – | ○ | ● (9) | ○ (RN/Expo) |
| React Native / Expo code samples | – | – | ○ | ● |
| Swift Bad/Good pattern files | – | ● (12) | – | ○ |
| Google Play policies | – | – | ● | – |
| 2026 regional policy deltas (EU/BR/KR) | – | – | – | ● |
| Multi-target / extension awareness | ● | – | ○ | – |
| Eval harness | ● | – | – | – |
| Shared-context orchestration | – | ● | – | – |
| Feedback / self-improvement loop | – | ○ | – | ● |
| Severity model | BLOCKER/WARN/INFO | 🔴🟠🟡🟢 | CRITICAL/WARNING + verdict | CRITICAL/HIGH/MEDIUM |
| Triggering evals (should / should-not) | ● | – | – | – |

---

## 3. Conflicts and contradictions to resolve

> **Status after the spec interview (2026-09-03).** Every claim below was checked by
> fact-finders; the corrections are inline. The *framing* of this section is also
> superseded: [ADR-0002](../docs/adr/0002-check-apples-live-guidelines-at-audit-time.md)
> decided that Apple's live published guidelines are fetched at audit time, so ranking these
> four snapshots against each other is no longer how the auditor decides what a rule says.
> The list below is retained as the derivation record — what each source got wrong and why —
> not as a set of open decisions.

1. ~~**Guidelines vintage.**~~ **Resolved by ADR-0002.** devsemih = Feb 6 2026;
   safaiyeh = Jun 8 2026 (+ Aug 29 verification). The verbatim text is *older* than the
   current-policy layer, so merging naively yields a document that contradicts itself on
   EU/Brazil payments and age ratings. The auditor now fetches Apple's live text instead of
   picking between snapshots, which removes the staleness at its root.

2. **4.8 Sign in with Apple.** justinperea and cruisediary state it as "third-party login ⇒ Sign
   in with Apple is required" (BLOCKER). safaiyeh and Apple's actual text state the requirement
   is *a login service meeting three criteria*, of which SIWA is one. The strict reading
   generates false positives against apps that offer compliant email-only login.

3. **Severity scales.** Four different vocabularies (see matrix). Also different semantics:
   justinperea's BLOCKER = "will definitely be rejected"; cruisediary's 🔴 = "reject almost
   certain"; these are not the same bar.

4. **Privacy manifest reason codes.** *(Corrected — the conflict is real, but this entry
   originally mis-stated one side.)* cruisediary maps `identifierForVendor` →
   `NSPrivacyAccessedAPICategoryDeviceID` reason `3EC4.1`. justinperea maps `3EC4.1` →
   "Customizing UI based on active keyboards" — it **never names a category**, and the
   category `NSPrivacyAccessedAPICategoryActiveKeyboards` asserted here may not exist in
   Apple's taxonomy at all. Same reason code, two incompatible use cases. **At least one is
   wrong**, and neither is verified against Apple.

5. **Extension privacy manifests.** justinperea explicitly upgrades this to BLOCKER (ITMS-91053
   is per-target and automated). No other source treats extensions as separate targets at all.
   justinperea is right and this is the single most valuable correction in the corpus.

6. **`UIWebView`.** Treated as hard BLOCKER (ITMS-90809) by justinperea/cruisediary. Given
   current SDKs this is close to extinct; risk of dead-weight checks.

7. ~~**Parental gate.**~~ **Retracted — this was never a conflict.** safaiyeh's
   "date-of-birth is trivially bypassable" targets the **Kids Category parental gate**
   (Guideline 1.3), which gates links, purchases and distractions away from children.
   devsemih's date-of-birth check targets **creator-content age restriction**
   (Guideline 1.2.1(a)), where Apple explicitly permits "verified or declared age". Two
   different mechanisms under two different guidelines. Flagging them as opposed was an
   error in this document, caught by a fact-finder.

8. **Guideline numbering drift.** cruisediary cites `2.5.10 — Current SDK` and
   `4.5.5 — Push Notifications`; Apple's current text has 2.5.10 *intentionally omitted* and push
   at 4.5.4. Citations must be validated against the verbatim text, not copied.

---

## 4. Reusable techniques worth carrying forward

- **`shared_context` single-pass collection** (cruisediary) — collect Info.plist, pbxproj,
  entitlements, source paths, privacy manifest once; all checks consume it.
- **Systematic `PBXNativeTarget` enumeration** (justinperea) — every target is a separate app
  from Apple's validation perspective; per-target Info.plist, entitlements, privacy manifest.
- **False-positive carve-outs as first-class content** (justinperea) — `#if DEBUG` doesn't ship;
  Firebase/Maps client keys are meant to be in the binary; `aps-environment: development` is
  normal pre-distribution; Apple's private-API scanner matches *selector names not intent*, so
  a developer's own `hide:` can false-positive.
- **Root-caused rejection cases with source URLs** (cruisediary) — grounding that measurably
  reduces hallucinated rules.
- **Bad/Good compilable pattern pairs** (cruisediary) — the fix is shown, not described.
- **Split "what the rule says" from "how to check it"** (devsemih) — reference doc is the source
  of truth; skill body is detection procedure. Keeps citations honest.
- **External-verification checklist** (justinperea R13) — explicit boundary between what static
  analysis can prove and what the developer must confirm out-of-band. Prevents both false
  confidence and false alarms.
- **Structured feedback taxonomy** (safaiyeh) — 11 named failure modes for the checker itself.
  *(Corrected: this line previously said 9, contradicting the count in section 1.)*
- **Readiness verdict as the first line** (justinperea) — single actionable answer before detail.
- **Functional evals** (justinperea, `evals/evals.json`) — including negative assertions
  (`no-false-blocker`: must NOT flag Firebase client keys).
- **Triggering evals** (justinperea, `evals/trigger-eval.json`) — `{query, should_trigger}`
  pairs written as long, concrete, realistic user prompts. This is a separate asset from the
  functional evals above and tests a different thing: whether the skill *loads* at all.
  Anthropic's authoring guidance names triggering the first of three test areas, and
  under/over-triggering the two failure modes a description is tuned against.

---

## 5. Known gaps across all four

Nothing in the corpus covers:
- visionOS / watchOS / tvOS-specific review rules (safaiyeh mentions the platforms, no rules)
- App Store Connect API integration to read actual submission state
- Verifying the app against its *own* declared privacy nutrition labels
- Localization completeness as a rejection vector (only justinperea R12, as advice)
- Accessibility as a *rejection* vector vs a quality signal
- Any machine-readable finding schema (all four emit prose markdown)
- Deterministic scripting — every check is model-executed grep; nothing is a script with
  reproducible output

---

## 6. Licensing

All four are MIT (`LICENSE` present in each). Derivative work with attribution is fine;
attribution must be carried into the merged plugin.
