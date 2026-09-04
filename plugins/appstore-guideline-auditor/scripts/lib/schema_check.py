# ABOUTME: Validates JSON documents against the draft-07 subset this plugin's schemas actually use.
#
# Why not the jsonschema package: it is not installed, and this repo's existing
# checkers are bash plus python3 stdlib for exactly that reason. The alternative
# was to hand-write assertions about the catalogue's structure in the check
# script — which is what makes a schema file decorative. Then the schema says one
# thing, the checker enforces another, and the drift is invisible until a
# subagent emits something both would have caught separately.
#
# So the schema files stay the single source of truth and this reads them.
# The supported subset is deliberately small and is listed in SUPPORTED below;
# an unsupported keyword raises rather than being skipped, because a validator
# that silently ignores a constraint is worse than one that is absent.

import json
import re
import sys

SUPPORTED = {
    "$schema", "$id", "$ref", "title", "description", "definitions",
    "type", "enum", "const", "required", "properties", "additionalProperties",
    "items", "minItems", "minLength", "minimum", "minProperties", "pattern",
    "allOf", "if", "then",
}

TYPES = {
    "object": dict, "array": list, "string": str,
    "integer": int, "number": (int, float), "boolean": bool, "null": type(None),
}


class SchemaError(Exception):
    pass


def _is_type(value, name):
    if name == "integer":
        # bool is a subclass of int in Python; a boolean is not an integer here.
        return isinstance(value, int) and not isinstance(value, bool)
    if name == "boolean":
        return isinstance(value, bool)
    if name == "number":
        return isinstance(value, (int, float)) and not isinstance(value, bool)
    return isinstance(value, TYPES[name])


def _resolve(ref, root):
    if not ref.startswith("#/"):
        raise SchemaError(f"only local $ref is supported, got {ref!r}")
    node = root
    for part in ref[2:].split("/"):
        try:
            node = node[part]
        except (KeyError, TypeError):
            raise SchemaError(f"$ref {ref!r} does not resolve — no {part!r} in the schema")
    return node


def validate(doc, schema, root=None, path="$", errors=None):
    """Returns a list of 'path: message' strings. Empty means valid."""
    root = root if root is not None else schema
    errors = errors if errors is not None else []

    unknown = set(schema) - SUPPORTED
    if unknown:
        raise SchemaError(f"{path}: schema uses unsupported keyword(s) {sorted(unknown)}")

    if "$ref" in schema:
        return validate(doc, _resolve(schema["$ref"], root), root, path, errors)

    if "type" in schema:
        names = schema["type"] if isinstance(schema["type"], list) else [schema["type"]]
        if not any(_is_type(doc, n) for n in names):
            errors.append(f"{path}: expected {'/'.join(names)}, got {type(doc).__name__}")
            return errors

    if "const" in schema and doc != schema["const"]:
        errors.append(f"{path}: must be {schema['const']!r}, got {doc!r}")
    if "enum" in schema and doc not in schema["enum"]:
        errors.append(f"{path}: {doc!r} is not one of {schema['enum']}")

    if isinstance(doc, str):
        if "minLength" in schema and len(doc) < schema["minLength"]:
            errors.append(f"{path}: needs at least {schema['minLength']} characters, has {len(doc)}")
        if "pattern" in schema and not re.search(schema["pattern"], doc):
            errors.append(f"{path}: {doc!r} does not match {schema['pattern']}")

    if _is_type(doc, "number") and "minimum" in schema and doc < schema["minimum"]:
        errors.append(f"{path}: must be >= {schema['minimum']}, got {doc}")

    if isinstance(doc, list):
        if "minItems" in schema and len(doc) < schema["minItems"]:
            errors.append(f"{path}: needs at least {schema['minItems']} item(s), has {len(doc)}")
        if "items" in schema:
            for i, item in enumerate(doc):
                validate(item, schema["items"], root, f"{path}[{i}]", errors)

    if isinstance(doc, dict):
        for key in schema.get("required", []):
            if key not in doc:
                errors.append(f"{path}: missing required field {key!r}")
        if "minProperties" in schema and len(doc) < schema["minProperties"]:
            errors.append(f"{path}: needs at least {schema['minProperties']} field(s), has {len(doc)}")
        props = schema.get("properties", {})
        for key, value in doc.items():
            if key in props:
                validate(value, props[key], root, f"{path}.{key}", errors)
            elif schema.get("additionalProperties") is False:
                errors.append(f"{path}: unexpected field {key!r} — the schema is closed")

    for sub in schema.get("allOf", []):
        if "if" in sub:
            if not validate(doc, sub["if"], root, path, []):
                validate(doc, sub.get("then", {}), root, path, errors)
        else:
            validate(doc, sub, root, path, errors)

    return errors


def validate_file(doc_path, schema_path):
    with open(schema_path) as fh:
        schema = json.load(fh)
    try:
        with open(doc_path) as fh:
            doc = json.load(fh)
    except json.JSONDecodeError as exc:
        return [f"$: not valid JSON — {exc}"]
    return validate(doc, schema)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("usage: schema_check.py <document.json> <schema.json>", file=sys.stderr)
        sys.exit(2)
    problems = validate_file(sys.argv[1], sys.argv[2])
    for problem in problems:
        print(f"      {problem}")
    sys.exit(1 if problems else 0)
