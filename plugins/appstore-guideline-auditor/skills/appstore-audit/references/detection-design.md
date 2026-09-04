# ABOUTME: Detection guidance and non-compliant/compliant pairs for the design rule category (Apple section 4).

Loaded by the `design` subagent. One section per rule, keyed by the rule's
`guidance` slug.

This category contains the catalogue's most dangerous false positive. Read
`login-service-equivalent-option-absent` before emitting anything from it.

## login-service-equivalent-option-absent

**Two of the four upstream sources state this rule wrongly, and the wrong
version generates false positives against compliant apps.**

What Apple's text actually says: an app using a third-party or social login must
*also offer as an equivalent option* another login service that

1. limits data collection to the user's name and email address,
2. allows the user to keep the email address private, and
3. does not collect interactions with the app for advertising without consent.

Sign in with Apple meets all three. So can an email-and-password login. So can
several others. The requirement is the three criteria — not the brand.

**Therefore: the absence of `ASAuthorizationAppleIDProvider` is not a finding.**
It is one input. Before emitting, establish that no *other* login meeting the
three criteria exists. Look for email sign-in, magic links, phone sign-in, and
read what they collect.

```swift
// Non-compliant — social login is the only option
Button("Continue with Google") { GIDSignIn.sharedInstance.signIn() }

// Compliant — no Sign in with Apple anywhere, and no finding
Button("Continue with email") { EmailAuth.signIn(collecting: [.name, .email]) }
Button("Continue with Google") { GIDSignIn.sharedInstance.signIn() }
```

Grade PROBABLE and state in `unconfirmed` what you could not verify about the
alternative login's data collection. When a compliant alternative exists, emit
nothing at all.

## minimum-functionality-web-wrapper

The rejection shape is a `WKWebView` loading a remote URL **as the app's root
interface**. A web view for one screen — help, checkout, a terms page — is
normal and must not fire.

Confirm what the root actually presents: the `App` scene's root view, or the
window's `rootViewController`. If you cannot establish that the web view is the
root, that is exactly what `unconfirmed` is for.

**Do not fire when** the app has native navigation, native screens and local
data, with web content inside one of them.

## push-entitlement-unused

`aps-environment` present in the entitlements file, `registerForRemoteNotifications`
absent from source. Grades PROVEN — the entitlement is at a specific line in a
specific file.

**This is the catalogue's canonical two-resolution finding.** Both are valid and
which is right depends on intent you cannot read:

- remove the entitlement and the Push Notifications capability, or
- call `registerForRemoteNotifications` and implement the delegate callbacks.

Print both. Choosing one silently is the defect this rule exists to demonstrate.

**Do not fire when** the value is `development` and the target is not being
prepared for distribution — though say so rather than staying silent, since
`aps-environment: development` in a release build is its own problem.

## push-required-to-function

Onboarding that will not continue until push permission is granted. The pattern
is a `requestAuthorization` completion whose non-granted branch returns, exits or
dismisses instead of proceeding.

```swift
// Non-compliant — the app is unusable if the user declines
center.requestAuthorization(options: [.alert]) { granted, _ in
    guard granted else { return }   // nothing else happens, ever
    self.showMainScreen()
}

// Compliant — permission changes what happens, not whether it happens
center.requestAuthorization(options: [.alert]) { _, _ in
    self.showMainScreen()
}
```

## push-marketing-without-optin

Promotional push with no in-app opt-out separate from transactional messages.
Look for campaign or marketing vocabulary in notification code, and for the
absence of a notification-preferences surface.

Grade PROBABLE — whether a notification is promotional is a judgement about
content, and the symbol name is a proxy for it.

## apple-trademark-in-bundle-id

An Apple mark as a **component** of the bundle identifier or display name.

Match component boundaries, not substrings. `com.pineapple.notes` contains
"apple" and is fine. `com.example.iphonetools` is a component containing
"iphone" and is not.

## spam-duplicate-bundle-ids

MANUAL. Whether the developer account ships near-identical apps is a fact about
the account, not the repository. No scan of one project can see it.

Show this item when the scan found location, team or franchise vocabulary in the
bundle identifier or display name — that is the shape 4.3(a) targets — and say
so in `found_because`.

## age-rating-questionnaire-unanswered

MANUAL, **unconditional**, and **dated**: Apple requires responses to the updated
age-rating questionnaire, Time Allowances included, from every new app and every
update submitted from September 2026.

It is unconditional because Apple's requirement is. An earlier version of this
catalogue showed the item only where social vocabulary appeared, which quietly
turned a rule about every submission into a rule about social apps — the
requirement was reported to the apps least likely to be surprised by it and
withheld from everyone else.

Carries `applies_to.effective`, so it is verified against the **policy sources**,
not the guidelines page — the guidelines page does not mention it. On a run where
the policy sources were not retrieved, this item's citation state is
`unverified`, and the report must say so rather than presenting the date as
confirmed. It carries no guideline anchor: the requirement is announced through
Apple's policy channel and App Store Connect, not through a numbered clause.

Omit `found_because`. Nothing found it; it always applies.

## age-rating-social-descriptor

MANUAL, and conditional on the app actually having user-to-user surfaces. It sits
alongside the unconditional questionnaire item above and answers a narrower
question: the Social Media descriptor specifically, which is the answer developers
most often get wrong.

**Match symbols, not substrings.** The pattern names user-to-user surfaces —
`sendMessage`, `followUser`, `postComment`, `userProfile` — and is anchored on
word boundaries. The previous substring pattern matched `chat|message|follow(ers|ing)|feed|comment`
anywhere in a Swift file, and on a live audit it hit 16 files of which every
single one was incidental: `errorMessage`, `statusMessage`, WebRTC signalling
payloads named `message`, `followDistance`, and a comment about a grid following
head inertia.

That run ended correctly — the subagent suppressed the item — and that is the
problem this section exists to fix. The catalogue matched and a judgement
overrode it, leaving no record and no guarantee the next run decides the same
way. A carve-out written down is reproducible; a carve-out improvised is not.
Where a symbol matches and it is plainly transport, geometry or diagnostics
rather than a social surface, the clause's `note` is what authorises not
emitting, and `found_because` names the symbol that did match so the developer
can see whether you read it correctly.

## streaming-game-catalogue-rules

MANUAL. Mini apps, mini games, chatbots, plug-ins and emulators may be offered
only under 4.7's conditions, and whether the remote catalogue meets them depends
on what it serves at review time.

Show it when the scan found emulator, mini-app or plug-in vocabulary, and name
what it found. The developer needs to know which symbol triggered it, because
the answer is often "that is not what this is".
