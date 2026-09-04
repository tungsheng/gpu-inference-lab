#!/usr/bin/env python3
"""Validate experiment report JSON against a checked-in JSON Schema.

Only the JSON Schema keywords the report schema actually uses are implemented.
Any other keyword is a hard error rather than a silent pass, so the schema can
never claim more than this validator enforces.

Usage:
  validate_report.py --schema path/to/schema.json report.json [report.json ...]
"""

import argparse
import json
import sys
from pathlib import Path

SUPPORTED = {
    "$schema", "$id", "title", "description",
    "type", "properties", "required", "additionalProperties", "items",
    "enum", "const", "oneOf", "minimum", "maximum",
}

TYPE_CHECKS = {
    "object": lambda v: isinstance(v, dict),
    "array": lambda v: isinstance(v, list),
    "string": lambda v: isinstance(v, str),
    "boolean": lambda v: isinstance(v, bool),
    # bool is a subclass of int in Python; a JSON boolean is not a JSON number.
    "integer": lambda v: isinstance(v, int) and not isinstance(v, bool),
    "number": lambda v: isinstance(v, (int, float)) and not isinstance(v, bool),
    "null": lambda v: v is None,
}


class UnsupportedSchema(Exception):
    pass


def type_name(value):
    if value is None:
        return "null"
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, int):
        return "integer"
    if isinstance(value, float):
        return "number"
    if isinstance(value, str):
        return "string"
    if isinstance(value, list):
        return "array"
    return "object"


def validate(value, schema, path, errors):
    unsupported = set(schema) - SUPPORTED
    if unsupported:
        raise UnsupportedSchema(
            f"{path or '<root>'}: schema uses unimplemented keyword(s): "
            f"{', '.join(sorted(unsupported))}"
        )

    if "oneOf" in schema:
        branches = schema["oneOf"]
        attempts = []
        for branch in branches:
            branch_errors = []
            validate(value, branch, path, branch_errors)
            if not branch_errors:
                return
            attempts.append((branch.get("title", "?"), branch_errors))
        # Report the closest branch rather than "matched nothing", which says
        # nothing useful when the branches are whole document shapes.
        name, best = min(attempts, key=lambda a: len(a[1]))
        errors.append(
            f"{path or '<root>'}: matched none of {len(branches)} allowed shapes; "
            f"closest is {name!r}"
        )
        errors.extend(best)
        return

    if "const" in schema and value != schema["const"]:
        errors.append(f"{path or '<root>'}: expected {schema['const']!r}, found {value!r}")
        return

    if "enum" in schema and value not in schema["enum"]:
        errors.append(
            f"{path or '<root>'}: expected one of {schema['enum']!r}, found {value!r}"
        )
        return

    expected = schema.get("type")
    if expected is not None:
        allowed = [expected] if isinstance(expected, str) else list(expected)
        for name in allowed:
            if name not in TYPE_CHECKS:
                raise UnsupportedSchema(f"{path or '<root>'}: unknown type {name!r}")
        if not any(TYPE_CHECKS[name](value) for name in allowed):
            errors.append(
                f"{path or '<root>'}: expected type {'|'.join(allowed)}, "
                f"found {type_name(value)}"
            )
            return

    if isinstance(value, (int, float)) and not isinstance(value, bool):
        if "minimum" in schema and value < schema["minimum"]:
            errors.append(f"{path or '<root>'}: {value} is below minimum {schema['minimum']}")
        if "maximum" in schema and value > schema["maximum"]:
            errors.append(f"{path or '<root>'}: {value} is above maximum {schema['maximum']}")

    if isinstance(value, dict):
        properties = schema.get("properties", {})
        for name in schema.get("required", []):
            if name not in value:
                errors.append(f"{path or '<root>'}: missing required field {name!r}")
        if schema.get("additionalProperties") is False:
            for name in sorted(set(value) - set(properties)):
                errors.append(f"{path or '<root>'}: unexpected field {name!r}")
        for name, child in value.items():
            if name in properties:
                child_path = f"{path}.{name}" if path else name
                validate(child, properties[name], child_path, errors)

    elif isinstance(value, list) and "items" in schema:
        for index, child in enumerate(value):
            validate(child, schema["items"], f"{path}[{index}]", errors)


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--schema", required=True, help="path to the JSON Schema")
    parser.add_argument("reports", nargs="+", help="report JSON files to validate")
    args = parser.parse_args(argv)

    try:
        schema = json.loads(Path(args.schema).read_text())
    except (OSError, json.JSONDecodeError) as error:
        sys.stderr.write(f"Unable to read schema {args.schema}: {error}\n")
        return 2

    failed = 0
    for report in args.reports:
        try:
            document = json.loads(Path(report).read_text())
        except (OSError, json.JSONDecodeError) as error:
            sys.stderr.write(f"{report}: unable to read report: {error}\n")
            failed += 1
            continue

        errors = []
        try:
            validate(document, schema, "", errors)
        except UnsupportedSchema as error:
            sys.stderr.write(f"{args.schema}: {error}\n")
            return 2

        if errors:
            failed += 1
            for message in errors:
                sys.stderr.write(f"{report}: {message}\n")

    if failed:
        sys.stderr.write(
            f"{failed} of {len(args.reports)} report(s) failed schema validation.\n"
        )
        return 1

    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
