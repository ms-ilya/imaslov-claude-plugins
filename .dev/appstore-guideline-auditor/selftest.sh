#!/usr/bin/env bash
# ABOUTME: Builds throwaway Xcode-shaped fixtures and asserts the collector, the catalogue gate and the findings validator behave on them.
#
# Usage: selftest.sh
#
# Every case here was a real defect found by auditing a real project, and each
# one shared a signature: the tool reported something it had not established. A
# nested project whose Info.plist "was missing" while it sat on disk. A sticker
# pack told there was "nothing App Review would see". A findings document citing
# a rule that does not exist, passing validation cleanly.
#
# The fixtures that found those defects were built by hand and thrown away, so
# nothing stopped the next edit from reintroducing them. That is what this file
# is for. It needs no network and no Xcode — a pbxproj is a text file and the
# collector reads it as one.
#
# It lives outside the plugin on purpose. The installed plugin contains only
# what an audit runs; a harness that checks the plugin itself is maintainer
# tooling and does not ship to the people who install it.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN="$(cd "$HERE/../../plugins/appstore-guideline-auditor" 2>/dev/null && pwd)"
[ -n "$PLUGIN" ] || { echo "selftest: cannot find the plugin from $HERE" >&2; exit 1; }
SCRIPTS="$PLUGIN/scripts"

command -v python3 >/dev/null 2>&1 || { echo "selftest: python3 not found" >&2; exit 1; }

ROOT="$(mktemp -d "${TMPDIR:-/tmp}/appstore-selftest.XXXXXX")"
trap 'rm -rf "$ROOT"' EXIT

pass=0; fail=0
ok()   { printf '  ok    %s\n' "$1"; pass=$((pass+1)); }
bad()  { printf '  FAIL  %s\n' "$1"; shift; [ $# -gt 0 ] && printf '        %s\n' "$*"; fail=$((fail+1)); }

# assert <name> <needle> <<< haystack
assert_has() {
  if printf '%s' "$3" | grep -qF -- "$2"; then ok "$1"; else bad "$1" "expected to find: $2"; fi
}
assert_lacks() {
  if printf '%s' "$3" | grep -qF -- "$2"; then bad "$1" "should not contain: $2"; else ok "$1"; fi
}

# --------------------------------------------------------------------------
# Fixture construction. A PBXNativeTarget plus one XCBuildConfiguration is the
# smallest thing the collector will read as a target.
# --------------------------------------------------------------------------

pbxproj() {
  # pbxproj <path> <target-name> <product-type> <settings-block>
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<EOF
// !\$*UTF8*\$!
{
	archiveVersion = 1;
	objectVersion = 56;
	objects = {
		AA01 = {
			isa = PBXNativeTarget;
			buildConfigurationList = CC01;
			name = $2;
			productType = "$3";
		};
		BB01 = { isa = XCBuildConfiguration; buildSettings = { $4 }; name = Release; };
		CC01 = { isa = XCConfigurationList; buildConfigurations = ( BB01 ); };
	};
	rootObject = ZZ01;
}
EOF
}

plist() {
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>MyApp</string>
<key>NSCameraUsageDescription</key><string>To scan documents</string>
</dict></plist>
EOF
}

entitlements() {
  mkdir -p "$(dirname "$1")"
  cat > "$1" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict><key>aps-environment</key><string>development</string></dict></plist>
EOF
}

collect() { python3 "$SCRIPTS/lib/collect_context.py" "$1" "$ROOT/out/$2" 2>&1; }
field() { python3 -c "
import json,sys
d=json.load(open(sys.argv[1]))
t=(d.get('shipping_targets') or [{}])[0]
print(json.dumps(t.get(sys.argv[2], d.get(sys.argv[2]))))" "$ROOT/out/$1/context.json" "$2"; }

echo "collector"

# A project one level below the path being audited, in a checkout that itself
# lives under a directory named `build`. Two separate defects meet here and
# compound: path-valued build settings are relative to SRCROOT — the .xcodeproj's
# parent — not to the scanned root, and the entitlements walk used to match
# SKIP_DIRS against the ABSOLUTE path, so an ancestor above the root named
# `build` emptied the list for the whole project.
#
# The `build` directory must sit above the audited root, not inside it: inside,
# pruning it is correct behaviour.
WRAP="$ROOT/checkout/build/Wrapper"
NEST="$WRAP/Nested"
pbxproj "$NEST/MyApp.xcodeproj/project.pbxproj" MyApp "com.apple.product-type.application" \
  'INFOPLIST_FILE = "MyApp/Info.plist"; CODE_SIGN_ENTITLEMENTS = "MyApp/MyApp.entitlements"; TARGETED_DEVICE_FAMILY = "1,2";'
plist "$NEST/MyApp/Info.plist"
entitlements "$NEST/MyApp/MyApp.entitlements"
collect "$WRAP" nested >/dev/null
assert_has  "nested project resolves its Info.plist"   "Info.plist"      "$(field nested info_plist)"
assert_has  "nested project reads the declared keys"   "NSCameraUsageDescription" "$(field nested info_plist_keys)"
assert_has  "nested project resolves its entitlements" "entitlements"    "$(field nested entitlements)"
assert_lacks "entitlements survive a build/ ancestor"  "[]"              "$(field nested all_entitlements)"

# Xcode 13+ default: no Info.plist on disk, keys supplied as build settings.
# A collector that reads only the file reports a compliant app as missing every
# usage description it has, at critical severity, graded PROVEN.
GEN="$ROOT/generated"
pbxproj "$GEN/GenApp.xcodeproj/project.pbxproj" GenApp "com.apple.product-type.application" \
  'GENERATE_INFOPLIST_FILE = YES; INFOPLIST_KEY_NSCameraUsageDescription = "To scan"; INFOPLIST_KEY_UILaunchScreen_Generation = YES;'
collect "$GEN" generated >/dev/null
assert_has "generated plist keys are read"        "NSCameraUsageDescription" "$(field generated info_plist_keys)"
assert_has "_Generation maps to the key it makes" "UILaunchScreen"           "$(field generated info_plist_keys)"
assert_has "source says where the keys came from" "build-settings"           "$(field generated info_plist_source)"

# An INFOPLIST_FILE that names a file nobody can find is NOT an empty plist.
# null means unread; only [] can support a finding of absence.
BROKEN="$ROOT/broken"
pbxproj "$BROKEN/App.xcodeproj/project.pbxproj" App "com.apple.product-type.application" \
  'INFOPLIST_FILE = "Nowhere/Missing.plist";'
out="$(collect "$BROKEN" broken)"
assert_has "unresolved plist yields null, not []" "null"       "$(field broken info_plist_keys)"
assert_has "unresolved plist marks the run degraded" "DEGRADED" "$out"

# A sticker pack is a whole App Store product. Telling its developer there is
# "nothing App Review would see" is false in every clause.
STICKER="$ROOT/sticker"
pbxproj "$STICKER/Stickers.xcodeproj/project.pbxproj" Stickers \
  "com.apple.product-type.app-extension.messages-sticker-pack" 'PRODUCT_BUNDLE_IDENTIFIER = "com.example.s";'
out="$(collect "$STICKER" sticker)"
assert_has  "sticker pack is in scope"          "IN SCOPE"                     "$out"
assert_lacks "sticker pack not called non-shipping" "nothing App Review would see" "$out"

# A product type this table does not know is not evidence that nothing ships.
WEIRD="$ROOT/weird"
pbxproj "$WEIRD/W.xcodeproj/project.pbxproj" FutureThing "com.apple.product-type.application.not-yet-invented" ''
out="$(collect "$WEIRD" weird)"
assert_has  "unknown product type says it is unknown" "unrecognised-product-types"   "$out"
assert_lacks "unknown type not called a test target"  "only tests, frameworks"       "$out"

# A manifest the collector cannot tie to a target is not a manifest the target
# lacks. Only a project with no manifest anywhere establishes absence; a null
# path with manifests on disk has to say "unattributed", or a compliant target
# is reported as shipping none, at critical severity, graded PROVEN.
assert_has "no manifest anywhere is established absence" "none-in-project" "$(field generated privacy_manifest_source)"
MAN="$ROOT/manifests"
pbxproj "$MAN/App.xcodeproj/project.pbxproj" App "com.apple.product-type.application" \
  'GENERATE_INFOPLIST_FILE = YES;'
mkdir -p "$MAN/App/Resources" "$MAN/Widget"
: > "$MAN/App/Resources/PrivacyInfo.xcprivacy"; : > "$MAN/Widget/PrivacyInfo.xcprivacy"
: > "$MAN/App/Camera.swift"
collect "$MAN" manifests >/dev/null
assert_has "manifests on disk but untied are unattributed" "unattributed" "$(field manifests privacy_manifest_source)"
BESIDE="$ROOT/beside"
pbxproj "$BESIDE/App.xcodeproj/project.pbxproj" App "com.apple.product-type.application" \
  'INFOPLIST_FILE = "App/Info.plist";'
plist "$BESIDE/App/Info.plist"; mkdir -p "$BESIDE/Other"
: > "$BESIDE/App/PrivacyInfo.xcprivacy"; : > "$BESIDE/Other/PrivacyInfo.xcprivacy"
collect "$BESIDE" beside >/dev/null
assert_has "a manifest beside the plist is tied to the target" '"file"' "$(field beside privacy_manifest_source)"

# Source files are facts about the project: the collector reads no build phase,
# so it cannot say which target compiles which file. A copy of the list inside
# target-X.json reads as that target's sources, and an app's camera call then
# supports a PROVEN finding against a widget's Info.plist.
jsonkeys() { python3 -c "import json,sys;print(' '.join(sorted(json.load(open(sys.argv[1])))))" "$1"; }
assert_lacks "a target file carries no source list"      "sources"       "$(jsonkeys "$ROOT/out/manifests/target-App.json")"
assert_has   "sources are written once for the project"  "Camera.swift"  "$(cat "$ROOT/out/manifests/project.json")"
assert_has   "project file lists every manifest found"   "Widget/PrivacyInfo.xcprivacy" "$(cat "$ROOT/out/manifests/project.json")"

# A package.json that cannot be read is not evidence the project is native. The
# React Native, Expo and Capacitor check reads it, so the run says it was skipped.
PKG="$ROOT/badpackage"
pbxproj "$PKG/App.xcodeproj/project.pbxproj" App "com.apple.product-type.application" 'GENERATE_INFOPLIST_FILE = YES;'
printf '{ "dependencies": ' > "$PKG/package.json"
out="$(collect "$PKG" badpackage)"
assert_has "an unreadable package.json marks the run degraded" "DEGRADED: package.json" "$out"

# plutil rejecting the project file is a fault in the project, and a missing
# plutil is a fault in the machine. One message for both sends the developer to
# fix the wrong one.
REJ="$ROOT/rejected"
pbxproj "$REJ/App.xcodeproj/project.pbxproj" App "com.apple.product-type.application" 'GENERATE_INFOPLIST_FILE = YES;'
printf '}}}\n' >> "$REJ/App.xcodeproj/project.pbxproj"
out="$(collect "$REJ" rejected)"
if command -v plutil >/dev/null 2>&1; then
  assert_has "a plutil failure is reported as a failure" "plutil could not convert" "$out"
else
  assert_has "a missing plutil is reported as missing"   "plutil is not installed"  "$out"
fi

echo "scratch containment"
mkdir -p "$ROOT/precious"; echo keep > "$ROOT/precious/thesis.txt"
bash "$SCRIPTS/collect-context.sh" "$GEN" "$ROOT/precious" >/dev/null 2>&1
[ -f "$ROOT/precious/thesis.txt" ] && ok "refuses to empty a directory it did not create" \
  || bad "refuses to empty a directory it did not create" "the file was deleted"
bash "$SCRIPTS/collect-context.sh" "$GEN" "$GEN/deep/scratch" >/dev/null 2>&1
[ -e "$GEN/deep" ] && bad "creates nothing inside the audited project" "$GEN/deep was created" \
  || ok "creates nothing inside the audited project"

echo "read-only check"
# The promise is that the audit leaves the project as it found it apart from the
# report. Each case below is one way that promise can be broken, and the check
# has to name the file rather than print UNTOUCHED.
UT="$ROOT/untouched-scratch"
bash "$SCRIPTS/collect-context.sh" "$GEN" "$UT" >/dev/null 2>&1
[ -s "$UT/project-files.before" ] && ok "the collector snapshots the file list" \
  || bad "the collector snapshots the file list" "no project-files.before in the scratch directory"

untouched() { bash "$SCRIPTS/check-untouched.sh" "$GEN" "$UT" "$@" 2>&1; }

out="$(untouched)"; rc=$?
[ $rc -eq 0 ] && ok "an untouched project passes" || bad "an untouched project passes" "exit $rc: $out"

mkdir -p "$GEN/.appstore-audit"; echo report > "$GEN/.appstore-audit/report.md"
out="$(untouched)"; rc=$?
[ $rc -eq 0 ] && ok "the report itself is not a violation" || bad "the report itself is not a violation" "exit $rc: $out"

echo stray > "$GEN/stray.txt"
out="$(untouched)"; rc=$?
[ $rc -eq 1 ] && ok "a created file fails the check" || bad "a created file fails the check" "exit $rc"
assert_has "a created file is named" "created  ./stray.txt" "$out"
rm "$GEN/stray.txt"

VICTIM="$(cd "$GEN" && find . -type f -name '*.pbxproj' | head -1)"
touch -t 203001010000 "$GEN/$VICTIM"
out="$(untouched)"; rc=$?
[ $rc -eq 1 ] && ok "a changed file fails the check" || bad "a changed file fails the check" "exit $rc"
assert_has "a changed file is named" "changed  $VICTIM" "$out"

mv "$GEN/$VICTIM" "$ROOT/victim.moved"
out="$(untouched)"
assert_has "a deleted file is named" "deleted  $VICTIM" "$out"
mv "$ROOT/victim.moved" "$GEN/$VICTIM"; touch "$GEN/$VICTIM"

out="$(untouched --report "$ROOT/elsewhere/report.md")"; rc=$?
[ $rc -eq 1 ] && ok "a report redirected elsewhere does not excuse the default path" \
  || bad "a report redirected elsewhere does not excuse the default path" "exit $rc"

rm "$UT/project-files.before"
untouched >/dev/null 2>&1; rc=$?
[ $rc -eq 2 ] && ok "a missing snapshot is an error, not a pass" || bad "a missing snapshot is an error, not a pass" "exit $rc"
rm -rf "$GEN/.appstore-audit"

echo "catalogue gate"
out="$(bash "$SCRIPTS/check-catalogue.sh" 2>&1)"
assert_has "shipped catalogue is clean" "CATALOGUE OK" "$out"

# Apple retires numbers by marking them "Intentionally omitted" while keeping
# their lettered sub-clauses. The index keeps the longest body per number, so a
# parser that drops the parenthetical lets a longer sibling overwrite the
# retirement and the drift goes unreported.
GL="$ROOT/guidelines.md"
python3 - "$GL" "$PLUGIN" <<'PY'
import json, glob, os, sys
out, plugin = sys.argv[1], sys.argv[2]
cited = {r['guideline'] for p in glob.glob(os.path.join(plugin, 'rules', '*.json'))
         for r in json.load(open(p))['rules'] if r.get('guideline')}
lines = ["# App Review Guidelines", ""]
for n in sorted(cited, key=lambda s: [int(x) for x in s.split('.')]):
    lines += [f"- **{n} Clause {n}**", f"  Body for {n}."]
lines += ["- **5.1.1(i) Data Collection and Storage**",
          "  A sub-clause body deliberately longer than its parent's, which is the shape "
          "that used to overwrite the parent entry and lose its omitted flag.",
          "- **5.1.1(ii) Permission**", "  Another sub-clause body.", ""]
open(out, "w").write("\n".join(lines))
PY
out="$(bash "$SCRIPTS/check-catalogue.sh" --guideline-text "$GL" 2>&1)"
assert_has "every citation resolves against the text" "CATALOGUE OK" "$out"
assert_has "the citation layer ran"                   "guideline citation(s) checked" "$out"

RETIRED="$ROOT/retired.md"
python3 -c "
import sys
t = open(sys.argv[1]).read().replace('- **5.1.1 Clause 5.1.1**\n  Body for 5.1.1.',
                                     '- **5.1.1** Intentionally omitted.')
open(sys.argv[2], 'w').write(t)" "$GL" "$RETIRED"
out="$(bash "$SCRIPTS/check-catalogue.sh" --guideline-text "$RETIRED" 2>&1)"
assert_has "a retired clause with sub-clauses is caught" "intentionally omitted" "$out"

# The retrieved text is a model's reproduction of Apple's page and can come back
# cut short. Every clause it lost then looks like a rule whose number drifted,
# so a text that cannot be the whole page is not judged: the citations are
# unverified, and no rule is reported as wrongly cited.
CUT="$ROOT/cut.md"
python3 -c "
import sys
keep = [l for l in open(sys.argv[1]).read().split('\n- **') if not l.startswith(('4.', '5.'))]
open(sys.argv[2], 'w').write('\n- **'.join(keep))" "$GL" "$CUT"
out="$(bash "$SCRIPTS/check-catalogue.sh" --guideline-text "$CUT" 2>&1)"
assert_has   "a cut-off text leaves citations unverified" "citations NOT verified" "$out"
assert_lacks "a cut-off text is not reported as drift"    "wrong-citation"         "$out"

# The text is passed as an argument because a leading VAR=value assignment puts
# the command outside the skill's permission rule. A mistyped option must not
# run the gate without the citation layer and report the catalogue clean.
out="$(bash "$SCRIPTS/check-catalogue.sh" --guideline_text "$GL" 2>&1)"
assert_has "an unknown option is refused, not read as a rule file" "unknown option" "$out"

echo "findings validator"
mk() { printf '%s' "$2" > "$ROOT/$1.json"; }
mk good '{"category":"legal","status":"completed","checklist":[],"findings":[{"rule":"privacy-manifest-absent","guideline":"5.1.1","severity":"critical","verifiability":"PROVEN","target":"App","file":"App","absence":true,"issue":"No privacy manifest in this target","evidence":"no PrivacyInfo.xcprivacy under App/","resolutions":["Add a PrivacyInfo.xcprivacy to the App target"],"citations":[{"source":"guidelines","state":"verified"}]}]}'
mk invented '{"category":"legal","status":"completed","checklist":[],"findings":[{"rule":"totally-invented-rule-id","guideline":"7.9.9(z)","severity":"critical","verifiability":"PROVEN","target":"App","file":"App/A.swift","line":42,"issue":"An issue no catalogue rule describes","evidence":"let x = 1","absence":false,"resolutions":["Do the thing that resolves it"],"citations":[{"source":"guidelines","state":"verified"}]}]}'
mk drifted '{"category":"legal","status":"completed","checklist":[],"findings":[{"rule":"privacy-manifest-absent","guideline":"1.2.3","severity":"suggestion","verifiability":"PROVEN","target":"App","file":"App","absence":true,"issue":"No privacy manifest in this target","evidence":"no PrivacyInfo.xcprivacy","resolutions":["Add a PrivacyInfo.xcprivacy"],"citations":[{"source":"guidelines","state":"verified"}]}]}'
mk manual '{"category":"legal","status":"completed","checklist":[],"findings":[{"rule":"privacy-policy-url-absent","guideline":"5.1.1","severity":"critical","verifiability":"PROVEN","target":"App","file":"App","absence":true,"issue":"No privacy policy URL was found","evidence":"nothing","resolutions":["Add a privacy policy URL"],"citations":[{"source":"catalogue","state":"unverified"}]}]}'
mk noline '{"category":"legal","status":"completed","checklist":[],"findings":[{"rule":"app-transport-security-disabled","guideline":"5.1.1","severity":"warning","verifiability":"PROVEN","target":"App","file":"App/Info.plist","absence":false,"issue":"Arbitrary loads are allowed","evidence":"NSAllowsArbitraryLoads = true","resolutions":["Remove NSAllowsArbitraryLoads"],"citations":[{"source":"guidelines","state":"verified"}]}]}'

expect() {  # expect <name> <file> <pass|refuse>
  if bash "$SCRIPTS/validate-findings.sh" "$ROOT/$2.json" >/dev/null 2>&1; then got=pass; else got=refuse; fi
  [ "$got" = "$3" ] && ok "$1" || bad "$1" "expected $3, got $got"
}
expect "a well-formed finding is accepted"          good     pass
expect "an invented rule id is refused"             invented refuse
expect "a drifted guideline and severity is refused" drifted  refuse
expect "a MANUAL rule emitted as a finding is refused" manual refuse
expect "PROVEN without a line is refused"           noline   refuse

mk withheld '{"category":"legal","status":"completed","checklist":[],"findings":[],"withheld":[{"rule":"privacy-manifest-absent","target":"Widget","reason":"privacy_manifest_source is unreadable-project"}],"uncatalogued":["A hard-coded review prompt on first launch"]}'
mk statusnote '{"category":"legal","status":"completed: withheld privacy-manifest-absent","checklist":[],"findings":[]}'
expect "a withheld rule and an uncatalogued note are accepted" withheld pass
expect "a note written into status is refused"       statusnote refuse

# A policy page that was fetched and checked by nothing is "retrieved". Without
# that state the only words left for it are verified, which it is not, and
# unverified, which says it was never fetched.
mk retrieved '{"category":"legal","status":"completed","checklist":[],"findings":[{"rule":"privacy-manifest-absent","guideline":"5.1.1","severity":"critical","verifiability":"PROVEN","target":"App","file":"App","absence":true,"issue":"No privacy manifest in this target","evidence":"no PrivacyInfo.xcprivacy anywhere in the project","resolutions":["Add a PrivacyInfo.xcprivacy to the App target"],"citations":[{"source":"guidelines","state":"verified"},{"source":"policy","state":"retrieved"}]}]}'
expect "a retrieved policy source is accepted"       retrieved pass

# A category whose agent wrote nothing has no file. Named, it is refused; the
# skill names all five for that reason.
expect "a findings file that does not exist is refused" never-written refuse

# With a category's rules file missing, its findings would be refused as citing
# invented rules. The cause is the installation, and the message has to say so.
mkdir -p "$ROOT/partial-rules"; cp "$PLUGIN/rules/legal.json" "$ROOT/partial-rules/"
out="$(python3 "$SCRIPTS/lib/check_findings.py" "$ROOT/good.json" "$ROOT/partial-rules" 2>&1)" && got=pass || got=refuse
[ "$got" = refuse ] && ok "an incomplete catalogue is refused" || bad "an incomplete catalogue is refused" "expected refuse, got $got"
assert_has "an incomplete catalogue names the missing file" "safety.json does not exist" "$out"

echo
if [ $fail -eq 0 ]; then
  echo "$pass check(s) passed"
else
  echo "$fail of $((pass+fail)) check(s) FAILED"
fi
exit $((fail > 0))
