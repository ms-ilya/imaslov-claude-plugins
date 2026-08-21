# Swift layer: what to ground in

**Loaded only when the stack detects as Swift.** On any other repo this file is
never read and none of its vocabulary appears anywhere — no questions about
state ownership on a Go service, no `@Observable` in a pipeline spec.

This layer shapes **what grounding goes looking for**, so it is loaded before the
fact-finders are dispatched, never after. It adds no rules of its own about how
code should be written; it names the things that, on this platform, are cheaper
to look up than to ask about.

Every answer is a **fact with a citation** — "`DraftStore` is an `@Observable`
held in `@State` by `ComposeView`", at `path:line`. "It uses SwiftUI state" is a
summary of a fact, not one, and the interview cannot build on it.

## Contents

- [What to look up first](#what-to-look-up-first) — six questions, each an interview slot saved
- [Reach and permission](#reach-and-permission) · [Concurrency facts](#concurrency-facts-worth-one-lookup) · [Test seams](#test-seams) — the lookup; `seams.md` has what to do with it
- [How to ask for these](#how-to-ask-for-these) · [What this layer must not do](#what-this-layer-must-not-do) · [Dormancy](#dormancy)

## What to look up first

Each collapses a question that would otherwise cost an interview slot.

### 1. What is the platform floor?

**Look for:** the deployment target in the project file or `Package.swift`, and
whether the target builds in Swift 6 language mode or Swift 5 with minimal
concurrency checking.

**Why it earns a slot:** it decides which of everything below is even available.
`@Observable` and `SwiftData` need iOS 17; `NavigationStack` needs iOS 16. A spec
assuming one of them on a lower floor is unimplementable, and gets found in review
rather than planning. The language mode decides whether the concurrency facts
below are load-bearing or merely advisory.

### 2. Who owns the state this feature touches?

**Look for:** `@State`, `@StateObject`, `@Observable` types held in `@State`,
`@Environment`, a singleton, an actor.

**Why it earns a slot:** ownership decides where the feature's code goes, and most
often makes a proposed design impossible — a feature that must mutate state owned
two screens up is a different feature. Report the owner **and its isolation**.

### 3. What persists, and where?

**Look for:** `SwiftData`, `CoreData`, `UserDefaults`, the keychain, files on
disk, or a server holding the source of truth.

**Why it earns a slot:** question 2 answers what holds the state while the app
runs; this answers what survives relaunch, and they are rarely the same store. It
decides whether the feature needs a migration, what it shows before data arrives
and what it does offline — requirements the moment they are known, open questions
when they are not.

### 4. What is the navigation pattern?

**Look for:** `NavigationStack` with a path binding, `NavigationSplitView`,
sheets presented by `item:`, a coordinator type, `UINavigationController`.

**Why it earns a slot:** it decides whether a new screen is a value appended to a
path or an object constructed by a parent — which changes what the feature can be
handed and what it must look up for itself.

### 5. How do sibling features handle errors and loading?

**Look for:** the nearest analogous screen or service, and what it does with a
failure — an alert, an inline banner, a retry, a silent log.

**Why it earns a slot:** the failure surface is a coverage category, and a repo
almost always has an answer already. Asking the user to invent one when three
siblings agree is the clearest case of asking what could be looked up.

### 6. What are these things already called?

**Look for:** the nouns in the types, the properties and the test names.

**Why it earns a slot:** a spec renaming the project's `Credential` to `AuthToken`
has invented a synonym nobody asked for, and the glossary now carries two entries
for one thing.

## Reach and permission

Two lookups that decide how big the feature actually is. Both are read, never asked.

| Look up | Because |
|---|---|
| Entitlements and the app's property list — camera, notifications, background modes, health data | A capability the app does not already hold turns a screen into a permission flow, a denied state and a deep-link to settings. Three requirements the spec would otherwise miss |
| Which module the feature lands in — the app target, a local package, an extension or a widget | An extension is a separate process with its own lifetime and no access to the app's memory. Shared state crosses an app group or it does not cross at all |

## Concurrency facts worth one lookup

Swift 6 isolation is where a plausible-sounding spec turns out to be
unimplementable. Three facts are cheap to establish, expensive to get wrong, and
all moot if question 1 says the target is not in Swift 6 mode.

| Look up | Because |
|---|---|
| Is the type an `actor`, `@MainActor`, or neither? | It decides whether the feature's work needs a hop, and hops are observable in the UI |
| Does the feature need to survive a suspension point? | An actor lets other calls interleave at every `await`; state read before one may be stale after it |
| Is there existing in-flight-work deduplication? | Storing a `Task` to dedupe is a shape the repo either already has or does not |

Report these as facts, never as advice. The layer names what to look up; it does
not tell the project how to write Swift.

## Test seams

**Where the seam already is, is a grounding fact:** a protocol the production type
conforms to, an initialiser taking a dependency, an existing fake in the test
target. Look it up here — with the framework the test target uses — and see
`seams.md` for what to do with the answer.

## How to ask for these

The fact-finder answers a numbered list and returns a fixed schema. Ask for one
fact per question, in the repo's own nouns:

- "Which type owns the state that `<feature noun>` mutates, and is it an `actor`,
  `@MainActor`, or neither?"
- "What is the deployment target, and does the target build in Swift 6 language
  mode?"
- "Where does `<noun>` persist between launches, and in which store?"
- "What does `<nearest sibling screen>` do when its load fails?"

"Describe the architecture" is not one of these. It returns a paragraph, and a
paragraph is not a fact.

## What this layer must not do

- **No opinions about architecture.** If the repo uses a pattern this layer would
  not have chosen, that is not a finding. The plugin enforces the project's
  stated rules, never its own taste.
- **No questions where the feature has no Swift surface.** A build-script change
  in a Swift project needs no state-ownership grounding — on a correctly scoped
  detection this layer never loaded for it.
- **No new vocabulary.** Every term reported here comes from the code.

## Dormancy

Detection is on **content**: a `.swift` file, a `Package.swift`, an `.xcodeproj`
or an `.xcworkspace`, within the feature's scope. Nothing else turns this layer
on — not a project name, not a mention in the user's idea, not a README.

When it is off it is fully off. The generic questions stand on their own, and the
absence of this layer must not be visible in the output: no apology for missing
platform intelligence, no hedged question about "your platform's equivalent of
state ownership". A pipeline spec should read as though this file did not exist.
