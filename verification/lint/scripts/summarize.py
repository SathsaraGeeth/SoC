#!/usr/bin/env python3
"""
Summarize lint results from all tools.
Scans build/lint/ directories and produces a summary report.
"""

import os
import re
import sys
from pathlib import Path

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "../../.."))
BUILD_DIR = os.path.join(ROOT, "build/lint")


def count_slang_issues(logfile: str) -> dict:
    """Count slang issues by severity."""
    counts = {"error": 0, "warning": 0, "note": 0}
    if not os.path.exists(logfile):
        return counts
    with open(logfile, "r") as f:
        for line in f:
            if "error:" in line.lower() and "warning:" not in line.lower():
                counts["error"] += 1
            elif "warning:" in line.lower():
                counts["warning"] += 1
            elif "note:" in line.lower():
                counts["note"] += 1
    return counts


def count_verilator_issues(logfile: str) -> dict:
    """Count Verilator issues."""
    counts = {"error": 0, "warning": 0}
    if not os.path.exists(logfile):
        return counts
    with open(logfile, "r") as f:
        for line in f:
            if "%Error" in line:
                counts["error"] += 1
            elif "%Warning" in line:
                counts["warning"] += 1
    return counts


def count_verible_issues(logfile: str) -> dict:
    """Count Verible issues."""
    counts = {"error": 0, "warning": 0}
    if not os.path.exists(logfile):
        return counts
    with open(logfile, "r") as f:
        for line in f:
            if ": Fatal: " in line:
                counts["error"] += 1
            elif ": " in line and line.strip().endswith(("-", "+")):
                counts["warning"] += 1
    return counts


def count_yosys_issues(logfile: str) -> dict:
    """Count Yosys issues."""
    counts = {"error": 0, "warning": 0}
    if not os.path.exists(logfile):
        return counts
    with open(logfile, "r") as f:
        for line in f:
            if "ERROR:" in line:
                counts["error"] += 1
            elif "Warning:" in line:
                counts["warning"] += 1
    return counts


def main():
    targets = ["chip", "core", "noc", "memory", "uart"]
    tools = ["slang", "verilator", "verible", "yosys"]
    counters = {
        "slang": count_slang_issues,
        "verilator": count_verilator_issues,
        "verible": count_verible_issues,
        "yosys": count_yosys_issues,
    }

    print("=" * 70)
    print("LINT SUMMARY REPORT")
    print("=" * 70)
    print(f"{'Target':<10}", end="")
    for tool in tools:
        print(f"{tool + ' err':<12} {tool + ' warn':<12}", end="")
    print()
    print("-" * 70)

    for target in targets:
        print(f"{target:<10}", end="")
        for tool in tools:
            logfile = os.path.join(BUILD_DIR, tool, target, "lint.log")
            counts = counters[tool](logfile)
            print(f"{counts['error']:<12} {counts['warning']:<12}", end="")
        print()

    print("=" * 70)
    print("Legend: err = errors, warn = warnings")
    print("=" * 70)


if __name__ == "__main__":
    main()