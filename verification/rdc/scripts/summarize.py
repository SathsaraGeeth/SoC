#!/usr/bin/env python3
import json
import sys
from pathlib import Path

path = Path(sys.argv[1] if len(sys.argv) > 1 else "build/rdc/soc/resets.json")
data = json.loads(path.read_text())
print(f"files={data['files']} resets={len(data['asynchronous_resets'])} "
      f"reset_sync_instances={len(data['reset_sync_instances'])}")
