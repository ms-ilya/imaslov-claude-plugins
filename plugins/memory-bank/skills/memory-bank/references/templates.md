# Memory Bank File Templates

This file contains the exact templates for every file in the Memory Bank.
Follow these templates precisely. Do not add extra sections. Do not skip sections.

---

## Root-Level Files

### WIKI.md

```markdown
<!-- Last verified: YYYY-MM-DD -->

# [Project Name] — Memory Bank

> Brief project description (1-2 sentences). What the app/system does.

## How to Use This Memory Bank

1. Start here — scan the feature index below
2. Read `systemPatterns.md` for architecture overview
3. Read `techContext.md` for build/dependency info
4. Navigate to the feature folder you need

## Feature Index

| Feature | Status | Summary | Path |
|---------|--------|---------|------|
| [feature-name] | 🟢 Active / 🟡 In Progress / 🔴 Blocked / ⚪ Stable | One-line description | `feature-name/` |

## Architecture Quick Reference

- **Pattern:** [e.g., MVVM + Coordinator]
- **UI Framework:** [e.g., SwiftUI / UIKit / Mixed]
- **Concurrency:** [e.g., async/await + Combine]
- **Dependency Management:** [e.g., SPM]

> Full details: `systemPatterns.md`
```

### systemPatterns.md

```markdown
<!-- Last verified: YYYY-MM-DD -->

# System Patterns

## Architecture Overview

[Describe the overall architecture: MVVM, MVC, Clean, TCA, etc.]
[Include module/target structure if applicable]

## Module Structure

[List the main modules/targets/packages and their responsibilities]

| Module | Responsibility |
|--------|---------------|
| ... | ... |

## Key Design Patterns

[List patterns actually in use, with brief descriptions and example locations]

- **[Pattern Name]:** [What it does, where it's used, example file path]

## Navigation Patterns

[How screens/views connect: Coordinator, NavigationStack, Router, etc.]

## Naming Conventions

[Describe naming patterns observed in the codebase]

## Shared Utilities

[Key extensions, helpers, utilities that multiple features depend on]

| Utility | Location | Used By |
|---------|----------|---------|
| ... | ... | ... |
```

### techContext.md

```markdown
<!-- Last verified: YYYY-MM-DD -->

# Tech Context

## Language & Versions

- **Language:** [e.g., Swift 5.9]
- **Minimum Deployment:** [e.g., iOS 17.0 / macOS 14.0]
- **Xcode:** [e.g., 15.4+]

## Dependencies

| Dependency | Version | Purpose |
|------------|---------|---------|
| ... | ... | ... |

## Package Manager

[SPM / CocoaPods / Carthage — link to manifest file]

## Build Configuration

- **Schemes:** [List schemes]
- **Configurations:** [Debug, Release, etc.]
- **Build Phases:** [Notable custom build phases or run scripts]

## Project Structure

```
[Brief tree showing top-level directory layout]
```

## Environment Setup

[Any setup required: certificates, provisioning, API keys, environment variables, etc.]

## CI/CD

[If applicable: what runs, where, how to trigger]
```

### TROUBLESHOOTING.md (root)

```markdown
<!-- Last verified: YYYY-MM-DD -->

# Troubleshooting

## Project-Wide Issues

[Issues that affect the whole project, not tied to a specific feature]

### [Issue Title]

- **Issue:** [What goes wrong]
- **Root Cause:** [Why, if known]
- **Fix/Workaround:** [How to handle it]
- **Status:** 🔴 Open / 🟢 Resolved

## Feature-Specific Issues

See individual feature troubleshooting files:

| Feature | Path |
|---------|------|
| [feature-name] | `feature-name/TROUBLESHOOTING.md` |
```

---

## Per-Feature Files

### IMPLEMENTATION.md

```markdown
<!-- Last verified: YYYY-MM-DD -->

# [Feature Name] — Implementation

## Overview

[What this feature does — 2-3 sentences max. Be concrete.]

## Key Files

| File | Role | Path |
|------|------|------|
| ... | ... | `relative/path/to/file.swift` |

## Architecture & Data Flow

[Describe how data moves through this feature: entry point → processing → output/UI]
[Use a simple text diagram if helpful:]

```
[EntryPoint] → [Service/Manager] → [ViewModel] → [View]
```

## Key Types

| Type | Kind | Role |
|------|------|------|
| [TypeName] | class/struct/protocol/enum | [Brief role] |

## Cross-Feature Dependencies

### This feature depends on:

| Feature/Module | How | Files Involved |
|---------------|-----|----------------|
| ... | [imports/calls/delegates to] | ... |

### Depends on this feature:

| Feature/Module | How | Files Involved |
|---------------|-----|----------------|
| ... | ... | ... |

## External Dependencies

| Library | Usage in This Feature |
|---------|----------------------|
| ... | ... |

## UI Components

[If applicable — key views, their view models, layout approach]

| View | ViewModel | Description |
|------|-----------|-------------|
| ... | ... | ... |

## Testing

[Test files related to this feature, what they cover]

| Test File | What It Tests | Path |
|-----------|--------------|------|
| ... | ... | ... |
```

### ACTIVE_CONTEXT.md

```markdown
<!-- Last verified: YYYY-MM-DD -->

# [Feature Name] — Active Context

## Current State

[What's working, what's partially implemented, what's broken. Be specific.]

- **Working:** [List what functions correctly]
- **Partial:** [List what's in progress or incomplete]
- **Broken:** [List what's not working, if anything]

## In-Progress Work

[What was being actively worked on. Be specific enough that a fresh agent can pick up exactly where it left off.]

- **Task:** [What's being done]
- **Current File(s):** [Which files are being modified]
- **Where I Left Off:** [Specific point — e.g., "implemented the request builder, still need to wire up the response handler"]
- **Blockers:** [Anything blocking progress]

## Next Steps

[Concrete, actionable next tasks for this feature. Ordered by priority.]

1. [Next thing to do]
2. [Then this]
3. [Then this]

## Open Questions

[Unresolved decisions or questions. Things that need user input or further investigation.]

- [ ] [Question or uncertainty]

## Recent Insights

[Patterns, learnings, or non-obvious things discovered during recent work that would help a fresh agent.]

- [Insight]
```

### DECISIONS.md

```markdown
<!-- Last verified: YYYY-MM-DD -->

# [Feature Name] — Decisions

> This file is **user-curated only**. Decisions are added explicitly by the user.
> To add a decision: `add decision for [feature]: [description]`

## Decisions

[Decisions are listed newest-first. Each follows the ADR format below.]

---

### [Decision Title]

- **Status:** Accepted / Proposed / Superseded by [link]
- **Context:** [Why this decision was needed]
- **Decision:** [What was decided]
- **Rationale:** [Why this option was chosen]
- **Alternatives Rejected:**
  - [Option]: [Why not]
- **Consequences:** [Trade-offs and implications]
```

### TROUBLESHOOTING.md (per-feature)

```markdown
<!-- Last verified: YYYY-MM-DD -->

# [Feature Name] — Troubleshooting

## Known Issues

### [Issue Title]

- **Issue:** [What goes wrong — be specific]
- **Root Cause:** [Why, if known. Otherwise: "Under investigation"]
- **Workaround/Fix:** [How to handle it]
- **Related Files:** `path/to/file.swift`, `path/to/other.swift`
- **Status:** 🔴 Open / 🟢 Resolved

## Common Gotchas

[Things that look wrong but are intentional, or things that trip people up]

- **[Gotcha]:** [Explanation]

## Debugging Tips

[Feature-specific debugging approaches]

- [Tip]
```

---

## Writing Guidelines

These apply to ALL files:

1. **Be concrete, not vague.** Write "handles OAuth 2.0 token refresh via `TokenManager.refresh()`" — not "manages authentication."
2. **Use verified paths.** Every file path must pass the verification check.
3. **Keep it scannable.** Tables > paragraphs. Short bullets > long sentences.
4. **No history.** Never write "we changed X to Y." Just describe Y.
5. **No speculation without flags.** If uncertain, use `⚠️ INFERRED` or `⚠️ UNVERIFIED`.
6. **Feature names as folder names.** Use kebab-case for folder names: `user-profile/`, `push-notifications/`.
7. **Cross-reference with relative paths.** Link to other memory-bank files using relative paths: `../other-feature/IMPLEMENTATION.md`.
