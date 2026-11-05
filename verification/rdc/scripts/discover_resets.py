#!/usr/bin/env python3
"""Create an RDC-oriented reset inventory from the shared structural scan."""
from pathlib import Path
import json
import sys

HERE = Path(__file__).resolve()
sys.path.insert(0, str(HERE.parents[2] / "cdc" / "scripts"))
from discover_domains import ROOT, filelist, inspect  # noqa: E402

if len(sys.argv) != 3:
    raise SystemExit("usage: discover_resets.py FILELIST OUTPUT")
report = inspect(filelist(ROOT / sys.argv[1]))
result = {
    "files": report["files"],
    "asynchronous_resets": report["asynchronous_resets"],
    "clock_domains": {name: len(sites)
                      for name, sites in report["clock_domains"].items()},
    "reset_sync_instances":
        report["known_primitive_instances"].get("reset_sync", []),
}
output = ROOT / sys.argv[2]
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(json.dumps(result, indent=2, sort_keys=True))
print(f"RDC reset inventory: {output}")
