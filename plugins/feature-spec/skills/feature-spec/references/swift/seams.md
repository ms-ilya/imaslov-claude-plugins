# Swift layer: test seams

**Loaded only on a Swift repo.** Carried into drafting through the design record,
so the spec's verification section says something true about *this* codebase
rather than something generic about testing.

Verification is a coverage category, which means a spec nobody can prove was met
is a failure of this plugin specifically. This file exists so that the
verification section names a seam that already exists.

## Contents

- [Which test, at which level](#which-test-at-which-level) · [Seams](#seams) · [The SwiftUI case](#the-swiftui-case)
- [Protocol or concrete](#protocol-or-concrete) · [What gets faked](#what-gets-faked)
- [Concurrency in the verification section](#concurrency-in-the-verification-section) · [What this file must not do](#what-this-file-must-not-do)

## Which test, at which level

> **Procedure: put the test at the lowest level where the behaviour is
> observable.** Not the level where it is easiest to write.

| Level | Owns | Stops owning when |
|---|---|---|
| **Unit** | a decision — a computed value, a state transition, a policy | the assertion needs a view or a running app |
| **Integration** | two components agreeing — a store and its client, a decoder and its schema | the assertion needs a rendered hierarchy |
| **UI** | a journey a person takes, end to end | it duplicates a decision already covered below |

**A UI test asserting a computed value is a unit test wearing a costume** — it
boots the app, drives the interface and waits, to settle something a function
could answer directly. Write it once, at the top, to prove the journey connects —
and never to prove the arithmetic.

The reverse error is rarer and worse: a feature whose only risk is that two
screens do not connect, covered entirely by unit tests of each screen.

## Seams

> **Prefer the highest existing seam. The ideal number of new seams is one, and
> zero is better.**

A seam that already exists is one the codebase's own conventions already handle,
one the test target already fakes, and one nobody has to learn. Three questions,
in order:

1. **Does a protocol already exist here?** Conform the fake to it. Done.
2. **Does the type already take its dependency in an initialiser?** Pass a
   different one. Done.
3. **Only then:** introduce a seam — and introduce exactly one.

A feature that needs three new protocols to be testable has usually been designed
against a testing style rather than against the code that is there.

## The SwiftUI case

The procedure above meets one hard case here: **a decision taken inside `body` is
observable only by rendering the view**, which pushes it up to the level this
file just called a costume.

The seam is not a testing tool. It is where the decision lives.

| The view | The model it reads |
|---|---|
| Reads values and describes what is on screen | Holds the decision — what is enabled, what is shown, what the next step is |
| Proven by a journey test, once | Proven as a value, with no view at all |

**Move the decision out of `body` and into the `@Observable` model the view
already reads.** The spec then states the criterion as a value — "with an empty
draft, `canSend` is false" — rather than as a journey somebody has to run on
every commit.

Where the project does not work this way, say so and put the criterion at the
journey level. The spec describes this codebase, not a better one.

## Protocol or concrete

| Reach for a protocol when | Reach for a concrete type when |
|---|---|
| Two implementations genuinely ship — a real one and a test one is **not** two | The dependency is a value, a store you can point at a temporary location, or a client you can point at a stub |
| The boundary is one the project already draws | Faking it would mean re-implementing behaviour the real type already has correctly |

The second column is the one usually skipped. A protocol whose only conformances
are `Thing` and `FakeThing` has bought indirection and sold nothing — and the
fake is now a second implementation that can drift from the first without any
test noticing.

## What gets faked

**Fake what you do not own and cannot make deterministic:** the network, the
clock, the file system when the test would race, anything asking a person for
permission.

**Do not fake what you own.** A faked store that returns what the test wants
proves the test agrees with itself. Point the real store at a temporary location
instead.

**Never fake the thing under test.** Obvious written down, common in practice —
usually as a "partial mock" of the type whose behaviour is the requirement.

## Concurrency in the verification section

Three specifics worth naming in a spec, because each is a real failure this
platform produces and none is covered by "it is tested":

| Name it when | The criterion |
|---|---|
| The feature dedupes in-flight work | Two concurrent callers produce **one** unit of work, and both get its result |
| The feature can be cancelled | Cancellation is cooperative — the criterion is that the work *stops*, not that cancel was called |
| The feature crosses an isolation boundary | State read before a suspension point is re-checked after it |

Each is a success criterion with a number or a count in it. That is why they
belong in the spec rather than in a testing guide.

## What this file must not do

- **No opinions about the project's testing framework.** Whatever the test target
  uses is what the spec names — it arrives as a grounding fact, not a preference.
- **No requirement that a seam be added.** If the code has no seam and the
  feature does not need one, the spec says the behaviour is covered at the
  journey level and why. An invented refactor is out of scope for a spec.
- **No coverage targets.** A percentage is a number that proves nothing, which is
  exactly what the measurable-criterion rule forbids.
