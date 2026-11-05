#!/usr/bin/env python3
import json
import sys
from pathlib import Path

path = Path(sys.argv[1] if len(sys.argv) > 1 else "build/cdc/soc/domains.json")
data = json.loads(path.read_text())
print(f"files={data['files']} clocks={len(data['clock_domains'])} "
      f"async_resets={len(data['asynchronous_resets'])} "
      f"primitive_types={len(data['known_primitive_instances'])}")
