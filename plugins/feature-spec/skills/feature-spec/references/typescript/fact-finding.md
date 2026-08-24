# TypeScript layer: what to ground in

**Loaded only when the stack detects as TypeScript.** On any other repo this file
is never read and none of its vocabulary appears anywhere — no questions about
server/client boundaries in a Go service, no `use client` in a pipeline spec.

This layer shapes **what grounding goes looking for**, so it is loaded before the
fact-finders are dispatched, never after. It adds no rules of its own about how
code should be written; it names the things that, on this stack, are cheaper to
look up than to ask about.

Every answer is a **fact with a citation** — "`CartProvider` is a React context
created in `app/providers.tsx:14` and consumed by nine components", at
`path:line`. "It uses context" is a summary of a fact, not one, and the interview
cannot build on it.

## Contents

- [What to look up first](#what-to-look-up-first) — seven questions, each an interview slot saved
- [The boundary that decides everything](#the-boundary-that-decides-everything) · [Type-level facts](#type-level-facts-worth-one-lookup)
- [How to ask for these](#how-to-ask-for-these) · [What this layer must not do](#what-this-layer-must-not-do) · [Dormancy](#dormancy)

## What to look up first

Each collapses a question that would otherwise cost an interview slot.

### 1. What is the runtime and the rendering model?

**Look for:** `next.config.*`, `vite.config.*`, `remix.config.*`, an `app/` versus
a `pages/` directory, `astro.config.*`, or none of these — a plain library or a
Node service.

**Why it earns a slot:** it decides whether "where does this run" is even a
question. In an `app/` router every component is a server component until a file
says `use client`, and a feature that needs a `useState` is a feature that needs a
client boundary somebody has to place. On a Vite SPA the question does not exist
and asking it wastes a slot.

### 2. Where is the server/client boundary today?

**Look for:** `'use client'` and `'use server'` directives, `getServerSideProps`,
route handlers, loaders and actions.

**Why it earns a slot:** this is the highest-blast-radius fact on the stack. It
decides where the feature's data fetch goes, whether its state can be a hook at
all, what ships in the bundle, and what a test can reach without a browser. Report
the **nearest** boundary to the feature, not the app's general shape.

### 3. Who owns the state this feature touches?

**Look for:** `useState` local to a component, a context provider, a store
(Zustand, Redux, Jotai, Valtio), a server-cache library (TanStack Query, SWR,
RTK Query), or URL search params.

**Why it earns a slot:** ownership decides where the code goes and most often
makes a proposed design impossible — a feature that must mutate state owned three
levels up is a different feature. Report the owner **and whether it is server
state or client state**, because the two have different invalidation stories and
conflating them is the most common design error on this stack.

### 4. What is the data-fetching convention?

**Look for:** `fetch` in a server component, a query library's hooks, a generated
client (tRPC, GraphQL codegen, OpenAPI), or a hand-rolled `api.ts`.

**Why it earns a slot:** it decides whether the feature's loading, error and
empty states are something the convention already gives it or something the spec
must specify. A repo on TanStack Query has answers for retry, stale time and
refetch-on-focus that a spec should cite rather than re-decide.

### 5. What persists, and where?

**Look for:** a database client and its schema (Prisma, Drizzle, Kysely),
`localStorage`/`sessionStorage`, cookies, IndexedDB, or a server holding the
source of truth.

**Why it earns a slot:** question 3 answers what holds the state while the tab is
open; this answers what survives a reload, and they are rarely the same store. It
decides whether the feature needs a migration, what it shows before data arrives,
and what it does offline.

### 6. How strict is the type checking?

**Look for:** `strict`, `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes`
in `tsconfig.json`; and whether `any` appears freely in the feature's neighbours.

**Why it earns a slot:** it decides whether "the type system enforces it" is a
verification answer or wishful thinking. Under `strict: false` a spec that leans
on non-nullability is specifying a guarantee the build does not make.

### 7. What is the validation boundary?

**Look for:** Zod, Valibot, io-ts, ArkType, or manual narrowing at the edges.

**Why it earns a slot:** TypeScript types vanish at runtime. Where a repo already
validates untrusted input, the spec cites that boundary; where it does not, "what
happens on a malformed payload" is a real open question rather than an assumed
answer, and it belongs in Failure & edge cases.

## The boundary that decides everything

On this stack one fact reorganises the whole interview, so it is worth stating
plainly once grounding returns it.

| If the feature is | Then these questions collapse | And these become real |
|---|---|---|
| Entirely server-side | state ownership, hydration, bundle cost | request lifetime, caching and revalidation, what the client is told on failure |
| Entirely client-side | request lifetime, revalidation | ownership, persistence across reload, what happens offline |
| Crossing the boundary | nothing | **all of the above, plus what is serialisable across it** |

The third row is the expensive one, and it is worth asking early which row the
feature is in — because in rows one and two, four grounding facts save four
questions, and in row three none of them do.

## Type-level facts worth one lookup

Three specifics that change what a spec can promise, each cheap to check:

| Look for | It decides |
|---|---|
| A discriminated union already modelling the feature's states | Whether "loading, loaded, error, empty" is a type the compiler enforces or four booleans that can contradict each other |
| Generated types from the API schema | Whether a contract change breaks the build, or breaks at runtime in front of a user |
| `satisfies` / branded types in the neighbourhood | Whether identity confusions (a `UserId` passed where an `OrgId` was meant) are a compile error or a bug class the spec must handle |

## How to ask for these

Give the fact-finder the questions above **verbatim and numbered**, plus the
scope path. Ask for the nearest instance to the feature, not a survey — "which
provider owns the cart state and where is it created" beats "describe the state
management architecture", which returns an essay nobody can cite.

When the repo is inconsistent, the inconsistency **is** the answer: say the
convention is mixed and cite two examples. A spec written as though one
convention held, on a repo where two do, is a spec that fails review.

## What this layer must not do

- **No opinions about the framework.** Whatever the repo uses is what the spec
  names. A preference for one router or one store is not a grounding fact.
- **No requirement to adopt anything.** If the repo has no validation boundary and
  the feature does not need one, the spec says so. An invented migration is out of
  scope for a spec.
- **No bundle-size targets.** A number nobody measures is exactly what the
  measurable-criterion rule forbids.

## Dormancy

On a repo with no `tsconfig.json`, `package.json` `types` field or `.ts` sources
in the feature's scope, this file is never loaded and the interview proceeds with
generic questions — with no apology for their absence.
