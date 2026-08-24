# TypeScript layer: test seams

**Loaded only on a TypeScript repo.** Carried into drafting through the design
record, so the spec's verification section says something true about *this*
codebase rather than something generic about testing.

Verification is a coverage category, which means a spec nobody can prove was met
is a failure of this plugin specifically. This file exists so that the
verification section names a seam that already exists.

## Contents

- [Which test, at which level](#which-test-at-which-level) · [Seams](#seams)
- [The React case](#the-react-case) · [The server-component case](#the-server-component-case)
- [What gets faked](#what-gets-faked) · [Async in the verification section](#async-in-the-verification-section)
- [What this file must not do](#what-this-file-must-not-do)

## Which test, at which level

> **Procedure: put the test at the lowest level where the behaviour is
> observable.** Not the level where it is easiest to write.

| Level | Owns | Stops owning when |
|---|---|---|
| **Unit** | a decision — a reducer, a selector, a validation schema, a formatting rule | the assertion needs a rendered tree |
| **Component** | one component's contract — given these props, this is on screen and this is callable | the assertion needs routing, a real server, or two pages |
| **Integration** | two units agreeing — a handler and its schema, a query and its cache key | the assertion needs a browser |
| **End-to-end** | a journey a person takes, in a real browser | it duplicates a decision already covered above |

**An end-to-end test asserting a computed value is a unit test wearing a
costume** — it boots the app, drives the interface and waits, to settle something
a function could answer directly. Write it once, at the top, to prove the journey
connects, and never to prove the arithmetic.

The reverse error is rarer and worse: a feature whose only risk is that two routes
do not connect, covered entirely by component tests of each route.

## Seams

> **Prefer the highest existing seam. The ideal number of new seams is one, and
> zero is better.**

Four questions, in order:

1. **Is the logic already a pure function?** Call it. Done — no seam needed.
2. **Does the repo already intercept the network** (MSW, a test server, a fetch
   mock in setup)? Add a handler. Done.
3. **Does the component already take its dependency as a prop, or read a context
   the test can wrap?** Pass a different one.
4. **Only then:** introduce a seam — and introduce exactly one.

A feature that needs three new injection points to be testable has usually been
designed against a testing style rather than against the code that is there.

**Prefer intercepting the network to injecting a client.** On this stack it is
usually the highest existing seam: it tests the real call path, the real
serialisation and the real error handling, and it does not require the production
code to grow a parameter it exists only to satisfy.

## The React case

The procedure above meets one hard case here: **a decision taken inside a
component body is observable only by rendering it**, which pushes it up to the
level this file just called a costume.

The seam is not a testing tool. It is where the decision lives.

| The component | The thing it calls |
|---|---|
| Reads values and describes what is on screen | Holds the decision — what is enabled, what is shown, what the next step is |
| Proven by a component test, once | Proven as a value, with no rendering at all |

**Move the decision out of the component and into a pure function, a reducer or a
selector the component calls.** The spec then states the criterion as a value —
"with an empty draft, `canSubmit(draft)` is false" — rather than as a render
somebody has to run on every commit.

Where the project does not work this way, say so and put the criterion at the
component level. The spec describes this codebase, not a better one.

**Query the way a user does.** Where the repo uses Testing Library, criteria are
written against role, label and visible text, not against a test id or a class
name — a criterion that survives a refactor is worth more than one that reports
every rename as a regression.

## The server-component case

A server component that is `async` and reads a database is not reachable by the
component-test tooling most repos have. Two honest options, and the spec must pick
one rather than pretend:

- **Test the data function, not the component.** Extract the query, assert on it,
  and cover the rendering at the journey level once.
- **Cover it end-to-end only**, and say so — with the reason, so the next reader
  does not assume it was an oversight.

Claiming unit coverage for something the test runner cannot render is the failure
this section exists to prevent.

## What gets faked

**Fake what you do not own and cannot make deterministic:** third-party HTTP, the
clock, randomness, anything asking a person for permission, anything charging
money.

**Do not fake what you own.** A faked repository that returns what the test wants
proves the test agrees with itself. Point the real one at a test database or an
in-memory adapter instead.

**Never fake the thing under test.** Obvious written down, common in practice —
usually as a partially mocked module whose un-mocked half is the requirement.

**Module mocking is the seam of last resort.** `vi.mock`/`jest.mock` reaches past
the boundary rather than through it, so it survives no refactor and hides the
design pressure that would otherwise have produced a real seam.

## Async in the verification section

Three specifics worth naming in a spec, because each is a real failure this stack
produces and none is covered by "it is tested":

| Name it when | The criterion |
|---|---|
| The feature dedupes in-flight work | Two concurrent callers produce **one** request, and both get its result |
| The feature can be abandoned mid-flight | A response arriving after the component unmounts, or after a newer request, **does not** overwrite current state |
| The feature retries | The retry count and the backoff are numbers in the criterion, and a permanently failing call terminates rather than retrying forever |

Each is a success criterion with a number or a count in it. That is why they
belong in the spec rather than in a testing guide.

## What this file must not do

- **No opinions about the project's test runner.** Whatever the repo uses is what
  the spec names — it arrives as a grounding fact, not a preference.
- **No requirement that a seam be added.** If the code has no seam and the feature
  does not need one, the spec says the behaviour is covered at the journey level
  and why.
- **No coverage targets.** A percentage is a number that proves nothing, which is
  exactly what the measurable-criterion rule forbids.
