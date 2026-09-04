# ABOUTME: Detection guidance and non-compliant/compliant pairs for the safety rule category (Apple section 1).

Loaded by the `safety` subagent. One section per rule, keyed by the rule's
`guidance` slug.

Most of Apple's section 1 is about what content *means*, which a matcher cannot
decide. The rules here are the subset with a structural signal: a feature that
exists without the safeguard the guideline requires beside it. Judging whether a
string is offensive is not in this catalogue, deliberately — it is in the
derivation record as not adopted, with that as the reason.

## ugc-no-report-mechanism

The four UGC capabilities Apple names are filtering, reporting, blocking, and
acting on reports. Reporting is the one most often absent.

Establish UGC first: posting, uploading, commenting, messaging, publishing.
Then look for report or flag vocabulary anywhere in the sources.

Grade PROBABLE. Reporting may be server-side, may be spelled `abuseReport`, or
may live in a web view. Say which of those you could not rule out.

```swift
// Non-compliant — content is published with no way to report it
struct PostView: View { var body: some View { Text(post.body) } }

// Compliant
struct PostView: View {
  var body: some View {
    Text(post.body)
      .contextMenu { Button("Report", role: .destructive) { reportContent(post.id) } }
  }
}
```

## ugc-no-block-user

User-to-user interaction — following, messaging, profiles, comments — with no
block or mute capability. Reviewers test this one directly by trying to block
someone.

Blocking must hide the blocked user's content, not only stop notifications. When
you find a block symbol but no filtering of blocked content, that is worth
saying in `unconfirmed`.

## ugc-no-content-filtering

Filtering happens **before** publication. Reporting is the after-the-fact half,
and Apple requires both.

Look for moderation vocabulary, `SensitiveContentAnalysis`, profanity filtering,
or a server moderation call in the publish path.

**Do not fire when** moderation is plainly server-side — but say in the finding
that the client shows no evidence of it, because that is what a reviewer sees
too, and it is worth putting in review notes.

## ugc-terms-not-accepted

Publishing without accepting terms stating a no-tolerance policy for
objectionable content. Look for terms acceptance in the sign-up or first-publish
path.

Grade PROBABLE — acceptance may be handled by a web onboarding flow.

## creator-content-age-restriction

Creator-content platforms must let users identify content above the app's age
rating and restrict access by **verified or declared** age.

Note the difference from the Kids Category gate: declared age is explicitly
permitted here. A date-of-birth picker satisfies 1.2.1 and does **not** satisfy
1.3. Two upstream sources were once read as disagreeing about this; they were
describing two different mechanisms under two different guidelines.

## kids-category-third-party-analytics

Kids Category apps may not include third-party analytics or advertising, and may
not send device information to third parties. This is enforced strictly.

**Kids Category membership is an App Store Connect setting.** Child-directed
vocabulary in the source is a signal, not proof, so this rule is PROBABLE by
construction. Say in `unconfirmed` that Kids Category membership could not be
confirmed from the repository — and mean it: if the app is not in the category,
there is no finding at all.

## kids-category-external-link-ungated

Outbound links and purchases must sit behind a parental gate.

The gate must be one a child cannot pass. A date-of-birth field does not
qualify — a child can answer it — which is exactly why 1.3 and 1.2.1 differ.
Arithmetic, a timed gesture or a press-and-hold are the accepted shapes.

## medical-claims-unsubstantiated

MANUAL. Whether a health claim is substantiated is a regulatory question about
the world, not a fact about the code.

Show it when the scan found diagnostic or measurement vocabulary, and name what
it found. The resolution is to state the methodology and its limits, and to have
regulatory clearance ready — both things the developer does outside the repo.

## healthkit-data-to-advertising

`HKHealthStore` together with an advertising or attribution SDK. Apple treats
health data reaching advertising as a removal ground rather than a rejection.

Both can legitimately exist in one app for unrelated features, so grade
PROBABLE and say that you could not confirm the data paths join. What the
developer needs is a prompt to check, and a note for review notes.

## live-payment-secret-in-binary

A **live server-side** secret shipped in the app. Grades PROVEN.

The formats worth matching: `sk_live_` / `rk_live_` (Stripe), `AKIA…` (AWS
access key id), `-----BEGIN … PRIVATE KEY-----`.

**The carve-out is the whole point of this rule's narrowness.** Client-side keys
designed to be public are not findings:

- Firebase's `API_KEY` in `GoogleService-Info.plist` — public by design, access
  is controlled by Firebase security rules, not by key secrecy
- a Google Maps key restricted to the bundle identifier
- any publishable key (`pk_live_`, `pk_test_`)

Flagging one of those is the most damaging thing this catalogue can do. It is
the documented false positive that the eval suite asserts against, and it costs
more than a missed finding, because it teaches the developer that the tool cries
wolf and everything after it gets skipped.

A matched key must be treated as compromised: rotation belongs in the
resolution alongside moving it server-side.

## emergency-services-reliance

MANUAL. Whether the app presents itself as a substitute for emergency services
is a judgement about presentation across screens and store metadata.

Show it when emergency or SOS vocabulary appears. The resolution is a disclaimer
wherever the feature surfaces — cheap to add, and the rejection is expensive.

## developer-contact-information-absent

MANUAL and **unconditional**. 1.5 requires a support URL carrying current
contact information for every app there is, so this item has no applicability
condition to meet and carries no `found_because`.

It is here because the checklist's bar is "no code scan can decide it", not "a
pattern matched". A requirement that applies to every submission and is
invisible to every scan is exactly what the checklist is for, and it costs one
line. The reason to keep such items rare is that a checklist listing everything
is one people skip — so this is the only unconditional item in this category,
and it earns the slot by applying to literally every app.
