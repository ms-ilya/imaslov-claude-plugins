# ABOUTME: Detection guidance and non-compliant/compliant pairs for the performance rule category (Apple section 2).

Loaded by the `performance` subagent. One section per rule, keyed by the rule's
`guidance` slug.

App completeness is the largest single cause of App Store rejection by volume.
Most of this category is about a build that is not finished being submitted as
though it were.

## Contents

- Build and bundle: `launch-screen-absent`, `app-icon-incomplete`,
  `beta-or-placeholder-version`, `placeholder-content-shipping`
- Software requirements: `webview-deprecated-class`, `private-api-usage`,
  `arbitrary-code-download`, `availability-check-missing`,
  `facial-recognition-wrong-framework`
- Capabilities and identifiers: `background-mode-unjustified`,
  `app-group-identifier-mismatch`, `url-scheme-reserved-collision`,
  `hidden-or-dormant-feature`
- Devices and layout: `ipad-support-disabled`, `ipad-layout-fixed-dimensions`
- Networking: `hardcoded-ipv4-address`
- Capture and privacy: `recording-without-consent-indicator`
- Submission-time (MANUAL): `metadata-screenshots-accurate`,
  `metadata-name-keywords-accurate`, `metadata-whats-new-accurate`,
  `metadata-category-and-rating`, `review-account-credentials`

## launch-screen-absent

Neither `UILaunchScreen` nor `UILaunchStoryboardName` in the target's
`Info.plist`. Grades PROVEN with `absence: true`.

The symptom is an app letterboxed at a legacy resolution on modern devices,
which reads to a reviewer as an app that does not fill the screen.

An **empty** `UILaunchScreen` dictionary is valid and sufficient for a plain
background. Do not require a storyboard.

## app-icon-incomplete

No asset catalog, or no `ASSETCATALOG_COMPILER_APPICON_NAME` on the target.

Grade PROBABLE: the presence of a catalog does not prove the icon set inside it
is complete, and transparency — accepted by Xcode, rejected by App Store Connect
— cannot be seen without opening the PNG. Say which you could not check.

## beta-or-placeholder-version

`CFBundleShortVersionString` starting `0.` or containing beta/alpha/rc/dev, or a
display name containing beta/demo/staging. Grades PROVEN.

Demos, betas and trial versions belong on TestFlight. A `0.9-beta` version
string on an App Store submission is read as an unfinished app.

## placeholder-content-shipping

Placeholder text in a **user-visible string literal**: lorem ipsum, "Coming
soon", "TODO:", "not implemented".

**Do not fire on comments.** A `// TODO:` is not shipped content and matching it
produces exactly the noise that teaches developers to ignore the tool.

## webview-deprecated-class

`UIWebView`, including in XIBs and storyboards. Grades PROVEN.

Match the type name with boundaries — `WKWebViewConfiguration` must not fire.
The class was removed from the SDK and its presence is caught automatically as
ITMS-90809, including when it arrives through a dependency.

## private-api-usage

Apple's scanner matches **selector names, not intent**. That cuts both ways: a
private selector reached through a runtime string is still found, and a
developer's own method that happens to share a name with a private selector is
flagged although it is entirely legitimate.

So this is PROBABLE, always, and the finding must say which case it could not
distinguish. Before emitting, check whether the symbol resolves to app-owned
code; if it does, say so rather than staying silent — the scanner will still
match it, and renaming is the fix.

The stronger signal is a leading underscore inside a `NSSelectorFromString`,
`performSelector` or `valueForKey` string.

## arbitrary-code-download

Downloading or evaluating code that changes the app's features. `JSPatch`,
`dlopen`, dynamic class resolution from a server value.

**`evaluateJavaScript` against bundled, app-authored script is normal** and must
not fire. The concern is script fetched from a network. Confirm the source of
the script before emitting.

## availability-check-missing

An API newer than `IPHONEOS_DEPLOYMENT_TARGET` called with no `@available` or
`if #available` guard. Crashes on the older OS, and review tests more than one.

Only meaningful once you have found at least one symbol above the deployment
target. Absence of `@available` anywhere is not itself a finding.

## facial-recognition-wrong-framework

Face tracking APIs used for **authentication**. Apps authenticating by face must
use LocalAuthentication, not ARKit or raw capture.

Face tracking for an avatar, a filter or a measurement is legitimate. Confirm
the face data reaches a login path before emitting, and say so if you cannot.

## background-mode-unjustified

`UIBackgroundModes` declared with no corresponding implementation —
`allowsBackgroundLocationUpdates`, `AVAudioSession`, `beginBackgroundTask`,
`BGTaskScheduler`, `PKPushRegistry`.

Apple reads an unused background mode as an attempt to stay alive. Location is
the most commonly over-declared.

## app-group-identifier-mismatch

Two shipping targets declaring different `com.apple.security.application-groups`
values while sharing a container. The widget silently reads nothing and never
populates, which review sees as broken functionality.

This is a **cross-target** rule: compare the value across every shipping target,
and emit only when two disagree. A single target with one group is fine.

## url-scheme-reserved-collision

A `CFBundleURLTypes` scheme that the system owns — `http`, `mailto`, `tel`,
`sms`, `itms`, `prefs` — or a `prefs:root=` / `App-Prefs:` string in source.

`UIApplication.openSettingsURLString` is the public route to the app's own
settings and is the resolution for the second case.

## hidden-or-dormant-feature

A flag whose **name references App Review** — `isReviewMode`, `isAppleReviewer`,
`hideForReview`. Behaviour that changes when the reviewer is detected is grounds
for removal, not merely rejection.

**A generic feature flag is normal engineering and must not fire.** The signal is
the name, not the mechanism.

## ipad-support-disabled

`TARGETED_DEVICE_FAMILY` of `1`. A **suggestion**, not a blocker: Apple asks that
iPhone apps run on iPad "whenever possible", which is encouragement rather than
a rejection ground. Grading it critical would be the wrong-citation failure mode.

## ipad-layout-fixed-dimensions

Arithmetic against `UIScreen.main.bounds`, or literal device dimensions (375,
414, 390, 428, 768, 1024) in layout code.

Reading `UIScreen.main.bounds` once for a full-screen background is normal.
Positioning content by arithmetic against it is what breaks in Split View.

## hardcoded-ipv4-address

A literal IPv4 address used as an endpoint. Apple reviews on an IPv6-only
network, so the app fails there while working perfectly for the developer.

Exclude `127.0.0.1` and `0.0.0.0`. A version string like `1.2.3.4` in a non-URL
context is a false positive worth confirming before emitting.

## metadata-screenshots-accurate · metadata-name-keywords-accurate · metadata-whats-new-accurate · metadata-category-and-rating

All MANUAL, all App Store Connect state. These four are the metadata half of the
checklist. Each applies to every submission, so each shows unconditionally, and
`found_because` is omitted rather than invented.

Keep them separate rather than collapsing into one "check your metadata" item:
they are four different screens in App Store Connect and four different people
often own them.

## review-account-credentials

MANUAL, and the fastest avoidable rejection there is. An app behind a login must
give review a working account.

Show it when the scan found sign-in vocabulary. The resolution includes verifying
the credentials **on the day of submission** — expired demo accounts are the
common form of this failure, not missing ones.

## recording-without-consent-indicator

PROBABLE at best, and it must stay there. Two clauses have to hold: a capture
API is present, and no consent or indicator vocabulary is.

The distinction that decides this rule is **whether a record is made**, not
whether a capture API is called. An `AVCaptureVideoDataOutput` feeding frames to
Vision or ARKit and never writing them anywhere is a camera preview; 2.5.14 is
not about that. An `AVAssetWriter`, a movie file output, or a WebRTC video track
carrying the feed to another device makes a record that outlives the moment or
leaves the machine, and that is what needs consent and an indicator.

**Non-compliant** — a peer connection publishes the camera track, and nothing
in the project asks first or shows that it is happening:

```swift
let track = factory.videoTrack(with: source, trackId: "camera0")
peerConnection.add(track, streamIds: ["stream0"])
```

**Compliant** — consent precedes the capture and an indicator runs alongside it:

```swift
guard await consentStore.confirmStreamingConsent() else { return }
recordingIndicator.isHidden = false
peerConnection.add(track, streamIds: ["stream0"])
```

Say in `unconfirmed` what you could not see: usually whether the consent lives
in a screen the pattern does not name, or whether the track is ever actually
published. The system's own recording indicator does not satisfy this on its
own — Apple asks for the app to make it clear — but a finding here should not
claim the app has no indicator when what you established is that you found none.
