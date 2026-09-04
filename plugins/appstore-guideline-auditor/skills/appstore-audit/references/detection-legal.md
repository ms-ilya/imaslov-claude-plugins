# ABOUTME: Detection guidance and non-compliant/compliant pairs for the legal rule category (Apple section 5).

Loaded by the `legal` subagent. One section per rule, keyed by the rule's
`guidance` slug. Read the section for a rule before emitting a finding from it.

This category carries the highest-frequency automated rejections in the whole
catalogue. ITMS-91053 is issued by a scanner, per target, before a human sees
the app — which means these are the findings most worth being right about, and
the ones where being wrong is cheapest to check.

## privacy-manifest-absent

The manifest must exist **and** be in the target's Copy Bundle Resources. A file
present on disk but not in the build phase does not ship, and the scanner sees
the built product.

Confirm from `context.json`: the target's `privacy_manifest` is null. Report
against the target's own `Info.plist` path with `absence: true` — there is no
line to point at, and inventing one is worse than omitting it.

**Do not fire when** the target is a framework, a static library or a test
target. The context collector already excludes these from `shipping_targets`;
if you are looking at one, you are reading the wrong file.

## privacy-manifest-extension-missing

The same requirement, stated separately because it is the one every source but
justinperea misses. A widget, share extension or notification service is a
separate product from Apple's side. The app target's manifest does not cover it.

Confirm the target's `kind` is `app-extension` and its `privacy_manifest` is
null. Where the app target has a manifest and the extension does not, say so —
that pairing is the strongest signal that the omission was an oversight rather
than a decision.

## required-reason-api-undeclared

Five categories, each with approved reason codes:

| API surface | Category | Common reason |
|---|---|---|
| `UserDefaults` | `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1`, or `1C8F.1` via App Groups |
| `mach_absolute_time`, `systemUptime` | `NSPrivacyAccessedAPICategorySystemBootTime` | `35F9.1` |
| `volumeAvailableCapacity` | `NSPrivacyAccessedAPICategoryDiskSpace` | `E174.1` |
| `contentModificationDate`, `creationDate` | `NSPrivacyAccessedAPICategoryFileTimestamp` | `C617.1` |
| `activeInputModes` | `NSPrivacyAccessedAPICategoryActiveKeyboards` | `3EC4.1` |

**There are exactly five.** `NSPrivacyAccessedAPICategoryDeviceID` does not
exist. One upstream source asserts it for `identifierForVendor` and states
outright that it is "the correct category"; it is not, `identifierForVendor` is
not a required-reason API at all, and the rule records both statements so the
error is visible rather than inherited.

Grade PROBABLE, not PROVEN, unless you have read the manifest and confirmed the
category is absent from it. The call site proves the API is used; it does not
prove the declaration is missing.

**The call may not be in first-party code.** Firebase Performance calls
`mach_absolute_time` internally, and the app is still responsible. When the
symbol does not appear in the sources but a dependency on the list is present,
say that in `unconfirmed`.

## usage-description-missing

Correlate two inputs: a protected API in Swift, and the matching key absent from
that target's `Info.plist`. The context gives you `info_plist_keys` per target,
so the second half needs no file read.

The evidence is **the call site**, not the plist. The developer needs the line
that will crash.

| API | Key |
|---|---|
| `AVCaptureDevice`, `AVCaptureSession` | `NSCameraUsageDescription` |
| `AVAudioRecorder`, `requestRecordPermission` | `NSMicrophoneUsageDescription` |
| `PHPhotoLibrary`, `PHAsset` | `NSPhotoLibraryUsageDescription` |
| `CLLocationManager` (whenInUse) | `NSLocationWhenInUseUsageDescription` |
| `CLLocationManager` (always) | `NSLocationAlwaysAndWhenInUseUsageDescription` |
| `CNContactStore` | `NSContactsUsageDescription` |
| `EKEventStore` | `NSCalendarsFullAccessUsageDescription` (iOS 17+) |
| `CBCentralManager` | `NSBluetoothAlwaysUsageDescription` |
| `CMMotionManager`, `CMPedometer` | `NSMotionUsageDescription` |
| `SFSpeechRecognizer` | `NSSpeechRecognitionUsageDescription` |
| `HKHealthStore` (read) | `NSHealthShareUsageDescription` |
| `HKHealthStore` (write) | `NSHealthUpdateUsageDescription` |
| `LAContext` with biometrics | `NSFaceIDUsageDescription` |
| `ATTrackingManager` | `NSUserTrackingUsageDescription` |
| `NFCTagReaderSession` | `NFCReaderUsageDescription` |
| `MPMediaLibrary` | `NSAppleMusicUsageDescription` |
| `NWBrowser`, Bonjour | `NSLocalNetworkUsageDescription` |

**Do not fire when** the call is inside `#if DEBUG`, in a test target, or in a
file the context's `sources` list does not contain.

## usage-description-vague

Apple rejects strings that restate the permission instead of naming the feature.

```swift
// Non-compliant — says nothing the dialog title did not already say
<key>NSCameraUsageDescription</key>
<string>This app needs camera access</string>

// Compliant — names the feature and what breaks without it
<key>NSCameraUsageDescription</key>
<string>Scan a receipt to attach it to an expense you are filing.</string>
```

Two signals: under roughly 25 characters, or opening with "we need" / "this app
needs" / "required for". Both are heuristics — grade PROBABLE and quote the
string, so the reader can disagree in one glance.

## att-usage-description-missing

`ATTrackingManager` present, `NSUserTrackingUsageDescription` absent. This is a
clean two-input correlation and grades PROVEN with the call site as evidence.

Note that the consequence is not only rejection: without the string the prompt
never shows, so the app silently loses the IDFA it was asking for.

## att-prompt-at-launch

The request must come after the user has seen enough to answer it. The pattern
that fails is a request inside `application(_:didFinishLaunchingWithOptions:)`
or a root `.task` that runs before any screen renders.

Match on **proximity within a method body**, not co-occurrence in a file. A file
containing both a launch method and a tracking request elsewhere is normal.

**Do not fire when** the request follows an onboarding completion check.

## account-deletion-absent

Account creation present, deletion absent. Deletion must be reachable in-app;
a mailto: link or a website form does not satisfy it.

Grade PROBABLE. The absence of a `deleteAccount` symbol does not prove the app
has no deletion path — it may be spelled differently, or live behind a web view
— and saying so in `unconfirmed` is the difference between a finding and an
accusation.

**Do not fire when** the app only authenticates against accounts created
elsewhere. Confirm a sign-up path exists first.

## siwa-token-revocation-missing

Sign in with Apple plus a deletion flow, with no call to Apple's revocation
endpoint. Deleting the local record while leaving the Apple credential live is
treated as incomplete deletion.

The refresh token is needed to revoke, so an app that never stored one cannot
comply without a change at sign-in time as well. Say that in the resolution when
you see no token storage.

## sensitive-data-in-userdefaults

Match the **key name**, not the value: `UserDefaults` within a short distance of
`password`, `token`, `secret`, `apiKey`, `credential`.

**Do not fire when** the key is a count, a flag or a timestamp about a secret
rather than the secret — `hasStoredToken`, `tokenRefreshCount`. Quote the key so
this is checkable.

## third-party-sdk-privacy-manifest-missing

Apple publishes a list of commonly-used SDKs that must each ship a privacy
manifest and a signature. Match the dependency name in the package manifest.

Grade PROBABLE always: the package manifest names the dependency, not its
version's manifest contents. Say in `unconfirmed` that the SDK version's own
`PrivacyInfo.xcprivacy` was not inspected.

## privacy-policy-url-absent

MANUAL. The URL lives in App Store Connect and its reachability depends on a
live server. A URL string in source proves neither.

Show this item when the scan found account creation, network calls or any data
collection — which is nearly always, and that is correct: every app needs one.

## privacy-nutrition-labels-match-build

MANUAL. The scan can see which SDKs are linked; it cannot see what was declared.
Name the SDKs it found, so the developer has a list to check the labels against
rather than a reminder to think about it.

## export-compliance-undeclared

`ITSAppUsesNonExemptEncryption` absent from `Info.plist`. Grades PROVEN with
`absence: true` against the plist.

This rule carries **no Apple guideline anchor**, and that is deliberate — export
compliance is a US export-law requirement surfaced by App Store Connect, not a
clause in the App Review Guidelines. Report it with no guideline number rather
than attaching a plausible-looking one.

## app-transport-security-disabled

`NSAllowsArbitraryLoads` true. Grades PROVEN.

```xml
<!-- Non-compliant — every connection, for one legacy host -->
<key>NSAppTransportSecurity</key>
<dict><key>NSAllowsArbitraryLoads</key><true/></dict>

<!-- Compliant — scoped to the host that needs it -->
<key>NSAppTransportSecurity</key>
<dict><key>NSExceptionDomains</key><dict>
  <key>legacy.example.com</key>
  <dict><key>NSExceptionAllowsInsecureHTTPLoads</key><true/></dict>
</dict></dict>
```

`NSAllowsArbitraryLoadsInWebContent` is a different key and is legitimate for an
app that loads arbitrary user-supplied web pages. Do not fire on it.

## data-collection-without-consent

Analytics or advertising SDK initialised inside the launch path, before any
consent gate. Match proximity within the launch method.

**Do not fire when** the SDK is configured in a mode that buffers without
transmitting, or when a consent check precedes it in the same method. Both are
common and both are compliant.
