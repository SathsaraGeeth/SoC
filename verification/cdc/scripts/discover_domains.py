#!/usr/bin/env python3
"""Development-only clock/reset inventory for SystemVerilog source trees."""
from __future__ import annotations

import argparse
import bisect
import json
import re
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
FF_RE = re.compile(r"always_ff\s*@\s*\((.*?)\)", re.S)
EDGE_RE = re.compile(r"(pos|neg)edge\s+([A-Za-z_][\w.$\[\]]*)")
MODULE_RE = re.compile(r"\bmodule\s+([A-Za-z_]\w*)")
KNOWN_CDC = {"cdc_bit_sync", "cdc_gray_sync", "cdc_pulse_sync",
             "cdc_handshake", "async_fifo", "reset_sync"}


def filelist(path: Path, seen: set[Path] | None = None) -> list[Path]:
    seen = seen or set()
    path = path.resolve()
    if path in seen:
        return []
    seen.add(path)
    result: list[Path] = []
    for raw in path.read_text().splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line or line.startswith("+"):
            continue
        if line.startswith("-f "):
            result += filelist(ROOT / line[3:].strip(), seen)
        elif not line.startswith("-"):
            candidate = ROOT / line
            if candidate.suffix in {".sv", ".v"}:
                result.append(candidate)
    return list(dict.fromkeys(result))


def inspect(paths: list[Path]) -> dict:
    domains: dict[str, list[dict]] = defaultdict(list)
    resets: dict[str, list[dict]] = defaultdict(list)
    primitives: dict[str, list[dict]] = defaultdict(list)
    for path in paths:
        text = re.sub(r"/\*.*?\*/|//[^\n]*", "", path.read_text(), flags=re.S)
        module_sites = [(match.start(), match.group(1))
                        for match in MODULE_RE.finditer(text)]
        module_offsets = [site[0] for site in module_sites]

        def module_at(offset: int) -> str:
            index = bisect.bisect_right(module_offsets, offset) - 1
            return module_sites[index][1] if index >= 0 else "<unknown>"

        module = "<unknown>"
        for lineno, line in enumerate(text.splitlines(), 1):
            match = MODULE_RE.search(line)
            if match:
                module = match.group(1)
            for primitive in KNOWN_CDC:
                if re.search(rf"\b{primitive}\b\s*(?:#\s*\(|[A-Za-z_])", line):
                    if not re.search(rf"\bmodule\s+{primitive}\b", line):
                        primitives[primitive].append(
                            {"file": str(path.relative_to(ROOT)), "line": lineno,
                             "module": module})
        for match in FF_RE.finditer(text):
            edges = EDGE_RE.findall(match.group(1))
            line = text.count("\n", 0, match.start()) + 1
            module = module_at(match.start())
            if edges:
                clock = edges[0][1]
                domains[clock].append({"file": str(path.relative_to(ROOT)),
                                       "line": line, "module": module})
            for edge, signal in edges[1:]:
                resets[signal].append({"file": str(path.relative_to(ROOT)),
                                       "line": line, "edge": edge,
                                       "clock": edges[0][1]})
    return {"files": len(paths), "clock_domains": domains,
            "asynchronous_resets": resets, "known_primitive_instances": primitives}


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("filelist", type=Path)
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = inspect(filelist(ROOT / args.filelist))
    if args.json:
        rendered = json.dumps(report, indent=2, sort_keys=True)
    else:
        lines = [f"Files scanned: {report['files']}", "Clock expressions:"]
        for name, sites in sorted(report["clock_domains"].items()):
            lines.append(f"  {name}: {len(sites)} always_ff block(s)")
        lines.append("Asynchronous reset expressions:")
        for name, sites in sorted(report["asynchronous_resets"].items()):
            lines.append(f"  {name}: {len(sites)} always_ff block(s)")
        lines.append("Recognized CDC/RDC primitive instances:")
        if not report["known_primitive_instances"]:
            lines.append("  none")
        for name, sites in sorted(report["known_primitive_instances"].items()):
            lines.append(f"  {name}: {len(sites)} instance(s)")
        rendered = "\n".join(lines) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered)
    else:
        print(rendered, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
