#!/usr/bin/env python3
"""Report reset synchronizer coverage without pretending to be signoff RDC."""
import json
import sys
from pathlib import Path

path = Path(sys.argv[1])
data = json.loads(path.read_text())
resets = data["asynchronous_resets"]
instances = data["reset_sync_instances"]
print(f"Asynchronous reset expressions: {len(resets)}")
for reset, sites in sorted(resets.items()):
    print(f"  {reset}: {len(sites)} sequential block(s)")
print(f"reset_sync instances: {len(instances)}")
if resets and not instances:
    print("NOTE: top-level reset release is not structurally synchronized by "
          "reset_sync in this target.")
