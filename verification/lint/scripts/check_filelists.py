#!/usr/bin/env python3
"""
Check filelists for consistency:
- Verify all referenced files exist
- Verify no duplicate entries
- Verify packages appear before modules
"""

import os
import re
import sys

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
FILELIST_DIR = os.path.join(ROOT, "verification/lint/filelists")


def resolve_path(path: str) -> str:
    """Resolve a relative path from the ROOT directory."""
    if path.startswith("+"):
        return None  # Compiler directive, skip
    if path.startswith("-f") or path.startswith("-F"):
        return None  # Filelist include directive
    return os.path.join(ROOT, path)


def parse_filelist(filepath: str) -> list:
    """Parse a filelist and return list of (line_no, raw_line, resolved_path)."""
    entries = []
    with open(filepath, "r") as f:
        for i, line in enumerate(f, 1):
            stripped = line.strip()
            if not stripped or stripped.startswith("#"):
                continue
            # Handle -f includes
            if stripped.startswith("-f ") or stripped.startswith("-F "):
                included = stripped.split(None, 1)[1]
                included_path = os.path.join(os.path.dirname(filepath), included)
                if os.path.exists(included_path):
                    entries.extend(parse_filelist(included_path))
                else:
                    entries.append((i, stripped, None))
                continue
            # Handle +incdir, +define, etc.
            if stripped.startswith("+"):
                entries.append((i, stripped, None))
                continue
            resolved = resolve_path(stripped)
            entries.append((i, stripped, resolved))
    return entries


def main():
    targets = ["common", "chip", "core", "noc", "memory", "uart"]
    errors = 0

    for target in targets:
        filelist = os.path.join(FILELIST_DIR, f"{target}.f")
        if not os.path.exists(filelist):
            print(f"ERROR: Filelist not found: {filelist}")
            errors += 1
            continue

        print(f"\nChecking {target}.f ...")
        entries = parse_filelist(filelist)
        seen_files = set()
        packages_before_modules = True
        seen_module = False

        for line_no, raw, resolved in entries:
            if resolved is None:
                continue
            if not os.path.exists(resolved):
                print(f"  ERROR (line {line_no}): File not found: {raw}")
                errors += 1
            if resolved in seen_files:
                print(f"  WARNING (line {line_no}): Duplicate entry: {raw}")
            seen_files.add(resolved)

            # Check package ordering
            if "_pkg.sv" in raw:
                if seen_module:
                    print(f"  WARNING (line {line_no}): Package after module: {raw}")
                    packages_before_modules = False
            else:
                seen_module = True

        print(f"  Total files referenced: {len(seen_files)}")

    if errors:
        print(f"\n{errors} error(s) found.")
        sys.exit(1)
    else:
        print("\nAll filelists look good!")
        sys.exit(0)


if __name__ == "__main__":
    main()