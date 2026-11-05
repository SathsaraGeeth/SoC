#!/usr/bin/env python3

# Selects user tests without groovy

from __future__ import annotations

import json
import os
from pathlib import Path
import sys


def main() -> int:
    if len(sys.argv) != 2:
        print(f"usage: {sys.argv[0]} MANIFEST", file=sys.stderr)
        return 2

    requested_tier = os.environ.get("CI_SELECT_TIER", "")
    requested = {
        item.strip() for item in os.environ.get("CI_SELECT_SUITES", "").split(",") if item.strip()
    }
    tier_order = {"smoke": 0, "presubmit": 1, "nightly": 2, "weekly": 3}
    if requested_tier not in tier_order:
        print(f"Unknown CI tier {requested_tier!r}", file=sys.stderr)
        return 1

    document = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    suites = [
        suite
        for suite in document.get("suites", [])
        if suite.get("enabled", True) is not False
        and suite.get("tier") in tier_order
        and tier_order[suite["tier"]] <= tier_order[requested_tier]
        and (not requested or suite.get("id") in requested)
    ]
    found = {suite.get("id") for suite in suites}
    missing = sorted(requested - found)
    if missing:
        print(
            "Unknown, disabled, or out-of-tier suites: " + ", ".join(missing),
            file=sys.stderr,
        )
        return 1

    for suite in suites:
        print("\t".join([
            str(suite["id"]),
            str(suite.get("agent", "linux")),
            str(suite.get("timeout_minutes", 30)),
        ]))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
