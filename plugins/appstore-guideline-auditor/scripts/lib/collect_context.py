# ABOUTME: Reads an Xcode project once — targets, plists, entitlements, manifests, sources — and writes the context outside it.
#
# Four properties this must have:
#
#   It writes nothing into the audited project. The audit allows itself exactly
#   one created path there — the report, written at the end by the skill. Every
#   file this produces goes to a scratch directory OUTSIDE the project, because a
#   git-ignored temp file is still a file created in a tree the audit promised
#   not to touch. The iOS review plugin in this repo writes its temp files inside
#   the project it reviews; that pattern is deliberately not borrowed.
#
#   It enumerates every shipping target separately. ITMS-91053 is evaluated per
#   target, so a scan that reads only the app target misses the entire class of
#   blocker that motivated the privacy-manifest rules. A widget extension is a
#   separate product from Apple's side and gets its own row here.
#
#   It never reports a substrate it could not read as a substrate that is empty.
#   `info_plist_keys: null` means "not read"; `[]` means "read, and the key is
#   genuinely not there". Only the second can support an absence finding:
#   absence findings are graded PROVEN, so an Info.plist the collector merely
#   failed to locate must not look like one that declares nothing. Every
#   substrate therefore carries a `*_source` field saying how it was
#   established, and the privacy manifest follows the same rule.
#
#   It does not say which target compiles or bundles a file. Membership lives
#   in build phases and synchronised folders, which this collector does not
#   parse. Source files and the project's privacy manifests are therefore
#   written once, in project.json, as facts about the project, and a manifest it
#   could not tie to a target by location is reported as unattributed, never as
#   absent.

import json
import os
import plistlib
import re
import subprocess
import sys

SHIPPING_PRODUCT_TYPES = {
    "com.apple.product-type.application": "app",
    "com.apple.product-type.app-extension": "app-extension",
    "com.apple.product-type.extensionkit-extension": "app-extension",
    "com.apple.product-type.application.watchapp": "watch-app",
    "com.apple.product-type.application.watchapp2": "watch-app",
    "com.apple.product-type.watchkit-extension": "app-extension",
    "com.apple.product-type.watchkit2-extension": "app-extension",
    # App Review sees all three of these. A sticker pack is a whole App Store
    # product on its own, so treating it as non-shipping told the developer of a
    # sticker-pack app that there was "nothing App Review would see".
    "com.apple.product-type.application.on-demand-install-capable": "app-clip",
    "com.apple.product-type.app-extension.messages": "app-extension",
    "com.apple.product-type.app-extension.messages-sticker-pack": "app-extension",
}

NON_SHIPPING_PRODUCT_TYPES = {
    "com.apple.product-type.bundle.unit-test": "test",
    "com.apple.product-type.bundle.ui-testing": "ui-test",
    "com.apple.product-type.framework": "framework",
    "com.apple.product-type.library.static": "library",
    "com.apple.product-type.library.dynamic": "library",
    "com.apple.product-type.bundle": "bundle",
}

# The 8 cross-platform families devsemih's table names, with its detection
# markers. Auditing these projects is out of scope; RECOGNISING them is not,
# because the alternative is reading one as native and emitting confident
# findings from a scan that could not see where the real configuration lives.
CROSS_PLATFORM = [
    ("Flutter", ["pubspec.yaml", "lib/main.dart", "ios/Runner"]),
    ("Expo", ["app.config.js", "eas.json"]),
    ("React Native", ["metro.config.js"]),
    ("Kotlin Multiplatform", ["iosApp", "shared/build.gradle.kts"]),
    (".NET MAUI", ["Platforms/iOS"]),
    ("Cordova/Ionic", ["config.xml", "ionic.config.json", "platforms/ios"]),
    ("Capacitor", ["capacitor.config.ts", "capacitor.config.json", "ios/App"]),
    ("Unity", ["ProjectSettings/ProjectVersion.txt", "Assets/Scenes"]),
]

SOURCE_SUFFIXES = (".swift", ".m", ".mm", ".h")
SKIP_DIRS = {".git", "Pods", "Carthage", "build", "DerivedData", ".build", "node_modules", ".appstore-audit"}


def detect_cross_platform(root):
    """Returns (framework, marker, note).

    `framework` is set when this is one of the 8 out-of-scope families. `note`
    is set when a check could not run: a package.json that cannot be read is not
    evidence that the project is native, so the caller reports it as a degraded
    scan instead of letting the project pass as native unremarked.
    """
    for name, markers in CROSS_PLATFORM:
        for marker in markers:
            if os.path.exists(os.path.join(root, marker)):
                return name, marker, None
    # React Native declares itself in package.json rather than by a unique file.
    package = os.path.join(root, "package.json")
    if os.path.exists(package):
        unread = ("package.json at the scanned root could not be read as a JSON object ({}), "
                  "so its dependencies were not checked for React Native, Expo or Capacitor")
        try:
            with open(package, encoding="utf-8") as fh:
                data = json.load(fh)
        except (OSError, ValueError) as exc:
            return None, None, unread.format(exc)
        if not isinstance(data, dict):
            return None, None, unread.format(f"top level is a {type(data).__name__}")
        deps = {}
        for section in ("dependencies", "devDependencies"):
            if isinstance(data.get(section), dict):
                deps.update(data[section])
        if "expo" in deps:
            return "Expo", "package.json dependency 'expo'", None
        if "react-native" in deps:
            return "React Native", "package.json dependency 'react-native'", None
        if "@capacitor/core" in deps:
            return "Capacitor", "package.json dependency '@capacitor/core'", None
    return None, None, None


def find_pbxproj(root):
    for entry in sorted(os.listdir(root)):
        if entry.endswith(".xcodeproj"):
            candidate = os.path.join(root, entry, "project.pbxproj")
            if os.path.exists(candidate):
                return candidate
    for dirpath, dirnames, _ in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for d in sorted(dirnames):
            if d.endswith(".xcodeproj"):
                candidate = os.path.join(dirpath, d, "project.pbxproj")
                if os.path.exists(candidate):
                    return candidate
    return None


def load_pbxproj(path):
    """Returns (doc, mode, why_not_plutil).

    pbxproj is an old-style plist. plutil converts it; without a conversion we
    parse the subset we need by hand rather than failing, because a non-macOS
    run should degrade rather than stop. The reason is returned because the
    causes need different fixes: a missing plutil is the machine, a plutil that
    rejects the file is the project.
    """
    try:
        out = subprocess.run(
            ["plutil", "-convert", "json", "-o", "-", path],
            capture_output=True, timeout=30,
        )
    except FileNotFoundError:
        return None, "regex", "plutil is not installed"
    except subprocess.TimeoutExpired:
        return None, "regex", "plutil did not finish converting the project file within 30 seconds"
    if out.returncode != 0:
        said = (out.stderr or out.stdout).decode("utf-8", "replace").strip().splitlines()
        return None, "regex", ("plutil could not convert the project file"
                               + (f" ({said[0]})" if said else ""))
    try:
        return json.loads(out.stdout), "plutil", None
    except json.JSONDecodeError as exc:
        return None, "regex", f"plutil's conversion of the project file was not valid JSON ({exc})"


def targets_via_plist(doc):
    objects = doc.get("objects", {})
    configs = {k: v for k, v in objects.items() if v.get("isa") == "XCBuildConfiguration"}
    lists = {k: v for k, v in objects.items() if v.get("isa") == "XCConfigurationList"}
    found = []
    for obj in objects.values():
        if obj.get("isa") != "PBXNativeTarget":
            continue
        product_type = obj.get("productType", "")
        settings = {}
        clist = lists.get(obj.get("buildConfigurationList"), {})
        for config_id in clist.get("buildConfigurations", []):
            config = configs.get(config_id, {})
            # Release wins where the two disagree: it is what ships.
            if config.get("name", "").lower() == "release":
                settings = {**settings, **config.get("buildSettings", {})}
            else:
                settings = {**config.get("buildSettings", {}), **settings}
        found.append({"name": obj.get("name", "?"), "productType": product_type, "buildSettings": settings})
    return found


def targets_via_regex(text):
    found = []
    for block in re.finditer(
        r"isa = PBXNativeTarget;(.*?)\n\t\t\};", text, re.S
    ):
        body = block.group(1)
        name = re.search(r"\n\t\t\tname = \"?([^\";\n]+)\"?;", body)
        ptype = re.search(r"productType = \"?([^\";\n]+)\"?;", body)
        found.append({
            "name": name.group(1) if name else "?",
            "productType": ptype.group(1) if ptype else "",
            "buildSettings": {},
        })
    # Build settings are not reliably attributable to a target without resolving
    # the configuration list, which this path does not do. Every target therefore
    # comes back with no settings at all, and the run is marked degraded — which
    # in turn leaves every substrate unread rather than empty, so no absence
    # finding can be built on top of a parse that did not read them.
    return found


def read_plist(path):
    try:
        with open(path, "rb") as fh:
            return plistlib.load(fh)
    except Exception:
        return None


def resolve(srcroot, root, value):
    """Resolves a build-setting path.

    Build settings are relative to SRCROOT — the .xcodeproj's parent — and NOT
    to the directory the scan was pointed at. The two are the same only when the
    project sits at the top of the scanned tree; they differ for every project
    under `ios/`, `App/` or a monorepo package, where a path joined onto the
    scan root names a file that does not exist while the real one sits a
    directory away.

    The scan root is still tried as a fallback, because a project laid out in
    some way neither of us anticipated is better read than not read.
    """
    if not value:
        return None
    value = value.strip('"')
    for token in ("$(SRCROOT)/", "$(PROJECT_DIR)/", "${SRCROOT}/", "${PROJECT_DIR}/"):
        value = value.replace(token, "")
    for base in (srcroot, root):
        candidate = os.path.normpath(os.path.join(base, value))
        if os.path.exists(candidate):
            return candidate
    return None


INFOPLIST_KEY_PREFIX = "INFOPLIST_KEY_"
GENERATION_SUFFIX = "_Generation"
TRUTHY = {"YES", "Yes", "yes", "1", "true", "TRUE"}


def keys_from_build_settings(settings):
    """Info.plist keys declared as build settings rather than in a file.

    Since Xcode 13, `GENERATE_INFOPLIST_FILE = YES` is the default for a new
    target and its Info.plist is synthesised from `INFOPLIST_KEY_<key>` build
    settings. A target that declares NSCameraUsageDescription this way HAS
    declared it. Reading only the file on disk reports a fully compliant app as
    missing every usage description it has — at critical severity, graded PROVEN,
    because a missing key looks exactly like a key that was never declared.

    `INFOPLIST_KEY_UILaunchScreen_Generation = YES` is Xcode's instruction to
    synthesise the `UILaunchScreen` dictionary, so it is recorded under the key
    it produces rather than under its own name.
    """
    keys = {}
    for name, value in settings.items():
        if not name.startswith(INFOPLIST_KEY_PREFIX):
            continue
        key = name[len(INFOPLIST_KEY_PREFIX):]
        if key.endswith(GENERATION_SUFFIX):
            if value not in TRUTHY:
                continue
            key = key[:-len(GENERATION_SUFFIX)]
        keys[key] = value
    return keys


def read_info_plist(srcroot, root, settings):
    """Resolves a target's Info.plist substrate.

    Returns (path, keys, source, note). `keys` is None whenever the substrate
    could not be read — that is the value an absence clause must refuse to act
    on. An empty dict means the substrate was read and holds nothing, which is
    a fact a finding may rest on.
    """
    declared = settings.get("INFOPLIST_FILE")
    generated = settings.get("GENERATE_INFOPLIST_FILE") in TRUTHY
    build_keys = keys_from_build_settings(settings)

    path = resolve(srcroot, root, declared) if declared else None

    if declared and path is None:
        return (None, None, "unresolved",
                f"INFOPLIST_FILE is set to {declared!r} but no such file was found; "
                "the plist may exist somewhere this collector did not look")

    file_keys = None
    if path is not None:
        data = read_plist(path)
        if data is None:
            return (path, None, "unreadable",
                    "the Info.plist was found but could not be parsed")
        file_keys = dict(data)

    if file_keys is not None and build_keys:
        return (path, {**file_keys, **build_keys}, "file+build-settings", None)
    if file_keys is not None:
        return (path, file_keys, "file", None)
    if generated or build_keys:
        # Xcode synthesises the whole plist from these settings, so this is a
        # complete substrate rather than a partial one.
        return (None, build_keys, "build-settings", None)
    return (None, None, "undeclared",
            "the target names no INFOPLIST_FILE and sets no INFOPLIST_KEY_* build "
            "settings; its plist keys may be defined in an .xcconfig this collector "
            "does not evaluate")


def find_named(root, filename):
    hits = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        if filename in filenames:
            hits.append(os.path.join(dirpath, filename))
    return hits


def collect_sources(root):
    out = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if name.endswith(SOURCE_SUFFIXES):
                out.append(os.path.relpath(os.path.join(dirpath, name), root))
    return sorted(out)


def find_suffixed(root, suffix):
    """Prunes with `dirnames[:]`, like the other two walks.

    SKIP_DIRS must be matched against directory names below the scan root,
    never against the absolute path: an ancestor ABOVE the root — a checkout
    that happens to live under `build/` or `Pods/` — would otherwise exclude
    the entire project and return an empty list that reads as "none exist".
    """
    hits = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        for name in filenames:
            if name.endswith(suffix):
                hits.append(os.path.join(dirpath, name))
    return sorted(hits)


def build(root):
    root = os.path.abspath(root)
    framework, marker, package_note = detect_cross_platform(root)
    project_notes = [package_note] if package_note else []
    if framework:
        return {
            "project": root,
            "in_scope": False,
            "out_of_scope_reason": "cross-platform-framework",
            "framework": framework,
            "marker": marker,
        }

    pbxproj = find_pbxproj(root)
    if not pbxproj:
        return {"project": root, "in_scope": False, "out_of_scope_reason": "no-xcode-project"}

    doc, mode, why_not_plutil = load_pbxproj(pbxproj)
    if why_not_plutil:
        project_notes.insert(0, f"{why_not_plutil}, so build settings could not be attributed "
                                "per target and every substrate is reported as unread")
    if doc is not None:
        raw = targets_via_plist(doc)
    else:
        with open(pbxproj, encoding="utf-8", errors="replace") as fh:
            raw = targets_via_regex(fh.read())

    # SRCROOT is the .xcodeproj's parent, which is what every path-valued build
    # setting is relative to. It is the scan root only when the project happens
    # to sit at the top of the tree that was handed to us.
    srcroot = os.path.dirname(os.path.dirname(pbxproj))

    sources = collect_sources(root)
    all_manifests = find_named(root, "PrivacyInfo.xcprivacy")
    all_entitlements = find_suffixed(root, ".entitlements")
    xcconfigs = find_suffixed(root, ".xcconfig")

    shipping, skipped = [], []
    for target in raw:
        kind = SHIPPING_PRODUCT_TYPES.get(target["productType"])
        if kind is None:
            skipped.append({
                "name": target["name"],
                "kind": NON_SHIPPING_PRODUCT_TYPES.get(target["productType"], "unknown"),
                "productType": target["productType"],
            })
            continue
        settings = target["buildSettings"]
        info, plist_keys, plist_source, plist_note = read_info_plist(srcroot, root, settings)

        declared_ent = settings.get("CODE_SIGN_ENTITLEMENTS")
        ent = resolve(srcroot, root, declared_ent) if declared_ent else None
        if declared_ent and ent is None:
            ent_source, ent_note = "unresolved", (
                f"CODE_SIGN_ENTITLEMENTS is set to {declared_ent!r} but no such file was found"
            )
        elif ent is not None:
            ent_source, ent_note = "file", None
        else:
            ent_source, ent_note = "undeclared", None

        # A target's own directory is the best available scope for its manifest
        # when the build settings do not name one.
        scope = os.path.dirname(info) if info else None
        manifest = None
        for candidate in all_manifests:
            if scope and os.path.dirname(candidate) == scope:
                manifest = candidate
                break
        if manifest is None and len(all_manifests) == 1 and kind == "app":
            manifest = all_manifests[0]
        # Neither match above reads Copy Bundle Resources membership, so a
        # target left without one has not been shown to lack a manifest: it may
        # sit in a subdirectory, or beside a plist Xcode generates and never
        # writes to disk. Absence is established for a target only when the
        # project holds no manifest at all.
        if manifest is not None:
            manifest_source = "file"
        elif all_manifests:
            manifest_source = "unattributed"
        else:
            manifest_source = "none-in-project"

        notes = [n for n in (plist_note, ent_note) if n]
        if xcconfigs and not settings:
            notes.append(
                "this target's build settings could not be read and the project uses "
                ".xcconfig files, which this collector does not evaluate"
            )
        shipping.append({
            "name": target["name"],
            "kind": kind,
            "product_type": target["productType"],
            "bundle_id": settings.get("PRODUCT_BUNDLE_IDENTIFIER"),
            "deployment_target": settings.get("IPHONEOS_DEPLOYMENT_TARGET"),
            "device_family": settings.get("TARGETED_DEVICE_FAMILY"),
            "info_plist": os.path.relpath(info, root) if info else None,
            # None means NOT READ. [] means read and empty. Only the second is
            # evidence of absence; see the module header.
            "info_plist_keys": sorted(plist_keys) if plist_keys is not None else None,
            "info_plist_source": plist_source,
            "entitlements": os.path.relpath(ent, root) if ent else None,
            "entitlements_source": ent_source,
            # None is "no manifest" only when the source is none-in-project.
            "privacy_manifest": os.path.relpath(manifest, root) if manifest else None,
            "privacy_manifest_source": manifest_source,
            "substrate_notes": notes,
            "build_settings": {k: v for k, v in settings.items() if isinstance(v, str)},
        })

    if not shipping:
        # A run with nothing to audit must not look like a run that found nothing
        # wrong. Silence is the auditor's most dangerous output: a developer who
        # gets an empty report concludes they are compliant, when the truth is
        # that the project could not be read. Distinguish the two causes, because
        # the fixes are different — one is a broken project file, the other is
        # pointing the tool at the wrong directory.
        unknown = [t for t in skipped if t["kind"] == "unknown"]
        if not raw:
            reason, detail = "unreadable-project", (
                "no native target could be read from the Xcode project. The pbxproj may be "
                "malformed, or in a format this parser does not handle."
            )
        elif unknown:
            # "Only tests, frameworks or libraries" is a claim about what the
            # targets ARE. It may not be made about a product type this table
            # does not recognise, because the honest statement is that the
            # collector did not know what it was looking at.
            reason, detail = "unrecognised-product-types", (
                f"{len(skipped)} target(s) found and {len(unknown)} of them carry a product "
                "type this collector does not recognise, so it cannot say whether App Review "
                "would see them: "
                + ", ".join(f"{t['name']} ({t['productType'] or 'no product type'})" for t in unknown)
            )
        else:
            reason, detail = "no-shipping-targets", (
                f"{len(skipped)} target(s) found, none of them shipping — only tests, "
                "frameworks or libraries. There is nothing App Review would see."
            )
        return {
            "project": root,
            "in_scope": False,
            "out_of_scope_reason": reason,
            "detail": detail,
            "pbxproj": os.path.relpath(pbxproj, root),
            "parse_mode": mode,
            "parse_degraded": bool(project_notes),
            "parse_degraded_reasons": degraded_reasons(project_notes, []),
            "shipping_targets": [],
            "skipped_targets": skipped,
        }

    return {
        "project": root,
        "in_scope": True,
        "pbxproj": os.path.relpath(pbxproj, root),
        "parse_mode": mode,
        "parse_degraded": bool(project_notes) or any(t["substrate_notes"] for t in shipping),
        "parse_degraded_reasons": degraded_reasons(project_notes, shipping),
        "shipping_targets": shipping,
        "skipped_targets": skipped,
        "sources": sources,
        "source_count": len(sources),
        "all_privacy_manifests": [os.path.relpath(p, root) for p in all_manifests],
        "all_entitlements": [os.path.relpath(p, root) for p in all_entitlements],
        "xcconfig_files": [os.path.relpath(p, root) for p in xcconfigs],
        "package_manifests": [
            os.path.relpath(p, root)
            for name in ("Package.swift", "Podfile", "Cartfile")
            for p in find_named(root, name)
        ],
    }


def degraded_reasons(project_notes, shipping):
    """Why this run is weaker than a clean one, in the reader's words.

    A degraded flag with no reason tells a developer their report is worth less
    without telling them what to fix, so every reason names the target it is
    about, or says what about the project as a whole could not be read.
    """
    reasons = list(project_notes)
    for target in shipping:
        for note in target["substrate_notes"]:
            reasons.append(f"{target['name']}: {note}")
    return reasons


def main(argv):
    if len(argv) < 3:
        print("usage: collect_context.py <project-root> <output-dir>", file=sys.stderr)
        return 2
    root, outdir = argv[1], argv[2]
    if not os.path.isdir(root):
        print(f"collect-context: {root} is not a directory", file=sys.stderr)
        return 2
    if os.path.abspath(outdir).startswith(os.path.abspath(root) + os.sep):
        print("collect-context: refusing to write context inside the audited project", file=sys.stderr)
        print("                 the audit creates exactly one path there, and it is the report", file=sys.stderr)
        return 2

    os.makedirs(outdir, exist_ok=True)
    context = build(root)

    with open(os.path.join(outdir, "context.json"), "w") as fh:
        json.dump(context, fh, indent=2)

    if not context["in_scope"]:
        print(f"OUT OF SCOPE: {context['out_of_scope_reason']}")
        if context.get("framework"):
            print(f"  framework: {context['framework']} (detected via {context['marker']})")
        if context.get("detail"):
            print(f"  {context['detail']}")
        for target in context.get("skipped_targets", []):
            print(f"  skipped ({target['kind']}): {target['name']}")
        for reason in context.get("parse_degraded_reasons", []):
            print(f"  DEGRADED: {reason}")
        return 0

    for target in context["shipping_targets"]:
        path = os.path.join(outdir, f"target-{re.sub(r'[^A-Za-z0-9_-]', '_', target['name'])}.json")
        with open(path, "w") as fh:
            json.dump({"target": target, "project": context["project"]}, fh, indent=2)

    # Written once, and not into the per-target files: nothing here was read as
    # belonging to a target, and a copy inside target-X.json reads as if it were.
    with open(os.path.join(outdir, "project.json"), "w") as fh:
        json.dump({key: context[key] for key in
                   ("project", "sources", "package_manifests", "all_privacy_manifests")},
                  fh, indent=2)

    print(f"IN SCOPE: {len(context['shipping_targets'])} shipping target(s), "
          f"{len(context['skipped_targets'])} skipped, {context['source_count']} source file(s)")
    for target in context["shipping_targets"]:
        keys = target["info_plist_keys"]
        plist = target["info_plist"] or f"<{target['info_plist_source']}>"
        print(f"  {target['kind']:14} {target['name']}"
              f"  plist={plist}"
              f"  keys={'UNREAD' if keys is None else len(keys)}"
              f"  manifest={target['privacy_manifest'] or '<' + target['privacy_manifest_source'] + '>'}"
              f"  entitlements={target['entitlements'] or '-'}")
    for target in context["skipped_targets"]:
        print(f"  skipped ({target['kind']}): {target['name']}")
    for reason in context["parse_degraded_reasons"]:
        print(f"  DEGRADED: {reason}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
