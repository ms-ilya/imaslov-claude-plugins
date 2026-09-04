# Maintainer tooling — appstore-guideline-auditor

Nothing here is installed. The marketplace entry points at
`plugins/appstore-guideline-auditor`, so this directory never reaches anyone who
installs the plugin. It is kept out of the plugin deliberately: the plugin ships
only what an audit runs.

## `selftest.sh`

```bash
bash .dev/appstore-guideline-auditor/selftest.sh
```

Builds throwaway Xcode-shaped fixtures in a temp directory and asserts the
collector, the catalogue gate and the findings validator behave on them. No
network and no Xcode needed — a `pbxproj` is a text file and the collector reads
it as one.

Run it before and after any change to `scripts/`. Every case in it was a real
defect found by auditing a real project, and each shared one signature: the tool
reported something it had not established.

- A project one directory below the audited path, whose Info.plist and
  entitlements "were missing" while both sat on disk.
- A target using Xcode's generated Info.plist, reported as having none of the
  usage descriptions it declares in `INFOPLIST_KEY_*` build settings.
- A sticker pack told there was "nothing App Review would see".
- An unresolved substrate reported as an empty one, which promotes to a PROVEN
  critical finding about a key that is present.
- A findings document citing a rule that does not exist, at a guideline number
  in a section Apple does not have, passing validation cleanly.

The fixtures that originally found those were built by hand and thrown away, so
nothing stopped the next edit from reintroducing them. That is what this file
prevents.

## `VALIDATION-2026-09-04.md`

The record of the first end-to-end run against a real project, and the source of
the defect list above. Kept as evidence of what was measured and when — the
numbers in it describe version 1.0.0, not the current plugin.
