#!/usr/bin/env python3
"""Check reusable synchronizer RTL for required structural markers."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
CHECKS = {
    "rtl/common/cdc/cdc_bit_sync.sv": ("async_reg", "STAGES >= 2"),
    "rtl/common/cdc/cdc_gray_sync.sv": ("async_reg", "STAGES >= 2"),
    "rtl/common/reset/reset_sync.sv": ("async_reg", "STAGES >= 2"),
}

failed = False
for relative, needles in CHECKS.items():
    text = (ROOT / relative).read_text()
    missing = [needle for needle in needles if needle not in text]
    if missing:
        failed = True
        print(f"ERROR {relative}: missing {', '.join(missing)}")
    else:
        print(f"PASS  {relative}")
sys.exit(1 if failed else 0)
